#!/usr/bin/env bash
# Tests for scripts/setup.sh
# Usage: bash tests/test-setup.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
ERRORS=()

pass() { echo "  pass  $1"; ((PASS++)) || true; }
fail() { echo "  FAIL  $1"; ((FAIL++)) || true; ERRORS+=("$1"); }

assert_dir()         { [ -d "$1" ]  && pass "$2" || fail "$2"; }
assert_file()        { [ -f "$1" ]  && pass "$2" || fail "$2"; }
assert_symlink()     { [ -L "$1" ]  && pass "$2" || fail "$2"; }
assert_contains()    { grep -q "$1" "$2"  && pass "$3" || fail "$3"; }
assert_not_contains(){ ! grep -q "$1" "$2" && pass "$3" || fail "$3"; }
assert_exit_zero()   { [ "$1" -eq 0 ] && pass "$2" || fail "$2 (exit $1)"; }
assert_exit_nonzero(){ [ "$1" -ne 0 ] && pass "$2" || fail "$2 (expected failure, got $1)"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_source_repo() {
    # Create a minimal local git repo that setup.sh can clone from
    local dir
    dir=$(mktemp -d)
    git init "$dir" --quiet
    mkdir -p "$dir/adapters"
    touch "$dir/adapters/claude-command.md"
    mkdir -p "$dir/adapters/codex-skill"
    touch "$dir/adapters/codex-skill/SKILL.md"
    touch "$dir/adapters/gemini-command.toml"
    mkdir -p "$dir/.cursor/rules"
    touch "$dir/.cursor/rules/zenith.mdc"
    mkdir -p "$dir/scripts"
    touch "$dir/scripts/setup.sh"
    git -C "$dir" add . 2>/dev/null
    git -C "$dir" -c user.email="test@test.com" -c user.name="Test" \
        commit -m "init" --quiet
    echo "$dir"
}

run_setup() {
    # $1 = ZENITH_DIR override
    # $2 = ZENITH_REPO override
    # $3 = GitHub username
    # $4 = cursor install answer (y/n, default n)
    # $5 = codex install answer (y/n, default n)
    # $6 = gemini install answer (y/n, default n)
    # GLOBAL_*_DIR vars point to subdirs of ZENITH_DIR to avoid touching real system dirs
    # TTY=/dev/stdin lets tests inject input via heredoc instead of /dev/tty
    local cursor_ans="${4:-n}"
    local codex_ans="${5:-n}"
    local gemini_ans="${6:-n}"
    ZENITH_DIR="$1" ZENITH_REPO="$2" GLOBAL_COMMANDS_DIR="$1/global-commands" \
        GLOBAL_CURSOR_RULES_DIR="$1/cursor-rules" \
        GLOBAL_CODEX_SKILLS_DIR="$1/codex-skills" \
        GLOBAL_GEMINI_COMMANDS_DIR="$1/gemini-commands" \
        TTY=/dev/stdin bash "$REPO_ROOT/scripts/setup.sh" \
        <<< "$(printf '%s\n%s\n%s\n%s\n' "$3" "$cursor_ans" "$codex_ans" "$gemini_ans")" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Test: fresh install
# ---------------------------------------------------------------------------

test_fresh_install() {
    echo
    echo "test: fresh install"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    run_setup "$zenith_dir" "$source_repo" "myuser"

    assert_dir     "$zenith_dir"                                "cloned zenith to ZENITH_DIR"
    assert_symlink "$zenith_dir/global-commands/zenith.md"      "created global zenith.md symlink"
    assert_file    "$zenith_dir/.global-config"                 "wrote .global-config"
    assert_contains "myuser" "$zenith_dir/.global-config"       ".global-config: github_username"
    assert_file    "$zenith_dir/.setup-complete"                "wrote .setup-complete marker"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: idempotency — second run exits cleanly with "already installed"
# ---------------------------------------------------------------------------

test_idempotent() {
    echo
    echo "test: idempotent (second run)"

    local zenith_dir
    zenith_dir=$(mktemp -d)
    touch "$zenith_dir/.setup-complete"  # marker → simulates already installed

    local output exit_code
    output=$(ZENITH_DIR="$zenith_dir" GLOBAL_COMMANDS_DIR="$zenith_dir/global-commands" \
        bash "$REPO_ROOT/scripts/setup.sh" 2>&1) || true
    exit_code=$?

    assert_exit_zero   "$exit_code"                              "exits 0 when already installed"
    echo "$output" | grep -q "already installed" \
        && pass "prints already-installed message" \
        || fail "prints already-installed message"

    rm -rf "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: partial install (dir exists, no marker) — cleans up and completes
# ---------------------------------------------------------------------------

test_partial_install_recovery() {
    echo
    echo "test: partial install recovery"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    # Simulate a partial install: directory exists but no .setup-complete marker
    mkdir -p "$zenith_dir"

    run_setup "$zenith_dir" "$source_repo" "myuser"

    assert_file    "$zenith_dir/.global-config"     "recovered: wrote .global-config"
    assert_file    "$zenith_dir/.setup-complete"    "recovered: wrote .setup-complete marker"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: .global-config contains correct username
# ---------------------------------------------------------------------------

test_global_config_username() {
    echo
    echo "test: global config stores username correctly"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    run_setup "$zenith_dir" "$source_repo" "bob-the-dev"

    assert_contains "bob-the-dev" "$zenith_dir/.global-config" "username written to .global-config"
    assert_not_contains "github_org"  "$zenith_dir/.global-config" "no github_org in .global-config (repo-specific)"
    assert_not_contains "base_branch" "$zenith_dir/.global-config" "no base_branch in .global-config (repo-specific)"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: no .agent-config or .gitignore written (repo config is zenith's job)
# ---------------------------------------------------------------------------

test_no_repo_files_written() {
    echo
    echo "test: setup does not write repo-level files"

    local source_repo zenith_dir check_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    check_dir=$(mktemp -d)  # a plain dir to check — setup shouldn't touch it

    run_setup "$zenith_dir" "$source_repo" "myuser"

    [ ! -f "$check_dir/.agent-config" ] \
        && pass "no .agent-config written outside repo" \
        || fail "no .agent-config written outside repo"

    rm -rf "$source_repo" "$zenith_dir" "$check_dir"
}

# ---------------------------------------------------------------------------
# Test: symlink points to correct target
# ---------------------------------------------------------------------------

test_symlink_target() {
    echo
    echo "test: global symlink points to ZENITH_DIR"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    run_setup "$zenith_dir" "$source_repo" "myuser"

    local link target
    link="$zenith_dir/global-commands/zenith.md"
    target=$(readlink "$link" 2>/dev/null || echo "")
    echo "$target" | grep -q "$zenith_dir" \
        && pass "symlink target contains ZENITH_DIR path" \
        || fail "symlink target contains ZENITH_DIR path (got: $target)"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: cursor opt-in creates symlink; opt-out skips it
# ---------------------------------------------------------------------------

test_cursor_install() {
    echo
    echo "test: cursor opt-in creates symlink; opt-out skips"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    # opt-in: symlink should be created
    run_setup "$zenith_dir" "$source_repo" "myuser" "y"
    assert_symlink "$zenith_dir/cursor-rules/zenith.mdc" "cursor rule symlink created on opt-in"
    rm -rf "$zenith_dir"

    # opt-out: symlink should not be created
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    run_setup "$zenith_dir" "$source_repo" "myuser" "n"
    [ ! -e "$zenith_dir/cursor-rules/zenith.mdc" ] \
        && pass "no cursor rule symlink on opt-out" \
        || fail "no cursor rule symlink on opt-out"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: broken symlink is repaired on re-run (migration for pre-adapters/ installs)
# ---------------------------------------------------------------------------

test_symlink_repair() {
    echo
    echo "test: broken symlink repaired on re-run"

    local source_repo zenith_dir commands_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    commands_dir=$(mktemp -d)

    # Fresh install
    run_setup "$zenith_dir" "$source_repo" "myuser"

    # Simulate broken symlink from pre-adapters/ install: replace with a stale target
    STALE_TARGET="$zenith_dir/.claude/commands/zenith.md"
    ln -sf "$STALE_TARGET" "$zenith_dir/global-commands/zenith.md"

    # Re-run setup — should repair the symlink without prompting
    ZENITH_DIR="$zenith_dir" GLOBAL_COMMANDS_DIR="$zenith_dir/global-commands" \
        GLOBAL_CODEX_SKILLS_DIR="$zenith_dir/codex-skills" \
        GLOBAL_GEMINI_COMMANDS_DIR="$zenith_dir/gemini-commands" \
        bash "$REPO_ROOT/scripts/setup.sh" 2>/dev/null || true

    local target
    target=$(readlink "$zenith_dir/global-commands/zenith.md" 2>/dev/null || echo "")
    echo "$target" | grep -q "adapters/claude-command.md" \
        && pass "stale symlink repaired to adapters/claude-command.md" \
        || fail "stale symlink repaired to adapters/claude-command.md (got: $target)"

    rm -rf "$source_repo" "$zenith_dir" "$commands_dir"
}

# ---------------------------------------------------------------------------
# Test: codex opt-in creates symlink; opt-out skips it
# ---------------------------------------------------------------------------

test_codex_install() {
    echo
    echo "test: codex opt-in creates symlink; opt-out skips"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    # opt-in: symlink should be created
    run_setup "$zenith_dir" "$source_repo" "myuser" "n" "y"
    assert_symlink "$zenith_dir/codex-skills/zenith" "codex skill symlink created on opt-in"
    rm -rf "$zenith_dir"

    # opt-out: symlink should not be created
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    run_setup "$zenith_dir" "$source_repo" "myuser" "n" "n"
    [ ! -e "$zenith_dir/codex-skills/zenith" ] \
        && pass "no codex skill symlink on opt-out" \
        || fail "no codex skill symlink on opt-out"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: gemini opt-in creates symlink; opt-out skips it
# ---------------------------------------------------------------------------

test_gemini_install() {
    echo
    echo "test: gemini opt-in creates symlink; opt-out skips"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    # opt-in: symlink should be created
    run_setup "$zenith_dir" "$source_repo" "myuser" "n" "n" "y"
    assert_symlink "$zenith_dir/gemini-commands/zenith.toml" "gemini command symlink created on opt-in"
    rm -rf "$zenith_dir"

    # opt-out: symlink should not be created
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    run_setup "$zenith_dir" "$source_repo" "myuser" "n" "n" "n"
    [ ! -e "$zenith_dir/gemini-commands/zenith.toml" ] \
        && pass "no gemini command symlink on opt-out" \
        || fail "no gemini command symlink on opt-out"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: cron command uses fetch+reset, not git pull (robust against untracked files)
# ---------------------------------------------------------------------------

test_cron_uses_fetch_reset() {
    echo
    echo "test: cron command uses git fetch+reset not git pull"

    grep -q "CRON_CMD=.*git fetch origin main" "$REPO_ROOT/scripts/setup.sh" \
        && pass "cron command uses git fetch" \
        || fail "cron command uses git fetch"
    grep -q "CRON_CMD=.*git reset --hard origin/main" "$REPO_ROOT/scripts/setup.sh" \
        && pass "cron command uses git reset --hard" \
        || fail "cron command uses git reset --hard"
    ! grep -q "CRON_CMD=.*git pull" "$REPO_ROOT/scripts/setup.sh" \
        && pass "cron command does not use git pull" \
        || fail "cron command does not use git pull"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "setup.sh tests"
echo "=============="

test_fresh_install
test_idempotent
test_partial_install_recovery
test_global_config_username
test_no_repo_files_written
test_symlink_target
test_cursor_install
test_codex_install
test_gemini_install
test_symlink_repair
test_cron_uses_fetch_reset

echo
echo "results: $PASS passed, $FAIL failed"

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
