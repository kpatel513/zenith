# Zenith

Git workflow automation for teams working in GitHub monorepos with mixed git skill levels and heavy Claude Code usage.

## What It Does

Zenith runs as a single Claude Code slash command: `/zenith`. You describe what you want in plain English. Zenith reads actual repo state, determines the correct sequence of operations, and executes them safely.

Zenith encodes specific expertise about monorepo git workflows, ML project conventions, and safety rules. It prevents cross-folder contamination, detects risky file patterns, and handles conflicts intelligently.

## Requirements

- git
- bash
- Claude Code
- cron (for automatic updates)
- GitHub repository

## Installation

### Prerequisites

- [Claude Code](https://claude.ai/code) installed and working
- git 2.23+
- A GitHub repository you can push to
- bash (macOS and Linux)

### Steps

**1. Run the setup script**

```bash
curl -fsSL https://raw.githubusercontent.com/your-org/zenith/main/scripts/setup.sh | bash
```

**2. Enter your monorepo path when prompted**

```
Monorepo absolute path: /Users/you/code/your-monorepo
```

This must be the root of your local git clone.

**3. Enter your project folder**

```
Your project folder name: team-alpha/ml-pipeline
```

This is the folder inside the monorepo where your work lives. Zenith will scope all git operations to this folder and warn you if changes appear outside it.

**4. Enter your GitHub details**

```
GitHub organization: your-org
GitHub repository:   your-repo
Base branch [main]:  main
GitHub username:     your-github-username
```

**5. Verify installation**

Open Claude Code in your monorepo and run:

```
/zenith help
```

You should see a table of available commands. If you see `Unknown command: zenith`, the symlink wasn't created — re-run the setup script.

### What the script does

- Clones Zenith to `~/.zenith`
- Creates `.claude/commands/zenith.md` in your monorepo as a symlink to `~/.zenith/.claude/commands/zenith.md`
- Writes a `.agent-config` file at your monorepo root (gitignored automatically)
- Installs a daily cron job (`0 9 * * *`) to keep Zenith up to date silently

### Reinstalling or reconfiguring

The script is idempotent — running it again on a fresh machine won't break anything. To reconfigure an existing install, edit `.agent-config` directly at your monorepo root.

## Usage

Everything goes through `/zenith` in plain English.

**Start new work:**
```
/zenith start new feature
```
Creates and pushes a new feature branch from main. Names it based on your description.

**Continue existing work:**
```
/zenith continue my work
```
Shows your recent branches, lets you pick one, shows what's new on main since you last worked.

**Save your changes:**
```
/zenith save my work
```
Runs contamination check, stages your project folder, shows what will be committed, commits with your message.

**Sync with main:**
```
/zenith sync with main
```
Fetches latest, shows incoming commits, rebases onto main with intelligent conflict resolution.

**Push and create PR:**
```
/zenith push
```
Syncs with main, stages and commits if needed, pushes to remote, shows PR URL.

**Check what you changed:**
```
/zenith what did I change
```
Shows uncommitted changes in your project folder, flags changes outside your folder if any.

## Configuration

After setup, `.agent-config` lives at your monorepo root:

```ini
[repo]
github_org = "your-org"
github_repo = "your-repo"
base_branch = "main"

[user]
project_folder = "your-project-folder"
github_username = "your-github-username"
```

This file is gitignored. Each team member has their own copy with their own project folder.

## How Updates Work

Setup installs a cron job that runs daily at 9am:
```
0 9 * * * cd ~/.zenith && git pull origin main --quiet
```

Updates are automatic and silent. The symlink means your `/zenith` command always points to the latest version.

## Contributing

Open issues for bugs or feature requests. PRs welcome.

## License

MIT
