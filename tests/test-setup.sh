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
    # $3 = stdin (heredoc)
    # TTY=/dev/stdin lets tests inject input via heredoc instead of /dev/tty
    ZENITH_DIR="$1" ZENITH_REPO="$2" TTY=/dev/stdin bash "$REPO_ROOT/scripts/setup.sh" \
        <<< "$3" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Test: fresh install
# ---------------------------------------------------------------------------

test_fresh_install() {
    echo
    echo "test: fresh install"

    local source_repo zenith_dir monorepo
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    monorepo=$(mktemp -d); git init "$monorepo" --quiet

    local input
    input="$monorepo
my-project
my-org
my-repo
main
myuser"

    run_setup "$zenith_dir" "$source_repo" "$input"

    assert_dir     "$zenith_dir"                                  "cloned zenith to ZENITH_DIR"
    assert_symlink "$monorepo/.claude/commands/zenith.md"         "created zenith.md symlink"
    assert_file    "$monorepo/.agent-config"                      "wrote .agent-config"
    assert_contains "my-org"     "$monorepo/.agent-config"        ".agent-config: github_org"
    assert_contains "my-repo"    "$monorepo/.agent-config"        ".agent-config: github_repo"
    assert_contains "my-project" "$monorepo/.agent-config"        ".agent-config: project_folder"
    assert_contains "myuser"     "$monorepo/.agent-config"        ".agent-config: github_username"
    assert_contains "main"       "$monorepo/.agent-config"        ".agent-config: base_branch"
    assert_contains ".agent-config" "$monorepo/.gitignore"        ".agent-config added to .gitignore"

    rm -rf "$source_repo" "$zenith_dir" "$monorepo"
}

# ---------------------------------------------------------------------------
# Test: idempotency — second run exits cleanly with "already installed"
# ---------------------------------------------------------------------------

test_idempotent() {
    echo
    echo "test: idempotent (second run)"

    local zenith_dir
    zenith_dir=$(mktemp -d)  # pre-exists → simulates already installed

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
# Test: .agent-config entry not duplicated on reinstall
# ---------------------------------------------------------------------------

test_gitignore_no_duplicates() {
    echo
    echo "test: .gitignore — no duplicate .agent-config entry"

    local source_repo zenith_dir monorepo
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    monorepo=$(mktemp -d); git init "$monorepo" --quiet
    echo ".agent-config" > "$monorepo/.gitignore"  # already present

    local input
    input="$monorepo
my-project
my-org
my-repo
main
myuser"

    run_setup "$zenith_dir" "$source_repo" "$input"

    local count
    count=$(grep -c "^\.agent-config$" "$monorepo/.gitignore" || true)
    [ "$count" -eq 1 ] \
        && pass ".agent-config appears exactly once in .gitignore" \
        || fail ".agent-config appears exactly once in .gitignore (found $count)"

    rm -rf "$source_repo" "$zenith_dir" "$monorepo"
}

# ---------------------------------------------------------------------------
# Test: existing .gitignore content is preserved
# ---------------------------------------------------------------------------

test_existing_gitignore_preserved() {
    echo
    echo "test: existing .gitignore content preserved"

    local source_repo zenith_dir monorepo
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    monorepo=$(mktemp -d); git init "$monorepo" --quiet
    printf "*.pyc\n__pycache__/\n" > "$monorepo/.gitignore"

    local input
    input="$monorepo
my-project
my-org
my-repo
main
myuser"

    run_setup "$zenith_dir" "$source_repo" "$input"

    assert_contains "*.pyc"        "$monorepo/.gitignore" "existing *.pyc entry preserved"
    assert_contains "__pycache__/" "$monorepo/.gitignore" "existing __pycache__/ entry preserved"
    assert_contains ".agent-config" "$monorepo/.gitignore" ".agent-config appended"

    rm -rf "$source_repo" "$zenith_dir" "$monorepo"
}

# ---------------------------------------------------------------------------
# Test: invalid monorepo path exits non-zero
# ---------------------------------------------------------------------------

test_invalid_monorepo_path() {
    echo
    echo "test: invalid monorepo path"

    local zenith_dir
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    local exit_code
    ZENITH_DIR="$zenith_dir" ZENITH_REPO="/dev/null" \
        bash "$REPO_ROOT/scripts/setup.sh" \
        <<< "/nonexistent/path/that/does/not/exist" \
        >/dev/null 2>&1 || exit_code=$?
    exit_code="${exit_code:-0}"

    assert_exit_nonzero "$exit_code" "exits non-zero for invalid monorepo path"

    rm -rf "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: symlink points to correct target
# ---------------------------------------------------------------------------

test_symlink_target() {
    echo
    echo "test: symlink points to ZENITH_DIR"

    local source_repo zenith_dir monorepo
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    monorepo=$(mktemp -d); git init "$monorepo" --quiet

    local input
    input="$monorepo
my-project
my-org
my-repo
main
myuser"

    run_setup "$zenith_dir" "$source_repo" "$input"

    local link target
    link="$monorepo/.claude/commands/zenith.md"
    target=$(readlink "$link" 2>/dev/null || echo "")
    echo "$target" | grep -q "$zenith_dir" \
        && pass "symlink target contains ZENITH_DIR path" \
        || fail "symlink target contains ZENITH_DIR path (got: $target)"

    rm -rf "$source_repo" "$zenith_dir" "$monorepo"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "setup.sh tests"
echo "=============="

test_fresh_install
test_idempotent
test_gitignore_no_duplicates
test_existing_gitignore_preserved
test_invalid_monorepo_path
test_symlink_target

echo
echo "results: $PASS passed, $FAIL failed"

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
