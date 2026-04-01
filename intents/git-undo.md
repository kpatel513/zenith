# Zenith — Undo Operations
# Handlers: INTENT_UNDO_COMMIT, INTENT_DISCARD, INTENT_UNSTAGE, INTENT_UNSTASH
# Read by ZENITH.md Step 4 router. See references/common-commands.md for CMD_* definitions.

### INTENT_UNDO_COMMIT

Execute:
```bash
git log --oneline -1               # CMD_LAST_COMMIT_ONELINE
```

Print:
```
undoing commit — removing from history, keeping your files
│ {hash}  {message}
│ your edits will be sitting unstaged, ready to re-commit
│ this is safe and fully reversible

Confirm? [y/n]
```

If confirmed:
```bash
git reset HEAD~1
```

Print:
```
  ✓ undone   {message}
  your changes are unstaged in your working tree
```

Next: "next: make changes and commit again, or run /zenith throw away changes to discard"

### INTENT_DISCARD

Execute:
```bash
git status --short -- {project_folder}/
```

Print:
```
⚠ discarding changes in {project_folder}/ — this cannot be undone
│ every file in `{project_folder}/` resets to your last commit
│ new files you created in {project_folder}/ will be permanently deleted
│ changes outside {project_folder}/ are NOT affected
│ there is no recovery after this

  these will be lost:
    {file}
    {file}

type YES to confirm (not "yes", not "y"):
```

Read response. Must be exactly "YES" (not "yes", not "y").

If "YES":
```bash
git restore --staged {project_folder}/
git restore {project_folder}/
git clean -fd {project_folder}/
```

Print:
```
  ✓ clean  all uncommitted changes in {project_folder}/ discarded
```

Else:
```
  cancelled  no changes made
```

Next: "next: start fresh with /zenith start new work"

### INTENT_UNSTAGE

Execute:
```bash
git diff --cached --stat           # CMD_DIFF_CACHED_STAT
```

Print:
```
staged files — currently queued for commit
│ {file}   +{n} -{n}
│ {file}   +{n} -{n}

Which file to unstage?
```

Execute:
```bash
git restore --staged {file}        # CMD_UNSTAGE_FILE
```

Print:
```
  ✓ unstaged  {file}
  still in your working tree, not staged
```

Next: "next: file is now unstaged but your changes remain"

### INTENT_UNSTASH

Execute:
```bash
git stash list                     # CMD_STASH_LIST
```

If no stashes:
```
nothing to restore — no stashed changes found
│ stashes are created automatically when you switch branches with unsaved work
```
Stop.

If only one stash, use it automatically. If multiple, show numbered list and ask: "Which stash?"

Print:
```
unstashing — restoring your saved changes back into the working tree
│ {stash_message}
│ the stash entry will be removed after restoring

Restore? [y/n]
```

Execute:
```bash
git stash pop stash@{n}
git status --short                 # CMD_STATUS_SHORT
```

Print:
```
  ✓ restored  {stash_message}
  files back in your working tree:
    {file}
    {file}
```

Next: "next: run /zenith save to commit these changes"
