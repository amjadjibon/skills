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

Work through each category. Not every category will have findings — that's fine. Only report real issues, not invented ones.

### Correctness
- Logic errors, off-by-one, wrong conditions, unreachable code
- Missing error handling at system boundaries (user input, external APIs, file I/O)
- Race conditions or unsafe concurrency
- Incorrect types, null/undefined not guarded where needed
- Functions that silently succeed when they should fail

### Security
- **Secrets in code**: hardcoded API keys, passwords, tokens — flag immediately, severity Critical
- **Input validation**: user-controlled data used without validation (paths, queries, shell args)
- **Command injection**: `shell=True`, string interpolation into shell commands
- **Path traversal**: user-supplied filenames used without sanitising `..` or absolute paths
- **Error messages leaking internals**: stack traces, credentials, or system paths in responses
- **Dependency issues**: obviously outdated or known-vulnerable packages
- **Sensitive data logged**: passwords, tokens, PII written to logs

### Simplicity & Reuse
- Code that duplicates existing utilities in the codebase
- Abstractions added for a single use case
- Functions doing more than one thing
- Dead code, unused imports, variables introduced but never read
- Unnecessary complexity that a senior engineer would flatten

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

- [ ] All Critical and High findings resolved
- [ ] No secrets or credentials in committed files
- [ ] Tests cover the changed behaviour
- [ ] `.gitignore` updated if new artifact types were introduced
```

**Finding numbering:** Use `CRIT-`, `HIGH-`, `MED-`, `LOW-`, `INFO-` prefixes with zero-padded sequence numbers per severity level. Skip severity sections with no findings.

## 6. Report to User

After writing the file, tell the user:

```
Review written to docs/<feature-name>/REVIEW.md
Verdict: <Approve | Request Changes | Block>
Findings: <N> critical, <N> high, <N> medium, <N> low
```

If there are Critical findings, call them out explicitly in the message — don't bury them in the file.

## 7. Language-Specific Standards

Detect the primary language from the diff and apply the relevant standards below as an additional lens on top of the general checklist. You don't need to report every violation — use these to calibrate what "good" looks like and raise findings where deviations cause real harm.

### Python — PEP 8 + PEP 20
**PEP 20 (Zen of Python)** — the principles that matter most in review:
- Explicit is better than implicit — flag magic values, implicit truthiness on non-booleans, and unexplained defaults
- Simple is better than complex; flat is better than nested — raise findings where nesting exceeds 3 levels or a function could be split
- Errors should never pass silently — bare `except:` or `except Exception: pass` is always a finding
- If the implementation is hard to explain, it's a bad idea — flag functions that require a paragraph to describe

**PEP 8** — only flag deviations that hurt readability or cause bugs:
- Mutable default arguments (`def f(x=[])`) — bug, not style
- Shadowing builtins (`list`, `id`, `type`) — correctness risk
- Wildcard imports (`from module import *`) — obscures dependencies
- Unused imports left in — dead code

**Python security additions:**
- `subprocess` with `shell=True` — command injection, flag Critical
- `pickle.loads` on untrusted data — arbitrary code execution, flag Critical
- `eval()`/`exec()` on user input — Critical
- File paths from user input without `Path.resolve()` and base-dir check — High

---

### Go — Effective Go + Go Code Review Comments
- Errors must be handled — ignoring `err` with `_` in non-trivial paths is a finding
- Goroutine leaks — goroutines started without a clear exit path
- `defer` in loops — executes at function return, not loop iteration
- Interface pollution — interfaces defined with only one concrete implementation and no tests
- `init()` side effects — flag if `init()` does I/O, network calls, or panics

---

### TypeScript / JavaScript — TC39 + Airbnb conventions
- `any` type without a comment explaining why — defeats type safety
- Non-null assertions (`!`) on values that could genuinely be null — correctness risk
- `console.log` / `debugger` left in — always a Low finding
- `==` instead of `===` — flag in non-trivial comparisons
- Unhandled promise rejections — floating `async` calls without `await` or `.catch()`
- `eval()` or `new Function()` on user input — Critical

---

### SQL (any language)
- String interpolation into queries — SQL injection, always Critical
- `SELECT *` in application code — fragile, flag as Low
- Missing transaction boundaries for multi-step writes — High if partial failure leaves inconsistent state

---

### Shell / Bash
- Variables unquoted in expansions (`$var` vs `"$var"`) — word splitting bug
- `rm -rf` with a variable path without null-guard — data loss risk, High
- Pipelines that swallow exit codes — `set -o pipefail` missing
- Hardcoded credentials anywhere in scripts — Critical

---

### Universal (all languages)
Apply these regardless of language, in addition to the general checklist:

**OWASP Top 10 (most commonly surfaced in review):**
- A01 Broken Access Control — endpoints or functions missing auth/permission checks
- A02 Cryptographic Failures — sensitive data unencrypted at rest or in transit, weak algorithms (MD5, SHA1 for security purposes)
- A03 Injection — SQL, shell, LDAP, template injection via unsanitised input
- A07 Identification and Authentication Failures — tokens stored insecurely, sessions not invalidated
- A09 Security Logging Failures — sensitive operations not logged, or secrets logged

**General principles (language-agnostic):**
- Single Responsibility — flag functions that do unrelated things
- Don't Repeat Yourself — flag copy-pasted logic that belongs in a shared utility
- Fail fast — functions that accept invalid input and silently produce wrong output
- Principle of Least Privilege — code requesting broader permissions/access than it needs

## Review Principles

- **Only report real issues.** If you're not confident something is a bug, say so or don't report it. False positives erode trust faster than missed findings.
- **Be specific.** Every finding needs a file and line number. "Input is not validated" is useless. "Line 47 passes `filename` directly to `open()` without stripping `..`" is actionable.
- **One finding per issue.** Don't split one problem into three findings to pad the list.
- **Explain the why.** A developer reading the review shouldn't have to ask why something matters — the issue description should make it obvious.
- **Don't review what wasn't changed.** If pre-existing code has problems, note them in Info findings or skip them — the review is of the diff, not the whole codebase.
