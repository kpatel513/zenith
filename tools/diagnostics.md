# Diagnostic Command Sequence

Zenith runs this exact diagnostic sequence on every invocation before interpreting the user's request. This is non-negotiable.

## Command Sequence

Execute these commands in order and store all results:

```bash
cat .agent-config
git status --short
git branch --show-current
git log --oneline -5
git stash list
git remote -v
git log HEAD..origin/{base_branch} --oneline 2>/dev/null | wc -l
git diff --stat HEAD
git diff --cached --stat
```

## Output Field Meanings

### cat .agent-config
Returns the configuration file contents. Parse for:
- `github_org` - GitHub organization name
- `github_repo` - GitHub repository name
- `base_branch` - Base branch (usually main)
- `project_folder` - User's designated project folder
- `github_username` - User's GitHub username

### git status --short
Returns short-format status. Interpret:
- ` M` - Modified, not staged
- `M ` - Modified, staged
- `MM` - Modified, staged, then modified again
- `A ` - Added (new file), staged
- `AM` - Added, staged, then modified
- `??` - Untracked
- `D ` - Deleted, staged
- ` D` - Deleted, not staged
- `R ` - Renamed
- `U ` - Unmerged (conflict)

### git branch --show-current
Returns the current branch name. Empty if detached HEAD.

### git log --oneline -5
Returns last 5 commits with format `{hash} {message}`. Used to understand recent history and commit message style.

### git stash list
Returns list of stashes. Format: `stash@{n}: {branch}: {message}`

### git remote -v
Returns remote URLs. Typical output:
```
origin  git@github.com:org/repo.git (fetch)
origin  git@github.com:org/repo.git (push)
```

### git log HEAD..origin/{base_branch} --oneline 2>/dev/null | wc -l
Returns number of commits the current branch is behind base_branch. 0 means up to date.

### git diff --stat HEAD
Returns statistics of unstaged changes:
```
 file1.py | 10 +++++-----
 file2.py |  3 +++
 2 files changed, 8 insertions(+), 5 deletions(-)
```

### git diff --cached --stat
Returns statistics of staged changes (same format as above).

## Error Conditions

### Not in git repository
If `git status` fails with "not a git repository":
- Stop immediately
- Error: "not a git repository. run this from inside your monorepo."

### Config file not found
If `cat .agent-config` fails:
- Stop immediately
- Error: "no .agent-config found. run setup.sh first."

### Remote unreachable
If remote commands fail:
- Note: user may be offline
- Continue with local diagnostics only
- Warn: "cannot reach remote. some operations unavailable."

## Situation Detection Algorithm

After running diagnostics, classify into one situation (S1-S9):

**S1**: `git status --short` is empty AND on base_branch AND behind count = 0
**S2**: `git status --short` is empty AND on base_branch AND behind count > 0
**S3**: Not on base_branch AND `git status --short` is empty AND behind count = 0
**S4**: Not on base_branch AND `git status --short` is empty AND behind count > 0
**S5**: Not on base_branch AND has unstaged changes (lines starting with ` M` or `??`)
**S6**: Not on base_branch AND has staged changes (lines starting with `M ` or `A `)
**S7**: `git branch --show-current` is empty (detached HEAD)
**S8**: `git status` output contains "rebase in progress"
**S9**: `git status` output contains "merge in progress"

Priority: Check S7, S8, S9 first (error states). Then check S1-S6.
