#!/usr/bin/env bash
# Markdown convention lint for Zenith
# Usage: bash tests/lint.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ZENITH_MD="$REPO_ROOT/ZENITH.md"
COMMON_COMMANDS="$REPO_ROOT/references/common-commands.md"
PLACEHOLDERS="$REPO_ROOT/references/placeholder-conventions.md"

PASS=0
FAIL=0
ERRORS=()

pass() { echo "  pass  $1"; ((PASS++)) || true; }
fail() { echo "  FAIL  $1"; ((FAIL++)) || true; ERRORS+=("$1"); }

# Intent files list (used by multiple checks)
EXPECTED_INTENT_FILES=(
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

# ---------------------------------------------------------------------------
# Check 1: Every CMD_* reference in ZENITH.md and intent files is defined in common-commands.md
# ---------------------------------------------------------------------------

echo
echo "check: CMD_* references"

# Check CMD_* in ZENITH.md AND all intent files
ALL_FILES_TO_CHECK=("$ZENITH_MD")
for f in "${EXPECTED_INTENT_FILES[@]}"; do
    [ -f "$REPO_ROOT/$f" ] && ALL_FILES_TO_CHECK+=("$REPO_ROOT/$f")
done

# Extract all CMD_XXX identifiers used as inline comments in code blocks
CMD_REFS=()
while IFS= read -r line; do
    CMD_REFS+=("$line")
done < <(grep -h -oE '# CMD_[A-Z_]+' "${ALL_FILES_TO_CHECK[@]}" 2>/dev/null | grep -oE 'CMD_[A-Z_]+' | sort -u)

for cmd in "${CMD_REFS[@]}"; do
    if grep -q "^### ${cmd}$" "$COMMON_COMMANDS"; then
        pass "$cmd defined in common-commands.md"
    else
        fail "$cmd used in ZENITH.md or intent files but not defined in common-commands.md"
    fi
done

[ "${#CMD_REFS[@]}" -eq 0 ] && fail "no CMD_* references found in ZENITH.md or intent files (pattern may be broken)"

# ---------------------------------------------------------------------------
# Check 2: Every INTENT_* in the intent list has a handler section
# ---------------------------------------------------------------------------

echo
echo "check: INTENT_* handlers"

# INTENT_UNKNOWN and INTENT_HELP are handled inline in Step 3 (not as ### sections in Step 4)
# INTENT_NAME is a placeholder in the routing table instructions, not a real intent
SKIP_INTENTS=("INTENT_UNKNOWN" "INTENT_HELP" "INTENT_NAME")

INTENT_LIST=()
while IFS= read -r line; do
    INTENT_LIST+=("$line")
done < <(grep -oE 'INTENT_[A-Z_]+' "$ZENITH_MD" | sort -u)

# Search for handlers in ZENITH.md and all intent files
has_handler() {
    local intent="$1"
    # Check ZENITH.md first
    grep -q "^### ${intent}$" "$ZENITH_MD" && return 0
    # Check all intent files
    for f in "${EXPECTED_INTENT_FILES[@]}"; do
        [ -f "$REPO_ROOT/$f" ] && grep -q "^### ${intent}$" "$REPO_ROOT/$f" && return 0
    done
    return 1
}

for intent in "${INTENT_LIST[@]}"; do
    # Skip intents that intentionally have no handler section
    skip=false
    for s in "${SKIP_INTENTS[@]}"; do
        [ "$intent" = "$s" ] && skip=true && break
    done
    $skip && continue

    if has_handler "$intent"; then
        pass "$intent has handler section"
    else
        fail "$intent listed in intent table but has no ### handler section"
    fi
done

[ "${#INTENT_LIST[@]}" -eq 0 ] && fail "no INTENT_* entries found in ZENITH.md (pattern may be broken)"

# ---------------------------------------------------------------------------
# Check 3: All references/*.md files referenced in ZENITH.md exist
# ---------------------------------------------------------------------------

echo
echo "check: references/*.md references"

TOOL_REFS=()
while IFS= read -r line; do
    TOOL_REFS+=("$line")
done < <(grep -oE 'references/[a-z-]+\.md' "$ZENITH_MD" | sort -u)

for ref in "${TOOL_REFS[@]}"; do
    if [ -f "$REPO_ROOT/$ref" ]; then
        pass "$ref exists"
    else
        fail "$ref referenced in ZENITH.md but file not found"
    fi
done

[ "${#TOOL_REFS[@]}" -eq 0 ] && fail "no references/*.md references found in ZENITH.md (pattern may be broken)"

# ---------------------------------------------------------------------------
# Check 4: No deprecated placeholder names in ZENITH.md, references/, or intent files
# ---------------------------------------------------------------------------

echo
echo "check: deprecated placeholders"

DEPRECATED=(
    "{branch_name}"
    "{selected_branch}"
)

# Files to check (exclude the deprecation table in placeholder-conventions.md
# which intentionally lists these names)
CHECK_FILES=(
    "$ZENITH_MD"
    "$REPO_ROOT/references/safety.md"
    "$REPO_ROOT/references/contamination.md"
    "$REPO_ROOT/references/conflict-resolver.md"
    "$REPO_ROOT/references/branch-ops.md"
    "$REPO_ROOT/references/commit-ops.md"
    "$REPO_ROOT/references/sync-ops.md"
    "$REPO_ROOT/references/push-ops.md"
    "$REPO_ROOT/references/undo-ops.md"
    "$REPO_ROOT/references/diagnostics.md"
    "$REPO_ROOT/intents/git-branch.md"
    "$REPO_ROOT/intents/git-commit.md"
    "$REPO_ROOT/intents/git-sync.md"
    "$REPO_ROOT/intents/git-push.md"
    "$REPO_ROOT/intents/git-undo.md"
    "$REPO_ROOT/intents/git-review.md"
    "$REPO_ROOT/intents/git-advanced.md"
    "$REPO_ROOT/intents/jira.md"
    "$REPO_ROOT/intents/meta.md"
)

for placeholder in "${DEPRECATED[@]}"; do
    found=false
    for file in "${CHECK_FILES[@]}"; do
        [ -f "$file" ] || continue
        if grep -q "$placeholder" "$file"; then
            fail "deprecated placeholder $placeholder found in $file"
            found=true
        fi
    done
    $found || pass "deprecated placeholder $placeholder not used"
done

# Check {commit} used as commit identifier (not as part of "commit message" etc.)
# Pattern: {commit} standing alone as a placeholder
for file in "${CHECK_FILES[@]}"; do
    [ -f "$file" ] || continue
    if grep -oE '\{commit\}' "$file" | grep -q .; then
        fail "deprecated placeholder {commit} found in $file (use {hash})"
    fi
done

# ---------------------------------------------------------------------------
# Check 5: references/ files reference common-commands.md where CMD_* are used
# ---------------------------------------------------------------------------

echo
echo "check: references/ CMD_* cross-references"

TOOLS_WITH_CMDS=()
while IFS= read -r line; do
    TOOLS_WITH_CMDS+=("$line")
done < <(grep -rl 'CMD_[A-Z_]' "$REPO_ROOT/references/" 2>/dev/null || true)

for file in "${TOOLS_WITH_CMDS[@]}"; do
    if grep -q "common-commands.md" "$file"; then
        pass "$(basename "$file") references common-commands.md"
    else
        fail "$(basename "$file") uses CMD_* but does not reference common-commands.md"
    fi
done

# ---------------------------------------------------------------------------
# Check 6: .cursor/rules/zenith.mdc exists and has required frontmatter
# ---------------------------------------------------------------------------

echo
echo "check: cursor rule"

CURSOR_RULE="$REPO_ROOT/.cursor/rules/zenith.mdc"

if [ ! -f "$CURSOR_RULE" ]; then
    fail ".cursor/rules/zenith.mdc does not exist"
else
    pass ".cursor/rules/zenith.mdc exists"

    if grep -q "^alwaysApply:" "$CURSOR_RULE"; then
        pass "zenith.mdc has alwaysApply field"
    else
        fail "zenith.mdc missing alwaysApply field in frontmatter"
    fi

    if grep -q "^description:" "$CURSOR_RULE"; then
        pass "zenith.mdc has description field"
    else
        fail "zenith.mdc missing description field in frontmatter"
    fi
fi

# ---------------------------------------------------------------------------
# Check 7: Every handler section ends with a next: line
# (INTENT_HELP and INTENT_UNKNOWN are handled inline in ZENITH.md, not in intent files)
# ---------------------------------------------------------------------------

echo
echo "check: next: lines in intent handlers"

INTENT_FILES=(
    "$REPO_ROOT/intents/git-branch.md"
    "$REPO_ROOT/intents/git-commit.md"
    "$REPO_ROOT/intents/git-sync.md"
    "$REPO_ROOT/intents/git-push.md"
    "$REPO_ROOT/intents/git-undo.md"
    "$REPO_ROOT/intents/git-review.md"
    "$REPO_ROOT/intents/git-advanced.md"
    "$REPO_ROOT/intents/jira.md"
    "$REPO_ROOT/intents/meta.md"
)

for file in "${INTENT_FILES[@]}"; do
    [ -f "$file" ] || continue
    # Extract each ### INTENT_* handler: find intent name and then find the last meaningful line before the next ### or EOF
    # Strategy: for each handler, check that "next:" appears somewhere in the handler body
    CURRENT_INTENT=""
    HANDLER_HAS_NEXT=false
    while IFS= read -r line; do
        if echo "$line" | grep -qE "^### INTENT_[A-Z_]+$"; then
            # Check previous handler before moving to next
            if [ -n "$CURRENT_INTENT" ]; then
                if $HANDLER_HAS_NEXT; then
                    pass "$CURRENT_INTENT has next: line"
                else
                    fail "$CURRENT_INTENT missing next: line in $(basename "$file")"
                fi
            fi
            CURRENT_INTENT=$(echo "$line" | grep -oE 'INTENT_[A-Z_]+')
            HANDLER_HAS_NEXT=false
        elif echo "$line" | grep -qEi '^next:'; then
            HANDLER_HAS_NEXT=true
        fi
    done < "$file"
    # Check last handler in file
    if [ -n "$CURRENT_INTENT" ]; then
        if $HANDLER_HAS_NEXT; then
            pass "$CURRENT_INTENT has next: line"
        else
            fail "$CURRENT_INTENT missing next: line in $(basename "$file")"
        fi
    fi
done

# ---------------------------------------------------------------------------
# Check 8: All intent files referenced in ZENITH.md routing table exist
# ---------------------------------------------------------------------------

echo
echo "check: intent files exist"

for f in "${EXPECTED_INTENT_FILES[@]}"; do
    if [ -f "$REPO_ROOT/$f" ]; then
        pass "$f exists"
    else
        fail "$f missing — referenced in ZENITH.md routing table but not found"
    fi
done

# ---------------------------------------------------------------------------
# Check 9: Every CMD_* reference in intent files is defined in common-commands.md
# (covered by Check 1 above, but verify intent files individually for clearer output)
# ---------------------------------------------------------------------------

echo
echo "check: CMD_* references in intent files"

for f in "${EXPECTED_INTENT_FILES[@]}"; do
    [ -f "$REPO_ROOT/$f" ] || continue
    INTENT_CMD_REFS=()
    while IFS= read -r line; do
        INTENT_CMD_REFS+=("$line")
    done < <(grep -oE '# CMD_[A-Z_]+' "$REPO_ROOT/$f" 2>/dev/null | grep -oE 'CMD_[A-Z_]+' | sort -u)
    if [ "${#INTENT_CMD_REFS[@]}" -eq 0 ]; then
        pass "$(basename "$f") has no CMD_* references (ok for meta files)"
        continue
    fi
    for cmd in "${INTENT_CMD_REFS[@]}"; do
        if grep -q "^### ${cmd}$" "$COMMON_COMMANDS"; then
            pass "$cmd (in $(basename "$f")) defined in common-commands.md"
        else
            fail "$cmd used in $(basename "$f") but not defined in common-commands.md"
        fi
    done
done

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

echo
echo "results: $PASS passed, $FAIL failed"

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "failures:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    exit 1
fi
