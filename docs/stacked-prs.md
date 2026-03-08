# Stacked PRs

When change B depends on change A and both need separate PRs, use a stack.

**Start a stack** — when you're already on a feature branch, run `start new work`. Zenith asks whether to branch from main or stack on top of the current branch. Choose "stack" and the new branch automatically targets the parent branch instead of main.

**What changes:**
- `push` — opens the PR against the parent branch (not main)
- `sync` — syncs against the parent branch
- `show my stack` — displays the full chain with PR status and CI state for each level

**When the parent PR merges:**

Run `I merged the PR`. Zenith detects which PR merged and handles the cascade:
1. Retargets your PR base from the parent branch to main
2. Runs `git rebase --onto` to drop the parent's commits from your branch
3. Force-pushes and cleans up the stored parent config

Your PR on GitHub automatically updates to show the correct diff.

**Stack info is stored in git config locally** — it is never committed and never sent anywhere.
