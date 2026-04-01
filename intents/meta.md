# Zenith — Meta Operations
# Handlers: INTENT_ZENITH_UPDATE
# Read by ZENITH.md Step 4 router.

### INTENT_ZENITH_UPDATE

Execute:
```bash
cd ~/.zenith && git fetch origin main --quiet && git reset --hard origin/main --quiet
```

Read the version after update:
```bash
grep "^version:" ~/.zenith/ZENITH.md | head -1
```

Print:
```
updating zenith — pulling latest from GitHub
│ fetching origin/main and resetting to latest

  ✓ updated  ~/.zenith
  version    {version}
```

next: "next: run /zenith help to see what's new"
