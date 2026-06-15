---
name: debug
description: Systematically debug a failing test, error, or unexpected behavior — reproduce, isolate root cause, fix minimally, verify. Use when the user says "debug", "fix this bug", "it's broken", "this is failing", "why is this happening", or shares an error message, stack trace, or failing test output.
---

# Debug

Reproduce → isolate → fix → verify. Never guess at a fix before reproducing the problem.

## 1. Reproduce

Get a reliable reproduction before touching any code:

```bash
# Run the failing test / command the user described
<test or command>
```

If you can't reproduce it, stop and ask for more context — environment, input, frequency. A fix you can't verify is a guess.

## 2. Isolate Root Cause

Work inward from the symptom to the cause. Don't fix the first thing that looks suspicious.

- Read the full stack trace top to bottom — the root cause is usually near the bottom, not the top
- Add temporary logging or assertions to confirm your hypothesis before changing code
- If multiple things look wrong, pick the deepest one — surface symptoms often disappear when the root is fixed
- Check recent commits if the bug is a regression: `git log --oneline -20`, `git bisect` if needed

State your hypothesis explicitly before writing any fix:
> "Root cause: `<what>` because `<why>`."

## 3. Fix Minimally

- Change only what's needed to fix the root cause
- Don't refactor, rename, or clean up adjacent code while fixing — that's a separate `refactor` session
- If the fix requires a larger structural change, note it and fix the symptom for now

## 4. Verify

```bash
# Re-run the reproduction case — must pass
<test or command>

# Run the full test suite — must not regress
<full test command>
```

If the full suite reveals new failures your fix introduced, address them before committing.

## 5. Regression Test

If no test caught this bug, add one that would have:

```bash
git add <test file> && git add -u && git commit -m "test: reproduce <bug summary>"
git add -u && git commit -m "fix: <root cause summary>"
```

Commit the failing test first (as a separate commit), then the fix. This makes the cause visible in history.

If adding a test isn't feasible (e.g. no test suite, integration-only bug), note why.

## 6. Report

```
Bug: <one-line description of what was wrong>
Root cause: <what caused it>
Fix: <what changed and why>
Verified: <test name or command that now passes>
Regression test: <added | not applicable — reason>
```
