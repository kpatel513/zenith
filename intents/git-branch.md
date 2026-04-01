# Zenith — Branch Operations
# Handlers: INTENT_START_NEW, INTENT_PICKUP_BRANCH, INTENT_CONTINUE, INTENT_CLEANUP_BRANCHES, INTENT_WORKTREE_ADD, INTENT_WORKTREE_LIST, INTENT_WORKTREE_REMOVE
# Read by ZENITH.md Step 4 router. See references/common-commands.md for CMD_* definitions.

### INTENT_START_NEW

Check situation. If S5 or S6:
```
blocked — you have uncommitted changes
│ save or discard them before starting a new branch
│ run /zenith save or /zenith throw away changes
```
Stop.

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git rev-list --count {base_branch}..origin/{base_branch}
```

If count > 0:
```
updating {base_branch} — your local copy is {n} commits behind GitHub
│ pulling latest so your new branch starts from current code
```

If count = 0:
```
checking {base_branch} — already up to date
│ your new branch will start from the latest commit
```

Execute:
```bash
git checkout {base_branch}
git pull origin {base_branch}
```

Ask: "What are you working on? (used to name your branch)"

Sanitize input:
- Lowercase
- Spaces → hyphens
- Remove special chars except hyphens/underscores
- Prefix with `feature/`

**If currently on a feature branch** (not `{base_branch}`), ask before creating:

```
creating branch — you're on {current_branch}, not {base_branch}
│ stack on {current_branch}: your new work builds directly on top of this branch
│   → PR will target {current_branch}; merges after {current_branch} merges
│ branch from {base_branch}: independent work, unrelated to {current_branch}
│   → PR will target {base_branch} directly

Stack on {current_branch} or branch from {base_branch}? [s/m]
```

**If stack (`s`):**

```bash
git checkout -b feature/{sanitized}
git config branch.feature/{sanitized}.zenith-parent {current_branch}
git config branch.feature/{sanitized}.zenith-parent-tip $(git rev-parse origin/{current_branch})
git push -u origin feature/{sanitized}  # CMD_PUSH_SET_UPSTREAM
```

Print:
```
  ✓ branch  feature/{sanitized}
  stacked   {current_branch} → feature/{sanitized}
  folder    work inside {project_folder}/ only
```

Next: "next: your stacked branch is ready — start coding in {project_folder}/"

**If branch from main (`m`) or currently on `{base_branch}`:**

Print:
```
creating branch — from latest {base_branch}
│ feature/{sanitized} will track origin/feature/{sanitized}
│ all your work lives on this branch until you open a PR

Create and push? [y/n]
```

Execute:
```bash
git checkout -b feature/{sanitized}
git push -u origin feature/{sanitized}  # CMD_PUSH_SET_UPSTREAM
```

Print:
```
  ✓ branch  feature/{sanitized}
  from      {base_branch} at {hash}
  folder    work inside {project_folder}/ only
```

Next: "next: your branch is ready — start coding in {project_folder}/"

### INTENT_PICKUP_BRANCH

Check situation.

If S5 or S6 (uncommitted or staged changes):
```
stashing — you have uncommitted changes on {current_branch}
│ your changes will be saved temporarily so you can switch branches
│ they will be waiting when you return to {current_branch}

Stash and switch? [y/n]
```

If yes:
```bash
git stash push -m "zenith: auto-stash before switching to {branch}"
```

Print:
```
  ✓ stashed  changes saved on {current_branch}
```

If no:
```
  cancelled  save or discard your changes first
```
Stop.

Execute:
```bash
git branch -r --format="%(refname:short)" | grep -v HEAD | grep -v {base_branch}
```

Show numbered list sorted by date. Ask: "Which branch?"

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git checkout -b {branch} origin/{branch}
git log --oneline -3 --format="%h %s — %an %ar"  # CMD_LAST_COMMIT_ONELINE
```

Print:
```
switching — checking out {branch}
│ tracking origin/{branch}
│ recent commits:
│   {hash} {message} — {author} {time}
│   {hash} {message} — {author} {time}
│   {hash} {message} — {author} {time}

  ✓ on {branch}
```

If stash was created:
```
  note  your changes on {previous_branch} are stashed — run /zenith unstash when you return
```

Next: "next: start working in {project_folder}/"

### INTENT_CONTINUE

Execute:
```bash
git branch --sort=-committerdate --format="%(refname:short) %(committerdate:relative) %(subject)" | grep -v {base_branch} | head -10
```

Show numbered list. Ask: "Which branch?"

Check situation.

If S5 or S6 (uncommitted or staged changes):
```
stashing — you have uncommitted changes on {current_branch}
│ your changes will be saved temporarily so you can switch branches
│ they will be waiting when you return to {current_branch}

Stash and switch? [y/n]
```

If yes:
```bash
git stash push -m "zenith: auto-stash before switching to {selected}"
```

Print:
```
  ✓ stashed  changes saved on {current_branch}
```

If no:
```
  cancelled  save or discard your changes first
```
Stop.

Execute:
```bash
git checkout {selected}
git fetch origin                   # CMD_FETCH_ORIGIN
git log {selected}..origin/{base_branch} --oneline  # CMD_LOG_SINCE_BASE
```

If nothing new:
```
switching — back to {selected}
│ nothing new on {base_branch} since your last session
│ you are up to date

  ✓ on {selected}
```

If new commits:
```
switching — back to {selected}
│ {n} new commit(s) on {base_branch} since you were last here:
│   {hash} {message}
│   {hash} {message}

syncing — replays your commits on top of the new ones
│ your branch moves forward cleanly — no merge commit is created

Sync with {base_branch} now? [y/n]
```

If yes: Execute INTENT_SYNC operation.

If stash was created:
```
  note  your changes on {previous_branch} are stashed — run /zenith unstash when you return
```

Next: "next: start working, or sync with main first"

### INTENT_CLEANUP_BRANCHES

Execute:
```bash
git fetch --prune origin           # CMD_FETCH_ORIGIN
```

Get merged branches via two methods, then union the results:

```bash
# Method 1: regular merges — tracked by git ancestry
git branch --merged origin/{base_branch} --format="%(refname:short)" | grep -v "^{base_branch}$"

# Method 2: squash merges — tracked by GitHub PR history
# git ancestry cannot detect squash merges; gh pr list catches them
gh pr list --repo {github_org}/{github_repo} --state merged --base {base_branch} \
  --json headRefName,author \
  --jq '.[] | select(.author.login == "{github_username}") | .headRefName'
```

Cross-reference the unioned list against locally existing branches:
```bash
git branch --format="%(refname:short)"
```

Keep only branches that exist locally. Filter to branches where the most recent commit author matches {github_username}. Exclude `{base_branch}`.

If none:
```
nothing to clean — no merged branches found for {github_username}
│ your branch list is already tidy
```
Stop.

For each branch in the list, fetch its tip hash before displaying:
```bash
git log -1 --format="%h" {branch}
```

Print:
```
merged branches — safe to delete, already in {base_branch}
│ 1. feature/old-thing    last commit 3 weeks ago    tip a1b2c3d
│ 2. feature/done-work    last commit 2 months ago   tip e4f5g6h
│ remotes already deleted by GitHub after merge
│ to recover a deleted branch: git checkout -b recovered {tip-hash}

Delete all? [y/n] (or enter numbers to pick specific ones)
```

Execute for each selected:
```bash
git branch -D {branch}
git push origin --delete {branch} 2>/dev/null || true
```

Note: `-D` is used instead of `-d` because squash-merged branches have no git ancestry link to {base_branch}, so git will refuse to delete them with `-d` even though they are safely merged. The remote delete is silenced — GitHub often auto-deletes branches after PR merge.

Print:
```
  ✓ deleted  feature/old-thing (local + remote)
  ✓ deleted  feature/done-work (local + remote)
```

Next: "next: your branch list is clean"

### INTENT_WORKTREE_ADD

List existing worktrees:
```bash
git worktree list --porcelain   # CMD_WORKTREE_LIST
```

Show numbered list of local branches for selection:
```bash
git branch --sort=-committerdate --format="%(refname:short) %(committerdate:relative)" | head -10
```

Ask: "Which branch to open in a new worktree? (enter a branch name, or 'new' to create one)"

If "new": ask "What are you working on?" and sanitize to `feature/{sanitized}` using the same rules as INTENT_START_NEW (lowercase, spaces to hyphens, no special chars, `feature/` prefix).

Check if branch is already checked out in another worktree:
```bash
git worktree list --porcelain | grep "^branch refs/heads/{branch}$"   # CMD_WORKTREE_LIST
```

If already checked out:
```
blocked — {branch} is already checked out
│ a branch can only be active in one worktree at a time
│ run /zenith list worktrees to see where it is checked out
```
Stop.

Compute path:
```bash
REPO_NAME=$(basename "$REPO_ROOT")
BRANCH_SAFE=$(echo "{branch}" | tr '/' '-')
WORKTREE_PATH="${REPO_ROOT}/../${REPO_NAME}-${BRANCH_SAFE}"
```

Show preview and confirm:
```
adding worktree — {branch} in a separate directory
│ path    {path}
│ branch  {branch}
│ your current directory is untouched

Add worktree? [y/n]
```

If existing branch:
```bash
git worktree add {path} {branch}   # CMD_WORKTREE_ADD
```

If new branch:
```bash
git worktree add -b {branch} {path} {base_branch}   # CMD_WORKTREE_ADD_NEW
git -C {path} push -u origin {branch}               # CMD_PUSH_SET_UPSTREAM
```

Print:
```
  ✓ worktree  {path}
  branch      {branch}
  navigate    cd {path}
```

Next: "next: cd {path} to start working — your current directory stays on {current_branch}"

### INTENT_WORKTREE_LIST

Execute:
```bash
git worktree list --porcelain   # CMD_WORKTREE_LIST
```

If only the main worktree exists:
```
no linked worktrees — only the main checkout is active
│ run /zenith open worktree to check out a branch in a separate directory
```
Next: "next: run /zenith open worktree to work on two branches simultaneously"
Stop.

Format as numbered list:
```
worktrees — {n} active
  1. {path}
     branch  {current_branch}  (main worktree)
  2. {path}
     branch  {branch}
```

Next: "next: cd to a worktree path to switch context, or /zenith remove worktree to clean up"

### INTENT_WORKTREE_REMOVE

Execute:
```bash
git worktree list --porcelain   # CMD_WORKTREE_LIST
```

If only the main worktree exists:
```
nothing to remove — no linked worktrees found
│ the main worktree cannot be removed
```
Stop.

Show numbered list of linked worktrees (exclude main). Ask: "Which worktree to remove? (enter number)"

Check for uncommitted changes in selected worktree:
```bash
git -C {path} status --short
```

If changes exist:
```
warning — worktree has uncommitted changes
│ {n} files modified in {path}
│ the branch is not deleted — only the working directory is removed
│ uncommitted changes in that directory will be lost

Remove anyway? [y/n]
```

If no uncommitted changes, show preview and confirm:
```
removing worktree — {path}
│ branch  {branch}
│ the branch itself is not deleted — only the working directory

Remove? [y/n]
```

Execute:
```bash
git worktree remove {path}   # CMD_WORKTREE_REMOVE
git worktree prune            # CMD_WORKTREE_PRUNE
```

Print:
```
  ✓ removed   {path}
  branch      {branch} still exists
```

Next: "next: run /zenith cleanup branches to delete {branch} if you're done with it"
