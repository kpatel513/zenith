#!/usr/bin/env bash
set -euo pipefail

# Zenith Uninstall Script
# Removes the global symlink, cron job, and installation directory.
# Idempotent - safe to run multiple times.
# Per-repo .agent-config files are NOT removed (they are local to each repo).

ZENITH_DIR="${ZENITH_DIR:-$HOME/.zenith}"
# Tests override this to avoid touching real ~/.claude/commands
GLOBAL_COMMANDS_DIR="${GLOBAL_COMMANDS_DIR:-$HOME/.claude/commands}"

echo "Zenith Uninstall"
echo "================"
echo

# Remove global symlink
GLOBAL_SYMLINK="$GLOBAL_COMMANDS_DIR/zenith.md"
if [ -L "$GLOBAL_SYMLINK" ] || [ -f "$GLOBAL_SYMLINK" ]; then
    echo "Removing global symlink..."
    rm -f "$GLOBAL_SYMLINK"
    echo "✓ Removed $GLOBAL_SYMLINK"
else
    echo "Global symlink not found — skipping"
fi

# Remove cron job
if crontab -l 2>/dev/null | grep -q "zenith"; then
    echo "Removing cron job..."
    crontab -l 2>/dev/null | grep -v "zenith" | crontab -
    echo "✓ Removed cron job"
else
    echo "Cron job not found — skipping"
fi

# Remove installation directory
if [ -d "$ZENITH_DIR" ]; then
    echo "Removing $ZENITH_DIR..."
    rm -rf "$ZENITH_DIR"
    echo "✓ Removed $ZENITH_DIR"
else
    echo "Zenith directory not found — skipping"
fi

echo
echo "Uninstall Complete"
echo "=================="
echo
echo "Note: .agent-config files in your repos were not removed."
echo "To clean up a repo: rm /path/to/repo/.agent-config"
echo
