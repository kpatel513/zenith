# Using Zenith in Cursor

## First-time install

Open Cursor once, then run the [Zenith installer](../README.md#install). It detects `~/.cursor` and links the rule at `~/.cursor/rules/zenith.mdc`, making `@zenith` available across repos.

## Already have Zenith installed?

If you added Cursor after installing Zenith, open Cursor once and rerun the installer to add or repair its rule. If `@zenith` already works, run `@zenith update zenith` in a repo to get the latest version.

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

Run `@zenith help` inside your repo. Zenith detects the repo settings and asks for your project folder. Enter `.` for the whole repo. If you've already configured this repo in another client, Cursor reuses its `.agent-config`.

To use Linear, run `@zenith linear setup`, then `@zenith my tickets` to verify. Cursor reuses any saved Linear key on this machine and any team and project defaults in this repo. See [Set up Linear](../README.md#set-up-linear) for the credential prompt and project choices.

## Model compatibility

**Claude Code is not required.** Zenith works with any model available in Cursor — Claude, GPT-4o, Gemini, or Cursor's built-in model.

> If your repo's `.gitignore` excludes `.cursor/`, add an exception so teammates who use Cursor can get the rule:
> ```
> !.cursor/rules/zenith.mdc
> ```
