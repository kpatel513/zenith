# PR Review

Zenith runs a three-pass adversarial review — designed to behave like a skeptical principal engineer, not a helpful assistant.

## Two tiers

`review` — standard tier, Layers 1–6. Fast. Uses git history, docs, project config, and code structure. Good for a quick pre-submit check.

`deep review` — full context, Layers 1–9. Adds PR history on touched files, open PRs touching the same files, and recurring themes from past review comments. Use this before submitting work in a high-traffic or contested area of the codebase.

**Author mode** — before you submit, while you're still on your branch:
```
/zenith review my PR
/zenith deep review my PR
```

**Reviewer mode** — when you've been assigned to review someone else's PR:
```
/zenith review PR 123
/zenith deep review PR 123
```

---

## How the three passes work

**Pass 1 — Benevolent.** What does this diff actually do? Zenith reads the raw diff, the commit messages, and the PR description and produces 3–5 plain English bullets. Facts, no opinions.

**Pass 2 — Signals.** Automated checks across nine dimensions:
- **Scope** — are all changed files inside your project folder, or did the PR accidentally touch something else?
- **Volatile files** — files with more than 10 commits in the past year are flagged; bugs introduced here tend to be expensive
- **Fragile files** — files that have had revert or hotfix commits are flagged with the history
- **Duplicate symbols** — new functions or classes are grep'd against the whole codebase; if the same name already exists somewhere, it's surfaced
- **PR history** — files that appeared in 3+ PRs in the past 60 days are flagged as actively evolving and higher integration risk
- **Open PR conflicts** — other open PRs touching the same files are surfaced so you can coordinate before merging
- **Reviewer patterns** — recurring themes from past review comments on these files are surfaced as known concerns for this area
- **Config signals** — duplicate dependencies, untyped code where mypy runs, version pins broken by the change
- **Structure signals** — code placed outside the established module layout, public API not exported in `__init__.py`

**Pass 3 — Architect (isolated).** Pass 3 sees only the raw diff — it never reads Pass 1 or Pass 2 output. Persona: senior architect with 15+ years of experience. Not adversarial — precise. Finds the one or two structural issues that will compound over time and states them plainly, in one sentence each. Ignores style and minor issues. Every concern has all four fields, each exactly one sentence:
- line citation
- failure scenario ("when X under Y condition, result is Z")
- alternative (what to do instead)
- question (what the author must answer before merging)

Pass 3 explicitly checks eleven things: right problem vs. symptom, failure recovery, coupling introduced, simpler path available, worst-case load and data, readability for the next engineer, what it makes harder to change in 6 months, hidden assumptions about callers or environment, correct abstraction level (not over/under-engineered), whether this belongs at this layer of the system, and whether total complexity is proportional to value delivered.

---

## Team context file

Create `.zenith-context` at the repo root (committed, not personal) to raise the quality ceiling:

```
[failure_patterns]
db query inside loop → connection pool exhaustion (incident 2024-03)

[existing_utilities]
src/utils/retry.js — circuit breaker, use instead of custom retry logic

[architecture]
never couple payment flow to session state (ADR-007)
```

A template is at `assets/.zenith-context.template`. Zenith checks every PR diff against the patterns in this file and flags matches in the signals section. No file, no error — it just runs on git history and codebase scan alone.

---

## What the output looks like

```
reviewing — feature/add-rate-limiter
│ CI: ✓  base: main  +84 -12
│ 3-pass review: summary → signals → architect (pass 3 sees raw diff only)

── what it does ──────────────────────────────────────────
│ • Adds a token bucket rate limiter to the API gateway middleware
│ • Stores per-user token counts in Redis with a 60s TTL
│ • Returns 429 with Retry-After header when limit is exceeded

── signals ───────────────────────────────────────────────
│ scope      ✓ within team-api/
│ volatile   src/middleware/auth.js — 18 commits in past year, 2 reverts
│ duplicate  RateLimiter already exists at src/utils/throttle.js
│ pr history src/middleware/auth.js appeared in PR #38 (12 days ago) and PR #35 (31 days ago)
│ conflict   PR #41 (bob) also touches src/middleware/auth.js — coordinate before merging
│ reviewer   recurring feedback on auth.js: "initialize clients at module load, not per-request"
│ config     requirements.txt pins redis==4.5.1 — new redis.asyncio import requires 4.6+

── concerns ──────────────────────────────────────────────
│ P1  src/middleware/auth.js line 47: Redis client initialized inside the middleware function.
│     failure:     New connection on every request under load causes pool exhaustion.
│     alternative: Initialize once at module load and inject as a dependency.
│     question:    What is the expected RPS and how many middleware instances run concurrently?

── directive ─────────────────────────────────────────────
│ Before merging: move rate limiting before auth so unauthenticated request floods
│ don't bypass it entirely.

  verdict  MERGE AFTER FIXES
```
