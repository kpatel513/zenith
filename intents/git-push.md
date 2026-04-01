# Zenith — Push Operations
# Handlers: INTENT_PUSH, INTENT_FIX_PUSH, INTENT_UPDATE_PR, INTENT_DRAFT_PR, INTENT_MERGE_COMPLETE
# Read by ZENITH.md Step 4 router. See references/common-commands.md for CMD_* definitions.

### INTENT_PUSH

Run full diagnostic. Check situation.

If on base_branch:
```
blocked — you are on {base_branch}
│ create a feature branch first, then push from there
│ run /zenith start new work
```
Stop.

Run contamination check silently. If files outside {project_folder}:
```
scope warning — changes detected outside {project_folder}/
│ {file}
│ {file}

Include or exclude outside files? [i/e]
```

If nothing staged and nothing committed ahead of base:
```
nothing to push — no changes and no unpushed commits
│ make some changes first, then run /zenith push
```
Stop.

If no message in request and uncommitted changes exist, ask: "Commit message?"

If uncommitted changes exist:
```bash
git add {project_folder}/          # CMD_STAGE_FILE (or all if include)
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

If behind count from Step 1 diagnostics is ≥5, check the `push_behind_main` threshold. If met, add the nudge line to the pipe block below.

Print:
```
pushing — commit → sync with {parent_branch} → push → open PR
│ {file}   +{n} -{n}
│ {file}   +{n} -{n}
│ all steps run automatically after you confirm
[If push_behind_main threshold met and behind ≥5:] │ heads up  you've pushed with {behind_count}+ commits behind {parent_branch} before — /zenith sync first catches conflicts earlier

Commit and push? [y/n]
```

If no:
```
  cancelled  no changes made
```
Stop.

Execute in order (stop on any failure):
```bash
git commit -m "{message}"          # CMD_COMMIT_WITH_MESSAGE (only if uncommitted changes exist — must be before sync)
```

Print:
```
committing
│ {message}

  ✓ {hash}
```

```bash
git fetch origin                   # CMD_FETCH_ORIGIN
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1
```

**If an open PR exists** — sync with merge to preserve review comments:

Print:
```
syncing — open PR exists, merging {parent_branch} to preserve review history
│ rewriting history would invalidate reviewer comments
```

```bash
git merge origin/{parent_branch}   # preserves commit history, no force push needed
```

**If no open PR** — sync with rebase for clean history:

Print:
```
syncing — no open PR, rebasing onto {parent_branch} for clean history
│ {n} new commits on {parent_branch} (or "{parent_branch} is up to date")
```

```bash
git rebase origin/{parent_branch}
```

Print:
```
  ✓ synced
```

Apply conflict resolution if needed (see INTENT_SYNC conflict rules above).

```bash
git push -u origin {current_branch}  # CMD_PUSH_SET_UPSTREAM
```

Print:
```
pushing — sending your branch to GitHub
│ → origin/{current_branch}

  ✓ pushed
```

If behind count from Step 1 diagnostics was ≥5, record pattern `push_behind_main` for `{github_org}/{github_repo}`.

Ask: "Open as draft PR or ready for review? [d/r]"

If draft:
```bash
gh pr create --draft --base {parent_branch} --head {current_branch} --title "{last_commit_message}" --body ""
```

Print:
```
opening draft PR — CI will run, reviewers not notified yet
│ branch   {current_branch}
│ base     {parent_branch}
│ commits  {n} ahead of {parent_branch}

  ✓ draft PR opened
```

Next: "next: when ready for review, run /zenith push — Zenith will mark it ready"

If ready for review:

Read commits to generate PR content:
```bash
git log origin/{parent_branch}..HEAD --format="%s" | head -1
git log origin/{parent_branch}..HEAD --reverse --format="- %s"
```

Print:
```
creating PR — {n} commit(s) ready for review
│ title   {first_commit_subject}
│ body
│   {commit_list}
```

If stacked (`{parent_branch}` ≠ `{base_branch}`), add to the preview:
```
│ note    stacked PR — targets {parent_branch}, not {base_branch}
│         this PR will merge after {parent_branch} merges
```

```
Create this PR? [y/edit/n]
```

If n:
```
  PR not created
  create it manually at:
  https://github.com/{github_org}/{github_repo}/compare/{parent_branch}...{current_branch}?expand=1
```
Stop.

If edit: Ask "Title?" (press Enter to keep current), then "Description?" (press Enter to keep current). Update values.

If y or after edit:
```bash
gh pr create --base {parent_branch} --head {current_branch} --title "{title}" --body "{body}"
```

Print:
```
  ✓ PR       {pr_url}
  branch     {current_branch}
  base       {parent_branch}
  commits    {n} ahead of {parent_branch}
```

If stacked, add:
```
  stack      {base_branch} → {parent_branch} → {current_branch}
```

Next: "next: when your PR is merged, run /zenith I merged the PR to sync up"

### INTENT_MERGE_COMPLETE

This intent handles the post-merge cleanup. Trigger when user says: "merge complete", "I merged it", "PR was merged", "merge the pr" (when no open PR exists), "done merging", "just merged".

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state merged --limit 1
git rev-list --count HEAD..origin/{base_branch}  # CMD_COMMITS_BEHIND
git rev-list --count origin/{base_branch}..HEAD
```

**Stacked case: this branch's own PR was merged into its parent (not into base_branch)**

If `{parent_branch}` ≠ `{base_branch}` AND merged PR found for `{current_branch}`:

```bash
git rev-list --count HEAD..origin/{parent_branch}
```

Print:
```
post-merge sync — your PR was merged into {parent_branch}
│ rebasing onto {parent_branch} to bring {current_branch} forward
```

Execute:
```bash
git rebase origin/{parent_branch}
git rev-list --count HEAD..origin/{parent_branch}
git rev-list --count origin/{parent_branch}..HEAD
```

Print:
```
  ✓ synced   {current_branch}
  behind     0 (relative to {parent_branch})
  ahead      0
  your branch is clean and in sync with {parent_branch}
```

Next: "next: start new work, or keep building on {current_branch}"
Stop.

---

**Stacked case: parent PR was merged into base_branch**

If `{parent_branch}` ≠ `{base_branch}` AND a merged PR exists for `{parent_branch}` into `{base_branch}`:

Print:
```
parent PR merged — {parent_branch} landed in {base_branch}
│ your branch still targets {parent_branch}, which no longer exists as a live branch
│ retargeting: {parent_branch} → {base_branch}
│ replaying your commits on top of {base_branch} (dropping {parent_branch}'s commits)
│ your work is preserved — only the stack structure changes

Retarget and rebase? [y/n]
```

If yes:

```bash
# Get parent tip for rebase --onto
PARENT_TIP=$(git config branch.{current_branch}.zenith-parent-tip 2>/dev/null)

# Fallback: use remote if still available
if [ -z "$PARENT_TIP" ] && git ls-remote --heads origin {parent_branch} | grep -q .; then
    PARENT_TIP=$(git rev-parse origin/{parent_branch})
fi

# Retarget this PR's base on GitHub
PR_NUMBER=$(gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --json number --jq '.[0].number' 2>/dev/null)
[ -n "$PR_NUMBER" ] && gh pr edit "$PR_NUMBER" --base {base_branch}

# Rebase: drop parent's commits, keep ours   # CMD_REBASE_ONTO_PARENT
git rebase --onto origin/{base_branch} ${PARENT_TIP}

git push origin {current_branch} --force-with-lease  # CMD_PUSH_FORCE_WITH_LEASE

# Clear parent tracking — this branch is no longer stacked
git config --unset branch.{current_branch}.zenith-parent
git config --unset branch.{current_branch}.zenith-parent-tip
```

Print:
```
  ✓ retargeted  PR now targets {base_branch}
  ✓ rebased     your commits are on top of {base_branch}
  ✓ pushed      history updated on origin
  stack         removed — {current_branch} is now a direct branch from {base_branch}
```

Next: "next: your PR is ready for review — CI will re-run on the rebased commits"
Stop.

If no, stop. User will retarget manually.

---

**Standard case: this branch's own PR was merged into base_branch**

If merged PR found for `{current_branch}` into `{base_branch}` OR (0 ahead AND behind > 0):

Print:
```
post-merge sync — your PR was merged, pulling in the merge commit
│ {current_branch} is {n} behind {base_branch}
│ rebasing to bring it forward
```

Execute:
```bash
git rebase origin/{base_branch}    # CMD_REBASE_ONTO_BASE
git rev-list --count HEAD..origin/{base_branch}
git rev-list --count origin/{base_branch}..HEAD
```

Print:
```
  ✓ synced   {current_branch}
  behind     0
  ahead      0
  your branch is clean and in sync with {base_branch}
```

Next: "next: start new work with /zenith start new feature, or keep building on {current_branch}"

If no merged PR found AND branch is not behind:
```
already in sync — no merged PR found for {current_branch}
│ branch is already up to date with {base_branch}
```

### INTENT_FIX_PUSH

Execute:
```bash
git status                         # CMD_STATUS_SHORT
git branch --show-current          # CMD_CURRENT_BRANCH
git fetch origin                   # CMD_FETCH_ORIGIN
git log --oneline -3               # CMD_LAST_COMMIT_ONELINE
```

Diagnose issue:

**Behind remote branch**:
```bash
git rev-list --count HEAD..origin/{current_branch}
```

If > 0:
```
push rejected — your branch is behind origin/{current_branch}
│ {n} commit(s) on the remote that you don't have locally
│ rebase will pull them in and keep your commits on top

Fix this now? [y/n]
```

If yes:
```bash
git pull --rebase origin {current_branch}
git push origin {current_branch}
```

Print:
```
  ✓ fixed  rebased and pushed
```

**Protected branch**:
If current_branch == base_branch:
```
push rejected — direct push to {base_branch} is not allowed
│ create a feature branch and push from there
│ run /zenith start new work
```

**No upstream**:
```bash
git rev-parse --abbrev-ref @{upstream} 2>/dev/null
```

If empty:
```
push failed — no upstream set for this branch
│ setting upstream and pushing now
```

```bash
git push -u origin {current_branch}
```

Print:
```
  ✓ upstream set and pushed
```

**Permission denied**:
```
push rejected — you do not have push access to this repository
│ check your GitHub permissions or SSH key configuration
```

Next: "next: run /zenith push to continue"

### INTENT_UPDATE_PR

Check situation. If on base_branch:
```
blocked — you are on {base_branch}
│ switch to your feature branch first
```
Stop.

If no message in request, ask: "Commit message?"

Execute:
```bash
git add {project_folder}/          # CMD_STAGE_FILE
git diff --cached --stat           # CMD_DIFF_CACHED_STAT
```

Print:
```
updating PR — staging new changes to add to your open PR
│ {file}   +{n} -{n}
│ {file}   +{n} -{n}

Add these to your PR? [y/n]
```

If yes:
```bash
git commit -m "{message}"          # CMD_COMMIT_WITH_MESSAGE
git push origin {current_branch}   # CMD_PUSH_SIMPLE
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --json url --jq '.[0].url'
```

Print:
```
  ✓ pushed   {hash}  {message}
  PR         {pr_url}
```

Next: "next: PR updated — reviewers will see the new commit"

### INTENT_DRAFT_PR

Same as INTENT_PUSH but always opens as draft. Skips the [d/r] question.

Execute the full INTENT_PUSH flow (commit if needed, sync, push), then:
```bash
gh pr create --draft --base {parent_branch} --head {current_branch} --title "{last_commit_message}" --body ""
```

Print:
```
opening draft PR — CI will run, reviewers not notified yet
│ branch   {current_branch}
│ base     {parent_branch}
│ commits  {n} ahead of {parent_branch}

  ✓ draft PR opened
```

Next: "next: when ready for review, say /zenith push — Zenith will mark the PR ready"
