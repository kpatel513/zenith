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

## Who it's for

Teams where multiple people share one repo, with each person owning a subfolder:

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

Run this from your terminal — anywhere, not inside the repo:

```bash
curl -fsSL https://raw.githubusercontent.com/kpatel513/zenith/main/scripts/setup.sh | bash
```

The script asks four questions.

---

**Question 1 — Where is your repo?**

```
Repo absolute path: /Users/alice/code/company-repo
```

The root folder of your local clone — the directory that contains the `.git/` folder. Not sure? Run this inside your repo:

```bash
git rev-parse --show-toplevel
```

It prints the exact path to paste in.

---

**Question 2 — Which folder is yours?**

```
Your project folder: team-ml/recommendations
```

The subfolder where your work lives, relative to the repo root. Zenith scopes commits, diffs, and safety checks to this folder.

Examples: `team-alpha/backend`, `ml/training-pipeline`, `services/auth`

If you work across the entire repo with no specific subfolder, enter `.`

---

**Question 3 — Your GitHub details**

```
GitHub organization: acme-corp
GitHub repository:   company-repo
Base branch [main]:  main
GitHub username:     alice
```

- **Organization** — the org or account name from your GitHub URL
- **Repository** — the repo name
- **Base branch** — the branch your team merges into, almost always `main`
- **Username** — your GitHub handle

Press Enter on base branch to accept `main` as the default.

---

**Verify it worked**

Open Claude Code from your repo root and run:

```
/zenith help
```

You'll see a table of everything Zenith can do. If it says the command isn't recognized, re-run the setup script.

---

**What setup does**

- Installs Zenith to `~/.zenith` on your machine
- Creates `.claude/commands/zenith.md` in your repo — this is what makes `/zenith` work in Claude Code
- Writes `.agent-config` at your repo root with your settings (excluded from git automatically)
- Installs a daily background update so you always have the latest version

**New machine or reinstalling?** The setup script is safe to re-run. It won't overwrite anything or create duplicates. To change a setting after setup, edit `.agent-config` at your repo root directly.

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

After setup, `.agent-config` lives at your repo root. It's excluded from git — each team member has their own copy with their own folder.

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

## Troubleshooting

**`/zenith` not recognized in Claude Code**
Re-run the setup script from inside your repo root.

**"no .agent-config found" error**
Open Claude Code from your repo root — the same folder where `.git/` lives.

**Push rejected**
Run `/zenith push failed`. Zenith will diagnose and fix the most common causes.

**Your folder warning on startup**
If Zenith warns that your `project_folder` doesn't exist, edit `.agent-config` and correct the path, or re-run setup.

---

## Contributing

Open an issue for bugs or feature requests. PRs welcome.

## License

MIT
