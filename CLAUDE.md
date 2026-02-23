# Zenith — CLAUDE.md

## What This Project Is

Zenith is a **prompt-only project**. There is no build step, no runtime, no server, no package manager, no executable code. Every file is either a markdown specification or a bash installer script.

The `/zenith` slash command is defined entirely in `.claude/commands/zenith.md`. When a user runs `/zenith`, Claude Code reads that file and executes the instructions inside it. The `tools/` files are reference documents that `zenith.md` reads and follows during execution.

**Deployment is immediate and live.** Edits to `zenith.md` on `main` go out to all users on their next cron pull. There is no staging environment. Treat every change like a production deploy.

---

## File Structure and Roles

```
.claude/commands/zenith.md        — The slash command. The only file Claude executes.
tools/safety.md                   — Non-negotiable safety rules.
tools/contamination.md            — Cross-folder contamination detection logic.
tools/conflict-resolver.md        — Three-tier conflict resolution rules.
tools/common-commands.md          — Shared git command patterns (CMD_* identifiers).
tools/placeholder-conventions.md  — Standard placeholder names for all docs.
tools/diagnostics.md              — Diagnostic command sequence and situation detection.
tools/branch-ops.md               — Branch operation specs.
tools/commit-ops.md               — Commit operation specs.
tools/sync-ops.md                 — Sync and rebase specs.
tools/push-ops.md                 — Push and PR specs.
tools/undo-ops.md                 — Undo and reset specs.
scripts/setup.sh                  — One-time installer. Idempotent.
templates/.agent-config.template  — Template for per-user config.
REQUIREMENTS.md                   — Functional and non-functional requirements.
tests/lint.sh                     — Automated convention checks. Run before every PR.
tests/test-setup.sh               — Automated setup.sh behavior tests.
tests/manual-checklist.md         — Situational tests requiring a real repo.
```

**`tools/` files are specifications, not executable code.** `zenith.md` reads and implements them. Never add scripts or logic directly to `tools/` files.

---

## How to Work on This Project

### Stay scoped to what was asked

Only touch files directly related to the request. If asked to fix an intent handler, change that handler — not the diagnostics section, not the output format, not unrelated tools files. This project's files are interconnected; an unrequested edit to a shared spec can break other intents silently.

Do not refactor, reformat, reorder, or "clean up" files that aren't part of the change. If something looks wrong but wasn't mentioned, flag it as a separate observation — don't fix it in the same commit.

### Map the full intent flow before editing zenith.md

`zenith.md` is a single large instruction file. A change in one section can affect behavior in situations the author wasn't thinking about. Before editing any intent handler:

1. Identify which situations (S1-S9) can reach this handler
2. Check whether the change could alter behavior in any situation other than the target one
3. Verify the execution order: detect → read state → check safety → show preview → confirm → execute → `next:`
4. Check if any `tools/` files referenced in the handler also need updating

### Run lint before and after every change to zenith.md

```bash
bash tests/lint.sh
```

This is fast and stateless. It must pass 100% before and after. If it was passing before and fails after your change, your change introduced the regression — find and fix it before committing.

For changes to `scripts/setup.sh`:
```bash
bash tests/test-setup.sh
```

### Know what to manually test

Lint catches structural conventions. It does not catch behavior bugs. Before merging anything that touches `zenith.md`, work through `tests/manual-checklist.md` for:
- The situations (S1-S9) your change is in
- Any safety rules your change is near
- The output format section if you changed any printed output

### After being corrected, record the lesson

If an edit was wrong and had to be fixed:
- Understand why the mistake happened
- Add the specific rule to the "Known lessons" section below
- Update the relevant constraint in this file if the correction reveals a gap

### Known lessons

- `mapfile` requires bash 4+. macOS ships bash 3.2. Use `while IFS= read -r line; do array+=("$line"); done < <(...)` everywhere
- `INTENT_PUSH` execution order must be: stage → commit → rebase → push. Rebasing with staged changes fails
- Markdown links inside code fences are not clickable. PR URLs must use `open "url"` to open a browser
- `INTENT_HELP` and `INTENT_UNKNOWN` have no `### HANDLER` sections in Step 4 — they are handled inline in Step 3. Exclude them from any lint check that looks for Step 4 handler sections

---

## Testing

```bash
# Run before and after every change to zenith.md — takes seconds
bash tests/lint.sh

# Run before and after any change to scripts/setup.sh
bash tests/test-setup.sh

# Manual — requires a real repo with Zenith installed
# See tests/manual-checklist.md for all S1-S9 scenarios and safety rules
```

`lint.sh` checks:
- Every `CMD_*` reference in `zenith.md` is defined in `common-commands.md`
- Every `INTENT_*` (except INTENT_HELP and INTENT_UNKNOWN) has a `### HANDLER` section
- Every `tools/*.md` reference exists on disk
- No deprecated placeholder names (`{branch_name}`, `{selected_branch}`, `{commit}`)
- Every `tools/` file that uses `CMD_*` references `common-commands.md`

---

## Editing Conventions

### Placeholder naming

All placeholders use `{curly_braces}`. Use only canonical names from `tools/placeholder-conventions.md`. Never invent a new name if a standard one exists.

| Placeholder | Meaning |
|-------------|---------|
| `{base_branch}` | Main/master branch from config — never hardcode `main` |
| `{current_branch}` | The branch currently checked out |
| `{project_folder}` | User's folder from `.agent-config` |
| `{hash}` | Short commit hash — not `{commit}`, not `{sha}` |

### Command references

Shared git commands live in `tools/common-commands.md` with `CMD_*` identifiers. Reference them as inline comments in `zenith.md`:

```bash
git fetch origin    # CMD_FETCH_ORIGIN
git diff --cached   # CMD_DIFF_CACHED_STAT
```

Never duplicate a command definition. If a command isn't in `common-commands.md` and you're using it in more than one place, add it there first.

### Adding new intents

Every new intent must:
1. Be added to the intent table in Step 3 with a clear, unique description
2. Have a `### INTENT_NAME` handler section in Step 4
3. Follow the read → check → show → confirm → execute → `next:` pattern
4. Check repo state before acting — never trust the user's description of their situation
5. Block on unsafe states (uncommitted changes, wrong branch, wrong folder)
6. Run contamination check if touching files
7. End with a `next:` line

---

## Hard Constraints

These cannot be negotiated or worked around:

- **No `-i` flag on git commands.** `git rebase -i`, `git add -i` — never. Claude Code does not support interactive terminal input.
- **No server, API, or external services.** Zenith runs entirely locally with git and bash.
- **No package manager dependencies.** Nothing requiring npm, pip, cargo, or any installer beyond git and bash.
- **`.agent-config` is never committed and never written by `zenith.md`.** It is personal. `setup.sh` writes it once. `zenith.md` only reads it.
- **No hardcoded org names, repo names, or paths.** Everything comes from `.agent-config`. The only exception is `scripts/setup.sh`, which has a `ZENITH_REPO` placeholder to update at publish time.
- **Safety rules in `tools/safety.md` are non-negotiable.** Do not relax them. They exist because Zenith targets users with mixed git skill levels in shared repos where a wrong commit or force push can affect the whole team.

---

## Core Principles

- **Read state, don't trust state.** Always run git commands to inspect actual repo state. Never act on the user's description of their situation alone.
- **Show before doing.** Every destructive or irreversible operation shows a preview and asks for confirmation before running.
- **Fail loudly and early.** When a situation is unclear or unsafe, stop and explain — don't attempt a best guess.
- **Plain English output.** Zenith targets users who know their code but not git internals. Error messages must say what to do next, not just what went wrong.
- **Prompt clarity over clever prompting.** An instruction that Claude misreads during execution is worse than no instruction. If a sentence in `zenith.md` has two plausible interpretations, rewrite it until it has one.

---

## Setup Script Notes

`scripts/setup.sh` is idempotent — running it twice produces the same result. If modifying it, verify it exits cleanly on a second run without making duplicate changes (especially the cron job and `.gitignore` entry).

The `ZENITH_REPO` variable at the top of `setup.sh` contains a placeholder URL (`your-org/zenith`). Update this when publishing to a real GitHub org.
