# Jira Operations

Specifications for Jira ticket management used by `INTENT_JIRA_CREATE`, `INTENT_JIRA_VIEW`, `INTENT_JIRA_LIST`, `INTENT_JIRA_UPDATE`, `INTENT_JIRA_TRANSITION`, `INTENT_JIRA_ASSIGN`, `INTENT_JIRA_BRANCH`, `INTENT_JIRA_CLOSE`, and `INTENT_JIRA_DELETE`.

See references/common-commands.md for command patterns (`CMD_JIRA_CREATE`, `CMD_JIRA_GET`, `CMD_JIRA_UPDATE`, `CMD_JIRA_DELETE`, `CMD_JIRA_TRANSITIONS`, `CMD_JIRA_TRANSITION`, `CMD_JIRA_ASSIGN`, `CMD_JIRA_SEARCH`, `CMD_JIRA_ME`, `CMD_JIRA_USER_SEARCH`).

---

## Config Storage

Jira config is split by scope:

**Global** — stored in `~/.zenith/.global-config` under `[jira]`, shared across all repos:
```ini
[jira]
jira_url = "https://your-org.atlassian.net"
jira_email = "you@company.com"
jira_api_token = "your-api-token"
```

**Repo** — stored in `.agent-config` under `[jira]`, sets the default project for this repo:
```ini
[jira]
jira_project = "AIE"
```

---

## First-Time Jira Setup

Two independent triggers — both can fire in sequence on first use.

**Global setup** — triggered when `jira_url` is missing from `~/.zenith/.global-config`:

```
jira setup — one-time credential configuration
│ saved globally and reused across all repos

  atlassian URL [your-org.atlassian.net]:
  email [{git_email}]:
  api token (https://id.atlassian.net/manage-profile/security/api-tokens):
```

Pre-fill email prompt with `git config user.email`. If user presses enter without typing, use the pre-filled value.

Write to `~/.zenith/.global-config`:
```bash
mkdir -p ~/.zenith
cat >> ~/.zenith/.global-config <<EOF

[jira]
jira_url = "https://{jira_host}"
jira_email = "{jira_email}"
jira_api_token = "{jira_api_token}"
EOF
```

**Repo setup** — triggered when `jira_project` is missing from `.agent-config`:

```
jira repo setup — set the default project for this repo
│ credentials already configured

  jira project key (e.g. AIE, INFRA, PLAT):
```

Append to `.agent-config`:
```bash
cat >> "$REPO_ROOT/.agent-config" <<EOF

[jira]
jira_project = "{jira_project}"
EOF
```

After both setups complete (or whichever ran), print:
```
  ✓ jira ready — {jira_url}, project {jira_project}
```

---

## Parsing Jira Config

Parse at the start of every Jira handler, after Step 1:

```bash
# From global config
jira_url=$(grep "jira_url" ~/.zenith/.global-config 2>/dev/null | cut -d'"' -f2)
jira_email=$(grep "jira_email" ~/.zenith/.global-config 2>/dev/null | cut -d'"' -f2)
_stored_token=$(grep "jira_api_token" ~/.zenith/.global-config 2>/dev/null | cut -d'"' -f2)
[ -n "$_stored_token" ] && JIRA_API_TOKEN="$_stored_token"

# From repo config
jira_project=$(grep "jira_project" "$REPO_ROOT/.agent-config" 2>/dev/null | cut -d'"' -f2)
```

If `jira_url` or `jira_email` or `JIRA_API_TOKEN` is empty: trigger global setup.
If `jira_project` is empty: trigger repo setup.

`JIRA_API_TOKEN` env var is honoured as a fallback — if nothing is stored in global config but the env var is set, it will be used. This supports CI environments and power users who prefer not to store the token on disk.

---

## API Token Check

After parsing, if `JIRA_API_TOKEN` is still empty:
```
blocked — jira API token not set
│ run /zenith jira setup to configure credentials
```
Stop.

---

## Auth Header Pattern

All Jira API calls use HTTP Basic auth. Construct the header once per handler:

```bash
JIRA_AUTH=$(printf '%s:%s' "{jira_email}" "$JIRA_API_TOKEN" | base64 | tr -d '\n')
```

Use as: `-H "Authorization: Basic $JIRA_AUTH"`

---

## Issue Hierarchy

```
Epic    → multi-sprint features, workstreams, milestones
  Story → sprint-sized work (≤2 weeks), user-facing
    Task  → hours to days, implementation work
    Bug   → engineering defects
```

All are issue types in Jira. Stories, Tasks, and Bugs link to an Epic via the `parent` field.

---

## JSON Payload Patterns

**Epic (no parent):**
```json
{
  "fields": {
    "project": {"key": "AIE"},
    "summary": "{ticket_summary}",
    "issuetype": {"name": "Epic"}
  }
}
```

**Story / Task / Bug with optional parent epic and description:**
```json
{
  "fields": {
    "project": {"key": "AIE"},
    "summary": "{ticket_summary}",
    "issuetype": {"name": "{issue_type}"},
    "parent": {"key": "{ticket_key}"},
    "description": {
      "type": "doc",
      "version": 1,
      "content": [{"type": "paragraph", "content": [{"type": "text", "text": "{description}"}]}]
    }
  }
}
```

Omit `parent` if no epic key provided. Omit `description` if user skipped it.

**Update payload (summary only):**
```json
{"fields": {"summary": "{ticket_summary}"}}
```

**Update payload (description only):**
```json
{"fields": {"description": {"type": "doc", "version": 1, "content": [{"type": "paragraph", "content": [{"type": "text", "text": "{description}"}]}]}}}
```

---

## Parsing JSON Responses

Use `grep -o` and `cut` to extract fields without requiring `jq`:

```bash
# Extract ticket key from create response
TICKET_KEY=$(echo "$BODY" | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4)

# Extract summary
SUMMARY=$(echo "$BODY" | grep -o '"summary":"[^"]*"' | head -1 | cut -d'"' -f4)

# Extract status name
STATUS=$(echo "$BODY" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

# Extract account ID (for assign-to-me)
ACCOUNT_ID=$(echo "$BODY" | grep -o '"accountId":"[^"]*"' | head -1 | cut -d'"' -f4)

# Extract transition ID by name (case-insensitive match)
TRANSITION_ID=$(echo "$BODY" | grep -B1 '"In Progress"' | grep '"id"' | head -1 | cut -d'"' -f4)
```

Check for error response:
```bash
echo "$BODY" | grep -q '"errorMessages"\|"errors"'
```

---

## Branch Naming Convention

Branches created from Jira tickets: `{ticket_key}-{slug}`

Slugify the ticket summary:
- Lowercase
- Spaces and special characters → hyphens
- Remove all characters except `a-z`, `0-9`, `-`
- Truncate to 40 characters
- Strip leading/trailing hyphens

Examples:
- `AIE-123-add-protein-sequence-query`
- `AIE-456-fix-umap-render-bug`
- `AIE-789-build-metagenomic-atlas`

Jira's GitHub integration scans branch names for `[A-Z]+-[0-9]+` and links automatically.

---

## Status Transitions

Fetch available transitions before executing — transition IDs vary per project:

```bash
# CMD_JIRA_TRANSITIONS
TRANSITIONS=$(curl -s -H "Authorization: Basic $JIRA_AUTH" \
  "https://czi.atlassian.net/rest/api/3/issue/{ticket_key}/transitions")
```

Match user intent to transition name (case-insensitive):

| User says | Match transition name |
|-----------|----------------------|
| in progress / start / working | "In Progress" |
| in review / review / pr | "In Review" |
| done / close / complete | "Done" |
| to do / backlog / reopen | "To Do" |

---

## Error Patterns

| HTTP code | Meaning | Response |
|-----------|---------|----------|
| 401 | Invalid token or email | Check JIRA_API_TOKEN and jira_email in .agent-config |
| 403 | No permission | Check project permissions in Jira admin |
| 404 | Ticket or project not found | Verify ticket key and jira_project |
| 204 | Success (update/delete/transition) | No body — treat as success |
| 201 | Success (create) | Parse `key` from body |

Surface errors using pipe format:
```
jira request failed — {HTTP_CODE}
│ {extracted errorMessages or errors from response}
│ {specific fix based on error code}
```
