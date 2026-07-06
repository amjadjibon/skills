---
name: dev-debug
description: Systematically debug a failing test, error, or unexpected behavior — reproduce, isolate root cause, fix minimally, verify. Use when the user says "debug", "fix this bug", "it's broken", "this is failing", "why is this happening", or shares an error message, stack trace, or failing test output.
argument-hint: "[lite|full|ultra]"
---

# Debug

Reproduce → isolate → fix → verify. Never guess at a fix before reproducing.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — one commit: test + fix together.
- `full` — regression test committed separately before the fix (cause visible in history).
- `ultra` — reproduce and fix in an isolated worktree when the bug touches shared/risky state; merge once verified.

## 1. Reproduce

Get a reliable reproduction before touching code. Can't reproduce → stop, ask for environment/input/frequency. A fix you can't verify is a guess.

## 2. Isolate Root Cause

Work from symptom inward — don't fix the first suspicious thing:

- Read the full stack trace; the root cause is usually near the bottom.
- Confirm the hypothesis with temporary logging/assertions before changing code.
- Multiple suspects → pick the deepest; surface symptoms vanish when the root is fixed.
- Regression? `git log --oneline -20`, `git bisect` if needed.

State it before fixing: "Root cause: `<what>` because `<why>`."

## 3. Fix Minimally

Change only what the root cause requires. No adjacent refactoring/renames — that's a `dev-refactor` session. If the real fix needs structural change, note it and fix the symptom for now.

## 4. Verify

Re-run the reproduction (must pass) and the full suite (must not regress). New failures your fix introduced → address before committing.

## 5. Regression Test

If no test caught this bug, add one that would have. Not feasible (no suite, integration-only) → note why.

Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.

`lite`: `git add <test file> && git add -u && git commit -m "fix: <root cause> (with regression test)"`.
`full`: `git commit -m "test: reproduce <bug>"` first, then `git commit -m "fix: <root cause>"`.

## 6. Report

Bug (one line) · root cause · fix (what and why) · verified by (test/command) · regression test (added | n/a — reason).
