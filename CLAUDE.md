# Zenith

## What this project is

Zenith is a **prompt-only project**. There is no build step, no runtime, no server, no package manager, no executable code. Every file is either a markdown specification or a bash installer script.

The `/zenith` slash command is defined entirely in `.claude/commands/zenith.md`. When a user runs `/zenith`, Claude Code reads that file and executes the instructions inside it. The `tools/` files are reference documents that `zenith.md` reads and follows during execution.

## File structure and roles

```
.claude/commands/zenith.md   — The slash command. This is the only file Claude executes.
tools/safety.md              — Non-negotiable safety rules. Referenced by zenith.md.
tools/contamination.md       — Cross-folder contamination detection logic.
tools/conflict-resolver.md   — Three-tier conflict resolution rules.
tools/common-commands.md     — Shared git command patterns (CMD_* identifiers).
tools/placeholder-conventions.md — Standard placeholder names for all docs.
tools/diagnostics.md         — Diagnostic command sequence and situation detection.
tools/branch-ops.md          — Branch operation specs.
tools/commit-ops.md          — Commit operation specs.
tools/sync-ops.md            — Sync and rebase specs.
tools/push-ops.md            — Push and PR specs.
tools/undo-ops.md            — Undo and reset specs.
scripts/setup.sh             — One-time installer. Idempotent.
templates/.agent-config.template — Template for per-user config.
REQUIREMENTS.md              — Functional and non-functional requirements.
```

**`tools/` files are specifications, not executable code.** `zenith.md` reads and implements them. Do not add scripts or logic directly to `tools/` files.

## How deployment works

`setup.sh` symlinks `~/.zenith/.claude/commands/zenith.md` into the user's monorepo at `.claude/commands/zenith.md`. A daily cron job runs `git pull` in `~/.zenith`. **Editing `zenith.md` on `main` immediately changes live behavior for all users on their next cron pull.** There is no staging environment.

## How to test changes

There is no test suite. The only way to test is:
1. Have a monorepo with Zenith installed (or install it via `setup.sh`)
2. Run `/zenith <phrase>` in Claude Code inside that repo
3. Verify behavior matches the intent in `zenith.md`

Test against the full diagnostic sequence first (Step 1 in `zenith.md`) — most bugs are in situation detection before any operation runs.

## Editing conventions

### Placeholder naming
All placeholders use `{curly_braces}`. Use only the canonical names defined in `tools/placeholder-conventions.md`. Never invent new placeholder names if a standard one exists.

Key ones:
- `{base_branch}` — the main/master branch (from config, never hardcoded)
- `{current_branch}` — the branch currently checked out
- `{project_folder}` — user's designated folder from `.agent-config`
- `{hash}` — short commit hash (not `{commit}`, not `{sha}`)

### Command references
Shared git commands are defined in `tools/common-commands.md` with `CMD_*` identifiers (e.g., `CMD_FETCH_ORIGIN`, `CMD_DIFF_CACHED_STAT`). When adding new operations to `zenith.md`, use these identifiers in inline comments rather than duplicating command definitions.

### Adding new intents
New intents must follow the S1-S9 situation detection model. Every operation must:
1. Check repo state before acting
2. Run contamination check if touching files
3. Block on unsafe states (uncommitted changes, wrong branch)
4. Show the user what will happen before doing it
5. Print a `next:` line after completion

## Constraints that must not be broken

- **No interactive git commands.** Never use `-i` flag (`git rebase -i`, `git add -i`, etc). Claude Code does not support interactive terminal input.
- **No server, no API, no external services.** Zenith runs entirely locally with git and bash.
- **No package manager dependencies.** No npm, pip, cargo, or anything requiring installation beyond git and bash.
- **`.agent-config` is never committed and never written by `zenith.md`.** It is personal to each user. `setup.sh` writes it once. `zenith.md` only reads it.
- **No hardcoded org names, repo names, or paths** anywhere except `scripts/setup.sh` (which has `your-org` as a placeholder to update before publishing).
- **Safety rules in `tools/safety.md` are non-negotiable.** Do not relax them. They exist because Zenith targets users with mixed git skill levels in shared monorepos.

## Running tests

```bash
# Automated tests (no external dependencies, no Claude API calls)
bash tests/test-setup.sh   # setup.sh behavior: install, idempotency, .gitignore handling
bash tests/lint.sh         # markdown conventions: CMD_* refs, INTENT_* handlers, file refs, deprecated placeholders

# Manual tests (requires a real monorepo with Zenith installed)
# See tests/manual-checklist.md
```

`test-setup.sh` spins up temporary git repos and cleans up after itself. Safe to run anywhere.

`lint.sh` is fast and stateless — no git operations, just grep checks. Run it before every PR.

Before merging anything that touches `zenith.md`, work through the relevant sections of `tests/manual-checklist.md`. At minimum cover: the situations (S1-S9) your change touches, any safety rules your change is near, and the output format section.

## Setup script

`scripts/setup.sh` is idempotent — running it twice produces the same result. If modifying it, verify it exits cleanly on a second run without making duplicate changes (especially the cron job and `.gitignore` entry).

The `ZENITH_REPO` variable at the top of `setup.sh` contains a placeholder URL (`your-org/zenith`). Update this when publishing to a real GitHub org.
