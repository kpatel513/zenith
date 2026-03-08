# How Zenith works at the team level

## Consistent behavior across engineers

When everyone uses the same command, the same sequence of operations runs every time — not because people remember to, but because there's no other path. Branch naming, scope checking, sync-before-push, and PR creation happen in the same order for everyone on the team.

## The spec is version-controlled

`ZENITH.md` lives in the repo. Changes to how Zenith behaves go through PR review, the same as any other codebase change. The team's git conventions are readable, diffable, and auditable.

## Scope enforcement happens before the PR queue

In a shared monorepo, cross-folder changes are flagged at commit time rather than during code review. Reviewers see PRs that have already been checked against folder boundaries.

## Context is configuration, not conversation

Your org name, base branch, project folder, and GitHub username are set once in `.agent-config`. They don't need to be re-specified each session. A new team member runs setup once and operates with the same context as everyone else.

---

## Who it's for

**Shared monorepos** — multiple people in one repo, each owning a subfolder:

```
company-repo/
├── team-payments/
│   └── checkout-service/    ← Alice's work lives here
├── team-ml/
│   └── recommendations/     ← Bob's work lives here
└── platform/
    └── infra/               ← Carol's work lives here
```

Zenith knows which folder is yours. It only commits your files, warns you if anything else changed, and blocks operations that could affect your teammates.

**Solo or small-team repos** — you own the whole thing, but you still want safe branching, automatic syncing, and PR workflows without thinking about git commands.

It's especially useful for people who are strong in their domain — ML, data, design — but don't spend their days thinking about git.
