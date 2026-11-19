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
    # $3 = GitHub username (passed via ZENITH_GITHUB_USERNAME, bypasses gh detection)
    # $4 = CURSOR_HOME dir (create it to simulate Cursor installed; omit or /nonexistent to skip)
    # $5 = CODEX_HOME dir
    # $6 = GEMINI_HOME dir
    # GLOBAL_*_DIR vars point to subdirs of ZENITH_DIR to avoid touching real system dirs
    ZENITH_GITHUB_USERNAME="$3" \
        ZENITH_DIR="$1" ZENITH_REPO="$2" \
        CURSOR_HOME="${4:-/nonexistent/cursor}" \
        CODEX_HOME="${5:-/nonexistent/codex}" \
        GEMINI_HOME="${6:-/nonexistent/gemini}" \
        GLOBAL_COMMANDS_DIR="$1/global-commands" \
        GLOBAL_CURSOR_RULES_DIR="$1/cursor-rules" \
        GLOBAL_CODEX_SKILLS_DIR="$1/codex-skills" \
        GLOBAL_GEMINI_COMMANDS_DIR="$1/gemini-commands" \
        TTY=/dev/stdin bash "$REPO_ROOT/scripts/setup.sh" < /dev/null 2>/dev/null
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
    echo "test: cursor symlink created when cursor installed; skipped when not"

    local source_repo zenith_dir fake_cursor
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    # cursor installed: symlink should be created
    fake_cursor=$(mktemp -d)
    run_setup "$zenith_dir" "$source_repo" "myuser" "$fake_cursor"
    assert_symlink "$zenith_dir/cursor-rules/zenith.mdc" "cursor rule symlink created when cursor installed"
    rm -rf "$zenith_dir" "$fake_cursor"

    # cursor not installed: symlink should not be created
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    run_setup "$zenith_dir" "$source_repo" "myuser"
    [ ! -e "$zenith_dir/cursor-rules/zenith.mdc" ] \
        && pass "no cursor rule symlink when cursor not installed" \
        || fail "no cursor rule symlink when cursor not installed"

    rm -rf "$source_repo" "$zenith_dir"
}

test_codex_symlink_repair() {
    echo
    echo "test: codex symlink repaired when stale target exists"

    local source_repo zenith_dir fake_home fake_codex stale_target actual_target
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    fake_home=$(mktemp -d)
    fake_codex="$fake_home/.codex"
    mkdir -p "$fake_codex"
    mkdir -p "$zenith_dir/codex-skills"
    printf "stale-codex" > "$zenith_dir/codex-skills/zenith"

    HOME="$fake_home" run_setup "$zenith_dir" "$source_repo" "myuser" "" "$fake_codex"
    assert_symlink "$zenith_dir/codex-skills/zenith" "codex skill symlink repaired when stale target exists"
    actual_target=$(readlink "$zenith_dir/codex-skills/zenith" 2>/dev/null || echo "")
    echo "$actual_target" | grep -q "adapters/codex-skill" \
        && pass "codex symlink points to adapters/codex-skill" \
        || fail "codex symlink points to adapters/codex-skill (got: $actual_target)"

    rm -rf "$source_repo" "$zenith_dir" "$fake_home"
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
    echo "test: codex symlink created when codex installed; skipped when not"

    local source_repo zenith_dir fake_codex
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    # codex installed: symlink should be created
    fake_codex=$(mktemp -d)
    run_setup "$zenith_dir" "$source_repo" "myuser" "" "$fake_codex"
    assert_symlink "$zenith_dir/codex-skills/zenith" "codex skill symlink created when codex installed"
    rm -rf "$zenith_dir" "$fake_codex"

    # codex not installed: symlink should not be created
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    run_setup "$zenith_dir" "$source_repo" "myuser"
    [ ! -e "$zenith_dir/codex-skills/zenith" ] \
        && pass "no codex skill symlink when codex not installed" \
        || fail "no codex skill symlink when codex not installed"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Test: gemini opt-in creates symlink; opt-out skips it
# ---------------------------------------------------------------------------

test_gemini_install() {
    echo
    echo "test: gemini symlink created when gemini installed; skipped when not"

    local source_repo zenith_dir fake_gemini
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    # gemini installed: symlink should be created
    fake_gemini=$(mktemp -d)
    run_setup "$zenith_dir" "$source_repo" "myuser" "" "" "$fake_gemini"
    assert_symlink "$zenith_dir/gemini-commands/zenith.toml" "gemini command symlink created when gemini installed"
    rm -rf "$zenith_dir" "$fake_gemini"

    # gemini not installed: symlink should not be created
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    run_setup "$zenith_dir" "$source_repo" "myuser"
    [ ! -e "$zenith_dir/gemini-commands/zenith.toml" ] \
        && pass "no gemini command symlink when gemini not installed" \
        || fail "no gemini command symlink when gemini not installed"

    rm -rf "$source_repo" "$zenith_dir"
}

test_gemini_symlink_repair() {
    echo
    echo "test: gemini symlink repaired when stale target exists"

    local source_repo zenith_dir fake_home fake_gemini stale_target actual_target
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"
    fake_home=$(mktemp -d)
    fake_gemini="$fake_home/.gemini"
    mkdir -p "$fake_gemini"
    mkdir -p "$zenith_dir/gemini-commands"
    printf "stale-gemini" > "$zenith_dir/gemini-commands/zenith.toml"

    HOME="$fake_home" run_setup "$zenith_dir" "$source_repo" "myuser" "" "" "$fake_gemini"
    assert_symlink "$zenith_dir/gemini-commands/zenith.toml" "gemini command symlink repaired when stale target exists"
    actual_target=$(readlink "$zenith_dir/gemini-commands/zenith.toml" 2>/dev/null || echo "")
    echo "$actual_target" | grep -q "adapters/gemini-command.toml" \
        && pass "gemini symlink points to adapters/gemini-command.toml" \
        || fail "gemini symlink points to adapters/gemini-command.toml (got: $actual_target)"

    rm -rf "$source_repo" "$zenith_dir" "$fake_home"
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
# Test: gh CLI not installed — warns and falls through to username prompt
# ---------------------------------------------------------------------------

test_gh_not_installed() {
    echo
    echo "test: gh not installed — warns and prompts for username"

    local source_repo zenith_dir
    source_repo=$(make_source_repo)
    zenith_dir=$(mktemp -d); rm -rf "$zenith_dir"

    local output exit_code
    # GH_BIN points to a nonexistent path — simulates gh not installed portably
    # (PATH restriction fails on CI where gh lives in /usr/bin)
    output=$(GH_BIN="/nonexistent/gh" \
        ZENITH_DIR="$zenith_dir" ZENITH_REPO="$source_repo" \
        CURSOR_HOME="/nonexistent/cursor" \
        CODEX_HOME="/nonexistent/codex" \
        GEMINI_HOME="/nonexistent/gemini" \
        GLOBAL_COMMANDS_DIR="$zenith_dir/global-commands" \
        GLOBAL_CURSOR_RULES_DIR="$zenith_dir/cursor-rules" \
        GLOBAL_CODEX_SKILLS_DIR="$zenith_dir/codex-skills" \
        GLOBAL_GEMINI_COMMANDS_DIR="$zenith_dir/gemini-commands" \
        TTY=/dev/stdin bash "$REPO_ROOT/scripts/setup.sh" <<< "testuser" 2>&1) || true
    exit_code=$?

    assert_exit_zero "$exit_code"                             "exits 0 when gh not installed"
    assert_file      "$zenith_dir/.setup-complete"            "setup completes when gh not installed"
    assert_contains  "testuser" "$zenith_dir/.global-config"  "username from prompt stored in .global-config"
    echo "$output" | grep -q "gh" \
        && pass "output warns about missing gh CLI" \
        || fail "output warns about missing gh CLI"

    rm -rf "$source_repo" "$zenith_dir"
}

# ---------------------------------------------------------------------------
# Linear credential setup and request authentication
# ---------------------------------------------------------------------------

test_linear_setup() {
    echo
    echo "test: guided Linear credentials"
    local root config output status input
    root=$(mktemp -d)
    config="$root/install/.global-config"
    output="$root/output"
    input="$root/input"
    printf 'lin_test_first\n' > "$input"
    ZENITH_DIR="$root/install" TTY="$input" bash "$REPO_ROOT/scripts/setup.sh" --linear > "$output" 2>&1
    status=$?
    assert_exit_zero "$status" "Linear setup succeeds without a prior install marker"
    assert_contains 'linear_api_key = "lin_test_first"' "$config" "key stored in global config"
    assert_not_contains 'lin_test_first' "$output" "key not printed"
    [ "$(LC_ALL=C ls -l "$config" | cut -c1-10)" = '-rw-------' ] \
        && pass "global config is private" || fail "global config is private"
    [ ! -e "$root/install/.setup-complete" ] \
        && pass "credential setup does not run the installer" || fail "credential setup does not run the installer"

    cat > "$config" <<'EOF'
[user]
github_username = "existing-user"
[jira]
jira_api_token = "jira_test_token"
# Preserve this comment and the other provider settings.
[linear]
linear_api_key = "lin_old"
custom_setting = "preserve"
[other]
linear_api_key = "unrelated"
EOF
    printf 'lin_test_replacement\n' > "$input"
    ZENITH_DIR="$root/install" TTY="$input" bash "$REPO_ROOT/scripts/setup.sh" --linear > "$output" 2>&1
    assert_exit_zero "$?" "Linear setup updates an existing key"
    assert_contains 'existing-user' "$config" "GitHub settings preserved"
    assert_contains 'jira_test_token' "$config" "Jira credentials preserved"
    assert_contains '# Preserve this comment' "$config" "comments preserved"
    assert_contains 'custom_setting = "preserve"' "$config" "other Linear settings preserved"
    assert_contains 'linear_api_key = "unrelated"' "$config" "similarly named fields in other sections preserved"
    assert_not_contains 'lin_old' "$config" "old Linear key replaced"
    [ "$(grep -c '^\[linear\]$' "$config")" -eq 1 ] \
        && pass "no duplicate Linear section" || fail "no duplicate Linear section"
    assert_not_contains 'lin_test_replacement' "$output" "replacement key not printed"

    cp "$config" "$root/before"
    for input in /dev/null "$root/blank" "$root/invalid"; do
        printf '\n' > "$root/blank"
        printf 'lin_test\rkey\n' > "$root/invalid"
        ZENITH_DIR="$root/install" TTY="$input" bash "$REPO_ROOT/scripts/setup.sh" --linear > "$output" 2>&1
        assert_exit_nonzero "$?" "cancelled or invalid key rejected ($input)"
        cmp -s "$config" "$root/before" \
            && pass "failed setup preserves global config" || fail "failed setup preserves global config"
    done
    touch "$root/install/.setup-complete"
    ZENITH_DIR="$root/install" TTY=/dev/null \
        GLOBAL_COMMANDS_DIR="$root/claude" GLOBAL_CURSOR_RULES_DIR="$root/cursor" \
        GLOBAL_CODEX_SKILLS_DIR="$root/codex" GLOBAL_GEMINI_COMMANDS_DIR="$root/gemini" \
        bash "$REPO_ROOT/scripts/setup.sh" > "$output" 2>&1
    assert_exit_zero "$?" "normal installer rerun does not prompt for credentials"
    cmp -s "$config" "$root/before" \
        && pass "normal installer rerun preserves credentials" || fail "normal installer rerun preserves credentials"
    rm -rf "$root"
}

test_linear_authentication() {
    echo
    echo "test: Linear authentication uses saved credentials and environment fallback"
    local root scenario expected fallback status output
    root=$(mktemp -d)
    mkdir -p "$root/install" "$root/bin"
    awk '
        /^### CMD_LINEAR_GRAPHQL$/ { section = 1; next }
        section && /^```bash$/ { block = 1; next }
        block && /^```$/ { exit }
        block { print }
    ' "$REPO_ROOT/references/common-commands.md" > "$root/request.sh"
    cat > "$root/bin/curl" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$ZENITH_LINEAR_TEST_ARGS"
cat > "$ZENITH_LINEAR_TEST_HEADER"
printf '200'
SH
    chmod +x "$root/bin/curl"
    for scenario in stored stored_only fallback blank missing literal; do
        expected="lin_saved"
        fallback="lin_environment"
        printf '[other]\nlinear_api_key = "wrong_section"\n[linear]\nlinear_api_key = "lin_saved"\n' > "$root/install/.global-config"
        case "$scenario" in
            stored_only)
                fallback=""
                ;;
            fallback)
                printf '[jira]\njira_api_token = "jira_only"\n' > "$root/install/.global-config"
                expected="$fallback"
                ;;
            blank)
                printf '[linear]\nlinear_api_key = ""\n' > "$root/install/.global-config"
                expected="$fallback"
                ;;
            missing)
                : > "$root/install/.global-config"
                fallback=""
                ;;
            literal)
                expected='lin_test_"quotes"_\\_$(touch injected)_`touch injected`'
                printf '%s\n' "$expected" > "$root/input"
                ZENITH_DIR="$root/install" TTY="$root/input" bash "$REPO_ROOT/scripts/setup.sh" --linear > "$root/setup-output" 2>&1
                ;;
        esac
        rm -f "$root/header" "$root/args"
        output=$(cd "$root" && ZENITH_DIR="$root/install" LINEAR_API_KEY="$fallback" \
            ZENITH_LINEAR_TEST_ARGS="$root/args" ZENITH_LINEAR_TEST_HEADER="$root/header" \
            linear_request_file="$root/request.json" linear_response_file="$root/response.json" \
            linear_headers_file="$root/headers" PATH="$root/bin:$PATH" bash "$root/request.sh" 2>&1)
        status=$?
        if [ "$scenario" = missing ]; then
            assert_exit_nonzero "$status" "missing credentials stop the request"
            [ ! -e "$root/header" ] && pass "no API call without credentials" || fail "no API call without credentials"
        else
            assert_exit_zero "$status" "$scenario credentials accepted"
            printf 'Authorization: %s\n' "$expected" > "$root/expected-header"
            cmp -s "$root/header" "$root/expected-header" \
                && pass "$scenario header uses the correct literal key" || fail "$scenario header uses the correct literal key"
            if printf '%s' "$output" | grep -Fq "$expected" || grep -Fq "$expected" "$root/args"; then
                fail "$scenario key leaked in output or arguments"
            else
                pass "$scenario key stays out of output and arguments"
            fi
        fi
    done
    [ ! -e "$root/injected" ] && pass "credential text never executes as shell code" || fail "credential text never executes as shell code"
    rm -rf "$root"
}

test_repo_config_parser() {
    echo
    echo "test: startup reads the config format written by onboarding"
    local root key expected actual
    root=$(mktemp -d)
    awk '/^_cfg\(\) \{/ { block = 1 } block { print } block && /^\}$/ { exit }' \
        "$REPO_ROOT/ZENITH.md" > "$root/parser.sh"
    cat > "$root/.agent-config" <<'EOF'
[repo]
github_org = "fixture"
github_repo = "fixture-repo" # trailing comment
base_branch = main # unquoted value
[user]
project_folder = "team/data #1=\"quoted\"\\models"
github_username = "fixture-user"
EOF
    for key in github_org github_repo base_branch project_folder github_username missing; do
        case "$key" in
            github_org) expected=fixture ;;
            github_repo) expected=fixture-repo ;;
            base_branch) expected=main ;;
            project_folder) expected='team/data #1="quoted"\models' ;;
            github_username) expected=fixture-user ;;
            missing) expected='' ;;
        esac
        actual=$(bash -c '. "$1"; _cfg "$2" "$3"' _ "$root/parser.sh" "$key" "$root/.agent-config")
        [ "$actual" = "$expected" ] \
            && pass "startup parses $key" || fail "startup parses $key"
    done
    rm -rf "$root"
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
test_codex_symlink_repair
test_gemini_install
test_gemini_symlink_repair
test_symlink_repair
test_cron_uses_fetch_reset
test_gh_not_installed
test_linear_setup
test_linear_authentication
test_repo_config_parser

echo
echo "results: $PASS passed, $FAIL failed"

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
