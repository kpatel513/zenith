# Safety Rules

Complete list of safety rules Zenith never violates. These are non-negotiable guardrails.

## Rule 1: Never Push to Base Branch Directly

**Enforcement**:
```bash
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "{base_branch}" ]; then
    echo "Error: Cannot push to {base_branch} directly"
    echo "Create a feature branch: /zenith start new work"
    exit 1
fi
```

**Rationale**: Base branch (main/master) should only receive changes through reviewed pull requests.

## Rule 2: Never Auto-Resolve Conflicts Outside Project Folder

**Enforcement**:
```bash
# Get conflicted files
CONFLICTED=$(git diff --name-only --diff-filter=U)

# For each conflicted file
for file in $CONFLICTED; do
    if [[ ! "$file" =~ ^{project_folder}/ ]]; then
        echo "conflict: $file"
        echo "this file is not in {project_folder}/. do not resolve this yourself."
        echo "contact the owner of this file."
        echo "to cancel: git rebase --abort"
        exit 1
    fi
done
```

**Rationale**: Files outside user's folder belong to other team members. Auto-resolving risks breaking their work.

## Rule 3: Never Run Destructive Operations Without Explicit Confirmation

**Destructive operations** requiring confirmation:
- `git reset --hard` (INTENT_DISCARD)
- `git clean -fd` (INTENT_DISCARD)
- `git push --force` (never run automatically)
- `git branch -D` (force delete)
- Amending pushed commits

**Enforcement**:
```bash
# For INTENT_DISCARD, require full word "YES"
echo "Cannot be undone. Type YES to confirm:"
read response

if [ "$response" != "YES" ]; then
    echo "Cancelled. No changes made."
    exit 0
fi

# Execute destructive operation
```

**Rationale**: Destructive operations cannot be undone. Explicit confirmation prevents accidents.

## Rule 4: Never Commit Without Showing User What Will Be Committed

**Enforcement**:
```bash
# Always run before committing
git add {files}
git diff --cached --stat

echo "Commit these? [y/n]"
read response

if [ "$response" = "y" ]; then
    git commit -m "{message}"
else
    echo "Cancelled. Changes remain staged."
    exit 0
fi
```

**Rationale**: Users should always know exactly what they're committing.

## Rule 5: Always Read Repo State Before Acting

**Enforcement**: Run full diagnostic sequence (diagnostics.md) on every invocation before interpreting user request.

```bash
# Non-negotiable sequence
cat .agent-config
git status --short
git branch --show-current
git log --oneline -5
git stash list
git remote -v
git log HEAD..origin/{base_branch} --oneline 2>/dev/null | wc -l
git diff --stat HEAD
git diff --cached --stat
```

**Rationale**: Cannot provide correct operation without understanding current state.

## Rule 6: Always Stop and Report Exact Error Output on Command Failure

**Enforcement**:
```bash
# Run command and capture output
OUTPUT=$(git push origin {branch} 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "Push failed with exit code $EXIT_CODE"
    echo ""
    echo "Error output:"
    echo "$OUTPUT"
    echo ""
    echo "Run /zenith fix push to diagnose and fix"
    exit 1
fi
```

**Rationale**: Users need exact error messages to understand and fix issues. Never swallow errors.

## Rule 7: Require Full Word "YES" Not "y" for INTENT_DISCARD

**Enforcement**:
```bash
if [ "$response" = "YES" ]; then
    # proceed with discard
elif [ "$response" = "yes" ] || [ "$response" = "y" ]; then
    echo "Type YES in capital letters to confirm"
    exit 1
else
    echo "Cancelled"
    exit 0
fi
```

**Rationale**: Higher friction for permanent data loss. "YES" is harder to type accidentally than "y".

## Rule 8: Never Amend a Pushed Commit Without Explicit Warning

**Enforcement**:
```bash
# Check if last commit is pushed
git log origin/{current_branch}..HEAD --oneline

if [ -z "$OUTPUT" ]; then
    # Last commit is on remote
    echo "This commit is already on origin."
    echo "Amending it will rewrite history."
    echo "Only safe if nobody else is working on this branch."
    echo ""
    echo "Run these commands manually if you want to proceed:"
    echo "  git commit --amend -m \"your new message\""
    echo "  git push --force-with-lease"
    exit 1
fi

# Last commit not pushed - safe to amend
git commit --amend -m "{new_message}"
```

**Rationale**: Amending pushed commits rewrites history and can break teammates' work.

## Rule 9: Never Stage or Commit Files Without Contamination Check

**Enforcement**: Before staging files in INTENT_SAVE or INTENT_PUSH:

```bash
# Run contamination check (see contamination.md)
# Check for:
# - Files outside project folder
# - Hardcoded paths
# - Credentials
# - Large files
# - ML outputs

# If issues found, warn user and require explicit decision
```

**Rationale**: Prevents accidental commits of sensitive data, large files, or out-of-scope changes.

## Rule 10: Never Execute git Commands with -i Flag

**Enforcement**: Code review all operations. Ensure none use:
- `git rebase -i`
- `git add -i`
- `git commit -i`
- Any interactive mode

**Rationale**: Interactive commands require terminal input not available in Claude Code environment.

## Rule 11: Always Sync with Base Branch Before Push

**Enforcement**: In INTENT_PUSH operation:

```bash
# After fetching, before pushing
BEHIND=$(git rev-list --count HEAD..origin/{base_branch})

if [ $BEHIND -gt 0 ]; then
    echo "Your branch is $BEHIND commits behind {base_branch}"
    echo "Syncing now..."
    git rebase origin/{base_branch}
    # Handle conflicts if any
fi

# Only push after confirmed up-to-date
git push origin {current_branch}
```

**Rationale**: Prevents conflicts in PR. Ensures clean merge into base branch.

## Rule 12: Never Modify .agent-config Programmatically

**Enforcement**: setup.sh writes it once. zenith.md only reads it, never writes.

**Rationale**: Config is personal to each user. Modifying it programmatically could break their setup.

## Rule 13: Always Show Next Action After Operation

**Enforcement**: After every operation, print one line suggesting what user can do next.

```bash
# After INTENT_SAVE
echo "next: run /zenith push to open a PR"

# After INTENT_SYNC
echo "next: continue working in {project_folder}/"

# After INTENT_START_NEW
echo "next: your branch is ready, start coding in {project_folder}/"
```

**Rationale**: Helps users navigate workflow. Clear guidance on next step.

## Rule 14: Never Auto-commit on Base Branch

**Enforcement**:
```bash
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "{base_branch}" ] && [ "$INTENT" = "INTENT_SAVE" ]; then
    echo "Error: Cannot commit on {base_branch}"
    echo "Create a feature branch first: /zenith start new work"
    exit 1
fi
```

**Rationale**: All work must be on feature branches, not base branch.

## Rule 15: Always Validate .agent-config Exists and Is Valid

**Enforcement**: First step of diagnostic sequence:

```bash
if [ ! -f .agent-config ]; then
    echo "Error: no .agent-config found"
    echo "Run setup.sh first"
    exit 1
fi

# Parse and validate required fields
GITHUB_ORG=$(grep "github_org" .agent-config | cut -d'"' -f2)
PROJECT_FOLDER=$(grep "project_folder" .agent-config | cut -d'"' -f2)

if [ -z "$GITHUB_ORG" ] || [ -z "$PROJECT_FOLDER" ]; then
    echo "Error: .agent-config is incomplete"
    echo "Re-run setup.sh"
    exit 1
fi
```

**Rationale**: Cannot operate safely without valid configuration.

## Rule 16: Never Trust User's Description of Repo State

**Enforcement**: Always run diagnostics first. Detect situation from actual git state, not from user's words.

User says "I'm on main" → verify with `git branch --show-current`
User says "I have no changes" → verify with `git status --short`
User says "I'm up to date" → verify with `git log HEAD..origin/{base_branch}`

**Rationale**: Users often misunderstand git state. Always verify with git commands.

## Rule 17: Always Prefer --force-with-lease Over --force

**Enforcement**: If force push is ever needed (and user runs manually):

```bash
# Recommend this:
git push --force-with-lease origin {branch}

# NOT this:
# git push --force origin {branch}
```

**Rationale**: `--force-with-lease` fails if remote has commits not in local. Safer than `--force`.

## Rule 18: Never Silently Skip Files in Contamination Check

**Enforcement**: Check ALL changed files, not just files in project folder.

```bash
# Get ALL changed files
git diff --name-only HEAD
git diff --name-only --cached
git status --short

# Check every single one for risks
# Report all findings, don't filter
```

**Rationale**: Risks can exist anywhere. Must check everything to be safe.

## Rule 19: Always Preserve User's Working Directory State on Error

**Enforcement**: If operation fails mid-way:
- Don't leave files staged that shouldn't be
- Don't leave in detached HEAD
- Don't leave in mid-rebase without instructions

```bash
# On error in rebase:
echo "Rebase encountered an error"
echo "Options:"
echo "  1. Fix conflicts and run: git rebase --continue"
echo "  2. Cancel rebase: git rebase --abort"
echo "Your working directory is unchanged."
```

**Rationale**: Errors happen. Don't leave user in broken state.

## Rule 20: Never Assume User Knows Git Terminology

**Enforcement**: Explain operations in plain English, not git jargon.

Bad: "Fast-forward merge failed. Need to rebase."
Good: "Can't push because your branch is behind main. Syncing now..."

Bad: "Detached HEAD state detected."
Good: "You're not on any branch. Switching you to main..."

**Rationale**: Zenith is for mixed skill levels. Clarity over precision.

## Enforcement Checklist

Before implementing any operation, verify:
- [ ] Runs diagnostics first
- [ ] Validates repo state
- [ ] Checks for destructive actions → requires confirmation
- [ ] Runs contamination check if touching files
- [ ] Applies conflict resolution rules
- [ ] Never operates on base branch directly
- [ ] Shows exact error output on failure
- [ ] Leaves user in clean state on error
- [ ] Explains next action
- [ ] Uses plain English, not jargon
