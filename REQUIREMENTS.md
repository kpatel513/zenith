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
- Check each file for root-level dependency files (requirements.txt, pyproject.toml, setup.py, setup.cfg, Pipfile, package.json) — flag even if inside project_folder
- Check each file for shared monorepo paths (common/, shared/, lib/, core/, infra/, scripts/ at root; Makefile, Dockerfile, .github/) — flag for cross-team impact
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
- Check staged file count: if >50 files, show breakdown by folder and ask to confirm before proceeding
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
- Check staged file count: if >50 files, show breakdown by folder and ask to confirm before proceeding
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
- For Tier 3 (substantive) resolutions: show the discarded version explicitly and require confirmation that it is safe to drop before proceeding
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

### FR-32: PR Review (INTENT_REVIEW_PR)
- Accept two modes from natural language: author mode (current branch) and reviewer mode (specific PR number)
- Author mode: block if on base branch; collect diff from open PR if one exists, otherwise diff against base branch
- Reviewer mode: fetch PR metadata, diff, and CI check status via GitHub CLI
- Three-pass review: Pass 1 (benevolent summary), Pass 2 (signals), Pass 3 (architect review, isolated from prior passes)
- Pass 3 sees only the raw diff — must not reference Pass 1 or Pass 2 output
- Pass 3 persona: senior architect, 15+ years — precise and direct, not adversarial; surfaces structural issues that compound over time; ignores style and minor issues
- Every concern in Pass 3 must include all four fields, each exactly one sentence: line citation, failure scenario, alternative, question for author
- Pass 3 must check all eleven explicit items: right problem vs symptom, failure recovery, coupling, simpler path, worst-case data/load, readability, changeability in 6 months, hidden assumptions, correct abstraction level, correct system layer, complexity proportional to value delivered
- Pass 3 output ends with a single directive ("Before merging: [imperative]") and one of three verdicts: MERGE / MERGE AFTER FIXES / REDESIGN NEEDED
- Signals layer (Pass 2) covers nine dimensions: scope, volatile files, fragile files, duplicate symbols, PR history on touched files, open PRs on same files, recurring reviewer patterns, config signals, structure signals
- Two review tiers selected by natural language:
  - Standard tier (`review my PR`, `review PR 123`): Layers 1–6 only — fast, no extra gh API calls
  - Deep tier (`deep review my PR`, `deep review PR 123`, or any request containing "deep", "full", "thorough", "architect"): Layers 1–9
- Context layers:
  - Layer 1: git commit history per file (volatility, fragility) — always
  - Layer 2: redundancy scan (git grep for new symbols) — always
  - Layer 3: docs — README (300 lines), per-folder README, ARCHITECTURE.md, CONTRIBUTING.md, ADR content (5 most recent) — always
  - Layer 4: .zenith-context if present — always
  - Layer 5: project config — pyproject.toml, requirements.txt, CI pipeline, linting config — always
  - Layer 6: code structure — module map of project_folder, __init__.py of touched packages — always
  - Layer 7: recent merged PRs cross-referenced against touched files (last 20 PRs) — **deep tier only**
  - Layer 8: open PRs touching same files — **deep tier only**
  - Layer 9: review comments from matched past PRs (capped at 3 most recent matches) — **deep tier only**
- Header must display which tier is active so the user knows the context level
- All layers are optional — missing files, absent gh CLI, or no PR history must not block the review
- No GitHub posting — terminal output only

### FR-33: Pre-Commit Checks (INTENT_RUN_CHECKS)
- Run pre-commit hooks against changed files in {project_folder} only (not --all-files)
- Short-circuit with clear message if no changed files exist
- Check pre-commit is installed; if not, surface pip install instruction and stop
- Check .pre-commit-config.yaml exists; if not, surface template copy instruction and stop
- Show per-hook ✓/✗ results with failure detail in pipe format
- End with clean summary or "fix required" summary
- Never commit or stage files — this is a read-only check operation

### FR-34: Gitignore Audit (INTENT_GITIGNORE_CHECK)
- Detect which .gitignore files (root or per-folder) have changed
- Extract newly added rules from the diff
- Simulate effect of each new rule across the entire repo using `git check-ignore -v`
- Group results by project folder to identify cross-team impact
- Warn if any rule would silently ignore files outside the folder where the .gitignore lives
- Show which rules are safely scoped and which have cross-folder reach
- Require explicit confirmation before rules with cross-folder effect are committed

### FR-35: Cherry-Pick (INTENT_CHERRY_PICK)
- Block if uncommitted changes
- Accept source branch and show recent commits from it
- Show diff of selected commit scoped to project_folder before applying
- Show files the commit touches outside project_folder (will not be applied) and warn
- Execute `git cherry-pick` and apply three-tier conflict resolution
- Run contamination check after clean apply
- Block out-of-scope application if commit has no changes in project_folder and user declines

### FR-36: Find Duplicates (INTENT_FIND_DUPLICATES)
- Accept a keyword, class name, or function description from user
- Search all .py (and configurable extension) files for matching filenames, class names, and function definitions
- Search directory names for keyword match
- Group results by project folder, excluding user's own project_folder
- Report matches with folder path and match type (filename / class / function)
- Surface matches before user builds, to prevent two implementations of the same thing landing in the repo

### FR-37: Pattern Learning (Pattern Store)
- Silently record workflow events to `~/.zenith/patterns.json` after relevant operations complete
- Tracked event types: `amend_after_commit` (recorded after INTENT_AMEND_ADD or INTENT_AMEND_MESSAGE), `push_behind_main` (recorded after INTENT_PUSH when behind count at start was ≥5), `contamination` (recorded when a contamination warning fires in INTENT_SAVE or INTENT_PUSH)
- Each entry stores: event type, repo identifier (`{github_org}/{github_repo}`), and ISO timestamp
- Nudge threshold: 3 or more occurrences in the last 5 entries for the same repo and event type
- Surface nudges inline in the confirmation pipe block for the relevant operation — not as a separate step
- `amend_after_commit` nudge: appears before INTENT_SAVE commit confirmation
- `push_behind_main` nudge: appears before INTENT_PUSH confirmation when behind count ≥5
- `contamination` nudge: adds historical count line to the existing contamination warning
- Create `~/.zenith/patterns.json` automatically if absent; never commit it
- Pattern store is global across repos; entries are scoped per repo using the repo identifier

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

### NFR-11: Detect Unexpected Commits on Base Branch
When on base branch, Step 1 diagnostics must check for unpushed commits and surface a visible warning. Applies to S25 (automated tools committing directly to main without creating a branch).

### NFR-12: Large Staged File Set Warning
INTENT_SAVE and INTENT_PUSH must pause and display a per-folder breakdown when staged file count exceeds 50. Prevents auto-generated or output files from reaching a PR unreviewed.

### NFR-13: Conflict Discard Visibility
After resolving a substantive (Tier 3) conflict, the discarded version must be shown explicitly and confirmed safe to drop before the commit proceeds. Silent loss of the correct version is not acceptable.

### NFR-14: PR Review Context Completeness
Before any review pass runs, all applicable context layers must be attempted (Layers 1–6 for standard tier, Layers 1–9 for deep tier). The review header must display which tier is active. A standard-tier review that runs on git history alone (no config, no docs) must be flagged as low-context.

### NFR-15: PR Review Concern Brevity
Every concern raised in Pass 3 must be expressible in four single-sentence fields. If a concern cannot be stated in one sentence per field, it must be rewritten until it can. Verbose or hedged concerns are not acceptable output.

### NFR-16: PR Review Verdict Actionability
The three verdict values (MERGE / MERGE AFTER FIXES / REDESIGN NEEDED) must map to unambiguous actions. MERGE means no blocking issues. MERGE AFTER FIXES means specific named issues must be addressed. REDESIGN NEEDED means the approach itself is wrong and the implementation is secondary.

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
Files in references/ are specifications, not executable code. ZENITH.md reads and implements them.

## Success Criteria

1. User can install with single curl command
2. User can perform all git workflow operations through natural language
3. System detects and prevents cross-folder contamination
4. System handles conflicts intelligently based on file location
5. System never performs destructive operations without explicit confirmation
6. System provides clear next-action guidance after every operation
7. Setup is idempotent and updates are automatic
8. All git errors show exact output for user troubleshooting
9. System detects when automated tools (e.g. Claude Code) commit directly to base branch and surfaces a recovery path
10. System pauses and requires review when staged file count is unusually large (>50 files)
11. System flags root-level dependency files and shared monorepo paths regardless of project_folder scope
12. System prevents silent discard of correct conflict resolution by showing the dropped version before committing
13. Users can audit .gitignore changes for cross-team scope impact before committing
14. Users can safely cherry-pick from other branches with scoped preview and contamination check
15. Users can search the repo for duplicate implementations before building something that already exists
16. PR review gathers context from nine layers (git history, docs, config, code structure, PR history, open PRs, reviewer patterns) before making any finding
17. PR review concerns are stated precisely in one sentence per field — no hedging, no padding
18. PR review verdict maps unambiguously to one of three actions: merge as-is, fix specific issues, redesign the approach
19. Pattern learning records workflow events silently and surfaces nudges inline before operations the user repeatedly gets wrong, without interrupting operations or requiring user configuration
