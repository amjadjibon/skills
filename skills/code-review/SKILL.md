---
name: code-review
description: Review code changes for correctness bugs, security issues, and simplification opportunities, then write findings to docs/<feature-name>/REVIEW.md. Use this skill whenever the user says "review this", "code review", "review my PR", "check this code", "security review", "audit this", or asks for feedback on a diff, branch, or set of files. Also trigger when the user has just finished implementing something and wants a quality check before merging.
---

# Code Review

Perform a thorough review of code changes — correctness, security, and simplicity — and write findings to `docs/<feature-name>/REVIEW.md`.

## 1. Identify What to Review

- **Branch diff**: `git diff main...HEAD` (or `git diff <base>...<head>`)
- **Staged changes**: `git diff --cached`
- **Specific files**: read the files the user named
- **PR number**: `gh pr diff <number>`

If the scope is ambiguous, ask before reviewing. A review of the wrong thing wastes everyone's time.

## 2. Determine the Feature Name

Use the current branch name, PR title, or ask the user. This becomes `<feature-name>` in `docs/<feature-name>/REVIEW.md`. Create the directory if it doesn't exist.

## 3. Review Checklist

Work through each category. Not every category will have findings — that's fine. Only report real issues, not invented ones. Apply language-appropriate standards (e.g. RLS on Supabase tables, wallet signature verification on Solana).

### Correctness
- Logic errors, off-by-one, wrong conditions, unreachable code
- Missing error handling at system boundaries (user input, external APIs, file I/O)
- Race conditions or unsafe concurrency
- Incorrect types, null/undefined not guarded where needed
- Functions that silently succeed when they should fail

### Async & Concurrency
- **Unhandled rejections** — `async` functions called without `await` or `.catch()`; errors silently swallowed
- **Blocking the event loop** — synchronous I/O (`fs.readFileSync`, `time.sleep`) inside async/concurrent code
- **Missing await** — `await` omitted on an async call whose result is used immediately after; subtle race
- **Deadlocks** — two coroutines/goroutines/threads each waiting for a lock the other holds
- **Shared mutable state without synchronisation** — variables written by multiple goroutines/threads without a mutex or channel
- **Async in constructors** — constructors or `__init__` that start async work with no way to await or cancel it
- **Fire-and-forget without error handling** — background tasks spawned with no mechanism to surface failures

### Memory & Resource Management
- **Unclosed resources** — files, DB connections, sockets, streams opened without `with`/`defer`/`finally` to guarantee close
- **Event listener leaks** — listeners added in a component/hook with no corresponding removal on teardown
- **Circular references** — objects that reference each other preventing garbage collection (common in caches and graph structures)
- **Unbounded caches or collections** — maps/lists that grow indefinitely with no eviction or size cap
- **Large allocations in hot paths** — buffers or slices allocated on every request/loop iteration that could be pooled or reused
- **Goroutine leaks** (Go) — goroutines that block forever on a channel no one will close

### Security
- **Secrets in code**: hardcoded API keys, passwords, tokens — flag immediately, severity Critical
- **Input validation**: user-controlled data used without validation (paths, queries, shell args); file uploads missing size/type/extension checks
- **Command injection**: `shell=True`, string interpolation into shell commands
- **Path traversal**: user-supplied filenames used without sanitising `..` or absolute paths
- **Auth token storage**: tokens in `localStorage` or `sessionStorage` are XSS-vulnerable — must use `httpOnly` cookies with `Secure; SameSite=Strict`
- **CSRF**: state-changing endpoints missing CSRF token verification or `SameSite` cookie protection
- **Rate limiting**: expensive or sensitive endpoints (login, search, payment) with no rate limiting
- **XSS**: user-provided HTML rendered without sanitisation; missing Content Security Policy on new endpoints
- **CORS**: overly permissive `Access-Control-Allow-Origin: *` on credentialed or sensitive endpoints
- **Missing authorisation checks**: operations that change or expose data without verifying the caller has permission
- **Error messages leaking internals**: stack traces, credentials, or system paths in responses
- **Dependency issues**: obviously outdated or known-vulnerable packages
- **Sensitive data logged**: passwords, tokens, PII written to logs

### Performance & Database
- **N+1 queries** — a query inside a loop that could be a single batched query; always a Medium or High depending on scale
- **Missing indexes** — `WHERE`, `JOIN`, `ORDER BY` on columns with no index and non-trivial table size; flag the column and suggest the index
- **Full table scans** — `SELECT` without a `WHERE` clause, or a `WHERE` that can't use an index (e.g. `LIKE '%foo'`, function on indexed column)
- **`SELECT *` in application code** — fetches columns the code never uses; fragile and wasteful
- **Missing pagination** — queries that can return unbounded rows from user-controlled filters
- **No transaction on multi-step writes** — partial failure leaves the database in an inconsistent state
- **Eager loading when lazy is sufficient** — fetching all relations upfront when only a subset is ever accessed

### Simplicity & Reuse
- Code that duplicates existing utilities in the codebase
- Abstractions added for a single use case
- Functions doing more than one thing
- Dead code, unused imports, variables introduced but never read
- Unnecessary complexity that a senior engineer would flatten
- **Too much verbosity** — multi-line expressions that could be one line without losing clarity; over-commented code that restates what the variable name already says; wrapper functions that add no logic
- **Missing function/method documentation** — flag when a function's purpose, parameters, or return value are non-obvious and there is no doc comment; do not flag trivially self-explanatory functions

### Test Quality
Only flag test issues when tests exist in the diff. Don't demand tests for code that doesn't include them — raise that as a Low finding, not a blocker.

- **Tests that always pass** — assertions on constants, `assert True`, mocking the thing under test so nothing real runs
- **No unhappy-path coverage** — tests cover only the success case; invalid input, missing data, and error responses untested
- **Brittle assertions** — tests that assert on exact error message strings, timestamps, or auto-generated IDs that will change
- **Testing implementation, not behaviour** — tests that break when internal variable names or private methods change but the observable output stays the same
- **Missing boundary tests** — off-by-one inputs, empty collections, zero, null/None, max values — especially for functions with numeric conditions
- **Test isolation** — tests that depend on execution order, shared mutable state, or external services without mocking
- **No coverage of the changed code path** — the diff adds a new branch or error handler with no test that exercises it; flag as Medium

## 4. Severity Levels

| Severity | Meaning |
|----------|---------|
| **Critical** | Must fix before merge — security hole, data loss, crash in happy path |
| **High** | Should fix before merge — likely bug or significant security risk |
| **Medium** | Fix soon — correctness concern or security best practice violated |
| **Low** | Cleanup — simplification, dead code, minor style |
| **Info** | Observation only — no action required |

## 5. Write REVIEW.md

Save to `docs/<feature-name>/REVIEW.md`. Use this structure:

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

> - Approve: no blocking issues; minor findings noted below if any
> - Request Changes: fixable issues that should be resolved before merge
> - Block: critical issue (security hole, data loss) — do not merge until resolved

## Summary

<2-4 sentences: what was reviewed, what was found overall, key theme of feedback>

## Findings

### [CRIT-001] <Title> *(Critical)*
**File**: `path/to/file.ext:42`
**Category**: Security | Correctness | Simplicity
**Issue**: <What is wrong and why it matters>
**Fix**: <Concrete suggestion or corrected code snippet>

---

### [HIGH-001] <Title> *(High)*
...

---

### [MED-001] <Title> *(Medium)*
...

---

### [LOW-001] <Title> *(Low)*
...

---

## What's Good

<1-3 bullet points on things done well — specific, not generic praise>

## Pre-Merge Checklist

**Always:**
- [ ] All Critical and High findings resolved
- [ ] No secrets or credentials in committed files
- [ ] `.gitignore` covers new artifact/config types introduced
- [ ] Tests cover the changed behaviour and at least one unhappy path
- [ ] All async calls awaited or errors handled
- [ ] Resources (files, connections, streams) closed in all code paths

**If this touches auth, sessions, or user data:**
- [ ] Tokens in `httpOnly` cookies, not `localStorage`
- [ ] CSRF protection on state-changing endpoints
- [ ] Rate limiting on login, signup, payment, and search endpoints
- [ ] No sensitive data in error responses or logs

**If this touches file uploads:**
- [ ] Size limit enforced server-side
- [ ] MIME type and extension allowlist validated
- [ ] User-supplied filenames never used directly in storage paths

**If this uses a database (Supabase / SQL):**
- [ ] Row Level Security enabled on all user-data tables
- [ ] All queries use parameterised inputs (no string interpolation)
- [ ] Multi-step writes wrapped in transactions

**If this is blockchain / Solana:**
- [ ] Wallet signatures verified before trusting identity
- [ ] Transaction recipient, amount, and balance validated before signing
```

**Finding numbering:** Use `CRIT-`, `HIGH-`, `MED-`, `LOW-`, `INFO-` prefixes with zero-padded sequence numbers per severity level. Skip severity sections with no findings.

## 6. Machine-Readable Verdict Block

**Always** append this block at the very end of `REVIEW.md`. It is parsed by `dev-loop` to make decisions without reading prose.

```markdown
## Machine-Readable Verdict

```yaml
verdict: <Approve | Request Changes | Block>
critical: <N>
high: <N>
medium: <N>
low: <N>
info: <N>
blocking_ids: [<CRIT-001>, <HIGH-002>]   # IDs of Critical/High findings; empty list if none
```
```

Rules:
- `verdict: Approve` → no Critical or High findings (Low/Info are fine)
- `verdict: Request Changes` → one or more Medium findings, no Critical/High
- `verdict: Block` → one or more Critical or High findings
- `blocking_ids` lists every Critical and High finding ID so `dev-loop` can reference them when writing fix tasks

## 7. Report to Caller

After writing the file, output:

```
Review written to docs/<feature-name>/REVIEW.md
Verdict: <Approve | Request Changes | Block>
Findings: <N> critical, <N> high, <N> medium, <N> low
```

If there are Critical findings, call them out explicitly — don't bury them in the file.

## Review Principles

- **Only report real issues.** If you're not confident something is a bug, say so or don't report it. False positives erode trust faster than missed findings.
- **Be specific.** Every finding needs a file and line number. "Input is not validated" is useless. "Line 47 passes `filename` directly to `open()` without stripping `..`" is actionable.
- **One finding per issue.** Don't split one problem into three findings to pad the list.
- **Explain the why.** A developer reading the review shouldn't have to ask why something matters — the issue description should make it obvious.
- **Don't review what wasn't changed.** If pre-existing code has problems, note them in Info findings or skip them — the review is of the diff, not the whole codebase.
