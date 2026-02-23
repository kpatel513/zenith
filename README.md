# Zenith

You write code. Your team shares one repo. Git is in the way.

Zenith is a Claude Code command that lets you describe what you want in plain English and handles all the git operations safely — branching, saving, syncing, pushing, and creating PRs.

```
/zenith start new feature for the login page
/zenith save my work "add input validation"
/zenith push
```

---

## Who It's For

Teams where multiple people work in a single shared repo with subfolders per team or project:

```
company-repo/
├── team-payments/
│   └── checkout-service/    ← one person's work lives here
├── team-ml/
│   └── recommendations/     ← another person's work lives here
└── platform/
    └── infra/
```

Zenith knows which folder is yours. It only commits files from your folder, warns you if anything else changed, and blocks dangerous operations like committing directly to `main`.

---

## Before You Install

- [Claude Code](https://claude.ai/code) installed and working (`claude --version` to check)
- git 2.23 or later (`git --version` to check)
- A GitHub repo you have push access to
- macOS or Linux (bash required)

---

## Install

Run this from your terminal — anywhere, not inside the repo:

```bash
curl -fsSL https://raw.githubusercontent.com/kpatel513/zenith/main/scripts/setup.sh | bash
```

The script asks four questions. Here's what each one means.

---

**Question 1 — Where is your repo?**

```
Repo absolute path: /Users/alice/code/company-repo
```

This is the root folder of your local git clone — the directory that contains the `.git/` folder.

Not sure what path to enter? Run this inside your repo:

```bash
git rev-parse --show-toplevel
```

It prints the exact path to paste in.

---

**Question 2 — Which folder is yours?**

```
Your project folder: team-ml/recommendations
```

This is the subfolder where your work lives, relative to the repo root. Zenith scopes everything to this folder — commits, diffs, contamination checks.

Examples:
- `team-alpha/backend`
- `ml/training-pipeline`
- `services/auth`

If you work across the entire repo with no specific subfolder, enter `.`

---

**Question 3 — Your GitHub details**

```
GitHub organization: acme-corp
GitHub repository:   company-repo
Base branch [main]:  main
GitHub username:     alice
```

- **Organization** — the account or org name in your GitHub URL: `github.com/acme-corp/...`
- **Repository** — the repo name: `github.com/acme-corp/company-repo`
- **Base branch** — the branch your team merges into, almost always `main`
- **Username** — your GitHub handle, used to track your branches

Press Enter on base branch to accept `main` as the default.

---

**Verify it worked**

Open Claude Code from your repo root and run:

```
/zenith help
```

You'll see a table listing everything Zenith can do. If Claude says it doesn't recognize `zenith`, the setup didn't complete — re-run the script.

---

### What setup does

- Installs Zenith to `~/.zenith` on your machine
- Creates `.claude/commands/zenith.md` in your repo pointing to `~/.zenith` — this is what makes `/zenith` work
- Writes `.agent-config` at your repo root with your settings (automatically excluded from git commits)
- Installs a daily background update so Zenith stays current

### New machine or reinstalling?

The setup script is safe to re-run. It won't overwrite an existing install or duplicate entries. To change a setting after setup, edit `.agent-config` at your repo root directly.

---

## Using Zenith

Everything goes through `/zenith` in plain English. You don't have to memorize exact phrases — Zenith infers intent from context.

| Say this | What happens |
|----------|-------------|
| `start new feature` | Creates a branch from main, pushes it, tells you where to work |
| `continue my work` | Shows your recent branches, switches to the one you pick |
| `work on their branch` | Checks out a teammate's branch and shows recent activity |
| `what did I change` | Shows your uncommitted changes scoped to your folder |
| `scope check` | Verifies you haven't changed files outside your folder |
| `what's staged` | Shows what's queued for the next commit |
| `save my work` | Commits your changes after a safety check |
| `sync with main` | Rebases your branch onto latest main |
| `push` | Commits (if needed), syncs, pushes, and shows the PR link |
| `update my PR` | Adds new commits to an existing open PR |
| `how behind am I` | Lists commits on main you don't have yet |
| `what changed today` | Shows what teammates pushed to main recently |
| `undo last commit` | Removes the last commit, keeps your changes unstaged |
| `throw away changes` | Permanently discards all uncommitted changes |
| `unstage a file` | Removes a specific file from the staging area |
| `forgot a file` | Adds a missed file to your last commit |
| `fix commit message` | Corrects the message on your last commit |
| `split commits` | Separates staged changes into two separate commits |
| `push failed` | Diagnoses why push was rejected and fixes it |
| `help` | Shows this table |

---

## Your Settings

After setup, `.agent-config` lives at your repo root. It's excluded from git — each team member has their own copy.

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

Zenith updates itself. Setup installs a background job that runs once a day at 9am:

```
0 9 * * * cd ~/.zenith && git pull origin main --quiet
```

Nothing to maintain. You always have the latest version.

---

## Troubleshooting

**`/zenith` not recognized in Claude Code**
The symlink from your repo to `~/.zenith` wasn't created. Re-run the setup script from the repo root.

**"no .agent-config found" error**
Setup didn't finish, or you opened Claude Code from the wrong folder. Make sure you open Claude Code from your repo root — the same folder where `.git/` lives.

**Push rejected**
Run `/zenith push failed`. Zenith will diagnose and fix the most common causes (branch behind remote, no upstream set, protected branch).

---

## Contributing

Open an issue for bugs or feature requests. PRs welcome.

## License

MIT
