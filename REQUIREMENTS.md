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
- Block if nothing to push
- Run contamination check
- Prompt for commit message if uncommitted changes
- Fetch and rebase onto base branch
- Stage and commit if needed
- Push with upstream tracking
- Display PR URL

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

### FR-21: Help (INTENT_HELP)
- Display table of natural language phrases and corresponding actions
- No technical jargon

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
