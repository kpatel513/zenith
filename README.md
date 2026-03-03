# Zenith

You're working in a shared repo. You don't want to accidentally overwrite someone else's work, commit to the wrong branch, or push something that breaks the team.

Zenith handles all of that. You describe what you want in plain English — it does the git operations safely.

```
/zenith start new feature for the login page
/zenith save my work "add input validation"
/zenith push
```

---

## A real example

Alice is on the ML team. She edits her model training code and types:

```
/zenith push my changes
```

Zenith checks she's not on `main`. Confirms she only touched files in her folder. Syncs with the latest code from the team. Opens a PR. She never runs a git command.

Meanwhile, if she had accidentally edited a file in the payments team's folder, Zenith would have caught it and asked what to do before committing anything.

---

## Why not just ask Claude Code directly?

You can. But you'll end up doing this every time:

> *"Please commit my changes — but first check I'm not on main, make sure I haven't touched anything outside team-ml/recommendations, sync with the latest main, then push and open a PR."*

And Claude might do it differently each session. It might forget the contamination check. It doesn't know your folder, your org, or your base branch unless you tell it.

Zenith is pre-configured with that context. It runs the same sequence every time, not based on how you phrase the request.

| | Raw Claude Code | Zenith |
|---|---|---|
| Knows your folder | You tell it each time | Pre-configured |
| Knows your repo/org | You tell it each time | Pre-configured |
| Safety checks | Run if you ask | Run every time |
| Push sequence | Depends on your prompt | Always: commit → check scope → sync → push → PR |
| Consistency | Varies by session | Deterministic |

`/zenith push` does the same thing every time. It's closer to a CLI command than a conversation.

---

## How it works at the team level

**Consistent behavior across engineers**
When everyone uses the same command, the same sequence of operations runs every time — not because people remember to, but because there's no other path. Branch naming, scope checking, sync-before-push, and PR creation happen in the same order for everyone on the team.

**The spec is version-controlled**
`SKILL.md` lives in the repo. Changes to how Zenith behaves go through PR review, the same as any other codebase change. The team's git conventions are readable, diffable, and auditable.

**Scope enforcement happens before the PR queue**
In a shared monorepo, cross-folder changes are flagged at commit time rather than during code review. Reviewers see PRs that have already been checked against folder boundaries.

**Context is configuration, not conversation**
Your org name, base branch, project folder, and GitHub username are set once in `.agent-config`. They don't need to be re-specified each session. A new team member runs setup once and operates with the same context as everyone else.

---

## Who it's for

**Shared monorepos** — multiple people in one repo, each owning a subfolder:

```
company-repo/
├── team-payments/
│   └── checkout-service/    ← Alice's work lives here
├── team-ml/
│   └── recommendations/     ← Bob's work lives here
└── platform/
    └── infra/               ← Carol's work lives here
```

Zenith knows which folder is yours. It only commits your files, warns you if anything else changed, and blocks operations that could affect your teammates.

**Solo or small-team repos** — you own the whole thing, but you still want safe branching, automatic syncing, and PR workflows without thinking about git commands.

It's especially useful for people who are strong in their domain — ML, data, design — but don't spend their days thinking about git.

---

## What it protects you from

- Committing directly to `main` by accident
- Pushing code that touches files outside your folder
- Pushing before syncing with the latest team changes
- Merge conflicts that invalidate your teammates' PR reviews
- Getting stuck after a push fails with a cryptic git error

---

## Before you install

- git 2.23 or later — run `git --version` to check
- [GitHub CLI (gh)](https://cli.github.com) — run `gh --version` to check; install with `brew install gh` then `gh auth login`
- A GitHub repo you have push access to
- macOS or Linux
- [Claude Code](https://claude.ai/code) — if using `/zenith` in Claude Code
- [Cursor](https://cursor.com) — if using `@zenith` in Cursor (any model works)

---

## Install

### Install as an agent skill (Claude Code, Codex CLI, Gemini CLI, Cursor)

Zenith follows the open agent skills standard. Any compatible runtime can install it with one command:

```bash
git clone https://github.com/kpatel513/zenith ~/.agents/skills/zenith
```

The runtime reads `SKILL.md` from the cloned directory. No setup script required.

---

### Step 1 — Install Zenith globally (once per machine)

Run this from your terminal — anywhere:

```bash
curl -fsSL https://raw.githubusercontent.com/kpatel513/zenith/main/scripts/setup.sh | bash
```

This installs Zenith to `~/.zenith` and asks two questions:

```
GitHub username:          [your github username]
Install Cursor rule? [y/N]: [y if you use Cursor, N otherwise]
```

That's it. Zenith is installed globally. You don't configure repos here — that happens automatically the first time you use `/zenith` or `@zenith` in each repo.

---

### Step 2 — Use /zenith in a repo (configures itself on first run)

Open Claude Code from inside any repo and run any `/zenith` command:

```
/zenith start new work
```

If this is the first time Zenith has been used in that repo, it detects there's no config and walks you through 4 quick questions before continuing:

```
first-time setup — no config found for this repo
│ detected: /Users/alice/code/company-repo
│ answering 4 questions configures Zenith for this repo permanently
│ your answers are saved locally and never committed to GitHub

Your project folder (or . for whole repo): team-ml/recommendations
GitHub organization:                       acme-corp
GitHub repository:                         company-repo
Base branch [main]:                        main

  ✓ config saved  /Users/alice/code/company-repo/.agent-config
  ✓ gitignore     .agent-config will not be committed
```

From that point on, `/zenith` in that repo reads the saved config and runs without asking again.

**Adding a new repo later?** Just open Claude Code in that repo and run any `/zenith` command. Same first-time setup, same 4 questions.

---

**Verify it worked**

Open Claude Code (from any directory) and run:

```
/zenith help
```

You'll see a table of everything Zenith can do.

---

**What setup does**

- Installs Zenith to `~/.zenith` on your machine
- Creates `~/.claude/commands/zenith.md` — makes `/zenith` available in every Claude Code session, regardless of which directory you open it from
- Creates `~/.cursor/rules/zenith.mdc` (if you opt in) — makes `@zenith` available in every Cursor session
- Writes `~/.zenith/.global-config` with your GitHub username — pre-fills it for every repo you configure
- Installs a daily background update so you always have the latest version

**New machine or reinstalling?** The setup script is safe to re-run. It won't overwrite anything or create duplicates. To change your username after setup, edit `~/.zenith/.global-config` directly.

---

## Using Zenith in Cursor

### First-time install

Run the same `setup.sh` installer and answer **y** to the Cursor question. That creates `~/.cursor/rules/zenith.mdc`, which makes `@zenith` available in every Cursor session on your machine.

### Already have Zenith installed?

Setup won't re-run if Zenith is already installed. Add Cursor support with one command:

```bash
mkdir -p ~/.cursor/rules && ln -s ~/.zenith/.cursor/rules/zenith.mdc ~/.cursor/rules/zenith.mdc
```

### How to invoke

Open Cursor's **Chat** or **Composer** panel, type `@zenith` followed by your request, and press Enter:

```
@zenith push my changes
@zenith start new feature
@zenith sync with main
@zenith help
```

Cursor will show a dropdown when you type `@` — select **zenith** from the list, then add your request. The same phrases from the "What you can say" table below all work.

### First use in a repo

The first time you run `@zenith` in a repo that hasn't been configured, Zenith walks you through the same 4-question setup as Claude Code:

```
first-time setup — no config found for this repo
│ detected: /Users/alice/code/company-repo
│ answering 4 questions configures Zenith for this repo permanently

Your project folder (or . for whole repo): team-ml/recommendations
GitHub organization:                       acme-corp
GitHub repository:                         company-repo
Base branch [main]:                        main
```

If you've already configured the repo via Claude Code, `@zenith` picks up the same `.agent-config` — no duplicate setup.

### Model compatibility

**Claude Code is not required.** Zenith works with any model available in Cursor — Claude, GPT-4o, Gemini, or Cursor's built-in model.

> If your repo's `.gitignore` excludes `.cursor/`, add an exception so teammates who use Cursor can get the rule:
> ```
> !.cursor/rules/zenith.mdc
> ```

---

## What you can say

You don't have to memorize exact phrases. Zenith understands intent.

| Say this | What happens |
|----------|-------------|
| `start new feature` | Creates a branch from main, pushes it, tells you where to work |
| `continue my work` | Shows your recent branches, switches to the one you pick |
| `work on their branch` | Checks out a teammate's branch and shows recent activity |
| `what did I change` | Shows your uncommitted changes scoped to your folder |
| `scope check` | Verifies you haven't changed files outside your folder |
| `what's staged` | Shows what's queued for the next commit |
| `save my work` | Commits your changes after a safety check |
| `sync with main` | Brings your branch up to date with the team's latest code |
| `push` | Commits (if needed), syncs, pushes, and shows the PR link |
| `draft PR` | Pushes as a draft PR — starts CI without requesting review |
| `update my PR` | Adds new commits to an existing open PR |
| `CI failed` | Shows which step failed and links to the logs |
| `PR has conflicts` | Walks you through resolving a merge conflict blocking your PR |
| `how behind am I` | Lists commits on main you don't have yet |
| `what changed today` | Shows what teammates pushed to main recently |
| `status` | Shows your branch, PR state, and pending changes in one view |
| `undo last commit` | Removes the last commit, keeps your changes unstaged |
| `throw away changes` | Permanently discards all uncommitted changes |
| `forgot a file` | Adds a missed file to your last commit |
| `remove file from commit` | Removes a file from the last commit, leaves it unstaged |
| `fix commit message` | Corrects the message on your last commit |
| `split commits` | Separates staged changes into two commits |
| `unstage a file` | Removes a file from the staging area |
| `push failed` | Diagnoses why push was rejected and fixes it |
| `I merged the PR` | Syncs your branch after a PR is merged, retargets stacked branches |
| `clean up history` | Removes merge commits, replays your commits cleanly onto main |
| `move my commits` | Cherry-picks commits to the correct branch and removes them from this one |
| `unstash` | Restores changes saved by a previous stash |
| `clean up branches` | Deletes your old merged branches |
| `show my stack` | Shows every branch in your stack with PR status and CI state |
| `run checks` | Runs pre-commit hooks against your changed files and reports pass/fail per hook |
| `review my PR` | Three-pass adversarial review of your branch: plain summary, signals (scope/volatility/duplicates), then a principal-engineer rejection pass |
| `review PR 123` | Same three-pass review for a teammate's PR — fetches the diff, runs all three passes |
| `help` | Shows this table |

---

## Stacked PRs

When change B depends on change A and both need separate PRs, use a stack.

**Start a stack** — when you're already on a feature branch, run `start new work`. Zenith asks whether to branch from main or stack on top of the current branch. Choose "stack" and the new branch automatically targets the parent branch instead of main.

**What changes:**
- `push` — opens the PR against the parent branch (not main)
- `sync` — syncs against the parent branch
- `show my stack` — displays the full chain with PR status and CI state for each level

**When the parent PR merges:**

Run `I merged the PR`. Zenith detects which PR merged and handles the cascade:
1. Retargets your PR base from the parent branch to main
2. Runs `git rebase --onto` to drop the parent's commits from your branch
3. Force-pushes and cleans up the stored parent config

Your PR on GitHub automatically updates to show the correct diff.

**Stack info is stored in git config locally** — it is never committed and never sent anywhere.

---

## PR Review

Zenith runs a three-pass adversarial review — designed to behave like a skeptical principal engineer, not a helpful assistant. It works in two modes.

**Author mode** — before you submit, while you're still on your branch:
```
/zenith review my PR
/zenith self-review
/zenith review my changes
```

**Reviewer mode** — when you've been assigned to review someone else's PR:
```
/zenith review PR 123
/zenith review #42
```

### How the three passes work

**Pass 1 — Benevolent.** What does this diff actually do? Zenith reads the raw diff, the commit messages, and the PR description and produces 3–5 plain English bullets. Facts, no opinions.

**Pass 2 — Signals.** Automated checks against the codebase:
- **Scope** — are all changed files inside your project folder, or did the PR accidentally touch something else?
- **Volatile files** — files with more than 10 commits in the past year are flagged; bugs introduced here tend to be expensive
- **Fragile files** — files that have had revert or hotfix commits are flagged with the history
- **Duplicate symbols** — new functions or classes are grep'd against the whole codebase; if the same name already exists somewhere, it's surfaced

**Pass 3 — Adversarial (isolated).** Pass 3 sees only the raw diff — it never reads Pass 1 or Pass 2 output. Persona: principal engineer, default verdict is REJECT, assumes junior author. Every concern it raises must have all four fields:
- line citation
- failure scenario (concrete: "when X under Y condition, result is Z")
- alternative implementation
- question the author must answer before merging

Pass 3 explicitly checks eight things: right problem vs. symptom, failure recovery, coupling introduced, simpler path available, worst-case load and data, readability for the next engineer, what it makes harder to change in 6 months, and hidden assumptions about callers or environment.

### Team context file

Create `.zenith-context` at the repo root (committed, not personal) to raise the quality ceiling:

```
[failure_patterns]
db query inside loop → connection pool exhaustion (incident 2024-03)

[existing_utilities]
src/utils/retry.js — circuit breaker, use instead of custom retry logic

[architecture]
never couple payment flow to session state (ADR-007)
```

A template is at `assets/.zenith-context.template`. Zenith checks every PR diff against the patterns in this file and flags matches in the signals section. No file, no error — it just runs on git history and codebase scan alone.

### What the output looks like

```
reviewing — feature/add-rate-limiter
│ CI: ✓  base: main  +84 -12
│ 3-pass review: summary → signals → adversarial (pass 3 sees raw diff only)

── what it does ──────────────────────────────────────────
│ • Adds a token bucket rate limiter to the API gateway middleware
│ • Stores per-user token counts in Redis with a 60s TTL
│ • Returns 429 with Retry-After header when limit is exceeded

── signals ───────────────────────────────────────────────
│ scope     ✓ within team-api/
│ volatile  src/middleware/auth.js — 18 commits in past year, 2 reverts
│ duplicate RateLimiter already exists at src/utils/throttle.js

── concerns ──────────────────────────────────────────────
│ P1  line 47: Redis client initialized inside the middleware function
│     failure:     new connection on every request under load — pool exhaustion
│     alternative: initialize once at module load, pass as dependency
│     question:    what's the expected RPS and how many middleware instances run concurrently?

── biggest concern ───────────────────────────────────────
│ The rate limiter is applied after auth, so a flood of unauthenticated
│ requests bypasses it entirely. Protect the auth endpoint first.

  verdict  NEEDS CHANGES
```

---

## Your settings

After first use in a repo, `.agent-config` lives at your repo root. **It is never committed to GitHub** — Zenith automatically adds it to `.gitignore`. Each team member runs the first-time setup once and gets their own private copy with their own folder and username.

```ini
[repo]
github_org    = "acme-corp"
github_repo   = "company-repo"
base_branch   = "main"

[user]
project_folder  = "team-ml/recommendations"
github_username = "alice"
```

Edit this file any time to update your settings.

---

## Updates

Zenith updates itself. A background job runs once a day:

```
0 9 * * * cd ~/.zenith && git pull origin main --quiet
```

Nothing to maintain.

---

## Uninstall

```bash
~/.zenith/scripts/uninstall.sh
```

This removes the global symlink, the cron job, and the `~/.zenith` directory. Your per-repo `.agent-config` files are not touched — remove them manually if you want:

```bash
rm /path/to/repo/.agent-config
```

---

## Troubleshooting

**`/zenith` not recognized in Claude Code**
Run `ls ~/.claude/commands/zenith.md` to check if the global symlink exists. If it's missing, re-run the install command.

**`@zenith` not appearing in Cursor**
Run `ls ~/.cursor/rules/zenith.mdc` to check if the rule is installed. If it's missing, run:
```bash
mkdir -p ~/.cursor/rules && ln -s ~/.zenith/.cursor/rules/zenith.mdc ~/.cursor/rules/zenith.mdc
```
Then open Cursor Settings → Rules and confirm `zenith` appears with `alwaysApply: false`.

**First-time setup not appearing**
Make sure you're opening Claude Code from inside a git repository. Zenith detects the repo automatically — it won't run if there's no `.git/` folder in the tree.

**Push rejected**
Run `/zenith push failed`. Zenith will diagnose and fix the most common causes.

**Your folder warning on startup**
If Zenith warns that your `project_folder` doesn't exist, edit `.agent-config` at your repo root and correct the path.

---

## Contributing

Open an issue for bugs or feature requests. PRs welcome.

## License

MIT
