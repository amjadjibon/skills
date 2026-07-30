---
name: dev-refactor
description: Refactor existing code without changing behavior — extract functions, reduce duplication, simplify logic, improve naming, against a test baseline taken before and verified after. Use on "refactor this", "clean up", "simplify", "extract", "reduce duplication", "improve naming", or a request for structural improvement without new features.
argument-hint: "[lite|full|ultra]"
---

# Refactor

Improve structure without changing observable behavior. Tests pass before and after every change.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — all steps squashed into one commit on the current branch.
- `full` — one commit per step, same branch.
- `ultra` — independent targets (no shared files/types) each get their own branch + worktree + PR.

## 1. Scope

Named target → use it. Vague ("clean this up") → read the code, name the specific smell (duplication, long function, deep nesting), state it before starting.

## 2. Baseline

Run the test suite; record the result. **Failing before you touch anything → stop and tell the user** — refactoring broken code hides bugs. No coverage on the target → "No tests cover `<target>`. Proceed anyway, or add tests first?" (autonomous mode: proceed, note the gap).

## 3. Refactor in Steps

One coherent change per step: make it → tests pass → (`full`: commit `refactor: <what and why>`; `lite`: hold, commit once at the end). Tests break → revert the step, explain why it isn't safe as written.

Rules: touch only what the refactor needs; match existing style — no whole-file reformats; mention unrelated issues, don't fix inline; **no behavior changes** — a refactor that would alter a side effect, edge case, or error message stops and asks.

## 4. Patterns (apply on the smell, never speculatively)

| Smell | Refactor |
| ----- | -------- |
| Function > ~40 lines | Extract named sub-functions |
| Same code 2+ places | Extract shared utility (not on first duplication) |
| Nesting > 3 levels | Early returns / guard clauses |
| Unclear names | Rename to intent |
| 4+ params traveling together | Group into struct/object |
| Boolean flag controlling flow | Split into two functions |
| Dead code | Delete |

## 5. Commit & Report

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

`lite`: `git add -u && git commit -m "refactor: <summary of all steps>"`. `full`: already committed per step.

Push: only if a remote is configured and you're on a feature branch. On `main`/`master`, ask first. Called by `dev-loop`: don't push — the loop pushes after approval.

Report: target, step count, tests passing, what was restructured, "behavior unchanged" (note any unverifiable edge cases).
