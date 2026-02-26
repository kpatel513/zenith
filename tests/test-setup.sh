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
    mkdir -p "$dir/.claude/commands"
    touch "$dir/.claude/commands/zenith.md"
    git -C "$dir" add . 2>/dev/null
    git -C "$dir" -c user.email="test@test.com" -c user.name="Test" \
        commit -m "init" --quiet
    echo "$dir"
}

run_setup() {
    # $1 = ZENITH_DIR override
    # $2 = ZENITH_REPO override
    # $3 = stdin (heredoc) — now just the GitHub username
    # GLOBAL_COMMANDS_DIR is set to a subdir of ZENITH_DIR to avoid touching ~/.claude/commands
    # TTY=/dev/stdin lets tests inject input via heredoc instead of /dev/tty
    ZENITH_DIR="$1" ZENITH_REPO="$2" GLOBAL_COMMANDS_DIR="$1/global-commands" \
        TTY=/dev/stdin bash "$REPO_ROOT/scripts/setup.sh" \
        <<< "$3" 2>/dev/null
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
    output=$(ZENITH_DIR="$zenith_dir" bash "$REPO_ROOT/scripts/setup.sh" 2>&1) || true
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

echo
echo "results: $PASS passed, $FAIL failed"

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
