---
name: dev-implement-plan
description: Execute an implementation plan from docs/<feature-name>/PLAN.md created by dev-create-plan — tick checkboxes, commit each phase. Trigger on "implement/execute/continue/resume the plan", "start phase 1", "go" right after a plan was created, or whenever there is a PLAN.md to build, even if the user never says "plan".
argument-hint: "[lite|full|ultra]"
---

# Implement Plan

Execute a `PLAN.md`: phases in order, tick checkboxes as tasks complete, commit each phase. The plan file stays an accurate progress record — anyone interrupted mid-plan must be able to resume from it alone.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — ignore phase boundaries: one branch, one implementation commit (plus the plan-status docs commits), one PR at the end.
- `full` — one branch + one stacked PR per phase (§3).
- `ultra` — phases marked `**Parallel**: yes` build in separate worktrees simultaneously; merge each into the stack when its completion criteria pass.

## Execution Principles

**Simplicity ladder** — stop at the first rung that satisfies the task: (1) doesn't need to exist → skip, note why; (2) stdlib/platform covers it; (3) already-installed dependency; (4) one function or one line; (5) only then minimum custom code.

**Defensive error handling — never simplify away.** Handle or explicitly propagate every error. Validate at trust boundaries (user input, external APIs, file I/O, env vars). Fail fast; close resources in all paths.

**Surgical changes.** Touch only what the task requires; match existing style; mention unrelated issues, don't fix them. Every changed line traces to the current task.

**Don't guess at externals.** Blocked on how a third-party API/library actually behaves → check `docs/<feature-name>/research/`, else spawn a research sub-agent (subagent type `dev-researcher` when available, else general-purpose with the template in dev-research §6) and implement from its findings; commit the topic file with the phase.

## 1. Locate the Plan

Named feature → `docs/<feature-name>/PLAN.md`; else `ls docs/*/PLAN.md` (prefer `status: 'In progress'`; several candidates → ask). None → offer `dev-create-plan`.

## 2. Pre-flight

Read the entire plan first.

1. **`status`**: `Planned` → fresh start · `In progress` → resume (§5) · `Completed`/`Deprecated` → stop and confirm · `On Hold` → ask.
2. **Sync** (only if a remote exists): `git fetch origin`, rebase onto `origin/main`. **Never rebase when phase branches are already pushed** (`git ls-remote --heads origin '<feature-name>/phase-*'` returns anything) — that rewrites the stacked PRs; warn and continue unrebased.
3. **Working copy clean?** Uncommitted unrelated changes contaminate phase commits — warn.
4. **Mark started** in its own commit: `status: 'In progress'`, `last_updated`, badge → `docs: start <feature-name> implementation`.

## 3. Phase Execution

`lite` (default): stay on one branch `<feature-name>`, tick checkboxes and run completion criteria per phase, but commit and push once at the end (§8). `full`: per phase —

```
1. git checkout -b <feature-name>/phase-<N>      # base = previous phase or main
2. Execute each task; tick its checkbox immediately (same phase commit)
3. Verify completion criteria — run the command, don't assume
4. git add -u && git commit -m "<type>: <phase summary>"   # new files: explicit paths
5. git push -u origin <feature-name>/phase-<N>
   gh pr create --base <previous-branch-or-main> --title "<imperative ≤60 chars>" \
     --body "<phase Goal + task list + completion criteria>"
6. Next phase branches off this one
```

Rules:
- Never tick a box for unverified work. Completion criteria are gates — fix before committing.
- Use the plan's commit message; if it no longer fits, write an accurate one and note the deviation (§6).
- Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.
- Check `git status` before staging — no build output or `.env`.
- Tasks are sequential unless genuinely independent domains with no shared types/fixtures.
- Keep history linear — rebase, not merge.

## 4. Blocked Tasks

Resolved differently: tick and note inline — `> Blocked: <reason>. Resolved by: <what was done>.` Unresolvable: leave unchecked with `> Blocked: <reason>.`, stop and ask. If it invalidates later tasks, update the plan (§6) first.

## 5. Resuming

First unchecked `- [ ] TASK-` is the resume point. Cross-check `git log --oneline` — if checkboxes and commits disagree, trust history, fix checkboxes, tell the user. Check `git status` for partial work.

## 6. Plan Deviations

Reality wins. Update PLAN.md in its own commit (`docs: update plan for <feature-name>`) — never buried in implementation commits. New tasks continue `TASK-NNN` numbering; bump `last_updated` and `version`.

## 7. Testing Section

Run/write each `TEST-NNN`, tick its box. Tests in a phase's criteria tick with that phase; otherwise final phase: `git add -u && git commit -m "test: <feature-name>"`.

## 8. Completion

All boxes ticked (or blocked with user sign-off):

1. `status: 'Completed'`, `last_updated`, badge.
2. `full`: commit `docs: complete <feature-name> plan` on the last phase branch (PRs already open). `lite`: same commit on `<feature-name>`, then `git push -u origin <feature-name> && gh pr create --base main --title "<imperative ≤60 chars>" --body "<summary + tasks + criteria>"`.

Report: plan path, phase count, PR URL(s) (`full`: one per phase with bases — merge phase-1 first, GitHub auto-retargets), deviations, what was run to verify.

No remote → skip pushes, say the branch is ready locally. Interrupted → leave `In progress`, tick finished tasks, commit partial work, say where to resume.
