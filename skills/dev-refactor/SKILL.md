---
name: dev-refactor
description: Refactor existing code without changing behavior — extract functions, reduce duplication, simplify logic, improve naming. Establishes a test baseline before touching anything and verifies equivalence after each change. Use when the user says "refactor this", "clean up", "simplify", "extract", "reduce duplication", "improve naming", or points at code and asks for structural improvement without new features.
argument-hint: "[lite|full|ultra]"
---

# Refactor

Improve code structure without changing observable behavior. Tests must pass before and after every change.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — squash all steps into one commit on the current branch.
- `full` — §3 as written: one commit per step, same branch.
- `ultra` — independent refactor targets (no shared files/types) each get their own branch + worktree, committed and PR'd separately, merged after tests pass.

## 1. Identify Scope

- If the user names a file, function, or module — use that.
- If the description is vague ("clean this up"), read the target and identify the specific smell: duplication, long function, unclear naming, deep nesting, etc. State what you're addressing before starting.

## 2. Establish Baseline

```bash
# Run the test suite — record the result
<test command>
```

If tests fail before you touch anything, stop and tell the user. Refactoring broken code hides bugs.

If the target code has no test coverage, note it explicitly:
> "No tests cover `<target>`. Changes are unverifiable — proceed anyway, or add tests first?"

In autonomous mode (called by `dev-loop`), proceed and note the gap; don't ask.

## 3. Refactor in Steps

Each step is one coherent change. Do not batch multiple refactors into one step.

For each step:
1. Make the change
2. Run tests — must still pass
3. If tests break, revert the step and explain why the refactor isn't safe as written
4. Commit — `full`: `git add -u && git commit -m "refactor: <what changed and why>"` after this step. `lite` (default): don't commit yet, continue to the next step; commit once at the end (§5) covering all steps.

**Rules:**
- Touch only what's needed for the refactor. Don't fix unrelated bugs or add features.
- Match the existing style — don't reformat the whole file.
- If you notice an unrelated issue, mention it; don't fix it inline.
- No behavior changes. If a refactor would change a side effect, edge case, or error message, stop and ask.

## 4. Common Refactor Patterns

Apply these when the code shows the smell — don't apply them speculatively.

| Smell | Refactor |
| ----- | -------- |
| Function > ~40 lines | Extract sub-functions with descriptive names |
| Same code in 2+ places | Extract shared utility; don't abstract on first duplication |
| Nested conditionals > 3 levels | Early returns / guard clauses |
| Unclear variable/function names | Rename to express intent |
| Large parameter list (4+) | Group into a struct/object if they travel together |
| Boolean flags controlling flow | Split into two functions |
| Dead code | Delete it |

## 5. Commit & Report

Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.

`lite` (default): `git add -u && git commit -m "refactor: <summary of all steps>"` — one commit for everything. `full`: already committed per step in §3; nothing left to commit here.

```
Refactor complete: <target>
Steps: <N> (1 commit | N commits)
Tests: passing
Changes: <bullet list of what was restructured>
Behavior unchanged: <yes | note any edge cases you couldn't verify>
```

Push: only if a remote is configured and you're on a feature branch — `git push origin <branch>`. On `main`/`master`, ask before pushing. When called by `dev-loop`: don't push, the loop pushes after user approval.
