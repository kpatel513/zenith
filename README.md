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

```bash
curl -fsSL https://raw.githubusercontent.com/your-org/zenith/main/scripts/setup.sh | bash
```

The setup script will:
1. Clone Zenith to ~/.zenith
2. Prompt for your monorepo configuration
3. Create a gitignored .agent-config in your monorepo root
4. Symlink the /zenith command into your Claude Code commands
5. Install a daily cron job for automatic updates

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
