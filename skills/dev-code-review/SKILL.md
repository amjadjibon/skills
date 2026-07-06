---
name: dev-code-review
description: Review code changes for correctness bugs, security issues, and simplification opportunities, then write findings to docs/<feature-name>/REVIEW.md. Use this skill whenever the user says "review this", "code review", "review my PR", "check this code", "security review", "audit this", or asks for feedback on a diff, branch, or set of files. Also trigger when the user has just finished implementing something and wants a quality check before merging.
argument-hint: "[lite|full|ultra]"
---

# Code Review

Review code changes — correctness, security, simplicity — and write findings to `docs/<feature-name>/REVIEW.md`.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Applies only if asked to also apply fixes — the review pass itself is unaffected.

- `lite` (default) — apply fixes on the current branch, one commit.
- `full` — group fixes by category (security, correctness, simplicity) into separate stacked branches/PRs.
- `ultra` — spawn one fix agent per independent finding cluster in its own worktree, in parallel (the mechanism `dev-loop` §3.C.2 uses), merge after.

## 1. Identify What to Review

Review **one file at a time** — never load the full diff in one shot.

**Step 1 — stat the diff:**

```bash
git diff main...HEAD --stat
# or: git diff --cached --stat
# or: gh pr diff <number> --stat
```

This gives a size overview with no diff content loaded yet.

**Step 2 — filter out noise files:**

Exclude generated, vendored, and dependency files — they are not worth reviewing:

```bash
git diff main...HEAD --name-only | grep -vE \
  'go\.sum|go\.mod|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|vendor/|\.pb\.go|\.pb\.ts|_generated\.|/__generated__/|dist/|\.min\.js'
```

**Step 3 — prioritise by risk:**

Review in this order — stop when time/context is limited:

| Priority | Path patterns |
|----------|--------------|
| 1 — Critical | auth, middleware, payment, crypto, permissions, migrations |
| 2 — High | API handlers, DB queries, background jobs, config loading |
| 3 — Medium | business logic, services, models |
| 4 — Low | utilities, helpers, tests, docs |

**Step 4 — review each file with reduced context lines:**

```bash
git diff main...HEAD --unified=3 -- <file>
# or: git diff --cached --unified=3 -- <file>
```

`--unified=3` loads 3 context lines per hunk instead of the default 10 — cuts diff size by ~30% on average.

Read, record findings, move to the next file. Do not load the next file until findings for the current one are noted.

**Step 5 — handle oversized files:** If a single file's diff still exceeds ~300 lines, review hunk by hunk using `git diff --unified=3 -- <file> | head -300` then `| tail -n +301`.

If scope is ambiguous (no branch, no PR number, no files named), ask before proceeding.

## 2. Determine the Feature Name

Use the branch name, PR title, or ask. This becomes `<feature-name>` in `docs/<feature-name>/REVIEW.md`.

## 3. Review Checklist

Work through each category. Only report real issues. Apply language-appropriate standards.

### Correctness
- Logic errors, off-by-one, wrong conditions, unreachable code
- Missing error handling at boundaries (user input, external APIs, file I/O)
- Race conditions or unsafe concurrency
- Incorrect types, null/undefined unguarded
- Functions that silently succeed when they should fail

### Async & Concurrency
- **Unhandled rejections** — `async` calls without `await`/`.catch()`
- **Blocking event loop** — sync I/O inside async code
- **Missing await** — omitted `await` on a call whose result is used immediately after
- **Deadlocks** — mutual lock dependencies
- **Shared mutable state** — written by multiple goroutines/threads without synchronisation
- **Async in constructors** — no way to await or cancel the work
- **Fire-and-forget** — background tasks with no mechanism to surface failures

### Memory & Resource Management
- **Unclosed resources** — files, connections, streams without `with`/`defer`/`finally`
- **Event listener leaks** — added without removal on teardown
- **Circular references** — preventing GC in caches or graph structures
- **Unbounded caches** — maps/lists with no eviction or size cap
- **Large allocations in hot paths** — buffers allocated on every request that could be pooled
- **Goroutine leaks** (Go) — goroutines blocked on a channel no one will close

### Security
- **Secrets in code** — hardcoded API keys, passwords, tokens — Critical
- **Input validation** — user-controlled data used without validation (paths, queries, shell args, file uploads)
- **Command injection** — `shell=True` or string interpolation into shell commands
- **Path traversal** — user-supplied filenames without sanitising `..` or absolute paths
- **Auth token storage** — tokens in `localStorage`/`sessionStorage` (XSS-vulnerable) instead of `httpOnly` cookies
- **CSRF** — state-changing endpoints missing CSRF token or `SameSite` protection
- **Rate limiting** — missing on login, search, payment, or other expensive endpoints
- **XSS** — user-provided HTML rendered without sanitisation; missing CSP on new endpoints
- **CORS** — `Access-Control-Allow-Origin: *` on credentialed or sensitive endpoints
- **Missing auth checks** — operations that expose/change data without permission verification
- **Error messages leaking internals** — stack traces, credentials, or paths in responses
- **Sensitive data logged** — passwords, tokens, PII in logs

### Performance & Database
- **N+1 queries** — query inside a loop; always Medium or High depending on scale
- **Missing indexes** — `WHERE`/`JOIN`/`ORDER BY` on unindexed columns
- **Full table scans** — `SELECT` without usable `WHERE`, or `LIKE '%foo'`
- **`SELECT *`** — fetches unused columns; fragile
- **Missing pagination** — unbounded results from user-controlled filters
- **No transaction on multi-step writes** — partial failure leaves inconsistent state
- **Eager loading when lazy is sufficient** — all relations fetched when only a subset is used

### Simplicity & Reuse
- Code duplicating existing utilities
- Abstractions introduced for a single use case
- Functions doing more than one thing
- Dead code, unused imports, unread variables
- Multi-line expressions that could be one line without losing clarity
- Missing doc comments on non-obvious functions (don't flag self-explanatory ones)

### Test Quality

Only flag when tests exist in the diff. Missing tests → Low finding, not a blocker.

- **Tests that always pass** — asserting constants, mocking the thing under test
- **No unhappy-path coverage** — only success case tested
- **Brittle assertions** — on error strings, timestamps, or auto-generated IDs
- **Testing implementation not behaviour** — breaks on rename without behaviour change
- **Missing boundary tests** — zero, empty, null, max for numeric conditions
- **Test isolation** — depends on execution order, shared state, or external services
- **No coverage of the new code path** — new branch or error handler with no test

## 4. Severity Levels

| Severity | Meaning |
|----------|---------|
| **Critical** | Must fix — security hole, data loss, crash in happy path |
| **High** | Should fix — likely bug or significant security risk |
| **Medium** | Fix soon — correctness concern or violated best practice |
| **Low** | Cleanup — simplification, dead code, minor style |
| **Info** | Observation — no action required |

## 5. Write REVIEW.md

Save to `docs/<feature-name>/REVIEW.md`:

```markdown
---
date: <YYYY-MM-DD>
branch: <branch-name>
reviewer: Claude
verdict: <Approve | Request Changes | Block>
---

# Code Review: <feature-name>

## Verdict

**<Approve | Request Changes | Block>** — <one sentence summary>

## Summary

<2-4 sentences: what was reviewed, what was found, key theme>

## Findings

### [CRIT-001] <Title> *(Critical)*
**File**: `path/to/file.ext:42`
**Category**: Security | Correctness | Simplicity
**Issue**: <What is wrong and why it matters>
**Fix**: <Concrete suggestion or corrected code snippet>

---

### [HIGH-001] <Title> *(High)*
...

### [MED-001] <Title> *(Medium)*
...

### [LOW-001] <Title> *(Low)*
...

## What's Good

<1-3 specific bullet points — no generic praise>

## Pre-Merge Checklist

**Always:**
- [ ] All Critical and High findings resolved
- [ ] No secrets or credentials in committed files
- [ ] `.gitignore` covers new artifact/config types
- [ ] Tests cover changed behaviour and at least one unhappy path
- [ ] All async calls awaited or errors handled
- [ ] Resources closed in all code paths

**If auth, sessions, or user data:**
- [ ] Tokens in `httpOnly` cookies, not `localStorage`
- [ ] CSRF protection on state-changing endpoints
- [ ] Rate limiting on login, signup, payment, search
- [ ] No sensitive data in error responses or logs

**If file uploads:**
- [ ] Size limit enforced server-side
- [ ] MIME type and extension allowlist validated
- [ ] User-supplied filenames never used directly in storage paths
```

Finding numbering: `CRIT-`, `HIGH-`, `MED-`, `LOW-`, `INFO-` with zero-padded sequence numbers per severity. Skip sections with no findings.

## 6. Machine-Readable Verdict Block

**Always** append at the very end of `REVIEW.md` — parsed by `dev-loop`:

```markdown
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
```

Rules:
- `Approve` → no Critical or High
- `Request Changes` → Medium only, no Critical/High
- `Block` → any Critical or High
- `blocking_ids` lists every Critical and High ID for `dev-loop`

## 7. Report to Caller

```
Review written to docs/<feature-name>/REVIEW.md
Verdict: <Approve | Request Changes | Block>
Findings: <N> critical, <N> high, <N> medium, <N> low
```

If Critical findings exist, call them out explicitly.

## Review Principles

- **Only report real issues.** False positives erode trust faster than missed findings.
- **Be specific.** Every finding needs file and line number. "Input not validated" → useless. "Line 47 passes `filename` to `open()` without stripping `..`" → actionable.
- **One finding per issue.**
- **Explain the why.** The issue description should make the risk obvious without follow-up.
- **Don't review what wasn't changed.** Pre-existing problems → Info finding or skip.
