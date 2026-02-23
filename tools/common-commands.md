# Common Git Command Patterns

This file contains frequently used git command sequences to eliminate duplication across the Zenith workflow documentation.

---

## Status and Information Commands

### CMD_STATUS_SHORT
```bash
git status --short
```
**Purpose:** Get concise status of working directory and staging area
**Output:** Two-column format showing index and working tree status
**Used for:** Quick checks, file listing, contamination detection

### CMD_CURRENT_BRANCH
```bash
git branch --show-current
```
**Purpose:** Get the name of the current branch
**Output:** Branch name (empty if detached HEAD)
**Used for:** Branch validation, output messages

### CMD_LAST_COMMIT_ONELINE
```bash
git log --oneline -1
```
**Purpose:** Show last commit in short format
**Output:** `{hash} {message}`
**Used for:** Displaying recent commit info, verification after commits

### CMD_LAST_COMMIT_DETAILS
```bash
git log -1 --format='%h %s'
```
**Purpose:** Show last commit hash and subject
**Output:** `{short_hash} {subject}`
**Used for:** Post-commit summaries

---

## Diff and Change Commands

### CMD_DIFF_CACHED_STAT
```bash
git diff --cached --stat
```
**Purpose:** Show summary of staged changes
**Output:** File list with change counts
**Used for:** Pre-commit review, verification before pushing

### CMD_DIFF_CACHED_FULL
```bash
git diff --cached
```
**Purpose:** Show full diff of staged changes
**Output:** Complete unified diff of staged files
**Used for:** Detailed review before commit

### CMD_DIFF_UNSTAGED
```bash
git diff
```
**Purpose:** Show unstaged changes in working directory
**Output:** Unified diff of modified files not yet staged
**Used for:** Review before staging, contamination checks

### CMD_DIFF_NAME_ONLY
```bash
git diff --name-only HEAD
```
**Purpose:** List files changed since HEAD (staged + unstaged)
**Output:** List of file paths, one per line
**Used for:** Contamination detection, file inventory

### CMD_DIFF_CACHED_NAME_ONLY
```bash
git diff --name-only --cached
```
**Purpose:** List files in staging area
**Output:** List of staged file paths, one per line
**Used for:** Contamination detection, staged file inventory

---

## Branch Comparison Commands

### CMD_COMMITS_AHEAD
```bash
git rev-list --count {base_branch}..HEAD
```
**Purpose:** Count commits ahead of base branch
**Output:** Number (e.g., `3`)
**Used for:** Determining if branch has new commits to push

### CMD_COMMITS_BEHIND
```bash
git rev-list --count HEAD..{base_branch}
```
**Purpose:** Count commits behind base branch
**Output:** Number (e.g., `2`)
**Used for:** Determining if branch needs syncing

### CMD_LOG_SINCE_BASE
```bash
git log --oneline {base_branch}..HEAD
```
**Purpose:** Show commits on current branch not in base
**Output:** List of commits in oneline format
**Used for:** Review before push, PR descriptions

### CMD_DIFF_FROM_BASE
```bash
git diff {base_branch}...HEAD
```
**Purpose:** Show all changes since branching from base
**Output:** Complete diff of all branch changes
**Used for:** Understanding full scope of changes

---

## Remote and Sync Commands

### CMD_FETCH_ORIGIN
```bash
git fetch origin
```
**Purpose:** Fetch latest refs and objects from origin
**Output:** List of updated refs
**Used for:** Before sync, before push, before branch comparison

### CMD_REMOTE_BRANCH_EXISTS
```bash
git ls-remote --heads origin {branch}
```
**Purpose:** Check if branch exists on remote
**Output:** Reference line if exists, empty if not
**Used for:** Determining if first push or subsequent push

### CMD_PULL_REBASE
```bash
git pull --rebase origin {branch}
```
**Purpose:** Fetch and rebase current branch on remote
**Output:** Rebase progress and result
**Used for:** Syncing feature branch with its remote

### CMD_REBASE_ONTO_BASE
```bash
git rebase origin/{base_branch}
```
**Purpose:** Rebase current branch onto latest base branch
**Output:** Rebase progress, potential conflicts
**Used for:** Updating feature branch with latest base changes

---

## Staging Commands

### CMD_STAGE_ALL
```bash
git add .
```
**Purpose:** Stage all changes in working directory
**Output:** None (silent on success)
**Used for:** Quick staging of all work

### CMD_STAGE_FILE
```bash
git add {file}
```
**Purpose:** Stage specific file
**Output:** None (silent on success)
**Used for:** Selective staging

### CMD_UNSTAGE_FILE
```bash
git restore --staged {file}
```
**Purpose:** Remove file from staging area (keep working changes)
**Output:** None (silent on success)
**Used for:** Removing files from commit

### CMD_STAGE_PATCH
```bash
git add -p {file}
```
**Purpose:** Interactively stage parts of file
**Output:** Interactive prompts for each hunk
**Used for:** Granular commit creation

---

## Commit Commands

### CMD_COMMIT_WITH_MESSAGE
```bash
git commit -m "{message}"
```
**Purpose:** Create commit with given message
**Output:** Commit summary
**Used for:** Standard commits

### CMD_AMEND_MESSAGE
```bash
git commit --amend -m "{new_message}"
```
**Purpose:** Change message of last commit
**Output:** Amended commit summary
**Used for:** Fixing commit messages

### CMD_AMEND_NO_EDIT
```bash
git commit --amend --no-edit
```
**Purpose:** Add staged changes to last commit without changing message
**Output:** Amended commit summary
**Used for:** Adding forgotten files to last commit

---

## Push Commands

### CMD_PUSH_SET_UPSTREAM
```bash
git push -u origin {branch}
```
**Purpose:** Push branch and set up tracking
**Output:** Push progress and remote ref
**Used for:** First push of new branch

### CMD_PUSH_FORCE_WITH_LEASE
```bash
git push --force-with-lease origin {branch}
```
**Purpose:** Force push with safety check
**Output:** Push progress
**Used for:** Pushing after rebase/amend

### CMD_PUSH_SIMPLE
```bash
git push origin {branch}
```
**Purpose:** Push commits to existing remote branch
**Output:** Push progress
**Used for:** Subsequent pushes

---

## Conflict and Merge Commands

### CMD_MERGE_ABORT
```bash
git merge --abort
```
**Purpose:** Abort merge and return to pre-merge state
**Output:** None (silent on success)
**Used for:** Canceling troubled merges

### CMD_REBASE_ABORT
```bash
git rebase --abort
```
**Purpose:** Abort rebase and return to pre-rebase state
**Output:** None (silent on success)
**Used for:** Canceling troubled rebases

### CMD_REBASE_CONTINUE
```bash
git rebase --continue
```
**Purpose:** Continue rebase after resolving conflicts
**Output:** Rebase progress
**Used for:** Resuming after conflict resolution

### CMD_CONFLICTS_LIST
```bash
git diff --name-only --diff-filter=U
```
**Purpose:** List files with unresolved conflicts
**Output:** List of conflicted file paths
**Used for:** Identifying remaining conflicts

### CMD_CHECKOUT_OURS
```bash
git checkout --ours {file}
```
**Purpose:** Resolve conflict by keeping current branch version
**Output:** None (silent on success)
**Used for:** Conflict resolution

### CMD_CHECKOUT_THEIRS
```bash
git checkout --theirs {file}
```
**Purpose:** Resolve conflict by accepting incoming version
**Output:** None (silent on success)
**Used for:** Conflict resolution

---

## Undo and Reset Commands

### CMD_RESET_SOFT
```bash
git reset --soft HEAD~{n}
```
**Purpose:** Undo last n commits, keep changes staged
**Output:** None (silent)
**Used for:** Recommitting with different structure

### CMD_RESET_MIXED
```bash
git reset HEAD~{n}
```
**Purpose:** Undo last n commits, keep changes unstaged
**Output:** None (silent)
**Used for:** Undoing commits but keeping work

### CMD_RESET_HARD
```bash
git reset --hard HEAD~{n}
```
**Purpose:** Undo last n commits and discard all changes
**Output:** HEAD position message
**Used for:** Completely removing commits (DANGEROUS)

### CMD_CLEAN_DRY_RUN
```bash
git clean -fd --dry-run
```
**Purpose:** Preview what would be deleted
**Output:** List of untracked files/directories
**Used for:** Safety check before cleaning

### CMD_CLEAN_EXECUTE
```bash
git clean -fd
```
**Purpose:** Delete untracked files and directories
**Output:** List of deleted items
**Used for:** Cleaning working directory

---

## Stash Commands

### CMD_STASH_LIST
```bash
git stash list
```
**Purpose:** List all stashed changes
**Output:** Stash entries with IDs
**Used for:** Checking for saved work

### CMD_STASH_SHOW
```bash
git stash show -p stash@{n}
```
**Purpose:** Show contents of specific stash
**Output:** Diff of stashed changes
**Used for:** Reviewing stashed work

---

## Configuration Commands

### CMD_GET_REMOTE_URL
```bash
git config --get remote.origin.url
```
**Purpose:** Get the URL of origin remote
**Output:** Remote URL (HTTPS or SSH)
**Used for:** Extracting org/repo for PR creation

### CMD_GET_USER_NAME
```bash
git config --get user.name
```
**Purpose:** Get configured user name
**Output:** User's name
**Used for:** Verification, PR attribution

### CMD_GET_USER_EMAIL
```bash
git config --get user.email
```
**Purpose:** Get configured user email
**Output:** User's email
**Used for:** Verification, commit attribution

---

## Reference Usage

**To reference a command in documentation:**

1. **Inline reference:** Use the command ID
   ```
   Run CMD_DIFF_CACHED_STAT to see staged changes
   ```

2. **With context:** Explain the purpose
   ```
   Check staging area (CMD_DIFF_CACHED_STAT)
   ```

3. **In code blocks:** Use the actual command
   ```bash
   # See tools/common-commands.md#CMD_DIFF_CACHED_STAT
   git diff --cached --stat
   ```

**Benefits:**
- Single source of truth for common commands
- Easier to update command patterns
- Clearer documentation through standardization
- Reduced duplication across tools
