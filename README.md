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
`zenith.md` lives in the repo. Changes to how Zenith behaves go through PR review, the same as any other codebase change. The team's git conventions are readable, diffable, and auditable.

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

- [Claude Code](https://claude.ai/code) installed and working — run `claude --version` to check
- git 2.23 or later — run `git --version` to check
- A GitHub repo you have push access to
- macOS or Linux

---

## Install

### Step 1 — Install Zenith globally (once per machine)

Run this from your terminal — anywhere:

```bash
curl -fsSL https://raw.githubusercontent.com/kpatel513/zenith/main/scripts/setup.sh | bash
```

This installs Zenith to `~/.zenith`, makes `/zenith` available in every Claude Code session on your machine, and asks one question:

```
GitHub username: [your github username]
```

That's it. Zenith is installed globally. You don't configure repos here — that happens automatically the first time you use `/zenith` in each repo.

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
- Writes `~/.zenith/.global-config` with your GitHub username — pre-fills it for every repo you configure
- Installs a daily background update so you always have the latest version

**New machine or reinstalling?** The setup script is safe to re-run. It won't overwrite anything or create duplicates. To change your username after setup, edit `~/.zenith/.global-config` directly.

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
| `fix commit message` | Corrects the message on your last commit |
| `push failed` | Diagnoses why push was rejected and fixes it |
| `clean up branches` | Deletes your old merged branches |
| `help` | Shows this table |

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
