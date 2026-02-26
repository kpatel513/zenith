#!/usr/bin/env bash
# Tests for scripts/uninstall.sh
# Usage: bash tests/test-uninstall.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
ERRORS=()

pass() { echo "  pass  $1"; ((PASS++)) || true; }
fail() { echo "  FAIL  $1"; ((FAIL++)) || true; ERRORS+=("$1"); }

assert_exists()     { [ -e "$1" ] && pass "$2" || fail "$2"; }
assert_not_exists() { [ ! -e "$1" ] && pass "$2" || fail "$2"; }
assert_exit_zero()  { [ "$1" -eq 0 ] && pass "$2" || fail "$2 (exit $1)"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

run_uninstall() {
    # $1 = ZENITH_DIR override
    # $2 = GLOBAL_COMMANDS_DIR override
    ZENITH_DIR="$1" GLOBAL_COMMANDS_DIR="$2" \
        bash "$REPO_ROOT/scripts/uninstall.sh" 2>/dev/null
}

make_fake_install() {
    # $1 = ZENITH_DIR   $2 = GLOBAL_COMMANDS_DIR
    # Creates a minimal installed state without actually cloning
    local zenith_dir="$1" global_dir="$2"
    mkdir -p "$zenith_dir"
    mkdir -p "$global_dir"
    touch "$zenith_dir/.setup-complete"
    ln -s "$zenith_dir/zenith.md" "$global_dir/zenith.md"
}

# ---------------------------------------------------------------------------
# Test: fresh uninstall — removes symlink and directory
# ---------------------------------------------------------------------------

test_fresh_uninstall() {
    echo
    echo "test: fresh uninstall"

    local zenith_dir global_dir
    zenith_dir=$(mktemp -d)
    global_dir=$(mktemp -d)

    make_fake_install "$zenith_dir" "$global_dir"

    local exit_code=0
    run_uninstall "$zenith_dir" "$global_dir" || exit_code=$?

    assert_exit_zero    "$exit_code"                         "exits 0"
    assert_not_exists   "$global_dir/zenith.md"              "global symlink removed"
    assert_not_exists   "$zenith_dir"                        "zenith directory removed"

    rm -rf "$global_dir"
}

# ---------------------------------------------------------------------------
# Test: idempotent — second run exits 0 cleanly
# ---------------------------------------------------------------------------

test_idempotent() {
    echo
    echo "test: idempotent (second run)"

    local zenith_dir global_dir
    zenith_dir=$(mktemp -d)
    global_dir=$(mktemp -d)

    make_fake_install "$zenith_dir" "$global_dir"

    run_uninstall "$zenith_dir" "$global_dir" || true  # first run
    local exit_code=0
    run_uninstall "$zenith_dir" "$global_dir" || exit_code=$?  # second run

    assert_exit_zero "$exit_code" "second run exits 0"

    rm -rf "$global_dir"
}

# ---------------------------------------------------------------------------
# Test: partial state — only symlink exists (directory already gone)
# ---------------------------------------------------------------------------

test_partial_symlink_only() {
    echo
    echo "test: partial state — symlink only"

    local zenith_dir global_dir
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"  # directory does not exist
    global_dir=$(mktemp -d)
    mkdir -p "$global_dir"
    touch "$global_dir/zenith.md"  # symlink/file exists

    local exit_code=0
    run_uninstall "$zenith_dir" "$global_dir" || exit_code=$?

    assert_exit_zero  "$exit_code"            "exits 0 with partial state"
    assert_not_exists "$global_dir/zenith.md" "symlink removed"

    rm -rf "$global_dir"
}

# ---------------------------------------------------------------------------
# Test: partial state — only directory exists (symlink already gone)
# ---------------------------------------------------------------------------

test_partial_dir_only() {
    echo
    echo "test: partial state — directory only"

    local zenith_dir global_dir
    zenith_dir=$(mktemp -d)
    global_dir=$(mktemp -d)
    touch "$zenith_dir/.setup-complete"
    # no symlink in global_dir

    local exit_code=0
    run_uninstall "$zenith_dir" "$global_dir" || exit_code=$?

    assert_exit_zero  "$exit_code"  "exits 0 with partial state"
    assert_not_exists "$zenith_dir" "zenith directory removed"

    rm -rf "$global_dir"
}

# ---------------------------------------------------------------------------
# Test: .agent-config files in repos are NOT removed
# ---------------------------------------------------------------------------

test_agent_config_untouched() {
    echo
    echo "test: .agent-config not removed"

    local zenith_dir global_dir repo_dir
    zenith_dir=$(mktemp -d)
    global_dir=$(mktemp -d)
    repo_dir=$(mktemp -d)

    make_fake_install "$zenith_dir" "$global_dir"
    echo 'github_org = "acme"' > "$repo_dir/.agent-config"

    run_uninstall "$zenith_dir" "$global_dir" || true

    assert_exists "$repo_dir/.agent-config" ".agent-config left untouched in repo"

    rm -rf "$global_dir" "$repo_dir"
}

# ---------------------------------------------------------------------------
# Test: nothing installed — exits cleanly (nothing to remove)
# ---------------------------------------------------------------------------

test_nothing_installed() {
    echo
    echo "test: nothing installed"

    local zenith_dir global_dir
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    global_dir=$(mktemp -d)

    local exit_code=0
    run_uninstall "$zenith_dir" "$global_dir" || exit_code=$?

    assert_exit_zero "$exit_code" "exits 0 when nothing to remove"

    rm -rf "$global_dir"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "uninstall.sh tests"
echo "=================="

test_fresh_uninstall
test_idempotent
test_partial_symlink_only
test_partial_dir_only
test_agent_config_untouched
test_nothing_installed

echo
echo "results: $PASS passed, $FAIL failed"

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
