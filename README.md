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
| Catches commits to main | No | Yes — warns on startup |
| Catches shared file edits | No | Yes — contamination check |
| Catches large staged sets | No | Yes — pauses at >50 files |
| Learns your workflow patterns | No | Yes — nudges before operations you keep getting wrong |
| Catches hardcoded local paths | No | Yes — scans diff content |
| Catches root-level dep changes | No | Yes — flags regardless of project_folder |

`/zenith push` does the same thing every time. It's closer to a CLI command than a conversation.

→ [How it works at the team level](docs/overview.md)

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

→ [Full safety rules and what Zenith catches](docs/safety.md)

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

### Step 1 — Run the installer (once per machine)

```bash
curl -fsSL https://raw.githubusercontent.com/kpatel513/zenith/main/scripts/setup.sh | bash
```

That's it. The installer:
- Detects your GitHub username from `gh` (asks if `gh` isn't installed or not authenticated)
- Installs adapters for any tools it finds — Cursor, Codex CLI, Gemini CLI — automatically
- Sets up a daily background update so you always have the latest version

### Step 2 — Open Claude Code in a repo and run any /zenith command

```
/zenith start new work
```

First time in a repo, Zenith detects your org, repo, and base branch from git and asks one question:

```
setting up zenith — detected from your repo
│ org: acme-corp   repo: company-repo   branch: main   user: alice

  your folder in this repo [. for whole repo]: team-ml/recommendations

  ✓ config saved  /Users/alice/code/company-repo/.agent-config
  ✓ gitignore     .agent-config will not be committed
```

Done. Every subsequent `/zenith` command in that repo runs without asking anything.

**Adding a new repo?** Open Claude Code in that repo and run any `/zenith` command — same one-question setup.

**Verify it worked:**

```
/zenith help
```

---

**What the installer puts on your machine**

| What | Where | Purpose |
|------|-------|---------|
| Zenith files | `~/.zenith/` | The skill definition, updated daily |
| Claude Code command | `~/.claude/commands/zenith.md` | Makes `/zenith` work in every session |
| Cursor rule | `~/.cursor/rules/zenith.mdc` | Makes `@zenith` work (if Cursor is installed) |
| Codex skill | `~/.codex/skills/zenith/` | Makes `$zenith` work (if Codex CLI is installed) |
| Global config | `~/.zenith/.global-config` | Stores your GitHub username and Jira/Linear credentials |

New machine or reinstalling? The installer is safe to re-run.

---

## Using Zenith in Cursor

Works via `@zenith`. If Cursor is installed when you run the installer, the adapter is set up automatically. Already installed Zenith but added Cursor later? One-liner to add Cursor support manually:

→ [Full Cursor setup and model compatibility](docs/cursor.md)

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
| `review my PR` | Three-pass review using git history, docs, config, and code structure (Layers 1–6) |
| `deep review my PR` | Same review with full context: adds PR history, open PR conflicts, past reviewer patterns (Layers 1–9) |
| `review PR 123` | Three-pass review for a teammate's PR (Layers 1–6) |
| `deep review PR 123` | Full-context review for a teammate's PR (Layers 1–9) |
| `check gitignore` | Audits .gitignore changes for rules that silently break other teams' folders |
| `cherry-pick a fix` | Safely applies a specific commit from another branch, scoped to your folder with contamination check |
| `find duplicates` | Searches the repo for similar filenames, classes, or functions before you build something that already exists |
| `blast radius` | Shows every file in the repo that imports or references what you changed — surface cross-team impact before you push |
| `conflict radar` | Shows open PRs that touch the same files as your current changes — surface conflicts before they happen |
| `open worktree` | Checks out a branch in a new directory so you can work on two branches simultaneously without stashing |
| `list worktrees` | Shows all active worktrees and their paths |
| `remove worktree` | Deletes a linked worktree directory (branch is not deleted) |
| `help` | Shows this table |

---

## Stacked PRs

When change B depends on change A and both need separate PRs, use a stack. Run `start new work` from an existing feature branch — Zenith asks whether to branch from main or stack on top. The stack is managed locally and never committed.

→ [Full stacked PR workflow](docs/stacked-prs.md)

---

## PR Review

Zenith runs a three-pass adversarial review — designed to behave like a skeptical principal engineer, not a helpful assistant. Two tiers:

- `review` / `review PR 123` — Layers 1–6, fast, good for pre-submit checks
- `deep review` / `deep review PR 123` — Layers 1–9, adds PR history, open PR conflicts, and past reviewer patterns

```
reviewing — feature/add-rate-limiter
│ CI: ✓  base: main  +84 -12

── what it does ────────────────────────────────────────
│ • Adds a token bucket rate limiter to the API gateway
│ • Stores per-user token counts in Redis with a 60s TTL
│ • Returns 429 with Retry-After header when limit exceeded

── signals ─────────────────────────────────────────────
│ volatile   src/middleware/auth.js — 18 commits, 2 reverts
│ duplicate  RateLimiter already exists at src/utils/throttle.js
│ conflict   PR #41 (bob) also touches src/middleware/auth.js

── concerns ────────────────────────────────────────────
│ P1  auth.js line 47: Redis client initialized per-request.
│     failure:     Pool exhaustion under load.
│     alternative: Initialize once at module load.
│     question:    What is the expected RPS?

  verdict  MERGE AFTER FIXES
```

→ [Three-pass review details, signal definitions, and team context file](docs/pr-review.md)

---

## Pattern learning

Zenith tracks your workflow events and surfaces nudges when a mistake recurs — before the operation that would repeat it. Nudges appear inline in the confirmation prompt and fade as your habits improve. Nothing to configure — it observes automatically.

→ [How pattern tracking works, tracked patterns, and examples](docs/pattern-learning.md)

---

## Jira integration

Zenith can create, view, update, and close Jira tickets without leaving Claude Code. Name Jira explicitly to select it; unqualified ticket requests use Linear.

```
/zenith jira create a bug ticket for the login timeout issue
/zenith jira show ticket AIE-234
/zenith jira my tickets
/zenith jira move AIE-234 to in progress
/zenith jira branch from ticket AIE-234
/zenith jira close ticket AIE-234
```

**Setup — runs once, automatically on first Jira command:**

```
jira setup — one-time credential configuration
│ saved globally and reused across all repos

  atlassian URL [your-org.atlassian.net]:
  email [alice@company.com]:
  api token (https://id.atlassian.net/manage-profile/security/api-tokens):

jira repo setup — configure this repo's default project
  jira project key (e.g. AIE, INFRA, PLAT):

  ✓ jira ready — https://your-org.atlassian.net, project AIE
```

Credentials are saved to `~/.zenith/.global-config` and reused across every repo. The default project is saved per-repo in `.agent-config`. You can override it inline: `/zenith jira my INFRA tickets`.

| Say this | What happens |
|----------|-------------|
| `jira create a ticket` | Create a story, task, bug, or epic; asks for type, summary, epic, description |
| `jira show ticket AIE-123` | Display ticket details: status, type, assignee |
| `jira my tickets` | List open tickets assigned to you in this repo's project |
| `jira update ticket summary` | Edit the summary or description of a ticket |
| `jira move ticket to in progress` | Transition a ticket to any status |
| `jira assign ticket to me` | Assign a ticket to yourself or search for a teammate |
| `jira branch from ticket AIE-123` | Create a git branch named after the ticket; Jira links it automatically |
| `jira close ticket AIE-123` | Transition ticket to Done |
| `jira delete ticket AIE-123` | Permanently delete a ticket (requires typing the ticket key to confirm) |

---

## Linear integration

Linear is the default for ticket and issue requests. Zenith manages Linear issues through the GraphQL API using a personal API key. It supports creation, viewing, listing, editing, status changes, assignment, branches, completion, and deletion. Issues can be scoped to a team and an existing project.

On your first Linear command, Zenith completes the normal repo setup and guides you through Linear credentials and defaults. Create a personal key in [Linear Security & access](https://linear.app/settings/account/security). Zenith uses hidden local terminal input and saves the key under `[linear]` as `linear_api_key` in `~/.zenith/.global-config`, with access restricted to your user. The saved key is reused across repos. Keep it out of chat and repository files.

If your client cannot accept hidden terminal input, Zenith asks you to run this locally, then resumes setup when you return:

```bash
bash ~/.zenith/scripts/setup.sh --linear
```

Zenith then asks for a default team and an optional project, validates the choices, and saves them in your repo's `.agent-config`:

```ini
[linear]
linear_team = "ENG"
linear_project = ""
```

The team can be a key, name, or UUID. The project can be a name or UUID; leave it empty for no default project. Returning users reuse these settings without setup prompts. Explicit team and project selections override defaults for that request; existing-issue changes use the issue's actual team. Use `$zenith linear setup` to finish or change setup.

For CI or users who prefer environment configuration, `LINEAR_API_KEY` remains a fallback when no nonempty key is saved globally. An environment key is not copied to disk. No Linear SDK or additional package is required.

Use `$zenith` in Codex, `/zenith` in Claude Code and Gemini, or `@zenith` in Cursor:

```text
$zenith create a ticket "Fix login timeout" in team ENG
$zenith my tickets
$zenith show ticket ENG-123
$zenith linear create issue "Fix login timeout" in team ENG
$zenith linear list in project "Website"
$zenith linear view ENG-123
$zenith linear update ENG-123 title to "Handle expired sessions"
$zenith linear transition ENG-123 to In Progress
$zenith linear assign ENG-123 to me
$zenith linear branch ENG-123
$zenith linear close ENG-123
$zenith linear delete ENG-123
```

`linear list` shows your open issues by default, with an optional project filter. Ask for all assignees, all projects, closed issues, or more results to change that scope. Status choices come from the issue's team. Updates change only requested fields. Deletion requires typing the issue identifier and uses Linear's normal trash workflow.

You can also name Linear explicitly or provide a Linear issue URL. To use Jira, name it explicitly, for example `$zenith jira create a ticket`. Jira credentials and project defaults do not change the provider selection. Missing Linear credentials trigger setup; failed requests report the problem without falling back to Jira. Onboarding may update config and `.gitignore`, but ticket operations do not sync or switch Git branches. `branch from ticket` and `linear branch` check the working tree, create a branch, and push it after confirmation. Creating or updating Linear Projects is outside this integration's scope.

See [Linear API operations](references/linear-ops.md) for authentication, request handling, and official API sources.

### Link Linear issues to PRs

Ask Zenith to associate an issue when creating a ready PR, opening a draft, or updating an existing PR:

```text
$zenith open a PR for Linear ENG-123
$zenith create a draft PR for ENG-123 and ENG-456
$zenith link Linear ENG-123 to PR 42
```

Zenith includes every requested issue ID in the title, for example `feat(auth): handle expired sessions [ENG-123]`, and adds `implements ENG-123` to the description. `implements` is the default closing keyword: Linear follows the team's configured workflow and applies its merge status when the PR merges. The repository must have Linear's GitHub integration enabled.

For partial work that must not close on merge, request `refs ENG-123` or `part of ENG-123`. For a relation without status changes, request `relates to ENG-123`. `skip ENG-123` or `ignore ENG-123` prevents automatic linking. A bare ID in the description or a magic word in a PR comment does not create the requested association. These behaviors follow [Linear's linking rules](https://linear.app/docs/github#link-through-pull-requests).

Existing PR edits preserve the description and valid links, avoid duplicates, and do not require a code commit or a Linear API key when the identifier is supplied. Zenith reports the saved PR metadata separately from whether Linear synchronization has been verified. Creating a ticket alone does not create a PR.

---

## Claude Code safety layer

Claude Code sees the whole codebase and makes reasonable calls — but it doesn't know your monorepo conventions. Zenith intercepts at commit and push time to catch scope violations, generated files, hardcoded paths, and conflict resolutions that silently discard correct code.

→ [Full list of what Zenith catches from Claude Code](docs/safety.md)

---

## Your settings

After first use in a repo, `.agent-config` lives at your repo root. **It is never committed to GitHub** — Zenith automatically adds it to `.gitignore`. Each team member gets their own private copy.

```ini
[repo]
github_org    = "acme-corp"
github_repo   = "company-repo"
base_branch   = "main"

[user]
project_folder  = "team-ml/recommendations"
github_username = "alice"

[jira]
jira_project = "AIE"
```

`project_folder` is relative to the repository root. Set it to `"."` to use the whole repository. You can edit these defaults at any time. Zenith stores Jira and Linear credentials in `~/.zenith/.global-config`.

---

## Updates

Zenith updates itself. A background job runs once a day:

```
0 9 * * * cd ~/.zenith && git fetch origin main --quiet && git reset --hard origin/main --quiet
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
