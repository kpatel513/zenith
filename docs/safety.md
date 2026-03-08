# Safety

## What Zenith protects you from

**General monorepo safety:**
- Committing directly to `main` by accident
- Pushing code that touches files outside your folder
- Pushing before syncing with the latest team changes
- Merge conflicts that invalidate your teammates' PR reviews
- Getting stuck after a push fails with a cryptic git error
- `.gitignore` rules that silently break other teams' folders
- PRs flooded with 400 auto-generated files because someone ran `git add .`
- Merge conflict resolutions that silently discard the correct version of code
- Root-level dependency changes (`requirements.txt`, `pyproject.toml`) that introduce version conflicts across unrelated projects

**Claude Code-specific:**
- Claude Code committing directly to `main` without creating a branch first
- Claude Code editing shared utilities (`common/`, `shared/`) that affect eight other projects
- Claude Code placing generated files (`.env`, output dirs, cache folders) in unexpected locations that end up committed
- Claude Code modifying root-level dependency files when you only asked it to add a dependency to your project
- Claude Code resolving a merge conflict by picking one side — and discarding the side that was actually correct
- Two engineers independently asking Claude Code to build the same thing, both landing in the repo

---

## Claude Code safety layer

When Claude Code helps you write code, it makes reasonable engineering decisions — but those decisions don't always account for monorepo conventions. Zenith adds a safety layer specifically for this.

**The problem:** Claude Code sees the whole codebase. When you ask it to add logging to your training script, it might edit `common/utils/logger.py` because that's the right call architecturally — but that file is used by eight other projects. Claude Code doesn't know that touching it requires team sign-off. You commit the diff without reading it carefully, and the PR shows up touching files in four different teams' folders.

**What Zenith catches automatically:**

| Situation | What Zenith does |
|-----------|-----------------|
| Claude Code commits directly to `main` | Step 1 warns on startup: "N unpushed commits on main — run /zenith move my commits" |
| Claude Code stages 400 generated files | INTENT_SAVE and INTENT_PUSH pause when >50 files staged and show a per-folder breakdown |
| Claude Code edits `common/` or `shared/` | Contamination check flags shared paths and asks to confirm before committing |
| Claude Code modifies `requirements.txt` | Contamination check flags root-level dependency files regardless of your project_folder setting |
| Claude Code writes `/Users/alice/data/` into your code | Contamination check scans diff content for absolute paths and blocks commit |
| Claude Code resolves a conflict by picking one side | INTENT_FIX_CONFLICT shows the discarded version and asks "is this safe to drop?" before committing |
| Claude Code generates `.env` or output dirs | Contamination check flags credential filenames and ML output paths |
| You ask Claude Code to build something that already exists | INTENT_FIND_DUPLICATES searches the repo before you start building |

**None of this requires you to change how you use Claude Code.** You keep using it as you normally would. Zenith intercepts at commit and push time — the natural checkpoint where a second set of eyes would catch these issues.
