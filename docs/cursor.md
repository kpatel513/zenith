# Using Zenith in Cursor

## First-time install

Run the same `setup.sh` installer and answer **y** to the Cursor question. That creates `~/.cursor/rules/zenith.mdc`, which makes `@zenith` available in every Cursor session on your machine.

## Already have Zenith installed?

Setup won't re-run if Zenith is already installed. Add Cursor support with one command:

```bash
mkdir -p ~/.cursor/rules && ln -s ~/.zenith/.cursor/rules/zenith.mdc ~/.cursor/rules/zenith.mdc
```

## How to invoke

Open Cursor's **Chat** or **Composer** panel, type `@zenith` followed by your request, and press Enter:

```
@zenith push my changes
@zenith start new feature
@zenith sync with main
@zenith help
```

Cursor will show a dropdown when you type `@` — select **zenith** from the list, then add your request. The same phrases from the "What you can say" table in the README all work.

## First use in a repo

The first time you run `@zenith` in a repo that hasn't been configured, Zenith walks you through the same 4-question setup as Claude Code:

```
first-time setup — no config found for this repo
│ detected: /Users/alice/code/company-repo
│ answering 4 questions configures Zenith for this repo permanently

Your project folder (or . for whole repo): team-ml/recommendations
GitHub organization:                       acme-corp
GitHub repository:                         company-repo
Base branch [main]:                        main
```

If you've already configured the repo via Claude Code, `@zenith` picks up the same `.agent-config` — no duplicate setup.

## Model compatibility

**Claude Code is not required.** Zenith works with any model available in Cursor — Claude, GPT-4o, Gemini, or Cursor's built-in model.

> If your repo's `.gitignore` excludes `.cursor/`, add an exception so teammates who use Cursor can get the rule:
> ```
> !.cursor/rules/zenith.mdc
> ```
