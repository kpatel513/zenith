# Requirements Specification

## Functional Requirements

### FR-1: Start New Work (INTENT_START_NEW)
- Fetch latest from remote
- Switch to base branch
- Pull latest changes
- Prompt for work description
- Sanitize description into branch name (lowercase, spaces to hyphens, prefix feature/)
- Create and checkout new branch
- Push branch with upstream tracking
- Display branch info and working folder

### FR-2: Pickup Teammate's Branch (INTENT_PICKUP_BRANCH)
- List all remote branches except base branch
- Display numbered list sorted by date
- Prompt for selection
- Fetch latest
- Checkout branch tracking remote
- Display last 3 commits with authors and times

### FR-3: Continue Existing Work (INTENT_CONTINUE)
- List local branches sorted by recent activity, exclude base branch
- Display numbered list with last commit info
- Prompt for selection
- Checkout selected branch
- Fetch and compare with base branch
- Show new commits on base branch since last work
- Optionally trigger sync

### FR-4: Show Changes (INTENT_SHOW_CHANGES)
- Display unstaged changes in project folder
- Display staged changes in project folder
- Group by file with line counts
- Silently check for changes outside project folder
- Flag if external changes detected

### FR-5: Check Scope (INTENT_CHECK_SCOPE)
- List all changed files grouped by inside/outside project folder
- Check each file for hardcoded paths (/Users/, /home/)
- Check each file for credentials patterns (.env, *secret*, *.key, *.pem)
- Check each file size (flag if >50MB)
- Check each file for ML output patterns (*.ckpt, *.pt, /outputs/, /checkpoints/)
- Display all findings or "clean" status

### FR-6: Show Staged (INTENT_SHOW_STAGED)
- Display staged files grouped by folder
- Show line counts for each file
- Show total changes
- Message if nothing staged

### FR-7: Save Work (INTENT_SAVE)
- Block if on base branch
- Run contamination check
- Prompt for include/exclude if external files found
- Prompt for commit message if not provided
- Stage files (scoped or all)
- Display what will be committed
- Confirm before committing
- Commit and display result

### FR-8: Amend Commit Message (INTENT_AMEND_MESSAGE)
- Display last commit
- Check if commit already pushed to remote
- If pushed: warn about history rewriting, show manual commands, stop
- If not pushed: prompt for new message and amend

### FR-9: Amend Add File (INTENT_AMEND_ADD)
- Display last commit
- Prompt for file to add
- Validate file exists
- Stage file and amend without changing message
- Display updated commit

### FR-10: Amend Remove File (INTENT_AMEND_REMOVE)
- Display files in last commit
- Prompt for file to remove
- Reset file from previous commit
- Amend without changing message
- Display updated commit and unstaged file status

### FR-11: Split Commits (INTENT_SPLIT)
- Display all changed files
- Prompt for files for first commit
- Stage selected files
- Prompt for first commit message
- Commit first set
- Display remaining files
- Prompt for second commit message
- Stage and commit remaining files
- Display both commits

### FR-12: Sync with Base Branch (INTENT_SYNC)
- Block if uncommitted changes
- Fetch latest
- Show incoming commits from base branch
- Rebase onto base branch
- Apply three-tier conflict resolution:
  - Tier 1: Outside project folder → stop, show error
  - Tier 2: Mechanical inside project folder → auto-resolve
  - Tier 3: Substantive inside project folder → show both, ask user
- Display sync summary on success

### FR-13: How Far Behind (INTENT_HOW_FAR_BEHIND)
- Fetch latest
- Count commits behind base branch
- Display commit list with authors and times
- Message if up to date

### FR-14: Teammates Changes (INTENT_TEAMMATES)
- Fetch latest
- Show commits to base branch in last 24 hours
- Display with authors and times
- Message if nothing

### FR-15: Undo Last Commit (INTENT_UNDO_COMMIT)
- Display last commit
- Confirm with user
- Soft reset (keep changes unstaged)
- Display result

### FR-16: Discard All Changes (INTENT_DISCARD)
- Display all files that will be lost
- Require typing "YES" in full
- Hard reset and clean untracked files
- Display result

### FR-17: Unstage File (INTENT_UNSTAGE)
- Display staged files
- Prompt for file selection
- Unstage selected file
- Display result

### FR-18: Push (INTENT_PUSH)
- Block if on base branch
- Block if nothing to push (no uncommitted changes and no unpushed commits)
- Run contamination check
- Prompt for commit message if uncommitted changes exist
- Stage files (scoped to project_folder, or all if user chose include)
- Show staged diff and confirm before committing
- Commit
- Fetch latest
- Check for open PR on this branch — determines rebase vs merge strategy
- If open PR exists: merge origin/{base_branch} (preserves review comments, avoids force push)
- If no open PR: rebase onto origin/{base_branch} (clean linear history)
- Push with upstream tracking
- Create PR via `gh pr create` (or mark existing draft as ready for review)

### FR-19: Fix Push (INTENT_FIX_PUSH)
- Run diagnostics
- Detect push failure reason:
  - Behind remote branch → pull with rebase
  - Protected branch → suggest feature branch
  - No upstream → set upstream and push
  - Permission denied → show troubleshooting

### FR-20: Update PR (INTENT_UPDATE_PR)
- Block if on base branch
- Prompt for commit message
- Stage project folder
- Display staged changes
- Confirm before committing
- Push to existing branch
- Display PR URL

### FR-21: Status (INTENT_STATUS)
- Fetch latest
- Display current branch, how far ahead/behind base branch, uncommitted changes count, staged file count, stash count, and open PR status in one view
- Suggest the most relevant next action based on current state

### FR-22: Draft PR (INTENT_DRAFT_PR)
- Same flow as FR-18 (Push) but always opens PR as draft
- Draft PR starts CI without notifying reviewers
- After push, run `gh pr create --draft`

### FR-23: Fix CI (INTENT_FIX_CI)
- Require open PR on current branch
- Fetch recent CI run list via `gh run list`
- Find most recent failed run and show failed step output via `gh run view --log-failed`
- Link to PR and failed run on GitHub

### FR-24: Clean Up Branches (INTENT_CLEANUP_BRANCHES)
- Fetch and prune remote refs
- Find merged branches via git ancestry (`git branch --merged`) union GitHub PR history (`gh pr list --state merged`)
- Filter to branches owned by current user
- Show list with last commit hash before deleting (for recoverability)
- Confirm before deleting; support selecting a subset
- Delete local branch with `-D`; attempt remote delete (silently skip if already deleted by GitHub)

### FR-25: Clean History (INTENT_CLEAN_HISTORY)
- Block if uncommitted changes
- Detect merge commits between current branch and base branch (`git log --merges`)
- If none: report history is already clean
- Show merge commits that will be removed and user commits that will be kept
- Rebase onto base branch to remove merge commits
- Apply three-tier conflict resolution
- Force-push with `--force-with-lease` if open PR exists

### FR-26: Move Commits (INTENT_MOVE_COMMITS)
- Block if uncommitted changes
- Block if on base branch
- Show commits ahead of base branch
- Prompt for which commits to move and target branch name
- Cherry-pick selected commits onto target branch (new or existing)
- Apply three-tier conflict resolution during cherry-pick
- Offer to remove commits from source branch after moving

### FR-27: Unstash (INTENT_UNSTASH)
- List all stashes
- If none: report no stashes
- If one: use it automatically
- If multiple: show numbered list, prompt for selection
- Restore selected stash via `git stash pop`
- Display files restored

### FR-28: Fix Conflict (INTENT_FIX_CONFLICT)
- Require open PR on current branch
- Block if uncommitted changes
- Merge base branch locally to surface conflicts
- Apply three-tier conflict resolution (same rules as FR-12)
- Push resolved state to update PR automatically

### FR-29: Merge Complete (INTENT_MERGE_COMPLETE)
- Detect merged PR for current branch via `gh pr list --state merged`
- Rebase local branch onto base branch to incorporate the merge commit
- Report 0 ahead / 0 behind when done

### FR-30: Help (INTENT_HELP)
- Display table of natural language phrases and corresponding actions
- No technical jargon

### FR-22: Status (INTENT_STATUS)
- Fetch latest from remote
- Show branch name, commits ahead/behind parent branch, uncommitted files, staged files, stash count
- Show open PR if one exists
- Show stack info if on a stacked branch
- Give one-line next-action guidance based on dominant issue

### FR-23: Draft PR (INTENT_DRAFT_PR)
- Same flow as INTENT_PUSH but always opens PR as draft
- Skips the draft/ready question
- CI runs, reviewers not notified

### FR-24: Fix CI (INTENT_FIX_CI)
- Check for open PR on current branch
- List last 5 CI runs with status
- Find most recent failed run and show log output
- Link to PR

### FR-25: Cleanup Branches (INTENT_CLEANUP_BRANCHES)
- Fetch and prune remote refs
- Find merged branches via git ancestry (regular merges) and GitHub PR history (squash merges)
- Filter to branches owned by current user
- Show numbered list with tip hash and age
- Delete selected branches locally and remotely (silently ignore remote failures)

### FR-26: Clean History (INTENT_CLEAN_HISTORY)
- Block if uncommitted changes
- Detect merge commits between current branch and parent branch
- Show merge commits to remove and own commits to keep
- Rebase onto parent branch to remove merge commits
- Force-push if open PR exists

### FR-27: Move Commits (INTENT_MOVE_COMMITS)
- Block if uncommitted changes or on base branch
- Show commits on current branch ahead of parent branch
- Ask which commits to move and which target branch
- Cherry-pick selected commits onto target branch
- Remove selected commits from source branch

### FR-28: Unstash (INTENT_UNSTASH)
- List all stashed entries
- If one stash: use automatically; if multiple: prompt for selection
- Pop selected stash and show restored files

### FR-29: Fix Conflict (INTENT_FIX_CONFLICT)
- Block if no open PR
- Block if uncommitted changes
- Merge base branch locally to surface conflicts
- Apply three-tier conflict resolution (see FR-12)
- Push resolved merge commit to unblock PR

### FR-30: Merge Complete (INTENT_MERGE_COMPLETE)
- Detect whether own PR or parent PR was merged
- If stacked and own PR merged into parent: rebase onto parent
- If stacked and parent PR merged into base: retarget PR, rebase --onto, unset parent config
- If standard: rebase onto base branch and confirm sync

### FR-31: Stacked PRs (INTENT_STACK_STATUS + cross-intent support)
- Allow creating a branch that targets another feature branch instead of base branch
- Store parent branch in git config (zenith-parent) at branch creation
- Store parent tip hash in git config (zenith-parent-tip) for rebase --onto after parent deletion
- All operations (push, sync, how far behind, clean history, move commits) use parent branch as comparison base
- INTENT_STACK_STATUS: walk the full stack chain, show each branch with PR status, CI status, and commit count
- INTENT_MERGE_COMPLETE: handle three cases — own PR merged, parent PR merged, standard
- PR retargeting: update PR base with gh pr edit --base after parent is merged

## Non-Functional Requirements

### NFR-1: Single Entry Point
All functionality accessible through single slash command `/zenith` with natural language input.

### NFR-2: Situation Detection Before Action
Must run full diagnostic sequence and detect situation (S1-S9) before interpreting user request.

### NFR-3: State Read Before Every Operation
Must read actual git state with commands, never trust user's description.

### NFR-4: Idempotent Setup
Running setup.sh multiple times must produce same result without errors or duplicate configuration.

### NFR-5: Automatic Silent Updates
Daily cron job pulls latest version without user action. Symlink ensures command always points to latest.

### NFR-6: Organization-Agnostic Configuration
No hardcoded organization names, repository names, paths, or API references except in per-user .agent-config.

### NFR-7: Destructive Operations Require Explicit Confirmation
Hard reset, force push, permanent deletion require confirmation before execution. "YES" not "y" for discard.

### NFR-8: Never Auto-Resolve Conflicts Outside User's Folder
Files outside project_folder in conflict state must stop operation and show error.

### NFR-9: Performance
Command execution should complete within 5 seconds for operations without user interaction.

### NFR-10: Error Reporting
All git command failures must show exact error output to user.

## External Dependencies

- **Claude Code**: Runtime environment for slash command execution
- **git**: Version 2.23+ (for git restore command)
- **gh (GitHub CLI)**: For PR creation, PR listing, CI status checks (`gh pr create`, `gh pr list`, `gh run list`). Must be authenticated via `gh auth login`.
- **bash**: Shell environment for script execution
- **cron**: For automatic update scheduling
- **GitHub**: Remote repository hosting

## Constraints

### C-1: No Server
Zenith runs entirely locally. No server, no database, no external API calls.

### C-2: No Package Manager Dependency
No npm, pip, cargo, or other package manager required. Pure bash and git.

### C-3: Works on Any GitHub Monorepo
No assumptions about repository structure beyond existence of base branch.

### C-4: Claude Code Environment
Must work within Claude Code's tool execution model. No interactive prompts unsupported by environment.

### C-5: Gitignored Configuration
.agent-config must be in .gitignore. Never committed.

### C-6: Read-Only Reference Documents
Files in tools/ are specifications, not executable code. zenith.md reads and implements them.

## Success Criteria

1. User can install with single curl command
2. User can perform all git workflow operations through natural language
3. System detects and prevents cross-folder contamination
4. System handles conflicts intelligently based on file location
5. System never performs destructive operations without explicit confirmation
6. System provides clear next-action guidance after every operation
7. Setup is idempotent and updates are automatic
8. All git errors show exact output for user troubleshooting
