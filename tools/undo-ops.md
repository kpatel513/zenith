# Undo Operations

Precise git command sequences for undoing changes safely.

## Undo Last Commit (Keep Changes)

Used in: INTENT_UNDO_COMMIT

Soft reset - moves HEAD back one commit, keeps all changes in working directory:

```bash
# 1. Show what will be undone
git log --oneline -1

# 2. Confirm with user
echo "About to undo: {hash} {message}"
echo "Your changes will stay in your working tree, unstaged."
echo "This is safe — nothing is deleted."
read -p "Confirm? [y/n] " response

# 3. If confirmed
if [ "$response" = "y" ]; then
    git reset --soft HEAD~1

    # Alternative to keep changes staged:
    # git reset --soft HEAD~1

    # Alternative to unstage:
    git reset HEAD~1

    echo "Undone: {message}"
    echo "Your changes are unstaged in your working tree"
fi
```

**What this does**:
- Removes the last commit from history
- Preserves all changes in working directory
- Changes become unstaged (or stay staged with --soft)
- Safe - can re-commit immediately if needed

## Discard All Uncommitted Changes

Used in: INTENT_DISCARD

Hard reset - permanently deletes all uncommitted changes:

```bash
# 1. Show what will be lost
git status --short

# 2. List every file that will be deleted
echo "WARNING: This permanently deletes all uncommitted changes."
echo "These files will be lost:"
git status --short | awk '{print "  " $2}'

# 3. Require explicit confirmation
echo ""
echo "Cannot be undone. Type YES to confirm:"
read response

# 4. If exactly "YES"
if [ "$response" = "YES" ]; then
    git reset --hard HEAD
    git clean -fd  # Remove untracked files and directories
    echo "Clean. All uncommitted changes discarded."
else
    echo "Cancelled. No changes made."
fi
```

**What this does**:
- Permanently deletes all uncommitted changes
- Removes untracked files
- Cannot be undone
- Requires typing full word "YES", not just "y"

## Unstage File

Used in: INTENT_UNSTAGE

Remove file from staging area, keep changes in working directory:

```bash
# 1. Show staged files
git diff --cached --stat

# 2. User selects file to unstage
read -p "Which file to unstage? " file

# 3. Unstage
git restore --staged {file}

# Alternative for older git:
# git reset HEAD {file}

echo "Unstaged: {file}"
echo "Still in your working tree, not staged"
```

## Unstage All Files

```bash
git restore --staged .

# Alternative for older git:
# git reset HEAD
```

## Discard Changes in Specific File

Revert file to last committed state:

```bash
# 1. Show current changes
git diff {file}

# 2. Warn user
echo "This will permanently discard all changes to {file}"
echo "Cannot be undone."
read -p "Confirm? [y/n] " response

# 3. If confirmed
if [ "$response" = "y" ]; then
    git restore {file}

    # Alternative for older git:
    # git checkout -- {file}

    echo "Discarded changes: {file}"
fi
```

## Undo Last N Commits (Keep Changes)

```bash
# Undo last 3 commits, keep all changes unstaged
git reset HEAD~3

# Undo last 3 commits, keep all changes staged
git reset --soft HEAD~3
```

## Undo to Specific Commit

```bash
# 1. Show recent commits
git log --oneline -10

# 2. User selects commit hash
read -p "Undo to which commit? " hash

# 3. Reset to that commit (keep changes)
git reset {hash}

# Or discard changes (dangerous):
# git reset --hard {hash}
```

## Recover from Accidental Reset

If user accidentally did hard reset:

```bash
# 1. Show reflog (history of HEAD movements)
git reflog

# 2. Find commit before reset
# Look for entry like: "HEAD@{1}: reset: moving to HEAD~1"

# 3. Reset to commit before the reset
git reset HEAD@{1}

# Or to specific hash from reflog:
# git reset {hash}
```

Reflog keeps history for 90 days by default.

## Undo Last Commit and Recommit Differently

```bash
# 1. Undo last commit, keep changes staged
git reset --soft HEAD~1

# 2. Unstage specific files
git restore --staged {file1} {file2}

# 3. Commit remaining staged files
git commit -m "{new message}"

# 4. Commit unstaged files separately
git add {file1} {file2}
git commit -m "{another message}"
```

## Discard Untracked Files Only

Remove files not tracked by git:

```bash
# 1. Show what will be removed (dry run)
git clean -n

# 2. Confirm
read -p "Remove these files? [y/n] " response

# 3. If confirmed
if [ "$response" = "y" ]; then
    git clean -f      # Remove untracked files
    git clean -fd     # Remove untracked files and directories
fi
```

## Undo Specific File to Previous Version

Restore file from N commits ago:

```bash
# From last commit (HEAD):
git restore --source=HEAD {file}

# From 3 commits ago:
git restore --source=HEAD~3 {file}

# From specific commit:
git restore --source={hash} {file}

# Alternative for older git:
# git checkout {hash} -- {file}
```

## Undo Merge

If merge was completed but not committed:

```bash
git merge --abort
```

If merge was committed:

```bash
# Undo merge commit
git reset --hard HEAD~1

# Or create new commit that reverses the merge:
git revert -m 1 {merge_commit_hash}
```

## Undo Rebase

If rebase in progress:

```bash
git rebase --abort
```

If rebase was completed:

```bash
# Use reflog to find commit before rebase
git reflog
git reset --hard HEAD@{n}
```

## Stash Changes (Temporary Undo)

Save changes temporarily without committing:

```bash
# 1. Stash all changes
git stash push -m "description of changes"

# 2. Working directory is now clean
git status

# 3. List stashes
git stash list

# 4. Apply stash (keep in stash list)
git stash apply stash@{0}

# 5. Pop stash (apply and remove from list)
git stash pop stash@{0}

# 6. Drop stash (remove without applying)
git stash drop stash@{0}
```

## Comparison: Reset vs Revert

**Reset** (changes history - use on unpushed commits):
```bash
git reset HEAD~1       # Undo commit, keep changes
git reset --hard HEAD~1  # Undo commit, discard changes
```

**Revert** (creates new commit - safe for pushed commits):
```bash
git revert {hash}      # Create new commit that undoes {hash}
```

Use reset for local changes only.
Use revert for pushed commits (safer for shared branches).

## Safety Levels

**Safe** (can recover easily):
- `git reset HEAD~1` (soft reset, keep changes)
- `git restore --staged` (unstage)
- `git stash` (temporary storage)

**Moderate** (can recover with reflog):
- `git reset --hard HEAD~1` (on unpushed commits)
- `git clean -fd` (reflog won't help with untracked files)

**Dangerous** (very hard to recover):
- `git reset --hard HEAD~1` (on pushed commits - creates divergence)
- `git push --force` (overwrites remote history)
- Discarding untracked files (no git history)

Zenith only performs Safe and Moderate operations automatically.
Dangerous operations require manual user action.
