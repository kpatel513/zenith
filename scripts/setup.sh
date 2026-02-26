#!/usr/bin/env bash
set -euo pipefail

# Zenith Installation Script
# Runs once per person. Idempotent - running twice changes nothing.

ZENITH_DIR="${ZENITH_DIR:-$HOME/.zenith}"
ZENITH_REPO="${ZENITH_REPO:-https://github.com/kpatel513/zenith.git}"
# When piped (curl | bash), stdin is the pipe — read prompts from the terminal instead.
# Tests override this to /dev/stdin to inject input via heredoc.
TTY="${TTY:-/dev/tty}"

echo "Zenith Setup"
echo "============"
echo

# Check if already installed (marker written at end of successful setup)
if [ -f "$ZENITH_DIR/.setup-complete" ]; then
    echo "Zenith already installed at $ZENITH_DIR"
    echo "To update, run: cd $ZENITH_DIR && git pull"
    exit 0
fi

# Partial install (directory exists but setup never completed) — clean up and retry
if [ -d "$ZENITH_DIR" ]; then
    echo "Found incomplete installation at $ZENITH_DIR — cleaning up and retrying..."
    rm -rf "$ZENITH_DIR"
fi

# Clone Zenith repository
echo "Cloning Zenith to $ZENITH_DIR..."
git clone "$ZENITH_REPO" "$ZENITH_DIR" 2>/dev/null || {
    echo "Error: Failed to clone Zenith repository"
    exit 1
}
echo "✓ Cloned successfully"
echo

# Collect configuration
echo "Configuration"
echo "-------------"
echo

read -rp "Repo absolute path: " MONOREPO_PATH <"$TTY"
MONOREPO_PATH="${MONOREPO_PATH/#\~/$HOME}"
if [ ! -d "$MONOREPO_PATH" ]; then
    echo "Error: Directory $MONOREPO_PATH does not exist"
    exit 1
fi

read -rp "Your project folder (or . for whole repo): " PROJECT_FOLDER <"$TTY"
read -rp "GitHub organization: " GITHUB_ORG <"$TTY"
read -rp "GitHub repository: " GITHUB_REPO <"$TTY"
read -rp "Base branch [main]: " BASE_BRANCH <"$TTY"
BASE_BRANCH="${BASE_BRANCH:-main}"
read -rp "GitHub username: " GITHUB_USERNAME <"$TTY"

echo

# Create .claude/commands directory if it doesn't exist
CLAUDE_COMMANDS_DIR="$MONOREPO_PATH/.claude/commands"
if [ ! -d "$CLAUDE_COMMANDS_DIR" ]; then
    echo "Creating $CLAUDE_COMMANDS_DIR..."
    mkdir -p "$CLAUDE_COMMANDS_DIR"
    echo "✓ Created"
fi

# Symlink zenith.md into the repo
SYMLINK_TARGET="$CLAUDE_COMMANDS_DIR/zenith.md"
if [ -L "$SYMLINK_TARGET" ] || [ -f "$SYMLINK_TARGET" ]; then
    echo "Removing existing zenith.md..."
    rm -f "$SYMLINK_TARGET"
fi
echo "Creating repo symlink to zenith.md..."
ln -s "$ZENITH_DIR/.claude/commands/zenith.md" "$SYMLINK_TARGET"
echo "✓ Symlinked (repo)"

# Symlink zenith.md globally so /zenith works in any Claude Code session
GLOBAL_COMMANDS_DIR="$HOME/.claude/commands"
if [ ! -d "$GLOBAL_COMMANDS_DIR" ]; then
    mkdir -p "$GLOBAL_COMMANDS_DIR"
fi
GLOBAL_SYMLINK="$GLOBAL_COMMANDS_DIR/zenith.md"
if [ -L "$GLOBAL_SYMLINK" ] || [ -f "$GLOBAL_SYMLINK" ]; then
    rm -f "$GLOBAL_SYMLINK"
fi
echo "Creating global symlink to zenith.md..."
ln -s "$ZENITH_DIR/.claude/commands/zenith.md" "$GLOBAL_SYMLINK"
echo "✓ Symlinked (global — /zenith works from any directory)"

# Write .agent-config
CONFIG_FILE="$MONOREPO_PATH/.agent-config"
echo "Writing .agent-config..."
cat > "$CONFIG_FILE" <<EOF
[repo]
github_org = "$GITHUB_ORG"
github_repo = "$GITHUB_REPO"
base_branch = "$BASE_BRANCH"

[user]
project_folder = "$PROJECT_FOLDER"
github_username = "$GITHUB_USERNAME"
EOF
echo "✓ Written to $CONFIG_FILE"

# Add .agent-config to .gitignore if not already present
GITIGNORE_FILE="$MONOREPO_PATH/.gitignore"
if [ -f "$GITIGNORE_FILE" ]; then
    if ! grep -q "^\.agent-config$" "$GITIGNORE_FILE"; then
        echo "Adding .agent-config to .gitignore..."
        echo ".agent-config" >> "$GITIGNORE_FILE"
        echo "✓ Added"
    else
        echo ".agent-config already in .gitignore"
    fi
else
    echo "Creating .gitignore with .agent-config..."
    echo ".agent-config" > "$GITIGNORE_FILE"
    echo "✓ Created"
fi

# Install cron job for automatic updates
echo "Installing automatic update cron job..."
CRON_CMD="0 9 * * * cd $ZENITH_DIR && git pull origin main --quiet"
(crontab -l 2>/dev/null | grep -v "zenith"; echo "$CRON_CMD") | crontab - 2>/dev/null || {
    echo "Warning: Could not install cron job. You can add it manually:"
    echo "$CRON_CMD"
}
echo "✓ Installed (runs daily at 9am)"

# Mark installation as complete (used to detect partial installs on re-run)
touch "$ZENITH_DIR/.setup-complete"

echo
echo "Installation Complete"
echo "====================="
echo
echo "Location:     $ZENITH_DIR"
echo "Repo:         $MONOREPO_PATH"
echo "Project:      $PROJECT_FOLDER"
echo "Base branch:  $BASE_BRANCH"
echo "Command:      /zenith <anything>"
echo
echo "Try: /zenith help"
echo
