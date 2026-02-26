#!/usr/bin/env bash
set -euo pipefail

# Zenith Installation Script
# Runs once per person. Idempotent - running twice changes nothing.
# Per-repo configuration happens on first /zenith use inside each repo.

ZENITH_DIR="${ZENITH_DIR:-$HOME/.zenith}"
ZENITH_REPO="${ZENITH_REPO:-https://github.com/kpatel513/zenith.git}"
# When piped (curl | bash), stdin is the pipe — read prompts from the terminal instead.
# Tests override this to /dev/stdin to inject input via heredoc.
TTY="${TTY:-/dev/tty}"
# Tests override this to avoid touching real ~/.claude/commands
GLOBAL_COMMANDS_DIR="${GLOBAL_COMMANDS_DIR:-$HOME/.claude/commands}"

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

read -rp "GitHub username: " GITHUB_USERNAME <"$TTY"

echo

# Symlink zenith.md globally so /zenith works in any Claude Code session
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

# Write global config
GLOBAL_CONFIG="$ZENITH_DIR/.global-config"
echo "Writing global config..."
cat > "$GLOBAL_CONFIG" <<EOF
[user]
github_username = "$GITHUB_USERNAME"
EOF
echo "✓ Written to $GLOBAL_CONFIG"

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
echo "Location:    $ZENITH_DIR"
echo "Username:    $GITHUB_USERNAME"
echo "Command:     /zenith <anything>"
echo
echo "Open Claude Code from inside any repo and run /zenith to get started."
echo "Zenith will configure itself for that repo on first use."
echo
