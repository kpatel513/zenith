#!/usr/bin/env bash
# Markdown convention lint for Zenith
# Usage: bash tests/lint.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ZENITH_MD="$REPO_ROOT/.claude/commands/zenith.md"
COMMON_COMMANDS="$REPO_ROOT/tools/common-commands.md"
PLACEHOLDERS="$REPO_ROOT/tools/placeholder-conventions.md"

PASS=0
FAIL=0
ERRORS=()

pass() { echo "  pass  $1"; ((PASS++)) || true; }
fail() { echo "  FAIL  $1"; ((FAIL++)) || true; ERRORS+=("$1"); }

# ---------------------------------------------------------------------------
# Check 1: Every CMD_* reference in zenith.md is defined in common-commands.md
# ---------------------------------------------------------------------------

echo
echo "check: CMD_* references"

# Extract all CMD_XXX identifiers used as inline comments in code blocks
CMD_REFS=()
while IFS= read -r line; do
    CMD_REFS+=("$line")
done < <(grep -oE '# CMD_[A-Z_]+' "$ZENITH_MD" | grep -oE 'CMD_[A-Z_]+' | sort -u)

for cmd in "${CMD_REFS[@]}"; do
    if grep -q "^### ${cmd}$" "$COMMON_COMMANDS"; then
        pass "$cmd defined in common-commands.md"
    else
        fail "$cmd used in zenith.md but not defined in common-commands.md"
    fi
done

[ "${#CMD_REFS[@]}" -eq 0 ] && fail "no CMD_* references found in zenith.md (pattern may be broken)"

# ---------------------------------------------------------------------------
# Check 2: Every INTENT_* in the intent list has a handler section
# ---------------------------------------------------------------------------

echo
echo "check: INTENT_* handlers"

# INTENT_UNKNOWN and INTENT_HELP use inline descriptions rather than full
# handler sections, but INTENT_HELP does have a ### section. Only skip UNKNOWN.
# INTENT_UNKNOWN and INTENT_HELP are handled inline in Step 3 (not as ### sections in Step 4)
SKIP_INTENTS=("INTENT_UNKNOWN" "INTENT_HELP")

INTENT_LIST=()
while IFS= read -r line; do
    INTENT_LIST+=("$line")
done < <(grep -oE '\`INTENT_[A-Z_]+\`' "$ZENITH_MD" | grep -oE 'INTENT_[A-Z_]+' | sort -u)

for intent in "${INTENT_LIST[@]}"; do
    # Skip intents that intentionally have no handler section
    skip=false
    for s in "${SKIP_INTENTS[@]}"; do
        [ "$intent" = "$s" ] && skip=true && break
    done
    $skip && continue

    if grep -q "^### ${intent}$" "$ZENITH_MD"; then
        pass "$intent has handler section"
    else
        fail "$intent listed in intent table but has no ### handler section"
    fi
done

[ "${#INTENT_LIST[@]}" -eq 0 ] && fail "no INTENT_* entries found in zenith.md (pattern may be broken)"

# ---------------------------------------------------------------------------
# Check 3: All tools/*.md files referenced in zenith.md exist
# ---------------------------------------------------------------------------

echo
echo "check: tools/*.md references"

TOOL_REFS=()
while IFS= read -r line; do
    TOOL_REFS+=("$line")
done < <(grep -oE 'tools/[a-z-]+\.md' "$ZENITH_MD" | sort -u)

for ref in "${TOOL_REFS[@]}"; do
    if [ -f "$REPO_ROOT/$ref" ]; then
        pass "$ref exists"
    else
        fail "$ref referenced in zenith.md but file not found"
    fi
done

[ "${#TOOL_REFS[@]}" -eq 0 ] && fail "no tools/*.md references found in zenith.md (pattern may be broken)"

# ---------------------------------------------------------------------------
# Check 4: No deprecated placeholder names in zenith.md or tools/
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
    "$REPO_ROOT/tools/safety.md"
    "$REPO_ROOT/tools/contamination.md"
    "$REPO_ROOT/tools/conflict-resolver.md"
    "$REPO_ROOT/tools/branch-ops.md"
    "$REPO_ROOT/tools/commit-ops.md"
    "$REPO_ROOT/tools/sync-ops.md"
    "$REPO_ROOT/tools/push-ops.md"
    "$REPO_ROOT/tools/undo-ops.md"
    "$REPO_ROOT/tools/diagnostics.md"
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
# Check 5: tools/ files reference common-commands.md where CMD_* are used
# ---------------------------------------------------------------------------

echo
echo "check: tools/ CMD_* cross-references"

TOOLS_WITH_CMDS=()
while IFS= read -r line; do
    TOOLS_WITH_CMDS+=("$line")
done < <(grep -rl 'CMD_[A-Z_]' "$REPO_ROOT/tools/" 2>/dev/null || true)

for file in "${TOOLS_WITH_CMDS[@]}"; do
    if grep -q "common-commands.md" "$file"; then
        pass "$(basename "$file") references common-commands.md"
    else
        fail "$(basename "$file") uses CMD_* but does not reference common-commands.md"
    fi
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
