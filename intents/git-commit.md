# Zenith — Commit Operations
# Handlers: INTENT_SHOW_CHANGES, INTENT_CHECK_SCOPE, INTENT_SHOW_STAGED, INTENT_SAVE, INTENT_AMEND_MESSAGE, INTENT_AMEND_ADD, INTENT_AMEND_REMOVE, INTENT_SPLIT
# Read by ZENITH.md Step 4 router. See references/common-commands.md for CMD_* definitions.

### INTENT_SHOW_CHANGES

Execute:
```bash
git diff {project_folder}/
git diff --cached {project_folder}/
```

Print:
```
changes in {project_folder}/ — unstaged and staged
│ {file}  +{n} -{n}
│ {file}  +{n} -{n}
```

If nothing: `│ no changes in {project_folder}/`

Then silently check contamination:
```bash
git diff --name-only HEAD
git diff --name-only --cached
```

If files outside {project_folder} detected:
```
  note  changes also detected outside {project_folder}/:
    {file}
    run /zenith scope check for details
```

Next: "next: run /zenith save to commit these changes"

### INTENT_CHECK_SCOPE

Execute full contamination check (see references/contamination.md).

Get all changed files:
```bash
git diff --name-only HEAD          # CMD_DIFF_NAME_ONLY
git diff --name-only --cached      # CMD_DIFF_CACHED_NAME_ONLY
```

Print:
```
scope check — comparing all changed files against {project_folder}/
│ inside {project_folder}/:
│   {file}   +{n} -{n}
│
│ outside {project_folder}/:
│   {file}   +{n} -{n}
```

Check each file for:
- Hardcoded paths (/Users/, /home/)
- Credentials (.env, *secret*, *.key)
- Large files (>50MB)
- ML outputs (*.ckpt, *.pt, /outputs/, /checkpoints/)

Print any findings as additional `│` lines under the relevant file.

If clean:
```
  ✓ clean  all changes scoped to {project_folder}/
```

Next: "next: if clean, run /zenith save to commit"

### INTENT_SHOW_STAGED

Execute:
```bash
git diff --cached --stat           # CMD_DIFF_CACHED_STAT
```

If nothing staged:
```
staged files — nothing queued yet
│ use /zenith save to stage and commit your changes
```

If staged:
```
staged files — queued for the next commit
│ {project_folder}/
│   {file}   +{n} -{n}
│
│ total  {n} files, +{n} -{n}
```

Next: "next: run /zenith save to commit these"

### INTENT_SAVE

Check situation. If on base_branch:
```
blocked — you are on {base_branch}
│ commits go on feature branches, not directly on {base_branch}
│ run /zenith start new work to create a branch first
```
Stop.

Run contamination check silently.

If files outside {project_folder} detected:

Record pattern `contamination` for `{github_org}/{github_repo}`. Then check the `contamination` threshold. If met, add the historical count line to the warning below.

```
scope warning — changes detected outside {project_folder}/
│ {file}
│ {file}
[If contamination threshold met:] │ this has happened {n} of your last 5 commits

Include or exclude outside files? [i/e]
```

If no message in request, ask: "Commit message?"

Execute:
```bash
git add {project_folder}/          # CMD_STAGE_FILE (or . if include)
git diff --cached --stat           # CMD_DIFF_CACHED_STAT
```

Check staged file count:
```bash
git diff --cached --name-only | wc -l
```

If count > 50:
```
large commit — {n} files staged
│ this is unusually large and may include auto-generated or output files
│ breakdown by folder:
│   {folder}/   {count} files
│   {folder}/   {count} files
│ run /zenith scope check for a full breakdown before continuing

Continue with all {n} files? [y/n]
```

If no: stop. User should review and re-stage selectively.

Check the `amend_after_commit` threshold. If met, add the nudge line to the pipe block below.

Print:
```
committing — saving a permanent snapshot on your branch
│ {file}   +{n} -{n}
│ {file}   +{n} -{n}
│ can be undone safely with /zenith undo last commit
[If amend_after_commit threshold met:] │ heads up  you've amended after committing {n} of your last 5 saves — review staged changes carefully

Commit these? [y/n]
```

If yes:
```bash
git commit -m "{message}"          # CMD_COMMIT_WITH_MESSAGE
git log --oneline -1               # CMD_LAST_COMMIT_ONELINE
git show --stat HEAD
```

Print:
```
  ✓ committed  {hash}
  message      {message}
    {file}   +{n} -{n}
```

Next: "next: run /zenith push to open a PR"

### INTENT_AMEND_MESSAGE

Execute:
```bash
git log --oneline -1               # CMD_LAST_COMMIT_ONELINE
git log origin/{base_branch}..HEAD --oneline  # CMD_LOG_SINCE_BASE
```

Check if commit already pushed:
```bash
git log origin/{current_branch}..HEAD --oneline
```

If last commit NOT in output (already on remote):
```
blocked — this commit is already on origin
│ amending it rewrites history, which is only safe if no one else is on this branch
│ run these manually if you want to proceed:
│   git commit --amend -m "your new message"
│   git push --force-with-lease
```
Stop.

If not pushed (safe):
```
amending message — commit not yet pushed, safe to rewrite
│ {hash}  {current_message}
│ your files stay the same — only the message changes
│ the commit gets a new hash, which is fine since it hasn't been pushed

New message?
```

Execute:
```bash
git commit --amend -m "{new_message}"
```

Print:
```
  ✓ updated  {new_message}
```

Record pattern `amend_after_commit` for `{github_org}/{github_repo}`.

Next: "next: run /zenith push when ready"

### INTENT_AMEND_ADD

Execute:
```bash
git log --oneline -1
```

Print:
```
amending commit — adding a missed file without changing the message
│ last commit: {hash}  {message}
│ the commit gets a new hash — only safe because it hasn't been pushed yet

Which file do you want to add?
```

Check file exists:
```bash
if [ ! -f {file} ]; then echo "not found: {file}"; exit 1; fi
```

Execute:
```bash
git add {file}
git commit --amend --no-edit
git show --stat HEAD
```

Print:
```
  ✓ added    {file}
  commit     {hash}
  message    {message}
```

Record pattern `amend_after_commit` for `{github_org}/{github_repo}`.

Next: "next: run /zenith push when ready"

### INTENT_AMEND_REMOVE

Execute:
```bash
git show --stat HEAD
```

Print:
```
amending commit — removing a file from the last commit
│ last commit: {hash}  {message}
│ the file will stay in your working tree, just not in the commit
│ only safe because the commit hasn't been pushed yet

Which file to remove?
```

Execute:
```bash
git reset HEAD~ {file}
git commit --amend --no-edit
git show --stat HEAD
```

Print:
```
  ✓ removed  {file}
  commit     {hash}
  file is unstaged in your working tree
```

Next: "next: file is now unstaged, not in the commit"

### INTENT_SPLIT

Execute:
```bash
git diff --stat
```

Print:
```
splitting — separating your changes into two commits
│ changed files:
│   {n}. {file}   +{n} -{n}
│   {n}. {file}   +{n} -{n}
```

Ask: "Which files go in the first commit? (enter numbers)"

Execute:
```bash
git add {selected_files}
git diff --cached --stat
```

Ask: "Message for first commit?"

Execute:
```bash
git commit -m "{message1}"
```

Show remaining files. Ask: "Message for second commit?"

Execute:
```bash
git add {remaining_files}
git commit -m "{message2}"
git log --oneline -2
```

Print:
```
  ✓ commit 1  {hash}  {message1}
  ✓ commit 2  {hash}  {message2}
```

Next: "next: run /zenith push to open PR with both commits"
