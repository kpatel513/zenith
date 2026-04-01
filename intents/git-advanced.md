# Zenith — Advanced Git Operations
# Handlers: INTENT_STATUS, INTENT_FIX_CI, INTENT_CLEAN_HISTORY, INTENT_MOVE_COMMITS, INTENT_FIX_CONFLICT, INTENT_STACK_STATUS
# Read by ZENITH.md Step 4 router. See references/common-commands.md for CMD_* definitions.

### INTENT_STATUS

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git branch --show-current          # CMD_CURRENT_BRANCH
git status --short                 # CMD_STATUS_SHORT
git rev-list --count HEAD..origin/{parent_branch}  # CMD_COMMITS_BEHIND
git rev-list --count origin/{parent_branch}..HEAD
git diff --stat HEAD
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1
git stash list                     # CMD_STASH_LIST
git config branch.{current_branch}.zenith-parent 2>/dev/null  # CMD_GET_PARENT_BRANCH
```

Print:
```
status — {current_branch}
│ behind    {n} commits behind {parent_branch}
│ ahead     {n} commits ahead of {parent_branch}
│ changes   {n} uncommitted files
│ staged    {n} files staged
│ stashes   {n} stashed entries
│ PR        {pr_title} #{pr_number} ({pr_status})
```

If stacked (zenith-parent is set and not {base_branch}), add:
```
│ stack     {base_branch} → {parent_branch} → {current_branch}
```

(or `│ PR        no open PR` if none)

If behind > 0: `  → run /zenith sync to catch up`
If uncommitted changes: `  → run /zenith save to commit, or /zenith what did I change to review`
If open PR: `  → run /zenith CI failed to check CI status`
If stacked: `  → run /zenith show my stack for full stack overview`
If everything clean and ahead > 0: `  → run /zenith push to open a PR`
If everything clean and ahead = 0: `  → nothing to do — branch is in sync`

Next: one-line guidance based on the dominant issue found

### INTENT_FIX_CI

Execute:
```bash
git branch --show-current          # CMD_CURRENT_BRANCH
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1
gh run list --repo {github_org}/{github_repo} --branch {current_branch} --limit 5
```

If no open PR:
```
no CI to check — {current_branch} has no open PR
│ CI only runs on open PRs
│ push your branch first with /zenith push
```
Stop.

Show last 5 CI runs with status. Find the most recent failed run.

```bash
gh run view {run_id} --repo {github_org}/{github_repo} --log-failed
```

If all runs passing:
```
CI status — {current_branch}
│ all checks passed

  ✓ CI is green
```

If failed:
```
CI failed — {run_name} #{run_id}
│ failed step   {step_name}
│ output:
│   {log_lines}
│
│ PR  https://github.com/{github_org}/{github_repo}/pull/{pr_number}
```

Next: "next: fix the failure, then run /zenith push to add a new commit and re-trigger CI"

### INTENT_CLEAN_HISTORY

Check situation. If S5 or S6 (uncommitted or staged changes):
```
blocked — you have uncommitted changes
│ save or discard them before cleaning history
│ run /zenith save or /zenith throw away changes
```
Stop.

Execute:
```bash
git log origin/{parent_branch}..HEAD --merges --oneline
git log origin/{parent_branch}..HEAD --no-merges --oneline
```

If no merge commits found:
```
history is clean — no merge commits found between {current_branch} and {parent_branch}
│ your branch already has a linear history
```
Stop.

Print:
```
tangled history — your branch contains merge commits from {parent_branch}
│ these make your PR diff show unrelated files that are already merged
│ merge commits (will be removed):
│   {hash} Merge branch '{parent_branch}' into feature/...
│
│ your commits (will be kept):
│   {hash} {message}
│   {hash} {message}
│
│ this rewrites history — if you have an open PR it will update automatically
│ reviewer comments stay attached to the code, not the commit hash

Clean history now? [y/n]
```

If no:
```
  cancelled  your branch is unchanged
```
Stop.

Execute:
```bash
git rebase origin/{parent_branch}    # CMD_REBASE_ONTO_BASE
```

If conflicts: apply three-tier conflict resolution (same rules as INTENT_SYNC — see INTENT_SYNC conflict rules above):
- To cancel: `git rebase --abort`
- Tier 1 (file outside {project_folder}): stop, do not resolve
- Tier 2 (mechanical): auto-resolve, `git add {file}`, `git rebase --continue`
- Tier 3 (substantive): show both versions, ask [y/i/e], `git add {file}`, `git rebase --continue`

Check if open PR exists:
```bash
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1
```

If open PR exists, force-push:
```bash
git push origin {current_branch} --force-with-lease    # CMD_PUSH_FORCE_WITH_LEASE
```

Print:
```
  ✓ cleaned  {current_branch}
  removed    {n} merge commit(s)
  kept       {n} your commit(s)
  ahead      {n} commits ahead of {parent_branch}
```

Next: "next: run /zenith push to push your clean history"

### INTENT_MOVE_COMMITS

Check situation. If S5 or S6 (uncommitted or staged changes):
```
blocked — you have uncommitted changes
│ save or discard them before moving commits
│ run /zenith save or /zenith throw away changes
```
Stop.

If on {base_branch}:
```
blocked — you are on {base_branch}
│ commits on {base_branch} cannot be moved this way
│ switch to a feature branch first
```
Stop.

Show commits available to move:
```bash
git log origin/{parent_branch}..HEAD --oneline --reverse --format="%h %s"
```

If no commits found:
```
nothing to move — no commits on this branch ahead of {parent_branch}
│ make some commits first, then run /zenith move my commits
```
Stop.

Print:
```
commits on this branch — select which to move
│ 1. {hash} {message}  (oldest)
│ 2. {hash} {message}
│ 3. {hash} {message}  (newest)

Which to move? (numbers, e.g. "1 2 3" or "all")
```

Ask: "Move to which branch? (new branch name, or existing branch name)"

If new branch:
```bash
git fetch origin                           # CMD_FETCH_ORIGIN
git checkout -b {target} origin/{base_branch}
```

If existing branch:
```bash
git fetch origin                           # CMD_FETCH_ORIGIN
git checkout {target}
```

Cherry-pick selected commits in order (oldest first):
```bash
git cherry-pick {hash1} {hash2} ...
```

If conflicts during cherry-pick, apply three-tier conflict resolution:
- To cancel: `git cherry-pick --abort`
- Tier 1 (file outside {project_folder}): stop, do not resolve
- Tier 2 (mechanical): auto-resolve, `git add {file}`, `git cherry-pick --continue`
- Tier 3 (substantive): show both versions, ask [y/i/e], `git add {file}`, `git cherry-pick --continue`

Print cherry-pick result:
```
  ✓ cherry-picked  {n} commit(s) onto {target}
    {hash} {message}
    {hash} {message}
```

Return to source branch:
```bash
git checkout {source_branch}
```

Print:
```
remove from {source_branch} — clean up after moving
│ the {n} commit(s) are now on {target}
│ this resets {source_branch} — changes remain in your working tree if you moved all commits

Remove from {source_branch}? [y/n]
```

If yes, remove commits from source branch:
- If ALL commits were moved: `git reset --hard origin/{base_branch}`
- If LAST N commits were moved (contiguous from HEAD): `git reset --hard HEAD~{n}`
- If non-contiguous selection: `git reset --soft {hash_before_first_selected}` then re-commit only the non-moved ones

Print:
```
  ✓ moved    {n} commit(s) → {target}
  ✓ removed  from {source_branch}
```

If no:
```
  skipped  commits remain on {source_branch}
```

Next: "next: run /zenith push on {target} to open a PR"

### INTENT_FIX_CONFLICT

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git branch --show-current          # CMD_CURRENT_BRANCH
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1
git log --merges --oneline -1 origin/{base_branch}
```

If no open PR:
```
no conflict to fix — {current_branch} has no open PR
│ merge conflicts only appear on open PRs
│ push your branch first with /zenith push
```
Stop.

Print:
```
conflict detected — your PR is blocked on {base_branch}
│ the conflicting files need to be resolved locally, then pushed
│ your PR unblocks automatically after you push the resolution
```

Check situation. If S5:
```
blocked — you have uncommitted changes
│ save or discard them before resolving conflicts
│ run /zenith save or /zenith throw away changes
```
Stop.

Print:
```
resolving conflict — merging {base_branch} locally so you can fix the conflicts
│ after you resolve and push, GitHub updates your PR automatically

Resolve conflicts now? [y/n]
```

If yes:
```bash
git merge origin/{base_branch}
```

If conflicts:

For each conflicted file:
```bash
git diff --name-only --diff-filter=U
```

Apply three-tier resolution (see references/conflict-resolver.md):

Tier 1 (file outside {project_folder}):
```
blocked — conflict in a file outside your folder
│ {file} is not in {project_folder}/ — do not resolve this yourself
│ contact the owner of this file before continuing
```
Stop.

Tier 2 (mechanical): auto-resolve, `git add {file}`, print:
```
  ✓ auto-resolved  {file} (whitespace / import ordering)
```

Tier 3 (substantive): show both versions, ask [y/i/e], `git add {file}`

After the user selects a resolution for each Tier 3 file, show the discarded version explicitly and ask for confirmation before moving on:

```
discarded version — this content will not be in the commit
│ {file}
│   {discarded_lines}
│ this is what was dropped — verify it does not contain logic you need

Is the discarded version safe to drop? [y/n]
```

If no: stop. User should manually merge the needed logic before proceeding.

After all conflicts resolved:
```bash
git commit
git push origin {current_branch}   # CMD_PUSH_SIMPLE
```

Print:
```
  ✓ conflict resolved  {file}
  ✓ pushed             {hash}
  PR is unblocked — GitHub will update automatically
```

Next: "next: check your PR on GitHub — CI will re-run on the new commit"

### INTENT_STACK_STATUS

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git branch --show-current          # CMD_CURRENT_BRANCH
```

Walk the stack upward from {current_branch} using stored config:
```bash
# Build ordered stack: oldest ancestor first, current branch last
STACK=("{current_branch}")
BRANCH="{current_branch}"
while true; do
    PARENT=$(git config branch."$BRANCH".zenith-parent 2>/dev/null)
    if [ -z "$PARENT" ] || [ "$PARENT" = "{base_branch}" ]; then
        break
    fi
    STACK=("$PARENT" "${STACK[@]}")
    BRANCH="$PARENT"
done
```

If no zenith-parent config found (stack has only one entry):
```
not in a stack — {current_branch} is a regular branch
│ stacks start when you run /zenith start new work while already on a feature branch
│ that creates a branch whose PR targets your feature branch instead of {base_branch}
│ use stacks when change B depends on change A and both need separate PRs
```
Stop.

For each branch in STACK (bottom-most ancestor first), collect:
```bash
# For each {stack_branch} in STACK:
PR_OPEN=$(gh pr list --repo {github_org}/{github_repo} --head {stack_branch} --state open --json number,isDraft,url --jq '.[0]' 2>/dev/null)
PR_MERGED=$(gh pr list --repo {github_org}/{github_repo} --head {stack_branch} --state merged --json number,url --jq '.[0]' 2>/dev/null)
STACK_PARENT=$(git config branch.{stack_branch}.zenith-parent 2>/dev/null || echo "{base_branch}")
COMMITS_AHEAD=$(git rev-list --count origin/"$STACK_PARENT"..origin/{stack_branch} 2>/dev/null || git rev-list --count origin/"$STACK_PARENT"..{stack_branch} 2>/dev/null || echo "?")
CI_STATUS=$(gh pr view {stack_branch} --repo {github_org}/{github_repo} --json statusCheckRollup --jq '.statusCheckRollup // [] | map(.conclusion) | if any(. == "FAILURE") then "CI ✗" elif any(. == null) then "CI …" elif length == 0 then "" else "CI ✓" end' 2>/dev/null)
```

Print the stack from base → tip (reading order matches merge order):
```
stack — {n} branches deep on {base_branch}

│ {base_branch} (base)
│   ↓
│ {branch_1}   PR #{n} open     CI ✓   {n} commits ahead of {base_branch}
│   ↓
│ {branch_2}   PR #{n} draft    CI …   {n} commits ahead of {branch_1}   ← you are here
```

Status labels per branch:
- `open` — PR is open and ready for review
- `draft` — PR is open as a draft (CI runs, reviewers not notified)
- `merged` — PR was merged; stack may need retargeting
- `no PR` — branch not yet pushed or PR not opened

After the table, if any branch in the stack shows `merged`:
```
  → merged branch detected — run /zenith I merged the PR to retarget the stack
```

If any branch has `no PR`:
```
  → {stack_branch} has no PR — run /zenith push on that branch to open one
```

If all branches are open and up to date:
```
  ✓ stack is clean — all branches have open PRs
```

Next: guidance based on the dominant issue in the stack (merged > no PR > CI failing > clean)
