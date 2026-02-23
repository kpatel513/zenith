# Push Operations

Precise git command sequences for pushing changes and creating pull requests.

## Full Push Workflow (Commit + Push + PR)

Used in: INTENT_PUSH

Complete sequence from uncommitted changes to PR:

```bash
# 1. Run diagnostics
# (see diagnostics.md)

# 2. Validate pre-push state
git status --short
CURRENT=$(git branch --show-current)

# If on base_branch: STOP
# Error: "You are on {base_branch}. Create a feature branch first."

# 3. Run contamination check
# (see contamination.md)

# If files outside project_folder: ask include/exclude

# 4. Fetch latest
git fetch origin

# 5. Sync with base branch (rebase)
git rebase origin/{base_branch}

# Handle conflicts if any (see conflict-resolver.md)

# 6. Stage files
git add {project_folder}/  # or all files if user chose include

# 7. Show what will be committed
git diff --cached --stat

# 8. Commit
git commit -m "{message}"

# 9. Push with upstream tracking
git push -u origin {current_branch}

# 10. Show PR URL
echo "PR: https://github.com/{org}/{repo}/compare/{base_branch}...{current_branch}?expand=1"
```

## Push Only (No New Commit)

When changes are already committed:

```bash
# 1. Validate branch
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "{base_branch}" ]; then
    echo "Error: Cannot push to {base_branch} directly"
    exit 1
fi

# 2. Fetch and sync
git fetch origin
git rebase origin/{base_branch}

# 3. Push
git push -u origin {current_branch}

# 4. Show PR URL
```

## Update Existing PR

Used in: INTENT_UPDATE_PR

```bash
# 1. Validate on feature branch
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "{base_branch}" ]; then
    echo "Error: Switch to your feature branch first"
    exit 1
fi

# 2. Stage and commit new changes
git add {project_folder}/
git diff --cached --stat
git commit -m "{message}"

# 3. Push to same branch (updates PR automatically)
git push origin {current_branch}

# 4. Show PR URL
echo "Updated PR: https://github.com/{org}/{repo}/compare/{base_branch}...{current_branch}"
```

## Fix Push Rejection

Used in: INTENT_FIX_PUSH

Diagnose why push failed and fix:

```bash
# 1. Get diagnostic info
git status
git branch --show-current
git fetch origin
git log --oneline -3

# 2. Diagnose issue
```

### Diagnosis: Behind Remote Branch

```bash
# Check if local branch behind remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/{current_branch} 2>/dev/null)

if [ "$LOCAL" != "$REMOTE" ]; then
    BEHIND=$(git rev-list --count HEAD..origin/{current_branch})
    if [ "$BEHIND" -gt 0 ]; then
        echo "Your branch is behind origin/{current_branch} by $BEHIND commits"
        echo "Fix: git pull --rebase origin {current_branch}"

        # Ask user
        read -p "Fix this now? [y/n] " response
        if [ "$response" = "y" ]; then
            git pull --rebase origin {current_branch}
            git push origin {current_branch}
        fi
    fi
fi
```

### Diagnosis: Protected Branch

```bash
if [ "{current_branch}" = "{base_branch}" ]; then
    echo "Direct push to {base_branch} is not allowed"
    echo "Create a feature branch:"
    echo "  git checkout -b feature/your-branch-name"
fi
```

### Diagnosis: No Upstream Set

```bash
# Check if branch has upstream
UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)

if [ -z "$UPSTREAM" ]; then
    echo "No upstream set for {current_branch}"
    git push -u origin {current_branch}
    echo "Upstream set and pushed"
fi
```

### Diagnosis: Permission Denied

```bash
# If git push returns 403 or permission error
echo "You do not have push access to this repository"
echo "Check:"
echo "  1. GitHub permissions"
echo "  2. SSH key configuration: ssh -T git@github.com"
echo "  3. Remote URL: git remote -v"
```

## Push with Force (Dangerous)

**Never do this automatically**. Only show commands for user to run manually.

```bash
# Use when:
# - Amended commit that was already pushed
# - Rebased after push
# - Need to rewrite history

# Safer force push (fails if remote has new commits):
git push --force-with-lease origin {current_branch}

# Unsafe force push (overwrites everything):
git push --force origin {current_branch}
```

## Construct PR URL

```bash
ORG="{github_org}"
REPO="{github_repo}"
BASE="{base_branch}"
HEAD="{current_branch}"

# Basic PR compare URL:
echo "https://github.com/$ORG/$REPO/compare/$BASE...$HEAD"

# With expand=1 to auto-open PR form:
echo "https://github.com/$ORG/$REPO/compare/$BASE...$HEAD?expand=1"

# With title and body pre-filled:
TITLE=$(echo "Add feature X" | sed 's/ /%20/g')
BODY=$(echo "This PR adds feature X" | sed 's/ /%20/g')
echo "https://github.com/$ORG/$REPO/compare/$BASE...$HEAD?expand=1&title=$TITLE&body=$BODY"
```

## Pre-push Validation Checklist

Before allowing push:

```bash
# 1. Not on base branch
[ "$(git branch --show-current)" != "{base_branch}" ]

# 2. No uncommitted changes (unless committing as part of push)
[ -z "$(git status --short)" ] || [ "$COMMITTING" = "true" ]

# 3. Remote reachable
git ls-remote origin &>/dev/null

# 4. Branch synced with base (no behind commits)
BEHIND=$(git rev-list --count HEAD..origin/{base_branch})
[ "$BEHIND" -eq 0 ]

# 5. Has commits to push
AHEAD=$(git rev-list --count origin/{base_branch}..HEAD)
[ "$AHEAD" -gt 0 ]
```

If any check fails, show specific error and fix suggestion.

## Check if PR Already Exists

```bash
# Using GitHub CLI (if available)
gh pr view {current_branch} 2>/dev/null

# If exists: show "PR already exists: {url}"
# If not: show "Create PR: {url}"
```

## Push Summary Output

After successful push:

```
branch:  {current_branch}
base:    {base_branch}
commits: {n} ahead of {base_branch}
PR:      https://github.com/{org}/{repo}/compare/{base_branch}...{current_branch}?expand=1
```

With commit details:
```
pushed commits:
  {hash} {message} — {author}
  {hash} {message} — {author}
  {hash} {message} — {author}
```

## Push to Different Remote

If multiple remotes exist:

```bash
# List remotes
git remote -v

# Push to specific remote
git push {remote_name} {current_branch}

# Set upstream to specific remote
git push -u {remote_name} {current_branch}
```

## Delete Remote Branch After PR Merge

After PR is merged:

```bash
# Delete remote branch
git push origin --delete {branch_name}

# Delete local branch
git checkout {base_branch}
git branch -d {branch_name}

# Pull latest base branch
git pull origin {base_branch}
```

## Push Tags

For releasing versions:

```bash
# Push specific tag
git push origin {tag_name}

# Push all tags
git push origin --tags
```

Zenith doesn't handle tags automatically - outside core workflow.
