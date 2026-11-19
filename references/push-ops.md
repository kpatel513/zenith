# Push Operations

Precise git command sequences for pushing changes and creating pull requests.

**See tools/common-commands.md for shared command patterns (CMD_*).**

## Linear issue links in PRs

Apply when the user asks to associate Linear issues with a new, draft, or existing PR, including creating a PR for a previously selected Linear issue. Ordinary PR work does not require an issue. Do not create tickets or add unrelated IDs found in code, quoted text, or commit history.

Resolve every requested identifier from the user's request, a supplied Linear issue URL, or an issue already selected for this work. Ask if the requested issue or target PR is missing or ambiguous. A branch name alone is not proof of the intended Linear issue. Use complete identifiers such as `ENG-123`; never invent IDs or use a `TEAM-NEW` placeholder. Editing GitHub PR text with a supplied identifier does not require `LINEAR_API_KEY` or a Linear API mutation.

For each issue the user wants linked:

- Include its ID once in the PR title, preserving the existing title and repository conventions. For example: `feat(auth): handle expired sessions [ENG-123]`. Include all requested IDs for a PR covering several issues.
- Add a plain description line with a magic word immediately before the ID. The default is `implements ENG-123`. A bare ID in the description or a magic word in a PR comment is not sufficient.
- Keep existing valid relationship keywords unless the user requests a change. Deduplicate repeated links; do not give the same ID conflicting relationships across the title and description. Preserve the template, other issue links, and unrelated description content.

Choose the relationship from the user's intent:

| Intent | Description line | Effect under the team's configured automation |
|--------|------------------|-----------------------------------------------|
| Link the work, with no other relationship specified | `implements ENG-123` | Closing relationship; follows progress and applies the configured merge status |
| Partial or contributing work that must not close on merge | `refs ENG-123` or `part of ENG-123` | Follows progress but skips the merge status transition |
| Related context with no status changes | `relates to ENG-123` or `related to ENG-123` | Relation only |
| Explicitly prevent automatic linking | `skip ENG-123` or `ignore ENG-123` | Suppresses automatic linking for that ID; exclude it from added title IDs and link lines |

Other closing words from Linear's list, such as `fixes`, `closes`, and `resolves`, remain valid when explicitly chosen. Do not substitute them for the default `implements`. Honor existing skip/ignore directives; if a new link request conflicts with one, resolve that conflict before editing. Suppression is not a promise to remove an already established link.

Preview the final title, description link lines, and relationship effects before publishing. Existing user authorization covers the requested association; ask only when the target or relationship is unresolved. Do not promise a specific Done status or change issue status directly. Linking depends on Linear's GitHub integration being enabled for the repository, and its workflow settings govern status and assignment effects.

Write the complete description to a temporary UTF-8 file and pass it with `--body-file`. Pass titles as quoted arguments, never interpolate issue or PR text into shell source. Keep the body file outside the repository.

For an existing PR, resolve the explicit PR number/URL or the unique open PR for the current branch. Resolve the repository from the supplied PR URL, existing config, or GitHub remote; ask if it cannot be determined. Read its title and body before preparing edits:

```bash
gh pr view "$pr_number" --repo {github_org}/{github_repo} --json number,url,title,body
gh pr edit "$pr_number" --repo {github_org}/{github_repo} --title "$pr_title" --body-file "$pr_body_file"
gh pr view "$pr_number" --repo {github_org}/{github_repo} --json number,url,title,body
```

Read again just before editing and preserve any intervening user changes. Skip the write if the requested links are already correct. Updating only links does not require a commit, a clean working tree, or a feature branch, and must not change Git state or create another PR.

After creating or editing a PR, verify its saved title and body. Report the PR update separately from Linear synchronization; only claim the issue is linked after observing that association. If synchronization cannot be verified, say so and point to the integration settings. Do not post a comment as a linking workaround or retry a successful edit to force synchronization.

Source: [Linear's GitHub linking and magic-word rules](https://linear.app/docs/github#link-through-pull-requests).

## Full Push Workflow (Commit + Push + PR)

Used in: INTENT_PUSH

Complete sequence from uncommitted changes to PR. Uses {parent_branch} — equals {base_branch} for non-stacked branches; equals the parent feature branch for stacked branches.

**Operation order is critical:** stage → commit → fetch → check PR → sync → push → create PR.
Rebasing with staged or uncommitted changes fails.

```bash
# 1. Run diagnostics
# (see diagnostics.md)

# 2. Validate pre-push state
git status --short
CURRENT=$(git branch --show-current)

# If on base_branch: STOP
# Error: "You are on {base_branch}. Create a feature branch first."

# If nothing staged and no unpushed commits: STOP
# Error: "Nothing to push."

# 3. Run contamination check (see contamination.md)
# If files outside project_folder: ask include/exclude

# 4. Stage files (BEFORE fetch/rebase)
git add {project_folder}/          # CMD_STAGE_FILE (or all files if user chose include)

# 5. Show what will be committed
git diff --cached --stat           # CMD_DIFF_CACHED_STAT

# 6. Commit (BEFORE rebase — rebase on staged/uncommitted changes fails)
git commit -m "{message}"          # CMD_COMMIT_WITH_MESSAGE

# 7. Fetch latest
git fetch origin                   # CMD_FETCH_ORIGIN

# 8. Check for open PR to choose sync strategy
gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open --limit 1

# 9. Sync with parent branch
# If open PR exists: merge (preserves reviewer comments)
git merge origin/{parent_branch}
# If no open PR: rebase (clean linear history)
git rebase origin/{parent_branch}  # CMD_REBASE_ONTO_BASE

# Handle conflicts if any (see conflict-resolver.md)

# 10. Push with upstream tracking
git push -u origin {current_branch}  # CMD_PUSH_SET_UPSTREAM

# 11. Prepare title/body, applying requested Linear links from the section above
# Write the full description to pr_body_file, including for drafts
gh pr create --base {parent_branch} --head {current_branch} --title "$pr_title" --body-file "$pr_body_file"
# or for draft:
gh pr create --draft --base {parent_branch} --head {current_branch} --title "$pr_title" --body-file "$pr_body_file"
```

**Stacked PR output example:**
```
stack:   {base_branch} → {parent_branch} → {current_branch}
PR:      https://github.com/{org}/{repo}/pull/{n}
```

## Push Only (No New Commit)

When changes are already committed (no staging/commit step needed):

```bash
# 1. Validate branch
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "{base_branch}" ]; then
    echo "Error: Cannot push to {base_branch} directly"
    exit 1
fi

# 2. Fetch and check PR state
git fetch origin                   # CMD_FETCH_ORIGIN
# gh pr list --repo {github_org}/{github_repo} --head {current_branch} --state open

# 3. Sync with base branch
# If open PR exists: git merge origin/{base_branch}
# If no open PR:     git rebase origin/{base_branch}    # CMD_REBASE_ONTO_BASE

# 4. Push
git push -u origin {current_branch}  # CMD_PUSH_SET_UPSTREAM

# 5. Create or update PR via GitHub CLI
# Apply requested Linear links before creating or editing the PR
# gh pr create --base {base_branch} --head {current_branch} --title "$pr_title" --body-file "$pr_body_file"
```

## Update Existing PR

Used in: INTENT_UPDATE_PR

For a request that only associates Linear issues with an existing PR, use the linking procedure above and skip the Git commands below. If code is also being pushed, apply requested links to the existing PR after the push.

```bash
# 1. Validate on feature branch
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "{base_branch}" ]; then
    echo "Error: Switch to your feature branch first"
    exit 1
fi

# 2. Stage and commit new changes
git add {project_folder}/          # CMD_STAGE_FILE
git diff --cached --stat           # CMD_DIFF_CACHED_STAT
git commit -m "{message}"          # CMD_COMMIT_WITH_MESSAGE

# 3. Push to same branch (updates PR automatically)
git push origin {current_branch}   # CMD_PUSH_SIMPLE

# 4. Show PR URL
echo "Updated PR: https://github.com/{org}/{repo}/compare/{base_branch}...{current_branch}"
```

## Fix Push Rejection

Used in: INTENT_FIX_PUSH

Diagnose why push failed and fix:

```bash
# 1. Get diagnostic info
git status
git branch --show-current
git fetch origin
git log --oneline -3

# 2. Diagnose issue
```

### Diagnosis: Behind Remote Branch

```bash
# Check if local branch behind remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/{current_branch} 2>/dev/null)

if [ "$LOCAL" != "$REMOTE" ]; then
    BEHIND=$(git rev-list --count HEAD..origin/{current_branch})
    if [ "$BEHIND" -gt 0 ]; then
        echo "Your branch is behind origin/{current_branch} by $BEHIND commits"
        echo "Fix: git pull --rebase origin {current_branch}"

        # Ask user
        read -p "Fix this now? [y/n] " response
        if [ "$response" = "y" ]; then
            git pull --rebase origin {current_branch}
            git push origin {current_branch}
        fi
    fi
fi
```

### Diagnosis: Protected Branch

```bash
if [ "{current_branch}" = "{base_branch}" ]; then
    echo "Direct push to {base_branch} is not allowed"
    echo "Create a feature branch:"
    echo "  git checkout -b feature/your-branch-name"
fi
```

### Diagnosis: No Upstream Set

```bash
# Check if branch has upstream
UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)

if [ -z "$UPSTREAM" ]; then
    echo "No upstream set for {current_branch}"
    git push -u origin {current_branch}
    echo "Upstream set and pushed"
fi
```

### Diagnosis: Permission Denied

```bash
# If git push returns 403 or permission error
echo "You do not have push access to this repository"
echo "Check:"
echo "  1. GitHub permissions"
echo "  2. SSH key configuration: ssh -T git@github.com"
echo "  3. Remote URL: git remote -v"
```

## Push with Force (Dangerous)

**Never do this automatically**. Only show commands for user to run manually.

```bash
# Use when:
# - Amended commit that was already pushed
# - Rebased after push
# - Need to rewrite history

# Safer force push (fails if remote has new commits):
git push --force-with-lease origin {current_branch}

# Unsafe force push (overwrites everything):
git push --force origin {current_branch}
```

## Construct PR URL

```bash
ORG="{github_org}"
REPO="{github_repo}"
BASE="{base_branch}"
HEAD="{current_branch}"

# Basic PR compare URL:
echo "https://github.com/$ORG/$REPO/compare/$BASE...$HEAD"

# With expand=1 to auto-open PR form:
echo "https://github.com/$ORG/$REPO/compare/$BASE...$HEAD?expand=1"

# With title and body pre-filled:
TITLE=$(echo "Add feature X" | sed 's/ /%20/g')
BODY=$(echo "This PR adds feature X" | sed 's/ /%20/g')
echo "https://github.com/$ORG/$REPO/compare/$BASE...$HEAD?expand=1&title=$TITLE&body=$BODY"
```

## Pre-push Validation Checklist

Before allowing push:

```bash
# 1. Not on base branch
[ "$(git branch --show-current)" != "{base_branch}" ]

# 2. No uncommitted changes (unless committing as part of push)
[ -z "$(git status --short)" ] || [ "$COMMITTING" = "true" ]

# 3. Remote reachable
git ls-remote origin &>/dev/null

# 4. Branch synced with base (no behind commits)
BEHIND=$(git rev-list --count HEAD..origin/{base_branch})
[ "$BEHIND" -eq 0 ]

# 5. Has commits to push
AHEAD=$(git rev-list --count origin/{base_branch}..HEAD)
[ "$AHEAD" -gt 0 ]
```

If any check fails, show specific error and fix suggestion.

## Check if PR Already Exists

```bash
# Using GitHub CLI (if available)
gh pr view {current_branch} 2>/dev/null

# If exists: show "PR already exists: {url}"
# If not: show "Create PR: {url}"
```

## Push Summary Output

After successful push:

```
branch:  {current_branch}
base:    {base_branch}
commits: {n} ahead of {base_branch}
PR:      https://github.com/{org}/{repo}/compare/{base_branch}...{current_branch}?expand=1
```

With commit details:
```
pushed commits:
  {hash} {message} — {author}
  {hash} {message} — {author}
  {hash} {message} — {author}
```

## Push to Different Remote

If multiple remotes exist:

```bash
# List remotes
git remote -v

# Push to specific remote
git push {remote_name} {current_branch}

# Set upstream to specific remote
git push -u {remote_name} {current_branch}
```

## Delete Remote Branch After PR Merge

After PR is merged:

```bash
# Delete remote branch
git push origin --delete {branch}

# Delete local branch
git checkout {base_branch}
git branch -d {branch}

# Pull latest base branch
git pull origin {base_branch}
```

## Push Tags

For releasing versions:

```bash
# Push specific tag
git push origin {tag_name}

# Push all tags
git push origin --tags
```

Zenith doesn't handle tags automatically - outside core workflow.
