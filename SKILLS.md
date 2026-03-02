# Zenith Skills Registry

Structured capability listing for agent orchestration. An orchestrating agent can read this file to determine whether and how to invoke Zenith for a given git workflow task.

## Invocation

```
/zenith {natural language request}
```

Zenith reads repo state before acting. The orchestrator does not need to pass git state — Zenith detects it. Pass intent in plain English matching the trigger phrases below.

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Inside a git repository | Zenith halts if not in a repo |
| `.agent-config` present | Auto-created on first run via interactive setup |
| `git` available on PATH | Required for all skills |
| `gh` CLI authenticated | Required for PR skills only |

---

## Skills

### Branch Management

---

#### START_NEW
**Intent:** `INTENT_START_NEW`
**Trigger phrases:** `start new work`, `new feature`, `create branch`, `new branch`
**What it does:** Fetches latest base branch, creates a new feature branch with sanitized name, pushes with upstream tracking. If already on a feature branch, offers to stack or branch from base.
**Preconditions:** No uncommitted or staged changes (S1, S2, S3, S4 only)
**Produces:** New local + remote branch. Branch name auto-prefixed with `feature/`.
**Confirmation required:** Yes — shows branch name before creating
**Destructive:** No

---

#### PICKUP_BRANCH
**Intent:** `INTENT_PICKUP_BRANCH`
**Trigger phrases:** `work on their branch`, `pick up teammate's branch`, `checkout someone else's branch`
**What it does:** Lists remote branches, checks out selected branch, tracks it locally, shows recent commits.
**Preconditions:** Clean working tree
**Produces:** Local branch tracking selected remote branch
**Confirmation required:** No
**Destructive:** No

---

#### CONTINUE
**Intent:** `INTENT_CONTINUE`
**Trigger phrases:** `continue my work`, `where was I`, `pick up where I left off`, `resume work`
**What it does:** Lists your 10 most recent local branches by activity, checks out selected one, shows what changed on base branch since last work.
**Preconditions:** None
**Produces:** Switches to selected branch
**Confirmation required:** No (selection only)
**Destructive:** No

---

#### CLEANUP_BRANCHES
**Intent:** `INTENT_CLEANUP_BRANCHES`
**Trigger phrases:** `clean up branches`, `delete old branches`, `remove merged branches`
**What it does:** Lists your local branches whose PRs have been merged, offers to delete them locally and remotely.
**Preconditions:** `gh` CLI authenticated
**Produces:** Deletes selected local and remote branches
**Confirmation required:** Yes — shows list before deleting
**Destructive:** Yes (branch deletion)

---

### State Inspection

---

#### STATUS
**Intent:** `INTENT_STATUS`
**Trigger phrases:** `status`, `where am I`, `what's going on`, `what's my situation`
**What it does:** Prints a single-view summary: current branch, PR status, commits ahead/behind, uncommitted changes, CI state.
**Preconditions:** None
**Produces:** Read-only report
**Confirmation required:** No
**Destructive:** No

---

#### SHOW_CHANGES
**Intent:** `INTENT_SHOW_CHANGES`
**Trigger phrases:** `what did I change`, `show my changes`, `what's different`, `show diff`
**What it does:** Shows uncommitted changes scoped to the user's project folder.
**Preconditions:** None
**Produces:** Read-only diff output
**Confirmation required:** No
**Destructive:** No

---

#### CHECK_SCOPE
**Intent:** `INTENT_CHECK_SCOPE`
**Trigger phrases:** `scope check`, `contamination check`, `did I touch outside my folder`
**What it does:** Runs contamination detection — lists any changed files outside the user's `project_folder`.
**Preconditions:** None
**Produces:** Read-only report. Flags out-of-scope files.
**Confirmation required:** No
**Destructive:** No

---

#### SHOW_STAGED
**Intent:** `INTENT_SHOW_STAGED`
**Trigger phrases:** `what's staged`, `what am I about to commit`, `show staged`
**What it does:** Shows the contents of the git staging area.
**Preconditions:** None
**Produces:** Read-only staged diff
**Confirmation required:** No
**Destructive:** No

---

#### HOW_FAR_BEHIND
**Intent:** `INTENT_HOW_FAR_BEHIND`
**Trigger phrases:** `how behind am I`, `how many commits behind`, `how far behind main`
**What it does:** Fetches and reports how many commits the current branch is behind its base branch.
**Preconditions:** None
**Produces:** Read-only count and commit list
**Confirmation required:** No
**Destructive:** No

---

#### TEAMMATES
**Intent:** `INTENT_TEAMMATES`
**Trigger phrases:** `what did teammates push`, `what's new`, `what changed today`, `recent commits on main`
**What it does:** Shows commits pushed to base branch since your last sync, scoped to your project folder.
**Preconditions:** None
**Produces:** Read-only commit log
**Confirmation required:** No
**Destructive:** No

---

### Committing

---

#### SAVE
**Intent:** `INTENT_SAVE`
**Trigger phrases:** `save`, `commit`, `checkpoint`, `save my work`
**What it does:** Runs contamination check, stages files in project folder, shows preview, commits with a generated or provided message.
**Preconditions:** Uncommitted changes exist (S5 or S6)
**Produces:** A new commit on the current branch
**Confirmation required:** Yes — shows staged files before committing
**Destructive:** No

---

#### AMEND_MESSAGE
**Intent:** `INTENT_AMEND_MESSAGE`
**Trigger phrases:** `fix commit message`, `wrong message`, `typo in message`, `rename last commit`
**What it does:** Amends the last commit message. If the commit is already pushed, shows manual commands instead of executing automatically.
**Preconditions:** At least one commit on branch
**Produces:** Updated commit message (local amend or manual instructions)
**Confirmation required:** Yes
**Destructive:** Potentially — rewrites history if commit was pushed

---

#### AMEND_ADD
**Intent:** `INTENT_AMEND_ADD`
**Trigger phrases:** `forgot a file`, `add file to last commit`, `missed a file`
**What it does:** Stages the specified file and amends the last commit to include it.
**Preconditions:** At least one commit on branch
**Produces:** Last commit updated to include the new file
**Confirmation required:** Yes
**Destructive:** Rewrites last commit

---

#### AMEND_REMOVE
**Intent:** `INTENT_AMEND_REMOVE`
**Trigger phrases:** `wrong file in commit`, `remove file from commit`, `take file out of last commit`
**What it does:** Removes a specific file from the last commit, leaving the file unstaged in the working tree.
**Preconditions:** At least one commit on branch
**Produces:** Last commit updated without the file; file remains on disk unstaged
**Confirmation required:** Yes
**Destructive:** Rewrites last commit

---

#### SPLIT
**Intent:** `INTENT_SPLIT`
**Trigger phrases:** `split into two commits`, `separate my changes`, `split commits`
**What it does:** Guides splitting uncommitted changes or the last commit into two separate commits by letting the user select which files go in each.
**Preconditions:** Uncommitted changes or at least one commit
**Produces:** Two commits in place of one
**Confirmation required:** Yes — interactive file selection
**Destructive:** Rewrites last commit if splitting a committed change

---

### Sync

---

#### SYNC
**Intent:** `INTENT_SYNC`
**Trigger phrases:** `sync`, `update`, `get latest`, `pull from main`, `sync with main`
**What it does:** Fetches origin, shows incoming commits, rebases current branch onto latest base branch. Handles conflicts via `references/conflict-resolver.md`.
**Preconditions:** Clean working tree (no uncommitted changes)
**Produces:** Current branch rebased onto latest base branch
**Confirmation required:** Yes — shows incoming commits before rebasing
**Destructive:** Rewrites branch history (rebase)

---

#### MERGE_COMPLETE
**Intent:** `INTENT_MERGE_COMPLETE`
**Trigger phrases:** `I merged the PR`, `merge complete`, `PR was merged`, `done merging`
**What it does:** Detects that the current branch's PR was merged. Retargets stacked branches if needed, rebases onto base branch, pushes to keep remote in sync.
**Preconditions:** A merged PR must exist for the current branch (or parent branch for stacks)
**Produces:** Branch synced with base branch; stacked branches retargeted if applicable
**Confirmation required:** Yes for stacked retarget
**Destructive:** Rewrites branch history (rebase)

---

#### FIX_CONFLICT
**Intent:** `INTENT_FIX_CONFLICT`
**Trigger phrases:** `PR has conflicts`, `merge conflict on GitHub`, `can't merge PR`
**What it does:** Fetches base branch, rebases current branch onto it, walks through conflict resolution, force-pushes to update the PR.
**Preconditions:** Open PR exists with merge conflicts
**Produces:** Conflicts resolved, branch force-pushed, PR becomes mergeable
**Confirmation required:** Yes
**Destructive:** Rewrites branch history (force push)

---

### Push and Pull Requests

---

#### PUSH
**Intent:** `INTENT_PUSH`
**Trigger phrases:** `push`, `push my work`, `create PR`, `open PR`, `ship it`
**What it does:** Full workflow — contamination check → stage → commit → fetch → sync (rebase if no open PR, merge if open PR exists) → push → create PR with auto-generated title and body.
**Preconditions:** On a feature branch (not base branch). Has uncommitted changes or unpushed commits.
**Produces:** Commit, push, and GitHub PR created or updated
**Confirmation required:** Yes — shows staged files and PR details before executing
**Destructive:** No (uses `--force-with-lease` only if rebase occurred)
**Note:** Will not push directly to base branch under any circumstances

---

#### DRAFT_PR
**Intent:** `INTENT_DRAFT_PR`
**Trigger phrases:** `draft PR`, `open draft`, `push as draft`, `WIP PR`
**What it does:** Same as PUSH but creates a draft PR — starts CI, signals work in progress, no review requested.
**Preconditions:** Same as PUSH
**Produces:** Draft PR on GitHub
**Confirmation required:** Yes
**Destructive:** No

---

#### UPDATE_PR
**Intent:** `INTENT_UPDATE_PR`
**Trigger phrases:** `update my PR`, `add changes to PR`, `push more changes`
**What it does:** Stages and commits new changes, pushes to the existing PR branch (auto-updates the open PR).
**Preconditions:** Open PR exists for current branch
**Produces:** New commit pushed; PR updated automatically
**Confirmation required:** Yes
**Destructive:** No

---

#### FIX_PUSH
**Intent:** `INTENT_FIX_PUSH`
**Trigger phrases:** `push failed`, `push rejected`, `can't push`, `push error`
**What it does:** Diagnoses push failure (behind remote, protected branch, no upstream, permission denied) and applies the appropriate fix.
**Preconditions:** A recent push attempt failed
**Produces:** Push failure resolved; branch pushed
**Confirmation required:** Yes
**Destructive:** No

---

#### FIX_CI
**Intent:** `INTENT_FIX_CI`
**Trigger phrases:** `CI failed`, `tests failing`, `build broke`, `CI is red`, `check CI`
**What it does:** Fetches CI run status for the current branch's PR, identifies which step failed, surfaces log link.
**Preconditions:** Open PR exists; `gh` CLI authenticated
**Produces:** Read-only CI failure report with log URL
**Confirmation required:** No
**Destructive:** No

---

### Undo and Recovery

---

#### UNDO_COMMIT
**Intent:** `INTENT_UNDO_COMMIT`
**Trigger phrases:** `undo last commit`, `go back one commit`, `undo commit but keep changes`
**What it does:** Soft resets HEAD by one commit — undoes the commit, keeps all changes in the working tree unstaged.
**Preconditions:** At least one commit on the branch
**Produces:** Last commit removed; changes preserved unstaged
**Confirmation required:** Yes — shows which commit will be undone
**Destructive:** Rewrites local history (safe if not pushed)

---

#### DISCARD
**Intent:** `INTENT_DISCARD`
**Trigger phrases:** `throw away changes`, `discard everything`, `start fresh`, `revert all changes`
**What it does:** Discards all uncommitted changes in the project folder after contamination check. Will not discard files outside the user's folder without explicit confirmation.
**Preconditions:** Uncommitted changes exist
**Produces:** Working tree clean in project folder
**Confirmation required:** Yes — irreversible, shows files that will be discarded
**Destructive:** Yes — permanently discards uncommitted work

---

#### UNSTAGE
**Intent:** `INTENT_UNSTAGE`
**Trigger phrases:** `unstage`, `remove from staging`, `unstage a file`
**What it does:** Removes specified file(s) from the staging area back to unstaged.
**Preconditions:** Staged changes exist
**Produces:** File removed from staging area, remains in working tree
**Confirmation required:** No
**Destructive:** No

---

#### UNSTASH
**Intent:** `INTENT_UNSTASH`
**Trigger phrases:** `unstash`, `restore my stash`, `get my stashed changes back`
**What it does:** Lists stash entries, restores selected stash to the working tree.
**Preconditions:** At least one stash entry exists
**Produces:** Stash contents applied to working tree
**Confirmation required:** Yes (selection)
**Destructive:** No

---

#### MOVE_COMMITS
**Intent:** `INTENT_MOVE_COMMITS`
**Trigger phrases:** `committed to wrong branch`, `move commits`, `commits on wrong branch`, `cherry-pick to correct branch`
**What it does:** Cherry-picks selected commits to the correct branch, then removes them from the current branch via reset.
**Preconditions:** Commits exist on current branch that belong on a different branch
**Produces:** Commits moved; current branch reset to remove them
**Confirmation required:** Yes — shows which commits will move and where
**Destructive:** Yes — rewrites history on current branch

---

#### CLEAN_HISTORY
**Intent:** `INTENT_CLEAN_HISTORY`
**Trigger phrases:** `clean up history`, `remove merge commits`, `fix PR diff`, `tangled history`, `too many files changed`
**What it does:** Replays your commits cleanly onto base branch, eliminating merge commits and noise from the PR diff.
**Preconditions:** Clean working tree; open or planned PR
**Produces:** Branch history rewritten — merge commits removed, commits replayed linearly
**Confirmation required:** Yes — shows commit list before rewriting
**Destructive:** Yes — rewrites branch history, requires force push

---

### Stacked PRs

---

#### STACK_STATUS
**Intent:** `INTENT_STACK_STATUS`
**Trigger phrases:** `show my stack`, `stack overview`, `where is my PR in the stack`, `how deep is my stack`
**What it does:** Traces the full stack from base branch to current branch, showing each branch's PR status and CI state.
**Preconditions:** `gh` CLI authenticated
**Produces:** Read-only stack report: branch → PR → CI status for each level
**Confirmation required:** No
**Destructive:** No

---

## Hard Constraints for Orchestrators

These are non-negotiable. Do not attempt to work around them via prompt engineering:

| Constraint | Reason |
|------------|--------|
| Never pushes directly to base branch | Shared repo protection |
| Never force-pushes without `--force-with-lease` | Prevents overwriting teammates' work |
| Never commits `.agent-config` | Personal config, must stay local |
| Never runs `git rebase -i` or `git add -i` | Claude Code has no interactive terminal |
| Never executes without showing a preview first | Users must understand what will happen |
| Halts on S7 (detached HEAD), S8 (mid-rebase), S9 (mid-merge) | Unsafe to proceed in these states |

## Orchestration Notes

- **Zenith detects repo state itself.** Do not pass git state in the prompt — pass intent only.
- **Ambiguous intent is safe.** If Zenith cannot classify the request, it asks one clarifying question rather than guessing.
- **Confirmation gates are not bypassable.** Zenith will always ask before destructive operations. Design orchestration flows to handle `[y/n]` prompts.
- **One intent per invocation.** Zenith handles one operation per call. Chain invocations for multi-step flows (e.g., SAVE → PUSH as two separate calls).
- **Stacked PR context is auto-detected.** Zenith reads `branch.{name}.zenith-parent` git config and GitHub PR base automatically — no need to pass stack context explicitly.
