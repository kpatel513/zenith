# Placeholder Naming Conventions

Standard placeholder names used consistently across all Zenith documentation.

## Purpose

This document defines the canonical naming for all placeholders in commands, documentation, and code examples. Using consistent names prevents confusion and makes documentation easier to maintain.

---

## Standard Placeholders

### Branches

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{base_branch}` | The main/master branch from config | `main`, `master` | Read from `.agent-config` |
| `{current_branch}` | The branch currently checked out | `feature/auth` | From `git branch --show-current` |
| `{branch}` | Generic branch reference or user input | `feature/new-feature` | Use when context is clear |
| `{remote_branch}` | Branch name on remote | `origin/feature/auth` | Includes remote name |

**Deprecated:** `{branch_name}`, `{selected_branch}` → Use `{branch}` or `{current_branch}` as appropriate

### Commits

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{hash}` | Short commit hash | `a3f2c1b` | 7-character short hash |
| `{full_hash}` | Full commit hash | `a3f2c1b8d...` | 40-character full hash |
| `{message}` | Commit message | `Add user authentication` | Subject line only |
| `{subject}` | Commit subject (first line) | `Add user authentication` | Same as `{message}` |

**Deprecated:** `{commit}` → Use `{hash}`

### Files and Paths

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{file}` | Single file path | `src/auth.py` | Relative to repo root |
| `{files}` | Multiple file paths | `src/auth.py src/utils.py` | Space-separated |
| `{project_folder}` | User's designated folder | `team-alpha/ml-pipeline` | From `.agent-config` |
| `{path}` | Generic path (file or directory) | `src/components/` | Use sparingly |

### GitHub Identifiers

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{github_org}` | GitHub organization | `anthropics` | From `.agent-config` |
| `{github_repo}` | GitHub repository | `zenith` | From `.agent-config` |
| `{github_username}` | User's GitHub username | `alice` | From `.agent-config` |
| `{org}` | Shorthand for `{github_org}` | `anthropics` | Use in URLs only |
| `{repo}` | Shorthand for `{github_repo}` | `zenith` | Use in URLs only |

### Counts and Numbers

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{n}` | Generic numeric count | `5` | Commits, files, lines, etc. |
| `{count}` | Explicit count with context | `ahead by 3` | Use when clarity needed |

### Author and Time

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{author}` | Commit author name | `Alice Smith` | From git log |
| `{email}` | Author email | `alice@example.com` | From git config |
| `{time}` | Relative time | `2 hours ago` | From git log --relative |
| `{date}` | Absolute date | `2024-01-15` | From git log --date |

### Remotes

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{remote}` | Remote name | `origin` | Usually `origin` |
| `{remote_name}` | Explicit remote name | `upstream` | Use when multiple remotes |
| `{remote_url}` | Remote URL | `git@github.com:org/repo.git` | Full URL |

### Change Statistics

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{additions}` | Lines added | `+45` | With + prefix |
| `{deletions}` | Lines deleted | `-12` | With - prefix |
| `{size}` | File size | `2.1GB`, `50MB` | Human-readable |

### User Input

| Placeholder | Meaning | Example | Notes |
|-------------|---------|---------|-------|
| `{message}` | User-provided commit message | `Fix authentication bug` | User input |
| `{response}` | User response to prompt | `y`, `YES`, `i` | Single-character or word |
| `{input}` | Generic user input | Any text | Use sparingly |

---

## Usage Guidelines

### 1. Be Specific Where Possible

**Good:**
```bash
git checkout {current_branch}
git rebase origin/{base_branch}
```

**Bad:**
```bash
git checkout {branch}
git rebase origin/{branch}
```

### 2. Use Full Names in Commands, Short Names in URLs

**Commands:**
```bash
git push origin/{current_branch}
PR: https://github.com/{github_org}/{github_repo}/pulls
```

**URLs (acceptable shorthand):**
```bash
https://github.com/{org}/{repo}/compare/{base_branch}...{current_branch}
```

### 3. Singular vs. Plural

- Use `{file}` when referring to a single file
- Use `{files}` when referring to multiple files
- Use `{branch}` for singular, `{branches}` for plural

### 4. Avoid Ambiguous Terms

**Avoid:** `{name}`, `{value}`, `{item}`, `{thing}`
**Use:** Specific placeholders like `{branch}`, `{file}`, `{message}`

### 5. Context Determines Choice

When `{current_branch}` is obvious from context, `{branch}` is acceptable:

```bash
# Clear context - we're pushing current branch
git push origin {branch}

# Ambiguous - which branch?
git diff {base_branch}..{current_branch}  # Explicit is better
```

---

## Migration from Old Names

| Deprecated | Replace With | Context |
|------------|--------------|---------|
| `{branch_name}` | `{branch}` | Generic branch reference |
| `{selected_branch}` | `{current_branch}` | After user selects branch |
| `{commit}` | `{hash}` | Commit identifier |
| `{org}` | `{github_org}` | Except in URLs where short form OK |
| `{repo}` | `{github_repo}` | Except in URLs where short form OK |

---

## Examples

### Branch Operations

```bash
# Creating new branch
git checkout -b {branch}
git push -u origin {branch}

# Switching to existing branch
git checkout {current_branch}

# Comparing branches
git diff {base_branch}..{current_branch}
```

### Commit Operations

```bash
# Creating commit
git commit -m "{message}"
git log --oneline -1  # Shows: {hash} {message}

# Viewing commit
git show {hash}
```

### Remote Operations

```bash
# Fetching and pushing
git fetch origin
git push origin {current_branch}
git pull --rebase origin {base_branch}
```

### File Operations

```bash
# Single file
git add {file}
git diff {file}

# Multiple files
git add {files}
git diff --name-only # Output: list of {file}
```

### Output Formatting

```bash
# Branch info
branch:  {current_branch}
from:    {base_branch}
folder:  {project_folder}/

# Commit info
committed: {hash}
message:   {message}
author:    {author} <{email}>

# PR URL
PR: https://github.com/{org}/{repo}/compare/{base_branch}...{current_branch}
```

---

## Validation Checklist

When writing new documentation:

- [ ] Branch references use `{base_branch}`, `{current_branch}`, or `{branch}`
- [ ] Commit references use `{hash}` or `{message}`, not `{commit}`
- [ ] File paths use `{file}` (singular) or `{files}` (plural)
- [ ] Config values use full names: `{github_org}`, `{github_repo}`, `{project_folder}`
- [ ] User input uses `{message}`, `{response}`, or specific term
- [ ] No deprecated placeholders (`{branch_name}`, `{selected_branch}`, `{commit}`)
- [ ] Placeholders match exactly with curly braces: `{example}`

---

## Reference in Code

When referencing these conventions in documentation:

```markdown
See tools/placeholder-conventions.md for standard naming
```

In commands with inline comments:

```bash
git checkout {current_branch}  # See placeholder-conventions.md
```

---

## Enforcement

All new documentation MUST follow these conventions. When updating existing docs:

1. Check current placeholder names against this document
2. Replace deprecated names with standard names
3. Be consistent within a single file
4. Cross-reference between files using standard names
