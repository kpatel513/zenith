# Conflict Resolution Rules

Three-tier conflict resolution system with non-negotiable rules for handling merge/rebase conflicts.

**See tools/common-commands.md for shared command patterns (CMD_*).**

## When Conflicts Occur

Conflicts occur during:
- `git rebase origin/{base_branch}` (INTENT_SYNC)
- `git pull --rebase` (INTENT_FIX_PUSH)
- `git merge` operations

Git status will show:
```
UU file1.py
UA file2.py
```

Or output contains "CONFLICT (content)" or "CONFLICT (modify/delete)"

## Three-Tier Resolution System

### Tier 1: Outside Project Folder (STOP - DO NOT RESOLVE)

**Rule**: If conflict is in a file outside `{project_folder}/`, STOP immediately.

**Detection**:
```bash
git diff --name-only --diff-filter=U
```

For each conflicted file, check if path starts with `{project_folder}/`:
- NO: apply Tier 1 rules

**Action**:
1. Print:
```
conflict: {file}
this file is not in {project_folder}/. do not resolve this yourself.
contact the owner of this file.
to cancel: git rebase --abort
```

2. STOP. Do not continue rebase.
3. Do not attempt resolution.
4. User must manually contact file owner or run `git rebase --abort`.

**Rationale**: Files outside user's folder are owned by others. Auto-resolving risks breaking their work.

### Tier 2: Mechanical Conflicts Inside Project Folder (AUTO-RESOLVE)

**Rule**: If conflict is inside `{project_folder}/` AND involves only mechanical changes, resolve automatically using incoming version.

**Mechanical Changes Include**:
- Whitespace only (spaces, tabs, blank lines)
- Import statement order
- Trailing commas
- Line endings (CRLF vs LF)
- Code formatting (indentation changes with no logic change)

**Detection Algorithm**:

1. Extract both versions from conflict:
```bash
git show :2:{file} > /tmp/ours
git show :3:{file} > /tmp/theirs
```

2. Normalize both versions (remove whitespace, sort imports):
```bash
# Remove all whitespace
sed 's/[[:space:]]//g' /tmp/ours > /tmp/ours_normalized
sed 's/[[:space:]]//g' /tmp/theirs > /tmp/theirs_normalized
```

3. Compare normalized versions:
```bash
diff /tmp/ours_normalized /tmp/theirs_normalized
```

4. If diff is empty: conflict is mechanical

**Action**:
```bash
git checkout --theirs {file}
git add {file}
echo "auto-resolved: {file} (whitespace/imports)"
git rebase --continue
```

**Examples of Mechanical Conflicts**:

```python
# OURS
import os
import sys
from typing import List

# THEIRS
from typing import List
import os
import sys
```
Result: Accept theirs, continue.

```python
# OURS
def process(data):
    return data.strip()

# THEIRS
def process(data):

    return data.strip()
```
Result: Accept theirs, continue.

### Tier 3: Substantive Conflicts Inside Project Folder (SHOW BOTH - ASK USER)

**Rule**: If conflict is inside `{project_folder}/` AND involves substantive code changes on both sides, show both versions and ask user.

**Substantive Changes Include**:
- Logic changes
- Different function implementations
- Variable name changes
- Added/removed function calls
- Different return values
- Algorithm changes

**Detection**: After Tier 2 check, if normalized versions differ, conflict is substantive.

**Action**:

1. Extract and display both versions clearly:
```
conflict in {file}

YOUR VERSION:
─────────────
{content from :2}

INCOMING VERSION:
─────────────────
{content from :3}
```

2. Ask: "keep yours / keep incoming / I will edit manually [y/i/e]"

3. Apply choice:
   - `y`: `git checkout --ours {file}`
   - `i`: `git checkout --theirs {file}`
   - `e`: Stop and let user edit manually, then `git add {file}` when done

4. Continue:
```bash
git add {file}
git rebase --continue
```

**Examples of Substantive Conflicts**:

```python
# OURS
def calculate(x):
    return x * 2

# THEIRS
def calculate(x):
    return x ** 2
```
Result: Show both, ask user.

```python
# OURS
result = api.fetch_user(id)

# THEIRS
result = api.get_user_by_id(id)
```
Result: Show both, ask user.

## Conflict Resolution Workflow

```
Start rebase
    ↓
Conflict detected
    ↓
Get conflicted file list
    ↓
For each file:
    ↓
    Is file outside project_folder?
    YES → Tier 1: STOP, show error
    NO  → Continue
    ↓
    Extract both versions
    ↓
    Normalize both versions
    ↓
    Are normalized versions identical?
    YES → Tier 2: Auto-resolve with theirs
    NO  → Tier 3: Show both, ask user
    ↓
    git add {file}
    ↓
Next file or continue rebase
```

## Error Handling

### Rebase cannot continue
If `git rebase --continue` fails:
1. Show exact error output
2. Check if user needs to stage files: `git status`
3. If files not staged: "stage your resolved files: git add {files}"

### User wants to abort
Recognize phrases: "abort", "cancel", "stop", "go back"
Run: `git rebase --abort`
Confirm: "rebase aborted. your branch is unchanged."

### Multiple conflicts in sequence
After resolving one conflict, check for more:
```bash
git rebase --continue
```
If another conflict appears, start Tier system again for new conflict set.
