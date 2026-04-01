# Zenith — Review & Analysis Operations
# Handlers: INTENT_REVIEW_PR, INTENT_RUN_CHECKS, INTENT_GITIGNORE_CHECK, INTENT_CHERRY_PICK, INTENT_FIND_DUPLICATES, INTENT_BLAST_RADIUS, INTENT_CONFLICT_RADAR
# Read by ZENITH.md Step 4 router. See references/common-commands.md for CMD_* definitions.

### INTENT_BLAST_RADIUS

Collect changed files:
```bash
git diff --name-only origin/{base_branch}...HEAD
```

If empty, fall back to:
```bash
git diff --name-only HEAD          # CMD_DIFF_NAME_ONLY
```

If still empty:
```
nothing to check — no changed files found on this branch
│ make some changes, then run /zenith blast radius
```
Stop.

For each changed file, extract the module name: take the filename, strip the directory path and file extension. Example: `src/auth/login.py` → `login`, `team-ml/pipeline.js` → `pipeline`.

Skip any module name shorter than 4 characters — too generic to search reliably.

For each module name, search for references across the repo:
```bash
git grep -l "{module_name}"   # CMD_GREP_FILE_REFS
```

From the results:
- Exclude the source file itself
- Exclude paths containing `.git/`, `__pycache__/`, `node_modules/`, `.egg-info/`
- Cap at 20 results per file — if more exist, note the count

Group all results by top-level directory (first path component of each result).

**Output — if no dependents found across all changed files:**
```
blast radius — no dependents found
│ no tracked files reference {module_names}
│ this may be a new file or an entry point with no importers
```
Next: "next: you're clear to push — run /zenith push"
Stop.

**Output — if impact is contained within {project_folder}:**
```
blast radius — impact contained
│ {n} dependent file(s) found, all within {project_folder}/
│ no cross-team impact detected
```
Next: "next: impact is local — run /zenith push when ready"
Stop.

**Output — if cross-folder impact detected:**
```
blast radius — {n} changed file(s), {total} dependent(s) across {m} folder(s)

│ {changed_file}  →  {count} file(s) reference it
│   {dependent_file}   {folder}/
│   {dependent_file}   {folder}/
[If count > 3:] │   ... {remaining} more in {folder}/

│ {changed_file}  →  {count} file(s) reference it
│   {dependent_file}   {folder}/

│ cross-folder impact: {folder} ({n}), {folder} ({n})
│ consider whether your changes are backwards compatible before pushing
```

Next: "next: review the cross-folder impact above before pushing — coordinate with affected teams if the interface changed"

### INTENT_CONFLICT_RADAR

If on `{base_branch}`:
```
blocked — you are on {base_branch}
│ conflict radar checks open PRs against your branch changes
│ switch to a feature branch first
```
Stop.

Collect this branch's file list:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git diff --name-only origin/{base_branch}...HEAD
```

If empty, fall back to:
```bash
git diff --name-only HEAD          # CMD_DIFF_NAME_ONLY
```

If still empty:
```
nothing to check — no changed files found on this branch
│ make some changes, then run /zenith conflict radar
```
Stop.

Fetch open PRs:
```bash
gh pr list --repo {github_org}/{github_repo} --state open --limit 30 --json number,title,author,createdAt,updatedAt,headRefName   # CMD_PR_LIST_OPEN
```

If `gh` fails (not installed or not authenticated): print error and stop:
```
conflict radar unavailable — GitHub CLI not configured
│ install gh and run gh auth login, then try again
```

Exclude the current branch's own PR from the list (match `headRefName` to `{current_branch}`).

If no PRs remain:
```
conflict radar — no open PRs found
│ no other open PRs in {github_org}/{github_repo}
│ nothing to conflict with
```
Next: "next: you're clear to push — run /zenith push"
Stop.

For each PR, fetch its file list:
```bash
gh pr diff {pr_number} --name-only   # CMD_PR_DIFF_NAME_ONLY
```

If a single PR call fails, skip it silently and continue.

Find the intersection of each PR's file list with `MY_FILES`. Track:
- `EXACT_OVERLAPS` — PRs with at least one file in common
- `DIR_OVERLAPS` — PRs whose files share a directory with `MY_FILES` but have no exact file match

**Risk labels (assign to each PR in EXACT_OVERLAPS):**

Read `createdAt` and `updatedAt` from the JSON metadata. Reason about the timestamps in plain English:
- If `updatedAt` is within the last 6 hours: label `→ likely to merge first`
- If `createdAt` is more than 7 days ago and `updatedAt` is more than 3 days ago: label `⚠ stale`
- Otherwise: no label

A PR is **highest risk** if it has exact file overlap AND the label `→ likely to merge first`.

**Output — if no overlaps:**
```
conflict radar — no overlapping PRs
│ none of the {n} open PRs touch the same files as your branch
```
Next: "next: you're clear to push — run /zenith push"
Stop.

**Output — if exact overlaps found:**
```
conflict radar — {n} open PR(s) overlap with your changes

│ PR #{number}  {author.login}   {overlapping_file}   opened {age}   {label}
│ PR #{number}  {author.login}   {overlapping_file}   opened {age}   {label}
│
│ highest risk: PR #{number} — same file, likely to merge before you
│ coordinate with {author.login} before pushing or expect a conflict
```

If no highest-risk PRs, omit the `highest risk` summary line.

If `DIR_OVERLAPS` exist, append:
```
│
│ possible overlap (same directory, different files):
│   PR #{number}  {author.login}   {dir}/
```

Next (if highest-risk found): "next: review PR #{number} before pushing — run /zenith review PR {number}"
Next (if overlaps but no highest-risk): "next: review the PRs above, then run /zenith push when ready"

### INTENT_REVIEW_PR

Detect review tier from user request:
- "deep", "full", "thorough", or "architect" present in request → **deep tier** (Layers 1–9)
- Otherwise → **standard tier** (Layers 1–6 only)

Detect subject mode from user request:
- PR number present (e.g. "review PR 123", "review #42") → **reviewer mode**
- Otherwise (e.g. "review my PR", "self-review", "review my changes") → **author mode**

Print tier at the start of the review header line so the user knows which context level is running:
- Standard tier: `│ context: Layers 1–6 (git history, docs, config, structure)`
- Deep tier: `│ context: Layers 1–9 (+ PR history, open PR conflicts, past reviewer patterns)`

── AUTHOR MODE ──

Check current branch:
```bash
git branch --show-current          # CMD_CURRENT_BRANCH
```

If on {base_branch}:
```
blocked — you are on {base_branch}
│ switch to a feature branch before running a self-review
│ run /zenith continue my work to pick up a feature branch
```
Stop.

Execute:
```bash
git fetch origin                   # CMD_FETCH_ORIGIN
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1
```

Collect diff:
```bash
# If open PR exists:
gh pr diff                         # CMD_PR_DIFF (no PR number = current branch's open PR)

# If no open PR:
git diff {base_branch}...HEAD      # CMD_DIFF_FROM_BASE
```

Collect commits:
```bash
git log {base_branch}..HEAD --oneline   # CMD_LOG_SINCE_BASE
```

── REVIEWER MODE ──

Execute:
```bash
gh pr view {pr_number} --json title,body,author,baseRefName,state,number   # CMD_PR_VIEW_JSON
gh pr diff {pr_number}             # CMD_PR_DIFF
gh pr checks {pr_number}           # CMD_PR_CHECKS
```

── CONTEXT GATHERING (both modes) ──

Extract touched file list from diff (lines starting with `diff --git`).

Layer 1 — git history (always run):
```bash
# For each touched file:
git log --oneline --since="1 year ago" -- {file} | wc -l   # CMD_LOG_FILE_HISTORY
git log --all --oneline --grep="revert\|hotfix" -- {touched_files}   # CMD_LOG_REVERTS_IN_FILES
```

Layer 2 — redundancy scan (always run):
Extract new symbol names from diff (function, class, const definitions on lines starting with `+`).
```bash
# For each new symbol:
git grep -l "{symbol}"             # CMD_GREP_SYMBOL
```

Layer 3 — docs (if present):
```bash
# Root README — full content up to 300 lines (not just 60)
head -300 README.md 2>/dev/null

# Per-folder README — many monorepos document each project area separately
head -200 {project_folder}/README.md 2>/dev/null

# Architecture and design docs — read if present
cat ARCHITECTURE.md 2>/dev/null
cat CONTRIBUTING.md 2>/dev/null
cat DESIGN.md 2>/dev/null

# ADR content — read the 5 most recently modified ADRs, not just list filenames
ls -t docs/adr/*.md 2>/dev/null | head -5 | while IFS= read -r adr; do
    echo "=== $adr ===" && head -80 "$adr"
done
```

Layer 4 — .zenith-context (if present):
```bash
cat "$REPO_ROOT/.zenith-context" 2>/dev/null
```

Layer 5 — project configuration (if present):
```bash
# Dependencies and Python/Node version targets
cat pyproject.toml 2>/dev/null
cat requirements.txt 2>/dev/null
cat setup.cfg 2>/dev/null
cat package.json 2>/dev/null | head -40

# CI pipeline — understand what tests and lints run on every PR
ls .github/workflows/ 2>/dev/null
head -80 .github/workflows/*.yml 2>/dev/null

# Coding standards enforced by tooling
cat ruff.toml .flake8 mypy.ini .pylintrc .eslintrc* 2>/dev/null
```

Use Layer 5 to inform review findings: if a PR adds a dependency already in requirements.txt, flag it. If CI runs `mypy` and the change introduces untyped functions, flag it. If `ruff` enforces a style the new code violates, flag it.

Layer 6 — code structure (if present):
```bash
# Module map of the project folder — understand where things live
find {project_folder} -type f -name "*.py" | grep -v __pycache__ | sort | head -40

# Public API of touched modules — read __init__.py for each touched file's package
# For each touched file {file}, read: dirname({file})/__init__.py
cat $(dirname {touched_file})/__init__.py 2>/dev/null
```

Use Layer 6 to inform review findings: if a new function bypasses the public API declared in `__init__.py`, flag it. If the module map shows a patterns/ or utils/ directory that the new code duplicates, flag it.

Layer 7 — recent PR history on touched files (**deep tier only**, if gh available):
```bash
# Find last 20 merged PRs, extract file lists
gh pr list --repo {github_org}/{github_repo} --state merged --base {base_branch} \
  --limit 20 --json number,title,author,mergedAt,files \
  --jq '.[] | {number, title, author: .author.login, mergedAt, files: [.files[].path]}'
```

Cross-reference each PR's file list against the current PR's touched files. For each match, record PR number, title, author, and merge date. Surface as a signal: files that have appeared in multiple recent PRs are actively evolving and warrant extra scrutiny. If 3+ PRs touched the same file in 60 days, flag it explicitly in signals.

Layer 8 — open PRs on same files (**deep tier only**, if gh available):
```bash
gh pr list --repo {github_org}/{github_repo} --state open \
  --json number,title,author,files \
  --jq '.[] | {number, title, author: .author.login, files: [.files[].path]}'
```

Cross-reference against current PR's touched files. Any open PR touching the same file is a merge conflict risk. Surface as a signal: "PR #{n} ({author}) also touches {file} — coordinate before merging."

Layer 9 — review comment patterns on recently matched PRs (**deep tier only**, capped, if gh available):
```bash
# For each PR found in Layer 7 that touches the same files (cap at 3 most recent):
gh api repos/{github_org}/{github_repo}/pulls/{number}/comments \
  --jq '.[] | {path, body, line}'
```

Extract recurring themes from review comments on the matched PRs. If reviewers have flagged the same pattern (e.g. "missing error handling", "wrong abstraction level") more than once across matched PRs, surface it in signals as a known reviewer concern for this area. This makes the review aware of what the team has been pushing back on, not just what the code looks like today.

**If standard tier:** skip Layers 7–9 entirely. Do not make any `gh pr list` calls beyond what is needed for subject mode detection.

── PASS 1: BENEVOLENT ──

Using: diff, commit messages, PR description (reviewer mode only), README head (if present).

Output 3 to 5 plain English bullets stating what this PR actually does. Facts only, no opinions. State the mechanism, not the intent.

── PASS 2: SIGNALS ──

Scope check:
- Author mode: run contamination check against {project_folder} (see references/contamination.md). Flag any files outside scope.
- Reviewer mode: flag files that span more than one logical area (e.g. both API layer and DB layer in the same PR).

Redundancy:
- For each new symbol where CMD_GREP_SYMBOL found existing matches: note the symbol and the existing file path.

History signals:
- Files with >10 commits in the past year (Layer 1): flag as volatile with commit count.
- Files with any revert or hotfix commits (Layer 1): flag as fragile with commit reference.

.zenith-context matches (Layer 4, if present):
- For each known failure pattern in [failure_patterns]: check if diff contains the same pattern.
- If match found: flag with description and incident reference from the context file.

Configuration signals (Layer 5, if present):
- If PR adds a dependency already listed in requirements.txt / pyproject.toml: flag as duplicate dependency.
- If CI config shows `mypy` runs and the diff introduces untyped functions: flag.
- If linting config enforces a rule the new code visibly violates: flag with rule name.
- If PR modifies a dependency version that is pinned in pyproject.toml: flag as potential breaking change for other teams.

Structure signals (Layer 6, if present):
- If a new function or class duplicates a pattern already visible in the module map: flag with the existing path.
- If the diff adds a file outside the established module structure (e.g. in root when the project uses src/ layout): flag.
- If a new public function is not exported in `__init__.py` but appears to be intended as part of the public API: flag.

PR history signals (Layer 7, **deep tier only**, if present):
- Files touched by 3 or more PRs in the past 60 days: flag as actively evolving — changes here have higher integration risk.

Concurrency signals (Layer 8, **deep tier only**, if present):
- Any open PR touching the same files: flag with PR number, author, and file overlap.

Reviewer pattern signals (Layer 9, **deep tier only**, if present):
- Recurring themes from past review comments on matched PRs: flag as known reviewer concern for this area.

── PASS 3: ADVERSARIAL (ISOLATED) ──

Do not reference Pass 1 or Pass 2 output. Read only the raw diff.

Persona: You are a senior architect with 15+ years of experience. You have seen what happens when the wrong abstraction ships — the team lives with it for years. You are not adversarial, you are precise. You say exactly what you think and nothing more. You do not soften observations, hedge with "it could be argued", or explain things the author should already know. You find the one or two structural issues that will compound over time and state them plainly. You ignore style preferences and minor issues — those are what linters are for. If the code is sound, you say so and move on.

For every concern found, provide all four fields. Each field must be one sentence — no more. If you cannot state it in one sentence, the concern is not well-understood:
- line citation (file and line number from the diff)
- failure scenario (one sentence: "when X under Y condition, result is Z")
- alternative (one sentence: what to do instead)
- question (one sentence: what the author must answer before this merges)

Check explicitly against this list — do not skip items:
- Is this solving the right problem, or treating a symptom of a deeper issue?
- What happens on failure — is it recoverable, and does the caller know it failed?
- What coupling does this introduce that will constrain future changes?
- Is there a simpler path to the same outcome with less moving parts?
- Worst-case load or data scenario — does the code degrade gracefully or fail hard?
- Will the next engineer understand this without asking the author?
- What does this make harder to change in 6 months?
- Hidden assumptions about callers, environment, or ordering?
- Is the abstraction level correct — not over-engineered for its scope, not under-engineered for its complexity?
- Does this belong at this layer of the system, or is it solving the problem at the wrong level?
- Is the total complexity (lines, moving parts, new concepts introduced) proportional to the value this change delivers?

── OUTPUT ──

Print this block. Author mode uses {current_branch}; reviewer mode uses PR #{pr_number} — {title} ({author}).

```
reviewing — {current_branch}  /  PR #{pr_number} — {title} ({author})
│ CI: ✓/✗/…  base: {base_branch}  +{lines_added} -{lines_removed}
│ context: Layers 1–6  /  Layers 1–9 (deep)
│ 3-pass review: summary → signals → architect (pass 3 sees raw diff only)

── what it does ──────────────────────────────────────────
│ • [bullet 1]
│ • [bullet 2]
│ • [bullet 3]

── signals ───────────────────────────────────────────────
│ scope      ✓ within {project_folder}/   OR   ✗ outside scope: {files}
│ volatile   {file} — {n} commits in past year, {n} reverts/hotfixes
│ duplicate  {symbol} already exists at {path}
│ pattern    ⚠ matches known failure: [description] ([incident ref])
│ pr history {file} appeared in PR #{n} ({n} days ago) and PR #{n} ({n} days ago) — actively evolving
│ conflict   PR #{n} ({author}) also touches {file} — coordinate before merging
│ reviewer   recurring feedback on {file}: "[theme from past review comments]"
│ config     [finding from pyproject.toml / CI / linting config]
│ structure  [finding from module map or __init__.py]

── concerns ──────────────────────────────────────────────
│ P1  {file} line {n}: [one-sentence citation]
│     failure:     [one sentence: when X under Y, result is Z]
│     alternative: [one sentence: what to do instead]
│     question:    [one sentence: what the author must answer before merging]
│
│ P2  {file} line {n}: [one-sentence citation]
│     failure:     [one sentence]
│     alternative: [one sentence]
│     question:    [one sentence]

── directive ─────────────────────────────────────────────
│ Before merging: [single direct instruction — the one structural change
│ that matters most. stated as an imperative, not a suggestion.]

  verdict  MERGE  /  MERGE AFTER FIXES  /  REDESIGN NEEDED
```

If signals section has no findings: omit that row (do not print empty rows).
If no concerns found in Pass 3: print `── concerns ──` header followed by `│ none found`.
Verdict guidance: MERGE = no blocking issues found; MERGE AFTER FIXES = specific addressable concerns; REDESIGN NEEDED = the approach itself is wrong, not just the implementation.

next: "next: share these findings with the PR author, or run /zenith deep review PR {n} for full context including PR history and past reviewer patterns"

### INTENT_RUN_CHECKS

Collect changed files scoped to {project_folder}:
```bash
git diff --name-only HEAD          # CMD_DIFF_NAME_ONLY
git diff --name-only --cached      # CMD_DIFF_CACHED_NAME_ONLY
```

Take the union of both lists. If {project_folder} is ".", include all changed files. Otherwise filter to files whose path starts with {project_folder}/.

If no changed files found:
```
blocked — nothing to check
│ no changed files found in {project_folder}/
│ make some changes first, then run /zenith run checks
```
Stop.

Check prerequisites:
```bash
pre-commit --version 2>/dev/null   # CMD_PRE_COMMIT_VERSION
```

If pre-commit not installed:
```
blocked — pre-commit not installed
│ install it with: pip install pre-commit
│ then run: pre-commit install  (from your repo root)
│ after that, run /zenith run checks again
```
Stop.

Check for config:
```bash
test -f "$REPO_ROOT/.pre-commit-config.yaml"
```

If config missing:
```
blocked — no .pre-commit-config.yaml found
│ copy the Zenith template to get started:
│   cp ~/.zenith/assets/.pre-commit-config.yaml {REPO_ROOT}/.pre-commit-config.yaml
│   pre-commit install
│ then run /zenith run checks again
```
Stop.

Print preview:
```
running checks — {n} file(s) in {project_folder}/
│ {file}
│ {file}
```

Execute:
```bash
pre-commit run --files {changed_files}   # CMD_PRE_COMMIT_RUN
```

Parse output. For each hook, print one line:
```
│ ✓  {hook_name}
│ ✗  {hook_name}
│    {failure detail line 1}
│    {failure detail line 2}
```

After pre-commit completes, check for files modified by auto-fixing hooks:
```bash
git diff --name-only   # CMD_DIFF_UNSTAGED (files modified since last stage)
```

Compare this list against the original changed files list. Any file that appears in the post-run diff but was not already unstaged before the run was auto-fixed by a hook (e.g. black, isort, prettier, end-of-file-fixer).

Classify outcomes into three buckets:
- **auto-fixed**: hooks that modified files in place (exit non-zero, files changed on disk)
- **needs manual fix**: hooks that failed and did NOT modify files (exit non-zero, no file changes)
- **passed**: hooks that exited zero

If all passed and no auto-fixes:
```
  ✓ clean  all hooks passed
```
next: "next: run /zenith save to commit, or /zenith push to commit and open a PR"

If any hooks auto-fixed files (with or without other failures):
```
  ~ auto-fixed  {n} hook(s) modified files — review the changes below
  │ {file}  ← modified by {hook_name}
  │ {file}  ← modified by {hook_name}
  │
  │ these changes are not staged — review them, then run /zenith run checks again
```
next: "next: review the auto-fixed changes above (run /zenith what did I change), then re-run /zenith run checks"

If hooks failed without auto-fixing (no file modifications):
```
  ✗ fix required  {n} hook(s) failed — see details above
```
next: "next: fix the issues above, then run /zenith run checks again before committing"

### INTENT_GITIGNORE_CHECK

Detect changes to any `.gitignore` file (root or per-folder):
```bash
git diff --name-only HEAD          # CMD_DIFF_NAME_ONLY
git diff --name-only --cached      # CMD_DIFF_CACHED_NAME_ONLY
```

Filter results to files matching `*/.gitignore` or `.gitignore` at root.

If no `.gitignore` files changed:
```
nothing to check — no .gitignore files changed
│ run /zenith check gitignore after modifying a .gitignore file
```
Stop.

For each changed `.gitignore`:
```bash
git diff HEAD -- {gitignore_file}
```

Extract newly added rules (lines starting with `+` that are not comments or blank).

For each new rule, simulate its effect across the entire repo:
```bash
git check-ignore -v --no-index $(git ls-files) 2>/dev/null | grep "{rule_pattern}"
```

Group results by project folder. Identify rules that would ignore files outside the folder where the `.gitignore` lives.

Print:
```
gitignore audit — {n} new rule(s) added in {gitignore_file}
│ new rules:
│   + {rule}
│   + {rule}
│
│ effect outside this folder:
│   {other_folder}/{file}   ← would be ignored by rule "{rule}"
│   {other_folder}/{file}   ← would be ignored by rule "{rule}"
│
│ effect is scoped correctly (no cross-folder matches):
│   ✓ {rule}
```

If cross-folder matches found:
```
scope warning — {n} rule(s) affect files outside {folder}/
│ a .gitignore rule at {gitignore_file} will silently ignore files in another team's folder
│ consider moving these rules to a per-folder .gitignore or using a more specific pattern

Continue committing these rules? [y/n]
```

If no cross-folder matches:
```
  ✓ clean  all new rules are scoped to {folder}/ only
```

Next: "next: rules look safe — run /zenith save to commit, or adjust patterns if the scope looks wrong"

### INTENT_CHERRY_PICK

Check situation. If S5 or S6:
```
blocked — you have uncommitted changes
│ save or discard them before cherry-picking
│ run /zenith save or /zenith throw away changes
```
Stop.

Ask: "Which branch has the commit you want to pick from?"

```bash
git fetch origin                   # CMD_FETCH_ORIGIN
git log origin/{source_branch} --oneline -10 --format="%h %s — %an %ar"
```

Print:
```
recent commits on {source_branch} — pick one to apply here
│ 1.  {hash} {message} — {author} {time}
│ 2.  {hash} {message} — {author} {time}
│ ...

Which commit? (number or hash)
```

Show the diff of the selected commit scoped to `{project_folder}`:
```bash
git show {hash} -- {project_folder}/
git show {hash} --stat
```

Print:
```
cherry-pick preview — what will be applied to your branch
│ from      {source_branch} at {hash}
│ message   {commit_message}
│ author    {author}
│
│ files touching {project_folder}/:
│   {file}   +{n} -{n}
│
│ files outside {project_folder}/ (will NOT be applied):
│   {file}   +{n} -{n}
```

If the commit touches no files in `{project_folder}`:
```
scope mismatch — this commit has no changes in {project_folder}/
│ all changes are in folders owned by other teams
│ cherry-picking it would bring in out-of-scope changes

Apply anyway? [y/n]
```

Execute:
```bash
git cherry-pick {hash}
```

If conflicts:
Apply three-tier conflict resolution (same rules as INTENT_FIX_CONFLICT):
- Tier 1 (file outside {project_folder}): block, contact owner
- Tier 2 (mechanical): auto-resolve
- Tier 3 (substantive): show both versions, confirm discard before proceeding

If clean:
```bash
git log --oneline -1               # CMD_LAST_COMMIT_ONELINE
```

Print:
```
  ✓ cherry-picked  {hash}
  message          {commit_message}
  from             {source_branch}
```

Run contamination check silently. Surface any flags.

Next: "next: run /zenith push to include this commit in your PR"

### INTENT_FIND_DUPLICATES

Ask: "What are you looking for? (e.g. 'scRNA data loader', 'image augmentation pipeline', 'metric logging helper')"

Search by filename pattern:
```bash
find . -type f -name "*.py" | xargs grep -l "{keyword}" 2>/dev/null | grep -v __pycache__ | grep -v ".git"
```

Search by class/function name (if user provides one):
```bash
grep -r "class {keyword}\|def {keyword}" --include="*.py" -l .   # CMD_GREP_SYMBOL
```

Search by directory name:
```bash
find . -type d -name "*{keyword}*" | grep -v ".git"
```

Group results by project folder. Exclude the user's own `{project_folder}` from the match list (they already know about their own code).

If no matches:
```
no duplicates found — nothing matching "{keyword}" outside {project_folder}/
│ searched filenames, class names, and function names across the repo
│ you appear to be the first to build this
```

If matches found:
```
possible duplicates — similar implementations found outside {project_folder}/
│ {other_folder}/{file}   contains class/def "{keyword}"
│ {other_folder}/{file}   filename matches "{keyword}"
│
│ review before building — one of these may already do what you need
│ or coordinate with the owner to avoid two versions landing in the repo
```

Next: "next: review the matches above — if they overlap, coordinate with the owner before building your own version"
