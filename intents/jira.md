# Zenith — Jira Integration
# Handlers: INTENT_JIRA_CREATE, INTENT_JIRA_VIEW, INTENT_JIRA_LIST, INTENT_JIRA_UPDATE, INTENT_JIRA_TRANSITION, INTENT_JIRA_ASSIGN, INTENT_JIRA_BRANCH, INTENT_JIRA_CLOSE, INTENT_JIRA_DELETE
# Read by ZENITH.md Step 4 router. See references/jira-ops.md for Jira API patterns and config.

### INTENT_JIRA_CREATE

Parse Jira config:
```bash
_gcfg() { awk -F'[="]+' '/^[[:space:]]*'"$1"'[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' ~/.zenith/.global-config 2>/dev/null; }
_rcfg() { awk -F'[="]+' '/^[[:space:]]*'"$1"'[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "$REPO_ROOT/.agent-config" 2>/dev/null; }
jira_url=$(_gcfg jira_url)
jira_email=$(_gcfg jira_email)
_stored_token=$(_gcfg jira_api_token)
[ -n "$_stored_token" ] && JIRA_API_TOKEN="$_stored_token"
jira_project=$(_rcfg jira_project)
```

If `jira_url`, `jira_email`, or `JIRA_API_TOKEN` empty → run global Jira setup (see references/jira-ops.md). If `jira_project` empty → run repo Jira setup. After setup, continue.

Build auth header:
```bash
JIRA_AUTH=$(printf '%s:%s' "$jira_email" "$JIRA_API_TOKEN" | base64 | tr -d '\n')
```

Fetch valid issue types for this project:
```bash
PROJECT_META=$(curl -s -H "Authorization: Basic $JIRA_AUTH" "{jira_url}/rest/api/3/project/{jira_project}")
VALID_TYPES=$(echo "$PROJECT_META" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -v "^$")
```

Determine issue type from the user's request, but only if it appears in `VALID_TYPES` (case-insensitive):
- "epic" → Epic
- "bug" or "defect" → Bug
- "task" → Task
- "story" → Story
- anything else, or no type specified → use the first non-Epic type in `VALID_TYPES` as the default

If the inferred type is not in `VALID_TYPES`, or type is ambiguous: print the valid types and ask:
```
  issue type ({valid_types_comma_separated}):
```

Ask for required fields:
```
  summary:
```

Ask for optional fields (user can press enter to skip):
```
  parent epic key (e.g. AIE-42, or enter to skip):
  description (or enter to skip):
```

For Epic type: do not ask for parent epic key.

Use `jira_project` as the project key unless user explicitly specified a different project in the request.

Show preview and confirm:
```
creating ticket — {jira_project}
│ type:    {issue_type}
│ summary: {ticket_summary}
│ epic:    {ticket_key} (omit line if no epic)
│ desc:    {description} (omit line if no description)

Create? [y/n]
```

Build JSON payload per references/jira-ops.md JSON Payload Patterns. Omit `parent` if no epic key. Omit `description` if skipped.

Execute:
```bash
BODY=$(curl -s -X POST \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "Content-Type: application/json" \
  -d '{payload}' \
  "{jira_url}/rest/api/3/issue")   # CMD_JIRA_CREATE
```

Check for error:
```bash
echo "$BODY" | grep -q '"errorMessages"\|"errors"'
```
If error found, print error in pipe format and stop.

Parse ticket key:
```bash
TICKET_KEY=$(echo "$BODY" | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4)
```

Print:
```
  ✓ {ticket_key}  {ticket_summary}
    {jira_url}/browse/{ticket_key}
```

next: "next: run /zenith jira branch to create a branch for {ticket_key}"

---

### INTENT_JIRA_VIEW

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Extract ticket key from request using pattern `[A-Z]+-[0-9]+`. If not found, ask: "Ticket key (e.g. AIE-123):"

Execute:
```bash
BODY=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_GET
```

Check for error. If HTTP 404 pattern found: "ticket not found — {ticket_key} does not exist in {jira_url}". Stop.

Parse fields:
```bash
SUMMARY=$(echo "$BODY" | grep -o '"summary":"[^"]*"' | head -1 | cut -d'"' -f4)
STATUS=$(echo "$BODY" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
ISSUE_TYPE=$(echo "$BODY" | grep -o '"name":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
ASSIGNEE=$(echo "$BODY" | grep -o '"displayName":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -z "$ASSIGNEE" ] && ASSIGNEE="unassigned"
```

Print:
```
{ticket_key} — {SUMMARY}
│ type:     {ISSUE_TYPE}
│ status:   {STATUS}
│ assignee: {ASSIGNEE}

  {jira_url}/browse/{ticket_key}
```

next: "next: run /zenith jira transition to move status, or /zenith jira branch to start work"

---

### INTENT_JIRA_LIST

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Determine project: extract `[A-Z]+` project prefix from request if specified (e.g. "my INFRA tickets"), otherwise use `jira_project`.

Build JQL:
```
assignee = currentUser() AND project = {project} AND statusCategory != Done ORDER BY updated DESC
```

Execute:
```bash
BODY=$(curl -s -X POST \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "Content-Type: application/json" \
  -d "{\"jql\":\"{jql}\",\"fields\":[\"summary\",\"status\",\"assignee\",\"issuetype\"],\"maxResults\":20}" \
  "{jira_url}/rest/api/3/search/jql")   # CMD_JIRA_SEARCH
```

Check for error.

If no issues returned:
```
no open tickets — none assigned to you in {project}
│ tickets with status Done are excluded
```
Stop.

Print table — one line per issue, pipe-separated:
```
{project} tickets — assigned to you
│ {ticket_key}  {issue_type}  {status}  {summary}
│ {ticket_key}  {issue_type}  {status}  {summary}
│ ...
```

next: "next: run /zenith jira view {first_ticket_key} for details"

---

### INTENT_JIRA_UPDATE

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Extract ticket key from request. If not found, ask: "Ticket key (e.g. AIE-123):"

Fetch current values:
```bash
BODY=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_GET
```

Check for error.

Parse current summary and description. Show current values and ask what to change:
```
updating {ticket_key}
│ current summary: {SUMMARY}

  new summary (enter to keep):
  new description (enter to keep):
```

If user leaves both empty: "nothing changed — no updates made". Stop.

Build payload containing only the fields the user changed:
- Summary changed: `{"fields":{"summary":"{new_summary}"}}`
- Description changed: use ADF format from references/jira-ops.md
- Both changed: combine both fields in one payload

Show confirmation:
```
updating — {ticket_key}
│ summary: {new_summary} (or "unchanged")
│ description: updated (or "unchanged")

Update? [y/n]
```

Execute:
```bash
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "Content-Type: application/json" \
  -d '{payload}' \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_UPDATE
```

If `STATUS_CODE` is not 204: print error and stop.

Print: `  ✓ {ticket_key} updated`

next: "next: run /zenith jira view {ticket_key} to confirm"

---

### INTENT_JIRA_TRANSITION

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Extract ticket key from request. If not found, ask: "Ticket key (e.g. AIE-123):"

Fetch current status:
```bash
BODY=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_GET
```

Parse `CURRENT_STATUS` from response.

Fetch available transitions:
```bash
TRANSITIONS=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}/transitions")   # CMD_JIRA_TRANSITIONS
```

Map user's words to target transition name (case-insensitive):
- "in progress", "start", "working", "begin" → "In Progress"
- "in review", "review", "pr", "under review" → "In Review"
- "done", "close", "complete", "finish", "resolve" → "Done"
- "to do", "backlog", "reopen", "open" → "To Do"

If no target found in the request, list available transitions and ask: "Move to:"

Find matching transition ID from `$TRANSITIONS` response (case-insensitive name match).

If no match: "transition not available — {target} is not a valid transition for {ticket_key} in its current state ({CURRENT_STATUS})". Stop.

Preview:
```
moving ticket — {ticket_key}
│ {CURRENT_STATUS} → {TARGET_STATUS}

Confirm? [y/n]
```

Execute:
```bash
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"transition":{"id":"{TRANSITION_ID}"}}' \
  "{jira_url}/rest/api/3/issue/{ticket_key}/transitions")   # CMD_JIRA_TRANSITION
```

If not 204: print error and stop.

Print: `  ✓ {ticket_key}  {CURRENT_STATUS} → {TARGET_STATUS}`

next: if TARGET_STATUS is "In Progress" → "next: run /zenith jira branch to create a branch for this ticket"
      if TARGET_STATUS is "Done" → "next: run /zenith cleanup branches to remove the feature branch"
      otherwise → "next: run /zenith jira view {ticket_key} to confirm"

---

### INTENT_JIRA_ASSIGN

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Extract ticket key from request. If not found, ask: "Ticket key (e.g. AIE-123):"

Determine assignee:
- If request says "assign to me", "take", "claim", or similar: call CMD_JIRA_ME to get own `accountId` and `displayName`
- Otherwise: ask "Assign to (name or email):" → call CMD_JIRA_USER_SEARCH with that query

If user search returns multiple results: show numbered list and ask which one.
If user search returns zero results: "no users found matching '{query}'". Stop.

Preview:
```
assigning ticket — {ticket_key}
│ to: {DISPLAY_NAME}

Confirm? [y/n]
```

Execute:
```bash
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"accountId":"{ACCOUNT_ID}"}' \
  "{jira_url}/rest/api/3/issue/{ticket_key}/assignee")   # CMD_JIRA_ASSIGN
```

If not 204: print error and stop.

Print: `  ✓ {ticket_key} assigned to {DISPLAY_NAME}`

next: "next: run /zenith jira view {ticket_key} to confirm"

---

### INTENT_JIRA_BRANCH

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Extract ticket key from request. If not found, ask: "Ticket key (e.g. AIE-123):"

Fetch ticket summary:
```bash
BODY=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_GET
```

Check for error.

Parse `SUMMARY`. Slugify:
```bash
SLUG=$(echo "$SUMMARY" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//' | cut -c1-40)
BRANCH_NAME="{ticket_key}-$SLUG"
```

Check current repo state: must be on `{base_branch}` or have a clean working tree. If on a feature branch with uncommitted changes, stop:
```
cannot create branch — uncommitted changes exist
│ commit or stash your changes first, then run /zenith jira branch again
```

If on a feature branch (clean), ask: "Create {BRANCH_NAME} from {base_branch}? This will switch you to {base_branch} first. [y/n]"

Preview:
```
creating branch — from {base_branch}
│ branch: {BRANCH_NAME}
│ ticket: {ticket_key} {SUMMARY}

Create? [y/n]
```

Execute branch creation and push (same sequence as INTENT_START_NEW):
```bash
git fetch origin                            # CMD_FETCH_ORIGIN
git checkout {base_branch}
git pull --rebase origin {base_branch}      # CMD_PULL_REBASE
git checkout -b {BRANCH_NAME}
git push -u origin {BRANCH_NAME}            # CMD_PUSH_SET_UPSTREAM
```

Print:
```
  ✓ branch  {BRANCH_NAME}
  ✓ pushed  origin/{BRANCH_NAME}
```

Jira's GitHub integration will auto-link this branch to {ticket_key} (branch name contains the ticket key pattern).

next: "next: start coding — your branch is ready at {BRANCH_NAME}"

---

### INTENT_JIRA_CLOSE

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Extract ticket key from request. If not found, ask: "Ticket key (e.g. AIE-123):"

Fetch current state:
```bash
BODY=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_GET
```

Parse `SUMMARY` and `CURRENT_STATUS`.

If already Done (or equivalent closed status):
```
already closed — {ticket_key}
│ current status: {CURRENT_STATUS}
```
Stop.

Fetch transitions:
```bash
TRANSITIONS=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}/transitions")   # CMD_JIRA_TRANSITIONS
```

Find transition with name matching "Done" (case-insensitive). If not found: "cannot close — no 'Done' transition available for {ticket_key} in its current state". Stop.

Preview:
```
closing ticket — {ticket_key}
│ {SUMMARY}
│ {CURRENT_STATUS} → Done

Close? [y/n]
```

Execute:
```bash
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"transition":{"id":"{TRANSITION_ID}"}}' \
  "{jira_url}/rest/api/3/issue/{ticket_key}/transitions")   # CMD_JIRA_TRANSITION
```

If not 204: print error and stop.

Print: `  ✓ {ticket_key} closed`

next: "next: run /zenith cleanup branches to remove the feature branch if you're done"

---

### INTENT_JIRA_DELETE

Parse Jira config (same block as INTENT_JIRA_CREATE). Build `$JIRA_AUTH`.

Extract ticket key from request. If not found, ask: "Ticket key (e.g. AIE-123):"

Fetch ticket to show what will be deleted:
```bash
BODY=$(curl -s \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_GET
```

Check for error.

Parse `SUMMARY` and `CURRENT_STATUS`.

Warn and require explicit confirmation — do not use [y/n]:
```
deleting ticket — this cannot be undone
│ {ticket_key}: {SUMMARY}
│ status: {CURRENT_STATUS}
│ this permanently removes the ticket from Jira

  type the ticket key to confirm:
```

Read user input. If it does not match `{ticket_key}` exactly: "cancelled — ticket key did not match". Stop.

Execute:
```bash
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  -H "Authorization: Basic $JIRA_AUTH" \
  "{jira_url}/rest/api/3/issue/{ticket_key}")   # CMD_JIRA_DELETE
```

If not 204: print error and stop.

Print: `  ✓ {ticket_key} deleted`

next: "next: run /zenith jira list to see remaining tickets"
