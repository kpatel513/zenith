# Contamination Check

The contamination check detects changes outside the user's designated project folder and identifies risky file patterns. It runs automatically during certain operations and can be invoked explicitly with `INTENT_CHECK_SCOPE`.

**See tools/common-commands.md for shared command patterns (CMD_*).**

## When to Run

Automatically run silently during:
- INTENT_SAVE
- INTENT_PUSH
- INTENT_SHOW_CHANGES (append note if found)

Run fully with output during:
- INTENT_CHECK_SCOPE

## Detection Logic

### Step 1: Collect All Changed Files

Run both commands to get complete picture:
```bash
git diff --name-only HEAD
git diff --name-only --cached
git status --short
```

Combine results to get unique list of all changed files (staged and unstaged).

### Step 2: Categorize by Location

For each file path, check if it starts with `{project_folder}/`:
- YES: inside project folder
- NO: outside project folder

Group and display:
```
inside {project_folder}/:
  {file}   +{n} -{n}
  {file}   +{n} -{n}

outside {project_folder}/:
  {file}   +{n} -{n}
  {file}   +{n} -{n}
```

### Step 3: Run Risk Checks

For **every changed file** regardless of location, check these patterns:

#### Hardcoded Paths
Search file content for patterns matching absolute paths:
- `/Users/` anywhere in content
- `/home/` anywhere in content
- `C:\Users\` anywhere in content (Windows)

Command:
```bash
git diff HEAD {file} | grep -E "^\+.*(\/Users\/|\/home\/|C:\\Users\\)"
```

If found, record: `hardcoded path: {file} line {line_number}`

#### Credentials Risk
Check filename against patterns:
- `.env`
- `.env.*` (e.g., .env.local, .env.production)
- `*secrets*`
- `*credentials*`
- `*secret*`
- `*.pem`
- `*.key` (but not `.pub`)
- `*token*`
- `*password*`

Case insensitive match. If matched: `credentials: {file}`

#### Large Files
Check file size:
```bash
ls -lh {file} | awk '{print $5}'
```

If size > 50MB: `large file: {file} {size}`

#### Root-Level Dependency Files

Check if any changed file is a root-level dependency file — one that controls dependencies for the entire repo, not just one project folder.

Patterns (filename at repo root, i.e., no `/` prefix in the path):
- `requirements.txt`
- `pyproject.toml`
- `setup.py`
- `setup.cfg`
- `Pipfile`
- `Pipfile.lock`
- `package.json`
- `yarn.lock`
- `poetry.lock`

If matched: `root dependency: {file}`

These files affect all projects in the repo. A version change or added package can break builds for every other team. Always flag — even if the file is inside `{project_folder}`.

#### Shared Path Risk

Check if any changed file lives under a path that is conventionally shared across teams in a monorepo.

Path starts with any of (at repo root, no preceding folder):
- `common/`
- `shared/`
- `utils/`
- `lib/`
- `core/`
- `infra/`
- `scripts/`
- `.github/`
- `docker/`

Or filename is any of:
- `Makefile`
- `Dockerfile`
- `.pre-commit-config.yaml`
- `.gitignore` (root-level only)

If matched: `shared path: {file}`

These paths are typically owned by platform or infra teams, or used by multiple project folders. Changes here can silently affect colleagues who never see your PR diff. Always surface — even if the file appears to be inside `{project_folder}`.

#### ML Output Risk
Check path components and extension against patterns:

Path contains any of:
- `/outputs/`
- `/checkpoints/`
- `/wandb/`
- `/mlruns/`
- `/.cache/`
- `/runs/`
- `/logs/training/`

Extension matches any of:
- `.ckpt`
- `.pt`
- `.pth`
- `.h5`
- `.hdf5`
- `.zarr`
- `.pkl`
- `.pickle`
- `.safetensors`

If matched: `ml output: {file}`

#### Content Scanning — Secret Patterns

**See tools/common-commands.md for shared command patterns (CMD_*).**

For each changed file, scan diff lines starting with `+` for secret patterns. Filename checks alone miss credentials embedded in non-credential-named files (e.g., `.env.example` renamed to `config.py`).

Command to scan each staged file:
```bash
git diff --cached -- {file} | grep -E '^\+' | grep -iE '{pattern}'
```

Patterns to scan for:

| Pattern | Matches |
|---|---|
| `AKIA[0-9A-Z]{16}` | AWS access key ID |
| `sk-[a-zA-Z0-9]{48}` | OpenAI API key |
| `ghp_[a-zA-Z0-9]{36}` | GitHub personal access token |
| `xoxb-[0-9]+-[0-9]+-[a-zA-Z0-9]+` | Slack bot token |
| `api[_-]?key\s*=\s*["'][a-zA-Z0-9/+]{20,}` | Generic named API key assignment |
| `secret\s*=\s*["'][a-zA-Z0-9/+]{20,}` | Generic named secret assignment |

Run each pattern separately against each staged file. If a match is found, record the line number and pattern type.

Output format — append as `│` lines under the relevant file in the contamination check output:
```
│   ⚠ secret pattern  line {n}: possible AWS access key
│   ⚠ secret pattern  line {n}: possible OpenAI API key
```

When secret patterns are found, block commit and require explicit confirmation:
```
credentials detected — possible secret values in staged content
│ {file}: line {n}: possible {pattern_type}
│ review these lines before committing

Type YES to commit anyway (not "yes", not "y"):
```

## Output Format

### Full Check (INTENT_CHECK_SCOPE)

```
inside {project_folder}/:
  src/model.py        +45 -12
  tests/test_model.py +20 -5

outside {project_folder}/:
  shared/utils.py     +8 -2

hardcoded path:  src/model.py line 42
large file:      outputs/model.ckpt 2.1GB
ml output:       outputs/model.ckpt
root dependency: requirements.txt
shared path:     common/utils.py
```

If nothing outside project folder and no flags:
```
clean: all changes scoped to {project_folder}/
```

### Silent Check (During INTENT_SAVE, INTENT_PUSH)

Only return TRUE/FALSE and list of files outside project_folder if any.

Used to prompt user: "These files are outside {project_folder}/. Include them or exclude them? [i/e]"

### Append Note (During INTENT_SHOW_CHANGES)

If files detected outside project_folder, append to normal output:
```
note: changes also detected outside {project_folder}/:
  shared/utils.py
  run /zenith scope check for details
```

## User Actions Based on Results

### Files outside project_folder detected
Ask: "Include or exclude these files? [i/e]"
- Include: proceed with all files
- Exclude: use `git add {project_folder}/` to stage only project folder

### Hardcoded paths detected
Warn: "Hardcoded paths found. Fix before committing?"
Block commit until user confirms or fixes.

### Credentials detected
Warn: "Potential credentials file detected: {file}"
Require explicit confirmation: "Type YES to commit anyway:"

### Large files detected
Warn: "Large file detected: {file} {size}"
Ask: "This may not belong in git. Continue? [y/n]"

### ML outputs detected
Warn: "ML output file detected: {file}"
Suggest: "Add to .gitignore? [y/n]"

### Root-level dependency file detected
Warn: "This file controls dependencies for the whole repo — changes here can break other teams"
Ask: "Confirm you've reviewed the version changes? [y/n]"

### Shared path detected
Warn: "This path is likely shared across teams — verify with the owner before committing"
Ask: "Continue anyway? [y/n]"
