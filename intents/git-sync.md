# Zenith — Sync Operations
# Handlers: INTENT_SYNC, INTENT_HOW_FAR_BEHIND, INTENT_TEAMMATES
# Read by ZENITH.md Step 4 router. See references/common-commands.md for CMD_* definitions.

### INTENT_SYNC

Check situation. If uncommitted changes:
```
blocked — you have uncommitted changes
│ save or discard them before syncing
│ run /zenith save or /zenith throw away changes
```
Stop.

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git log HEAD..origin/{parent_branch} --oneline --format="%h %s — %an %ar"
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1
```

If no incoming commits:
```
already up to date — {parent_branch} has no new commits
│ your branch is in sync, nothing to do
```

If stacked (`{parent_branch}` ≠ `{base_branch}`), also check if `{parent_branch}` itself is behind `{base_branch}`:
```bash
git rev-list --count origin/{parent_branch}..origin/{base_branch}
```
If parent is behind main, append:
```
│ note  {parent_branch} is {n} commits behind {base_branch}
│       sync {parent_branch} first to propagate main changes up the stack
```

Stop.

Print incoming commits as `│` lines:
```
checking {parent_branch} — {n} new commit(s) since your branch diverged
│ {hash} {message} — {author} {time}
│ {hash} {message} — {author} {time}
```

**Stale branch warning** — if behind > 20 commits:

```bash
git log HEAD..origin/{parent_branch} --oneline --format="%h %s" -- {project_folder}
```

Print:
```
heads up — {n} commits to sync, this may take a moment
│ commits that touched {project_folder}/:
│   {hash} {message}
```

If none touched `{project_folder}`:
```
│ none of these touched your folder — sync should be conflict-free
```

**Determine sync strategy based on PR state:**

If an **open PR exists** for {current_branch}:
```
syncing — open PR exists, using merge to preserve review history
│ merge commit will be added to your branch
│ rewriting history would invalidate reviewer comments, so we merge instead

Sync now? [y/n]
```

If **no open PR** (pre-review, history can be rewritten safely):
```
syncing — no open PR, using rebase for clean history
│ your {n} commit(s) will replay on top of the {n} new ones from {parent_branch}
│ no merge commit will be created

Sync now? [y/n]
```

If no:
```
  cancelled  your branch is unchanged
```
Stop.

**If open PR exists — execute merge:**
```bash
git merge origin/{parent_branch}
```

If conflicts: apply three-tier resolution (see references/conflict-resolver.md), replacing abort/continue with:
- To cancel: `git merge --abort`
- After resolving and staging: `git commit` (no `--continue` needed for merge)
- Tier 1 (file outside {project_folder}): stop, do not resolve. `git merge --abort` to cancel.
- Tier 2 (mechanical): `git checkout --theirs {file}`, `git add {file}`, `git commit`
- Tier 3 (substantive): show both versions, ask [y/i/e], `git add {file}`, `git commit`

**If no open PR — execute rebase:**
```bash
git rebase origin/{parent_branch}
```

If conflicts: apply three-tier conflict resolution (see references/conflict-resolver.md):

**Tier 1**: File outside {project_folder}:
```
blocked — conflict in a file outside your folder
│ {file} is not in {project_folder}/ — do not resolve this yourself
│ contact the owner of this file
│ to cancel: git rebase --abort
```
Stop. Do not continue.

**Tier 2**: Mechanical conflict inside {project_folder} (whitespace, imports):
- Extract both versions
- Normalize (remove whitespace)
- If identical after normalization:
```bash
git checkout --theirs {file}       # CMD_CHECKOUT_THEIRS
git add {file}
```
Print:
```
  ✓ auto-resolved  {file} (whitespace / import ordering)
```
Continue rebase.

**Tier 3**: Substantive conflict inside {project_folder}:
Print:
```
conflict — {file} has changes in both your branch and {base_branch}
│ YOUR VERSION:
│ ─────────────
│ {content}
│
│ INCOMING VERSION:
│ ─────────────────
│ {content}

keep yours / keep incoming / edit manually [y/i/e]
```

Execute based on choice:
```bash
# y: git checkout --ours {file}      # CMD_CHECKOUT_OURS
# i: git checkout --theirs {file}    # CMD_CHECKOUT_THEIRS
# e: let user edit, wait for confirmation

git add {file}
git rebase --continue              # CMD_REBASE_CONTINUE
```

On rebase success, run post-rebase sanity check:
```bash
git log origin/{base_branch}..HEAD --merges --oneline
```

If merge commits found:
```
warning — merge commits found in your branch after sync
│ these shouldn't be here after a clean rebase:
│   {hash} Merge branch 'feature/teammate' into ...
│ this may mean your branch was rebased onto the wrong base at some point
│ inspect: git log origin/{base_branch}..HEAD --oneline
│ to clean: run /zenith clean up history
```

On success:
```
  ✓ synced   {current_branch}
  ahead      {n} commits ahead of {base_branch}
  latest     {hash} {message} — {author} {time}
```

Next: "next: run /zenith push when ready"

### INTENT_HOW_FAR_BEHIND

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git rev-list --count HEAD..origin/{parent_branch}  # CMD_COMMITS_BEHIND
git log HEAD..origin/{parent_branch} --oneline --format="%h %s — %an %ar"
```

If count = 0:
```
checking distance — comparing your branch against {parent_branch}
│ you are up to date, nothing to sync

  ✓ up to date with {parent_branch}
```

If count > 0:
```
checking distance — comparing your branch against {parent_branch}
│ {hash} {message} — {author} {time}
│ {hash} {message} — {author} {time}

  behind  {n} commits
```

Next: "next: run /zenith sync to catch up"

### INTENT_TEAMMATES

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git log origin/{base_branch} --since="24 hours ago" --format="%h %s — %an %ar"
```

If nothing:
```
teammate activity — last 24 hours on {base_branch}
│ nothing pushed in the last 24 hours
```

If commits:
```
teammate activity — last 24 hours on {base_branch}
│ {hash} {message} — {author} {time}
│ {hash} {message} — {author} {time}
```

Next: "next: run /zenith sync to get these changes"
