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

## Output Format

Verify that output format matches the spec in `zenith.md`:

- Branch info after `start new work` shows `branch:`, `from:`, `folder:` fields
- Sync summary shows `synced:`, `ahead:`, `latest:` fields
- Commit result shows `committed:`, `message:`, and file list
- Push result shows `branch:`, `base:`, `commits:`, and a valid PR URL
- Every operation ends with a `next:` line
