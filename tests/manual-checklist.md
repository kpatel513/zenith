# Manual Test Checklist

Run these in a real monorepo with Zenith installed. Cover each situation before merging changes to `zenith.md`.

For each test: describe the repo state to get into the situation, run the `/zenith` phrase, verify the expected behavior.

---

## Situation S1 — Clean, on base branch, up to date

**Setup:** `git checkout main && git pull`

| Phrase | Expected |
|--------|----------|
| `/zenith start new feature called user auth` | Creates `feature/user-auth`, pushes it, prints branch/folder info |
| `/zenith help` | Prints the two-column help table, no git operations run |
| `/zenith what did I change` | Reports no changes |
| `/zenith how behind am I` | Reports 0 commits behind |
| `/zenith save my work` | Blocks: "You are on main. Create a feature branch first." |

---

## Situation S2 — Clean, on base branch, behind remote

**Setup:** `git checkout main`, then have a teammate push a commit to main before you pull.

| Phrase | Expected |
|--------|----------|
| `/zenith start new feature` | Pulls main first, then branches — does NOT branch from stale commit |

---

## Situation S3 — On feature branch, clean, up to date

**Setup:** On a feature branch with no uncommitted changes, up to date with main.

| Phrase | Expected |
|--------|----------|
| `/zenith what did I change` | Reports no changes |
| `/zenith how behind am I` | Reports 0 commits behind main |
| `/zenith what changed today` | Shows teammate commits to main in last 24 hours (or "nothing") |
| `/zenith continue my work` | Shows recent branches list |
| `/zenith scope check` | Reports clean |

---

## Situation S4 — On feature branch, clean, behind main

**Setup:** On a feature branch; teammate has pushed commits to main that you don't have.

| Phrase | Expected |
|--------|----------|
| `/zenith how behind am I` | Shows list of commits you're missing |
| `/zenith sync with main` | Fetches, shows incoming commits, rebases, confirms sync |
| `/zenith push` | Syncs with main first, then pushes |

---

## Situation S5 — On feature branch, uncommitted changes

**Setup:** Edit a file inside your `project_folder/` without staging it.

| Phrase | Expected |
|--------|----------|
| `/zenith what did I change` | Shows changed files with line counts |
| `/zenith scope check` | Shows files inside/outside project folder |
| `/zenith save my work "add login endpoint"` | Runs contamination check, stages, shows what will be committed, confirms, commits |
| `/zenith sync with main` | Blocks: "You have uncommitted changes. Save or discard them first." |
| `/zenith start new feature` | Blocks: "You have uncommitted changes. Save or discard them first." |

**Also test with a file edited outside `project_folder/`:**

| Phrase | Expected |
|--------|----------|
| `/zenith save my work` | Shows contamination warning, asks include or exclude |
| `/zenith scope check` | Lists outside files separately, flags them |

---

## Situation S6 — On feature branch, staged changes

**Setup:** `git add <file>` without committing.

| Phrase | Expected |
|--------|----------|
| `/zenith what's staged` | Shows staged files grouped by folder with line counts |
| `/zenith save` | Shows what will be committed, confirms, commits |

---

## Situation S7 — Detached HEAD

**Setup:** `git checkout <commit-hash>` to enter detached HEAD.

| Phrase | Expected |
|--------|----------|
| `/zenith continue my work` | Detects detached HEAD (S7), shows recovery path |

---

## Situation S8 — Mid-rebase

**Setup:** Start a rebase that hits a conflict, leave it in mid-rebase state.

| Phrase | Expected |
|--------|----------|
| `/zenith sync` | Detects S8, shows options to continue or abort |

---

## Situation S9 — Mid-merge

**Setup:** Start a merge that hits a conflict, leave it in mid-merge state.

| Phrase | Expected |
|--------|----------|
| `/zenith sync` | Detects S9, shows options to continue or abort |

---

## Safety Rules

These must be verified explicitly on each release.

### Block commits on base branch
**Setup:** `git checkout main`, make a change.

| Phrase | Expected |
|--------|----------|
| `/zenith save my work` | Blocks with: "You are on main. Create a feature branch first." |
| `/zenith push` | Blocks with: "You are on main. Create a feature branch first." |

### Discard requires "YES" not "y"
**Setup:** Have uncommitted changes.

| Input | Expected |
|-------|----------|
| `/zenith throw away changes` → type `y` | Cancelled, no changes made |
| `/zenith throw away changes` → type `yes` | Cancelled, no changes made |
| `/zenith throw away changes` → type `YES` | Changes discarded |

### Amend pushed commit shows warning only
**Setup:** Commit and push to a feature branch.

| Phrase | Expected |
|--------|----------|
| `/zenith fix commit message` | Shows warning about history rewriting, prints manual commands to run, stops — does NOT amend automatically |

### Conflict outside project_folder stops rebase
**Setup:** Get into a conflict state where the conflicted file is outside your `project_folder/`.

| Phrase | Expected |
|--------|----------|
| `/zenith sync` | Stops with: "this file is not in {project_folder}/. do not resolve this yourself. contact the owner of this file." Does NOT auto-resolve. |

### Conflict inside project_folder offers resolution choice
**Setup:** Get into a conflict state where the conflicted file is inside your `project_folder/`.

| Phrase | Expected |
|--------|----------|
| `/zenith sync` | Shows both versions, asks "keep yours / keep incoming / I will edit manually [y/i/e]" |

---

## Intent Disambiguation

Same phrase in different situations should produce different behavior.

| Phrase | Situation | Expected |
|--------|-----------|----------|
| `/zenith push` | S5 (uncommitted changes) | Asks for commit message, then syncs and pushes |
| `/zenith push` | S3 (clean, nothing ahead of main) | Blocks: "Nothing to push." |
| `/zenith push` | S4 (behind main) | Syncs first, then pushes |
| `/zenith continue my work` | S1 (on main) | Lists recent branches |
| `/zenith continue my work` | S5 (on feature branch) | Checks out chosen branch, shows what's new on main |

---

---

## INTENT_REVIEW_PR — Author Mode

**Setup:** On a feature branch with an open PR (`gh pr create` already run).

| Phrase | Expected |
|--------|----------|
| `/zenith review my PR` | Runs 3-pass review on current branch's open PR diff; all three passes present; each concern has line citation, failure scenario, alternative, and question |
| `/zenith self-review` | Same as above |
| `/zenith review my changes` | Runs 3-pass review against `{base_branch}` diff (no open PR required); signals section present |

**Setup:** On `{base_branch}` (e.g. main).

| Phrase | Expected |
|--------|----------|
| `/zenith review my PR` | Blocked — prints "switch to a feature branch before running a self-review" |

**Setup:** Feature branch, `.zenith-context` present in repo root.

| Phrase | Expected |
|--------|----------|
| `/zenith review my PR` | Signals section includes failure pattern matches from `.zenith-context` if diff matches any pattern |

**Setup:** Feature branch, no `.zenith-context` in repo root.

| Phrase | Expected |
|--------|----------|
| `/zenith review my PR` | Review runs cleanly using git history and codebase scan only — no error, no mention of missing file |

---

## INTENT_REVIEW_PR — Reviewer Mode

**Setup:** Any branch; teammate has an open PR with a known number.

| Phrase | Expected |
|--------|----------|
| `/zenith review PR 123` | Fetches PR 123 diff via `gh pr diff 123`; runs 3-pass review; header shows PR title and author |
| `/zenith review #42` | Same — parses PR number from `#42` format |
| `/zenith review PR 123` (CI failing) | Review header shows `CI: ✗`; CI state surfaced in output |

**Setup:** Any branch; `.zenith-context` present in repo root.

| Phrase | Expected |
|--------|----------|
| `/zenith review PR 123` | Signals section includes operational constraints and failure pattern matches if diff triggers them |

**Setup:** Any branch; `.zenith-context` absent.

| Phrase | Expected |
|--------|----------|
| `/zenith review PR 123` | Review runs on git history + codebase scan only — no error, signals section omits pattern row |

---

## INTENT_RUN_CHECKS

**Setup:** Feature branch with changed files in {project_folder}/, pre-commit installed, .pre-commit-config.yaml present in repo root.

| Phrase | Expected |
|--------|----------|
| `/zenith run checks` | Runs hooks against changed files; shows ✓/✗ per hook; clean summary if all pass |
| `/zenith check my code` | Same as above |
| `/zenith lint my changes` | Same as above |

**Setup:** Feature branch, no changed files.

| Phrase | Expected |
|--------|----------|
| `/zenith run checks` | Blocked — "nothing to check — no changed files found in {project_folder}/" |

**Setup:** pre-commit not installed (uninstall or use a machine without it).

| Phrase | Expected |
|--------|----------|
| `/zenith run checks` | Blocked — "pip install pre-commit" instruction, stops cleanly |

**Setup:** pre-commit installed, no .pre-commit-config.yaml in repo root.

| Phrase | Expected |
|--------|----------|
| `/zenith run checks` | Blocked — template copy instruction (`cp ~/.zenith/assets/.pre-commit-config.yaml ...`), stops cleanly |

**Setup:** A hook fails (e.g. introduce a trailing-whitespace or linting error in a changed file).

| Phrase | Expected |
|--------|----------|
| `/zenith run checks` | ✗ for failing hook with failure detail lines; "fix required" summary; no commit or stage performed |

---

---

## Jira — First-time setup

**Setup:** Fresh install, `~/.zenith/.global-config` has no `[jira]` section, `.agent-config` has no `[jira]` section.

| Phrase | Expected |
|--------|----------|
| `/zenith my tickets` | Triggers global Jira setup (URL, email, token prompts), then repo setup (project key), then runs the list |
| `/zenith create a ticket` | Same setup flow, then proceeds to ticket creation |

**Setup:** Global config has `[jira]` credentials but `.agent-config` has no `[jira]` section.

| Phrase | Expected |
|--------|----------|
| `/zenith my tickets` | Skips global setup, triggers repo setup only (project key prompt), then runs the list |

**Setup:** Both global and repo Jira configs present but `JIRA_API_TOKEN` not in global config and not in env.

| Phrase | Expected |
|--------|----------|
| `/zenith my tickets` | Blocked: "blocked — jira API token not set", no API call made |

---

## Jira — INTENT_JIRA_CREATE

**Setup:** Valid Jira config. On any branch.

| Phrase | Expected |
|--------|----------|
| `/zenith create a story for adding export to CSV` | Asks for summary (pre-filled from phrase), epic key (optional), description (optional), shows preview, confirms, creates, prints ticket key + URL |
| `/zenith create a bug` | Asks for summary, sets type to Bug |
| `/zenith create an epic` | Sets type to Epic, does NOT ask for parent epic key |
| `/zenith create a task in INFRA` | Uses INFRA as project key, overriding repo default |
| `/zenith create a ticket` (API returns error) | Prints error in pipe format, stops |

---

## Jira — INTENT_JIRA_VIEW

**Setup:** Valid Jira config.

| Phrase | Expected |
|--------|----------|
| `/zenith show ticket AIE-123` | Fetches and displays: key, summary, type, status, assignee |
| `/zenith what's AIE-123` | Same — parses ticket key from phrase |
| `/zenith show ticket` (no key given) | Asks "Ticket key (e.g. AIE-123):" before fetching |
| `/zenith show ticket AIE-9999` (non-existent) | Prints "ticket not found", stops |

---

## Jira — INTENT_JIRA_LIST

**Setup:** Valid Jira config. You have open tickets assigned to you.

| Phrase | Expected |
|--------|----------|
| `/zenith my tickets` | Lists open tickets in repo's project, one per line: key, type, status, summary |
| `/zenith my INFRA tickets` | Uses INFRA as project, overriding repo default |
| `/zenith my tickets` (none assigned) | Prints "no open tickets — none assigned to you in {project}" |

---

## Jira — INTENT_JIRA_UPDATE

**Setup:** Valid Jira config. Ticket AIE-123 exists.

| Phrase | Expected |
|--------|----------|
| `/zenith update ticket AIE-123` | Fetches current values, shows them, prompts for new summary and description, confirms, updates |
| Enter to skip both fields | Prints "nothing changed — no updates made", stops |
| `/zenith rename ticket AIE-123 to new title` | Updates summary only, skips description prompt |

---

## Jira — INTENT_JIRA_TRANSITION

**Setup:** Valid Jira config. Ticket AIE-123 exists in "To Do" status.

| Phrase | Expected |
|--------|----------|
| `/zenith move AIE-123 to in progress` | Shows current → target status, confirms, transitions |
| `/zenith start AIE-123` | Maps "start" → In Progress |
| `/zenith move AIE-123 to review` | Maps "review" → In Review |
| `/zenith mark AIE-123 done` | Maps "done" → Done |
| `/zenith move AIE-123` (no target) | Lists available transitions, asks which one |
| Target transition not available for current status | Prints "transition not available" error, stops |

---

## Jira — INTENT_JIRA_ASSIGN

**Setup:** Valid Jira config. Ticket AIE-123 exists.

| Phrase | Expected |
|--------|----------|
| `/zenith assign AIE-123 to me` | Calls /myself to get accountId, shows preview "assigning to {your name}", confirms, assigns |
| `/zenith take ticket AIE-123` | Same as above |
| `/zenith assign AIE-123 to bob` | Searches users for "bob", if one result: confirms and assigns; if multiple: shows list |
| Search returns no users | Prints "no users found", stops |

---

## Jira — INTENT_JIRA_BRANCH

**Setup:** Valid Jira config. On base branch, clean working tree.

| Phrase | Expected |
|--------|----------|
| `/zenith branch from ticket AIE-123` | Fetches summary, slugifies, proposes `AIE-123-{slug}`, confirms, creates and pushes branch |
| `/zenith start work on AIE-123` | Same behavior |

**Setup:** On a feature branch with uncommitted changes.

| Phrase | Expected |
|--------|----------|
| `/zenith branch from ticket AIE-123` | Blocked: "cannot create branch — uncommitted changes exist" |

---

## Jira — INTENT_JIRA_CLOSE

**Setup:** Valid Jira config. Ticket AIE-123 in "In Progress".

| Phrase | Expected |
|--------|----------|
| `/zenith close ticket AIE-123` | Shows summary + status → Done, confirms, transitions |

**Setup:** Ticket AIE-123 already in "Done".

| Phrase | Expected |
|--------|----------|
| `/zenith close ticket AIE-123` | Prints "already closed — current status: Done", stops |

---

## Jira — INTENT_JIRA_DELETE

**Setup:** Valid Jira config. Ticket AIE-123 exists.

| Phrase | Expected |
|--------|----------|
| `/zenith delete ticket AIE-123` | Shows summary and status, warns "cannot be undone", asks user to TYPE the ticket key |
| User types `AIE-123` exactly | Deletes, prints "✓ AIE-123 deleted" |
| User types anything else (e.g. `y`, `yes`) | Prints "cancelled — ticket key did not match", no deletion |

---

## Output Format

Verify that output format matches the spec in `zenith.md`:

- Branch info after `start new work` shows `branch:`, `from:`, `folder:` fields
- Sync summary shows `synced:`, `ahead:`, `latest:` fields
- Commit result shows `committed:`, `message:`, and file list
- Push result shows `branch:`, `base:`, `commits:`, and a valid PR URL
- Every operation ends with a `next:` line
