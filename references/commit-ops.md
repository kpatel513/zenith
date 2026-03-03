# Commit Operations

Precise git command sequences for all commit-related operations.

**See tools/common-commands.md for shared command patterns (CMD_*).**

## Standard Commit (Scoped to Project Folder)

Used in: INTENT_SAVE

```bash
# 1. Stage files in project folder only
git add {project_folder}/         # CMD_STAGE_FILE

# 2. Show what will be committed
git diff --cached --stat           # CMD_DIFF_CACHED_STAT

# 3. Commit with message
git commit -m "{message}"          # CMD_COMMIT_WITH_MESSAGE

# 4. Show commit info
git log --oneline -1               # CMD_LAST_COMMIT_ONELINE
git show --stat HEAD
```

## Commit All Files (Including Outside Project Folder)

Used when user explicitly chooses to include files outside project folder:

```bash
# 1. Stage all changed files
git add .                          # CMD_STAGE_ALL

# 2. Show what will be committed
git diff --cached --stat           # CMD_DIFF_CACHED_STAT

# 3. Commit with message
git commit -m "{message}"          # CMD_COMMIT_WITH_MESSAGE

# 4. Show commit info
git log --oneline -1               # CMD_LAST_COMMIT_ONELINE
git show --stat HEAD
```

## Amend Last Commit Message

Used in: INTENT_AMEND_MESSAGE

**Check if commit is pushed**:
```bash
# Get last local commit hash
git rev-parse HEAD

# Get remote branch hash (if exists)
git rev-parse origin/{current_branch} 2>/dev/null

# Compare
# If HEAD is in `git log origin/{current_branch}..HEAD`, not pushed yet
```

**If not pushed** (safe):
```bash
git commit --amend -m "{new_message}"
```

**If already pushed** (dangerous):
- Print warning about history rewriting
- Do NOT execute automatically
- Print commands for user to run manually:
```
git commit --amend -m "your new message"
git push --force-with-lease
```

## Amend: Add File to Last Commit

Used in: INTENT_AMEND_ADD

```bash
# 1. Check last commit
git log --oneline -1

# 2. Stage additional file
git add {file}

# 3. Amend without changing message
git commit --amend --no-edit

# 4. Show updated commit
git show --stat HEAD
```

## Amend: Remove File from Last Commit

Used in: INTENT_AMEND_REMOVE

```bash
# 1. Show files in last commit
git show --stat HEAD

# 2. Reset file from HEAD~1 (previous commit)
git reset HEAD~ {file}

# 3. Amend commit without changing message
git commit --amend --no-edit

# 4. Show updated commit
git show --stat HEAD

# 5. Show status of removed file
git status {file}
```

The file now exists unstaged in working directory.

## Split Changes into Two Commits

Used in: INTENT_SPLIT

**If changes are uncommitted**:
```bash
# 1. Show all changed files
git status --short

# 2. Stage files for first commit (user selects)
git add {file1} {file2}            # CMD_STAGE_FILE

# 3. Show what's staged
git diff --cached --stat           # CMD_DIFF_CACHED_STAT

# 4. Commit first set
git commit -m "{message1}"         # CMD_COMMIT_WITH_MESSAGE

# 5. Show remaining files
git status --short

# 6. Stage remaining files
git add {file3} {file4}

# 7. Commit second set
git commit -m "{message2}"

# 8. Show both commits
git log --oneline -2
```

**If last commit needs splitting**:
```bash
# 1. Soft reset to undo last commit, keep changes
git reset --soft HEAD~1

# 2. Unstage all
git reset HEAD

# 3. Follow uncommitted flow above
```

## Interactive Add (Fine-grained Staging)

For staging specific hunks within files:

```bash
# Stage specific parts of a file interactively
git add -p {file}
```

Interactive options:
- `y` - stage this hunk
- `n` - skip this hunk
- `s` - split this hunk into smaller hunks
- `q` - quit, don't stage this or any remaining hunks
- `e` - manually edit this hunk

## Commit Message Best Practices

**Format**:
```
Short summary (50 chars or less)

Longer description if needed (wrap at 72 chars).
Explain what and why, not how.

- Bullet points are fine
- Use present tense: "Add feature" not "Added feature"
```

**Learn from repo history**:
```bash
# Show last 5 commit messages to match style
git log --oneline -5
```

**Common patterns**:
- `Add {feature}` - New functionality
- `Fix {bug}` - Bug fixes
- `Update {component}` - Improvements to existing code
- `Refactor {area}` - Code restructuring
- `Remove {feature}` - Deletion
- `Docs: {change}` - Documentation only

## View Commit History

**Last N commits**:
```bash
git log --oneline -n {n}
```

**Commits since base branch**:
```bash
git log origin/{base_branch}..HEAD --oneline
```

**Commits with file changes**:
```bash
git log --stat --oneline -n {n}
```

**Commits with full diff**:
```bash
git log -p -n {n}
```

**Commits by author**:
```bash
git log --author="{name}" --oneline
```

**Commits in date range**:
```bash
git log --since="2024-01-01" --until="2024-01-31" --oneline
```

## Show Commit Details

**Last commit**:
```bash
git show HEAD
```

**Specific commit**:
```bash
git show {hash}
```

**File in commit**:
```bash
git show {hash}:{file}
```

**Stat summary**:
```bash
git show --stat {hash}
```

## Check Commit Status

**Are there uncommitted changes?**
```bash
git status --short
```
Empty output = nothing uncommitted

**Are there staged changes?**
```bash
git diff --cached --quiet
```
Exit code 0 = nothing staged
Exit code 1 = changes staged

**Are there unstaged changes?**
```bash
git diff --quiet
```
Exit code 0 = nothing unstaged
Exit code 1 = changes unstaged

## Verify Commit Before Push

```bash
# 1. Show commits that will be pushed
git log origin/{base_branch}..HEAD --oneline

# 2. Show changed files across all commits
git diff --stat origin/{base_branch}..HEAD

# 3. Run contamination check
# (see contamination.md)

# 4. Show commit count
git rev-list --count origin/{base_branch}..HEAD
```
