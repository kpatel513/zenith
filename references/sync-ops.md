# Sync Operations

Precise git command sequences for synchronizing branches with base branch.

**See tools/common-commands.md for shared command patterns (CMD_*).**

## Full Sync (Rebase onto Base Branch)

Used in: INTENT_SYNC

```bash
# 1. Check for uncommitted changes (must be clean)
git status --short

# If output is not empty: STOP
# Error: "You have uncommitted changes. Save or discard them first."

# 2. Fetch latest from remote
git fetch origin

# 3. Show incoming commits from base branch
git log HEAD..origin/{base_branch} --oneline --format="%h %s — %an %ar"

# If no output: already up to date, exit

# 4. Rebase onto base branch
git rebase origin/{base_branch}

# 5. If conflicts: apply conflict resolution (see conflict-resolver.md)

# 6. On success: show sync summary
git log --oneline -1
```

**Conflict handling**: See conflict-resolver.md for three-tier resolution system.

## Check How Far Behind

Used in: INTENT_HOW_FAR_BEHIND

```bash
# 1. Fetch latest
git fetch origin

# 2. Count commits behind
git rev-list --count HEAD..origin/{base_branch}

# 3. Show commit details
git log HEAD..origin/{base_branch} --oneline --format="%h %s — %an %ar"

# If count is 0: "up to date with {base_branch}"
```

## View What Teammates Pushed

Used in: INTENT_TEAMMATES

```bash
# 1. Fetch latest
git fetch origin

# 2. Show commits to base branch in last 24 hours
git log origin/{base_branch} --since="24 hours ago" --format="%h %s — %an %ar"

# If no output: "nothing pushed to {base_branch} in the last 24 hours"
```

Alternative timeframes:
- Last hour: `--since="1 hour ago"`
- Last week: `--since="1 week ago"`
- Today: `--since="midnight"`

## Pull Latest on Base Branch

Used in: INTENT_START_NEW (when on base branch)

```bash
# 1. Ensure on base branch
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "{base_branch}" ]; then
    git checkout {base_branch}
fi

# 2. Fetch and pull
git fetch origin
git pull origin {base_branch}

# 3. Show latest commit
git log --oneline -1
```

## Rebase Continuation

After resolving conflicts:

```bash
# 1. Verify all conflicts resolved
git diff --check

# 2. Verify conflicted files are staged
git diff --name-only --diff-filter=U

# If output is not empty: still have conflicts
# Error: "conflicts remaining in: {files}"

# 3. Continue rebase
git rebase --continue

# 4. If more conflicts: repeat resolution process
# 5. If no more conflicts: rebase complete
```

## Rebase Abort

User wants to cancel sync:

```bash
git rebase --abort
```

Confirms: "rebase aborted. your branch is unchanged."

## Compare Current Branch with Base Branch

```bash
# Commits in current branch not in base
git log origin/{base_branch}..HEAD --oneline

# Commits in base not in current branch
git log HEAD..origin/{base_branch} --oneline

# File changes between branches
git diff --stat origin/{base_branch}..HEAD
```

## Sync Local Branch with Remote Branch

When local branch is behind its remote counterpart:

```bash
# 1. Fetch latest
git fetch origin

# 2. Check if behind
BEHIND=$(git rev-list --count HEAD..origin/{current_branch})

# If BEHIND > 0:
# 3. Pull with rebase
git pull --rebase origin {current_branch}

# 4. Handle conflicts if any (see conflict-resolver.md)
```

## Fast-forward Merge (When Possible)

If rebase is not needed (no divergence):

```bash
# 1. Fetch latest
git fetch origin

# 2. Check if can fast-forward
git merge-base --is-ancestor HEAD origin/{base_branch}

# If exit code 0: can fast-forward
git merge --ff-only origin/{base_branch}

# If exit code 1: need rebase (diverged)
```

## Sync Multiple Branches

For maintenance: sync all feature branches with base branch:

```bash
# 1. Get all local branches except base
git branch --format="%(refname:short)" | grep -v "^{base_branch}$"

# 2. For each branch:
git checkout {branch}
git fetch origin
git rebase origin/{base_branch}

# 3. Return to original branch
git checkout {original_branch}
```

Note: Zenith doesn't do this automatically - dangerous for multiple branches.

## Detect Divergence

Check if branch has diverged from base:

```bash
# Commits in current branch not in base
AHEAD=$(git rev-list --count origin/{base_branch}..HEAD)

# Commits in base not in current branch
BEHIND=$(git rev-list --count HEAD..origin/{base_branch})

# Divergence matrix:
# AHEAD=0, BEHIND=0: up to date
# AHEAD>0, BEHIND=0: ahead, can push
# AHEAD=0, BEHIND>0: behind, need sync
# AHEAD>0, BEHIND>0: diverged, need sync before push
```

## Pre-sync Validation

Before starting sync:

```bash
# 1. Check repo state
git status

# Must not have:
# - Uncommitted changes
# - Ongoing rebase ("rebase in progress")
# - Ongoing merge ("merge in progress")
# - Detached HEAD

# 2. Check remote reachable
git ls-remote origin &>/dev/null

# If fails: warn "cannot reach remote"

# 3. Check branch exists on remote
git rev-parse --verify origin/{base_branch} &>/dev/null

# If fails: error "base branch {base_branch} not found on remote"
```

## Post-sync Summary

After successful sync:

```
synced:  {current_branch}
ahead:   {n} commits ahead of {base_branch}
latest:  {hash} {message} — {author} {time ago}
```

## Sync Frequency Recommendations

Display to user after sync:
- Sync daily before starting work
- Sync before pushing
- Sync after long-running feature development
- Sync after major changes merged to base branch
