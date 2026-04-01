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
# Tests override this to avoid touching real ~/.cursor/rules
GLOBAL_CURSOR_RULES_DIR="${GLOBAL_CURSOR_RULES_DIR:-$HOME/.cursor/rules}"
# Tests override this to avoid touching real ~/.codex/skills
GLOBAL_CODEX_SKILLS_DIR="${GLOBAL_CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
# Tests override this to avoid touching real ~/.gemini/commands
GLOBAL_GEMINI_COMMANDS_DIR="${GLOBAL_GEMINI_COMMANDS_DIR:-$HOME/.gemini/commands}"

echo "Zenith Setup"
echo "============"
echo

# Check if already installed (marker written at end of successful setup)
if [ -f "$ZENITH_DIR/.setup-complete" ]; then
    # Repair symlink if broken or pointing to old path (handles repo restructuring migrations)
    GLOBAL_SYMLINK="$GLOBAL_COMMANDS_DIR/zenith.md"
    CORRECT_TARGET="$ZENITH_DIR/adapters/claude-command.md"
    if [ ! -L "$GLOBAL_SYMLINK" ] || [ "$(readlink "$GLOBAL_SYMLINK" 2>/dev/null)" != "$CORRECT_TARGET" ]; then
        mkdir -p "$GLOBAL_COMMANDS_DIR"
        ln -sf "$CORRECT_TARGET" "$GLOBAL_SYMLINK"
        echo "✓ Repaired /zenith symlink"
    fi
    # Migrate cron job from git pull to fetch+reset (git pull fails silently on untracked files)
    UPDATED_CRON="0 9 * * * cd $ZENITH_DIR && git fetch origin main --quiet && git reset --hard origin/main --quiet && bash $ZENITH_DIR/scripts/setup.sh 2>/dev/null"
    if crontab -l 2>/dev/null | grep -q "zenith.*git pull"; then
        (crontab -l 2>/dev/null | grep -v "zenith"; echo "$UPDATED_CRON") | crontab - 2>/dev/null && \
            echo "✓ Migrated cron job to robust update command" || true
    fi
    # Auto-install Codex skill if Codex is installed but Zenith skill is missing or stale
    if [ -d "$HOME/.codex" ]; then
        CODEX_SKILL_TARGET="$GLOBAL_CODEX_SKILLS_DIR/zenith"
        CODEX_SKILL_SOURCE="$ZENITH_DIR/adapters/codex-skill"
        if [ ! -L "$CODEX_SKILL_TARGET" ] || [ "$(readlink "$CODEX_SKILL_TARGET" 2>/dev/null)" != "$CODEX_SKILL_SOURCE" ]; then
            mkdir -p "$GLOBAL_CODEX_SKILLS_DIR"
            ln -sf "$CODEX_SKILL_SOURCE" "$CODEX_SKILL_TARGET"
            echo "✓ Added Codex skill ($CODEX_SKILL_TARGET)"
        fi
    fi
    # Auto-install Gemini command if Gemini CLI is installed but Zenith command is missing or stale
    if [ -d "$HOME/.gemini" ]; then
        GEMINI_CMD_TARGET="$GLOBAL_GEMINI_COMMANDS_DIR/zenith.toml"
        GEMINI_CMD_SOURCE="$ZENITH_DIR/adapters/gemini-command.toml"
        if [ ! -L "$GEMINI_CMD_TARGET" ] || [ "$(readlink "$GEMINI_CMD_TARGET" 2>/dev/null)" != "$GEMINI_CMD_SOURCE" ]; then
            mkdir -p "$GLOBAL_GEMINI_COMMANDS_DIR"
            ln -sf "$GEMINI_CMD_SOURCE" "$GEMINI_CMD_TARGET"
            echo "✓ Added Gemini command ($GEMINI_CMD_TARGET)"
        fi
    fi
    echo "Zenith already installed at $ZENITH_DIR"
    echo "To update, run: cd $ZENITH_DIR && git fetch origin main --quiet && git reset --hard origin/main --quiet"
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

# Auto-detect GitHub username from gh CLI; ask only if that fails.
# ZENITH_GITHUB_USERNAME overrides detection (used by tests and scripted installs).
if [ -n "${ZENITH_GITHUB_USERNAME:-}" ]; then
    GITHUB_USERNAME="$ZENITH_GITHUB_USERNAME"
else
    GITHUB_USERNAME=$(gh api user --jq '.login' 2>/dev/null)
    if [ -z "$GITHUB_USERNAME" ]; then
        read -rp "GitHub username: " GITHUB_USERNAME <"$TTY"
    fi
fi

# Auto-detect installed tools — install adapters silently if the tool is present.
# *_HOME vars are overridable for tests to avoid touching real system directories.
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/.gemini}"
[ -d "$CURSOR_HOME" ] && INSTALL_CURSOR=y || INSTALL_CURSOR=n
[ -d "$CODEX_HOME" ]  && INSTALL_CODEX=y  || INSTALL_CODEX=n
[ -d "$GEMINI_HOME" ] && INSTALL_GEMINI=y || INSTALL_GEMINI=n

# Symlink zenith.md globally so /zenith works in any Claude Code session
mkdir -p "$GLOBAL_COMMANDS_DIR"
GLOBAL_SYMLINK="$GLOBAL_COMMANDS_DIR/zenith.md"
if [ -L "$GLOBAL_SYMLINK" ] || [ -f "$GLOBAL_SYMLINK" ]; then
    rm -f "$GLOBAL_SYMLINK"
fi
ln -s "$ZENITH_DIR/adapters/claude-command.md" "$GLOBAL_SYMLINK"

# Install Cursor rule if Cursor is installed
if [[ "${INSTALL_CURSOR:-n}" =~ ^[Yy]$ ]]; then
    CURSOR_RULE_TARGET="$GLOBAL_CURSOR_RULES_DIR/zenith.mdc"
    CURSOR_RULE_SOURCE="$ZENITH_DIR/.cursor/rules/zenith.mdc"
    mkdir -p "$GLOBAL_CURSOR_RULES_DIR"
    if [ ! -L "$CURSOR_RULE_TARGET" ] && [ ! -f "$CURSOR_RULE_TARGET" ]; then
        ln -s "$CURSOR_RULE_SOURCE" "$CURSOR_RULE_TARGET"
    fi
fi

# Install Codex skill if Codex CLI is installed
if [[ "${INSTALL_CODEX:-n}" =~ ^[Yy]$ ]]; then
    CODEX_SKILL_TARGET="$GLOBAL_CODEX_SKILLS_DIR/zenith"
    CODEX_SKILL_SOURCE="$ZENITH_DIR/adapters/codex-skill"
    mkdir -p "$GLOBAL_CODEX_SKILLS_DIR"
    if [ ! -L "$CODEX_SKILL_TARGET" ] && [ ! -e "$CODEX_SKILL_TARGET" ]; then
        ln -s "$CODEX_SKILL_SOURCE" "$CODEX_SKILL_TARGET"
    fi
fi

# Install Gemini command if Gemini CLI is installed
if [[ "${INSTALL_GEMINI:-n}" =~ ^[Yy]$ ]]; then
    GEMINI_CMD_TARGET="$GLOBAL_GEMINI_COMMANDS_DIR/zenith.toml"
    GEMINI_CMD_SOURCE="$ZENITH_DIR/adapters/gemini-command.toml"
    mkdir -p "$GLOBAL_GEMINI_COMMANDS_DIR"
    if [ ! -L "$GEMINI_CMD_TARGET" ] && [ ! -f "$GEMINI_CMD_TARGET" ]; then
        ln -s "$GEMINI_CMD_SOURCE" "$GEMINI_CMD_TARGET"
    fi
fi

# Write global config
GLOBAL_CONFIG="$ZENITH_DIR/.global-config"
cat > "$GLOBAL_CONFIG" <<EOF
[user]
github_username = "$GITHUB_USERNAME"
EOF

# Install cron job for automatic updates
CRON_CMD="0 9 * * * cd $ZENITH_DIR && git fetch origin main --quiet && git reset --hard origin/main --quiet && bash $ZENITH_DIR/scripts/setup.sh 2>/dev/null"
(crontab -l 2>/dev/null | grep -v "zenith"; echo "$CRON_CMD") | crontab - 2>/dev/null || true

# Mark installation as complete (used to detect partial installs on re-run)
touch "$ZENITH_DIR/.setup-complete"

echo
echo "✓ installed   $ZENITH_DIR"
echo "✓ command     /zenith  (Claude Code)"
if [[ "${INSTALL_CURSOR:-n}" =~ ^[Yy]$ ]]; then
    echo "✓ command     @zenith  (Cursor)"
fi
if [[ "${INSTALL_CODEX:-n}" =~ ^[Yy]$ ]]; then
    echo "✓ command     \$zenith  (Codex CLI)"
fi
if [[ "${INSTALL_GEMINI:-n}" =~ ^[Yy]$ ]]; then
    echo "✓ command     /zenith  (Gemini CLI)"
fi
echo "✓ updates     daily at 9am"
echo
echo "Open Claude Code in any repo and run /zenith to get started."
echo
