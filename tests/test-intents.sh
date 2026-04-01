#!/usr/bin/env bash
# Structural tests for intents/ directory
# Usage: bash tests/test-intents.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
ERRORS=()

pass() { echo "  pass  $1"; ((PASS++)) || true; }
fail() { echo "  FAIL  $1"; ((FAIL++)) || true; ERRORS+=("$1"); }

# ---------------------------------------------------------------------------
# Test: All expected intent files exist
# ---------------------------------------------------------------------------

test_intent_files_exist() {
    echo
    echo "test: intent files exist"

    local files=(
        "intents/git-branch.md"
        "intents/git-commit.md"
        "intents/git-sync.md"
        "intents/git-push.md"
        "intents/git-undo.md"
        "intents/git-review.md"
        "intents/git-advanced.md"
        "intents/jira.md"
        "intents/meta.md"
    )

    for f in "${files[@]}"; do
        [ -f "$REPO_ROOT/$f" ] \
            && pass "$f exists" \
            || fail "$f missing"
    done
}

# ---------------------------------------------------------------------------
# Test: Each intent file has at least one ### INTENT_* handler
# ---------------------------------------------------------------------------

test_intent_files_have_handlers() {
    echo
    echo "test: intent files have handlers"

    local files=(
        "intents/git-branch.md"
        "intents/git-commit.md"
        "intents/git-sync.md"
        "intents/git-push.md"
        "intents/git-undo.md"
        "intents/git-review.md"
        "intents/git-advanced.md"
        "intents/jira.md"
        "intents/meta.md"
    )

    for f in "${files[@]}"; do
        [ -f "$REPO_ROOT/$f" ] || continue
        if grep -q "^### INTENT_" "$REPO_ROOT/$f"; then
            pass "$f has at least one handler"
        else
            fail "$f has no ### INTENT_* handlers"
        fi
    done
}

# ---------------------------------------------------------------------------
# Test: Every handler ends with a next: line
# ---------------------------------------------------------------------------

test_handlers_have_next_lines() {
    echo
    echo "test: every handler has a next: line"

    local files=(
        "intents/git-branch.md"
        "intents/git-commit.md"
        "intents/git-sync.md"
        "intents/git-push.md"
        "intents/git-undo.md"
        "intents/git-review.md"
        "intents/git-advanced.md"
        "intents/jira.md"
        "intents/meta.md"
    )

    for file in "${files[@]}"; do
        [ -f "$REPO_ROOT/$file" ] || continue

        local current_intent=""
        local handler_has_next=false

        while IFS= read -r line; do
            if echo "$line" | grep -qE "^### INTENT_[A-Z_]+$"; then
                if [ -n "$current_intent" ]; then
                    if $handler_has_next; then
                        pass "$current_intent has next: line"
                    else
                        fail "$current_intent missing next: line in $(basename "$file")"
                    fi
                fi
                current_intent=$(echo "$line" | grep -oE 'INTENT_[A-Z_]+')
                handler_has_next=false
            elif echo "$line" | grep -qEi '^next:'; then
                handler_has_next=true
            fi
        done < "$REPO_ROOT/$file"

        if [ -n "$current_intent" ]; then
            if $handler_has_next; then
                pass "$current_intent has next: line"
            else
                fail "$current_intent missing next: line in $(basename "$file")"
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
# Test: ZENITH.md routing table covers all intents in the intent list
# ---------------------------------------------------------------------------

test_routing_table_complete() {
    echo
    echo "test: ZENITH.md routing table covers all INTENT_* handlers"

    local zenith_md="$REPO_ROOT/ZENITH.md"
    # INTENT_NAME is a placeholder in the routing table instructions, not a real intent
    local skip_intents=("INTENT_UNKNOWN" "INTENT_HELP" "INTENT_NAME")

    local intents=()
    while IFS= read -r line; do
        intents+=("$line")
    done < <(grep -oE 'INTENT_[A-Z_]+' "$zenith_md" | sort -u)

    for intent in "${intents[@]}"; do
        local skip=false
        for s in "${skip_intents[@]}"; do
            [ "$intent" = "$s" ] && skip=true && break
        done
        $skip && continue

        # Check routing table references this intent
        if grep -q "^| ${intent} |" "$zenith_md"; then
            pass "$intent in routing table"
        else
            fail "$intent not found in ZENITH.md routing table"
        fi
    done
}

# ---------------------------------------------------------------------------
# Test: No handler is listed in routing table but missing from intent files
# ---------------------------------------------------------------------------

test_routing_table_handlers_exist() {
    echo
    echo "test: all routed intents have handlers in intent files"

    local zenith_md="$REPO_ROOT/ZENITH.md"

    # Extract intent→file mappings from routing table
    while IFS='|' read -r _ intent file _; do
        intent=$(echo "$intent" | tr -d ' ')
        file=$(echo "$file" | tr -d ' ')
        [ -z "$intent" ] || [ -z "$file" ] && continue
        echo "$intent" | grep -qE "^INTENT_" || continue

        if [ ! -f "$REPO_ROOT/$file" ]; then
            fail "$file missing — needed for $intent"
            continue
        fi

        if grep -q "^### ${intent}$" "$REPO_ROOT/$file"; then
            pass "$intent handler found in $file"
        else
            fail "$intent routed to $file but handler not found there"
        fi
    done < <(grep "^| INTENT_" "$zenith_md")
}

# ---------------------------------------------------------------------------
# Test: Version field present in ZENITH.md frontmatter
# ---------------------------------------------------------------------------

test_version_present() {
    echo
    echo "test: version field in ZENITH.md"

    if grep -qE '^version:' "$REPO_ROOT/ZENITH.md"; then
        pass "ZENITH.md has version field"
        local ver
        ver=$(grep -E '^version:' "$REPO_ROOT/ZENITH.md" | head -1)
        echo "  info  $ver"
    else
        fail "ZENITH.md missing version field in frontmatter"
    fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "test-intents.sh"
echo "==============="

test_intent_files_exist
test_intent_files_have_handlers
test_handlers_have_next_lines
test_routing_table_complete
test_routing_table_handlers_exist
test_version_present

echo
echo "results: $PASS passed, $FAIL failed"

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
