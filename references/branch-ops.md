# Branch Operations

Precise git command sequences for all branch operations.

**See tools/common-commands.md for shared command patterns (CMD_*).**

## Create New Branch from Base Branch

Used in: INTENT_START_NEW

```bash
# 1. Fetch latest
git fetch origin

# 2. Switch to base branch
git checkout {base_branch}

# 3. Pull latest
git pull origin {base_branch}

# 4. Create and switch to new branch
git checkout -b {branch}

# 5. Push and set upstream
git push -u origin {branch}
```

**Branch Name Sanitization**:
- Convert to lowercase
- Replace spaces with hyphens
- Remove special characters except hyphens and underscores
- Prefix with `feature/`

Examples:
- "User Authentication" → `feature/user-authentication`
- "Fix bug #123" → `feature/fix-bug-123`
- "Add ML model" → `feature/add-ml-model`

## Checkout Existing Local Branch

Used in: INTENT_CONTINUE

```bash
# 1. List local branches sorted by recent activity
git branch --sort=-committerdate --format="%(refname:short) %(committerdate:relative) %(subject)"

# 2. Filter out base branch
grep -v "^{base_branch} "

# 3. Limit to 10 most recent
head -10

# 4. After user selects, checkout
git checkout {branch}

# 5. Fetch to compare with remote
git fetch origin

# 6. Show what's new on base branch since last work
git log {branch}..origin/{base_branch} --oneline
```

## Track Remote Branch

Used in: INTENT_PICKUP_BRANCH

```bash
# 1. List all remote branches
git branch -r --format="%(refname:short)"

# 2. Filter out HEAD and base branch
grep -v "HEAD" | grep -v "origin/{base_branch}"

# 3. After user selects remote branch, fetch
git fetch origin

# 4. Create local branch tracking remote
git checkout -b {branch} origin/{branch}

# 5. Show recent commits
git log --oneline -3
```

Alternative if local branch already exists:
```bash
git checkout {branch}
git branch --set-upstream-to=origin/{branch}
git pull
```

## List Branches with Metadata

**Local branches with last commit info**:
```bash
git for-each-ref --sort=-committerdate refs/heads/ \
  --format='%(refname:short)|%(committerdate:relative)|%(subject)|%(authorname)'
```

**Remote branches with last commit info**:
```bash
git for-each-ref --sort=-committerdate refs/remotes/origin/ \
  --format='%(refname:short)|%(committerdate:relative)|%(subject)|%(authorname)' \
  | grep -v "HEAD"
```

Format output as numbered list for user selection:
```
1. feature/auth-flow          2 hours ago    Add login component — Alice
2. feature/data-pipeline      1 day ago      Update preprocessing — Bob
3. feature/model-training     3 days ago     Initial model setup — Charlie
```

## Check Branch Status

**Is branch up to date with remote?**
```bash
git fetch origin
git rev-list --count HEAD..origin/{current_branch}
```
- Output 0: up to date
- Output N > 0: behind by N commits

**Is branch ahead of base branch?**
```bash
git rev-list --count origin/{base_branch}..HEAD
```
- Output 0: no new commits
- Output N > 0: ahead by N commits

**Is branch behind base branch?**
```bash
git rev-list --count HEAD..origin/{base_branch}
```
- Output 0: up to date
- Output N > 0: behind by N commits

## Delete Branch

**Delete local branch** (safe):
```bash
git branch -d {branch}
```
Fails if branch has unmerged changes.

**Delete local branch** (force):
```bash
git branch -D {branch}
```
Always succeeds.

**Delete remote branch**:
```bash
git push origin --delete {branch}
```

## Rename Branch

**Rename current branch**:
```bash
# 1. Rename local branch
git branch -m {new_name}

# 2. Delete old remote branch
git push origin --delete {old_name}

# 3. Push new branch
git push -u origin {new_name}
```

## Compare Branches

**Files changed between branches**:
```bash
git diff --name-status {branch1}..{branch2}
```

**Commits in branch A not in branch B**:
```bash
git log {branch_b}..{branch_a} --oneline
```

**Commits in branch B not in branch A**:
```bash
git log {branch_a}..{branch_b} --oneline
```

## Branch Naming Conventions

Standard prefixes:
- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation changes
- `test/` - Test additions or changes
- `experiment/` - Experimental work

Format: `{prefix}/{descriptive-name}`

Examples:
- `feature/user-authentication`
- `fix/memory-leak-in-parser`
- `refactor/split-large-module`
- `experiment/new-loss-function`
