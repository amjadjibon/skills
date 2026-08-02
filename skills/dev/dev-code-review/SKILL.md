---
name: dev-code-review
description: Review a diff, branch, or PR for correctness bugs, security issues, and simplification opportunities; findings to docs/<feature-name>/REVIEW.md. Trigger on "review this", "code review", "security review", "audit this", or after something is implemented and needs checking before merge.
argument-hint: "[lite|full|ultra]"
---

# Code Review

Review changes — correctness, security, simplicity — and write findings to `docs/<feature-name>/REVIEW.md`.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

Applies only if asked to also apply fixes; the review pass itself is unaffected.

- `lite` (default) — fixes on the current branch, one commit.
- `full` — fixes grouped by category (security, correctness, simplicity) into stacked branches/PRs.
- `ultra` — one fix agent per independent finding cluster in its own worktree, in parallel (dev-loop §3.C.2 mechanism), merged after.

## Artifact Location

Artifact paths below are relative to the artifact root: `docs/` by default, or wherever the user (or
`dev-loop`, which passes the one it resolved) points it. A gitignored or out-of-repo root means the
artifacts are scratch — write and read them as normal, but **never commit them**.

## 1. Identify What to Review

Review **one file at a time** — never load the full diff in one shot.

1. Stat: `git diff main...HEAD --stat` (or `--cached`, or `gh pr diff <number> --stat`).
2. Filter noise — exclude generated/vendored/lockfiles:
   ```bash
   git diff main...HEAD --name-only | grep -vE 'go\.sum|go\.mod|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|vendor/|\.pb\.go|\.pb\.ts|_generated\.|/__generated__/|dist/|\.min\.js'
   ```
3. Prioritise by risk, stop when context is limited: **1** auth/middleware/payment/crypto/permissions/migrations · **2** API handlers/DB queries/jobs/config · **3** business logic/services/models · **4** utilities/tests/docs.
4. Per file: `git diff main...HEAD -- <file>`. Record findings before loading the next file. If one file exceeds ~300 diff lines, chunk with `| head -300` then `| tail -n +301`.

Scope ambiguous (no branch, PR, or files named)? Ask first.

## 2. Feature Name

Branch name, PR title, or ask → `<feature-name>` for `docs/<feature-name>/REVIEW.md`.

## 3. Review Checklist

Only report real issues; apply language-appropriate standards.

**Correctness** — logic errors, off-by-one, unreachable code; missing error handling at boundaries (user input, external APIs, file I/O); race conditions; unguarded null/undefined; functions that silently succeed when they should fail.

**Async & concurrency** — unhandled rejections (`async` without `await`/`.catch()`); missing `await` on a result used immediately; sync I/O blocking the event loop; deadlocks; shared mutable state without synchronisation; async work in constructors; fire-and-forget tasks with no failure surface.

**Memory & resources** — unclosed files/connections/streams (`with`/`defer`/`finally`); event listeners without teardown; unbounded caches; large per-request allocations that could be pooled; goroutines blocked on channels no one closes.

**Security** — hardcoded secrets (Critical); unvalidated user input (paths, queries, shell args, uploads); command injection (`shell=True`, string-built commands); path traversal (`..`, absolute paths); tokens in `localStorage` instead of `httpOnly` cookies; missing CSRF/`SameSite`; missing rate limits on login/search/payment; unsanitised HTML render (XSS); `Access-Control-Allow-Origin: *` on credentialed endpoints; missing auth checks; stack traces/internals in responses; passwords/tokens/PII in logs.

**Performance & DB** — N+1 queries; missing indexes on `WHERE`/`JOIN`/`ORDER BY`; full table scans (`LIKE '%foo'`); `SELECT *`; unbounded results without pagination; multi-step writes without a transaction; eager loading unused relations.

**Simplicity & reuse** — duplicates existing utilities; single-use abstractions; functions doing more than one thing; dead code, unused imports; missing doc comments on non-obvious functions only. In `full`/`ultra`, or when the diff reads as over-built, run `dev-ponytail-review` over the same diff and fold its findings in here rather than re-deriving them.

**Test quality** (only when tests exist in the diff; missing tests → Low) — tests that can't fail (asserting constants, mocking the thing under test); happy-path-only; brittle assertions (error strings, timestamps, generated IDs); testing implementation not behaviour; no boundary cases (zero/empty/null/max); order- or state-dependent tests; new code paths with no coverage.

## 4. Severity

| Severity | Meaning |
|----------|---------|
| **Critical** | Security hole, data loss, crash in happy path |
| **High** | Likely bug or significant security risk |
| **Medium** | Correctness concern or violated best practice |
| **Low** | Cleanup — simplification, dead code, style |
| **Info** | Observation, no action |

## 5. Write REVIEW.md

Save to `docs/<feature-name>/REVIEW.md`. Overwriting a previous pass is intentional — REVIEW.md is always the latest review; per-iteration history lives in dev-loop's LOOP.md.

````markdown
---
date: <YYYY-MM-DD>
branch: <branch-name>
reviewer: Claude
verdict: <Approve | Request Changes | Block>
---

# Code Review: <feature-name>

## Verdict

**<Approve | Request Changes | Block>** — <one sentence>

## Summary

<2-4 sentences: what was reviewed, what was found, key theme>

## Findings

### [CRIT-001] <Title> *(Critical)*
**File**: `path/to/file.ext:42`
**Category**: Security | Correctness | Simplicity
**Issue**: <what is wrong and why it matters>
**Fix**: <concrete suggestion or corrected snippet>

<!-- [HIGH-001], [MED-001], [LOW-001], [INFO-001] — same shape; skip empty severities -->

## What's Good

<1-3 specifics, no generic praise>

## Pre-Merge Checklist

- [ ] All Critical and High findings resolved
- [ ] No secrets in committed files; `.gitignore` covers new artifact types
- [ ] Tests cover changed behaviour + at least one unhappy path
- [ ] All async calls awaited or errors handled; resources closed in all paths
- [ ] If auth/user data: httpOnly tokens, CSRF protection, rate limits, no sensitive data in errors/logs
- [ ] If uploads: server-side size limit, MIME/extension allowlist, sanitised filenames

## Machine-Readable Verdict

```yaml
verdict: <Approve | Request Changes | Block>
critical: <N>
high: <N>
medium: <N>
low: <N>
info: <N>
blocking_ids: [<CRIT-001>, <HIGH-002>]
```
````

The Machine-Readable Verdict block is **always** last — dev-loop parses it. `Approve` = no Critical/High · `Request Changes` = Medium only · `Block` = any Critical/High; `blocking_ids` lists every Critical/High ID.

## 6. Report to Caller

```
Review written to docs/<feature-name>/REVIEW.md
Verdict: <Approve | Request Changes | Block>
Findings: <N> critical, <N> high, <N> medium, <N> low
```

Call out Critical findings explicitly.

## Principles

- Only real issues — false positives erode trust faster than missed findings.
- Every finding needs file:line and a why. "Input not validated" is useless; "line 47 passes `filename` to `open()` without stripping `..`" is actionable.
- One finding per issue. Don't review what wasn't changed — pre-existing problems are Info or skipped.
