---
name: implement-plan
description: Execute an implementation plan from a docs/<feature-name>/PLAN.md file created by the create-plan skill. Trigger when the user says "implement the plan", "execute the plan", "run the plan", "work through the plan", "continue the plan", "resume the plan", "start phase 1", or points at any PLAN.md file and asks to build it. Also trigger when the user references a planned feature by name and wants implementation to begin, or when a plan was just created and the user says "go", "start", or "implement it". Use this skill whenever there is a PLAN.md to execute, even if the user doesn't say the word "plan".
---

# Implement Plan

Execute a `PLAN.md` produced by the `create-plan` skill: work through its phases in order, tick checkboxes as tasks complete, commit each phase with jj, and keep the plan file itself an accurate record of what actually happened.

The plan file is both the instruction set and the progress tracker. Someone (human or agent) interrupted mid-plan must be able to resume from the file alone — that's why checkbox updates and status changes happen *as you go*, never batched at the end.

## 1. Locate the Plan

- If the user names a plan or feature, use `docs/<feature-name>/PLAN.md`.
- Otherwise, find candidates: `ls docs/*/PLAN.md`. If exactly one exists, use it. If several exist, prefer the one with `status: 'In progress'`; if none are in progress, ask the user which to run.
- If no PLAN.md exists, say so and offer to create one with the `create-plan` skill instead of improvising.

## 2. Pre-flight

Read the entire plan before touching any code. Then:

1. **Check `status` in frontmatter:**
   - `Planned` → fresh start.
   - `In progress` → resume (see §5).
   - `Completed` / `Deprecated` → stop and confirm with the user; re-running a finished or abandoned plan is rarely intended.
   - `On Hold` → ask the user to confirm before resuming; it was paused for a reason that may still apply.
2. **Verify the repo uses jj** (`jj root` succeeds). If it's git-only, follow the same protocol but substitute commits: `git add -A && git commit -m "<message>"` wherever a jj command appears, and skip `jj new` (git commits implicitly seal work).
3. **Enforce linear history in git-only repos.** Before starting implementation, run:
   - `git fetch origin`
   - rebase current branch onto `origin/main` when it exists, otherwise `origin/master`
   - resolve conflicts before continuing; do not create merge commits for sync
4. **Check the working copy is clean enough to start** — uncommitted unrelated changes will get swept into phase commits. If `jj st` (or `git status`) shows unrelated dirty files, tell the user before proceeding.
5. **Mark the plan started.** In its own commit, before any implementation:
   - Set frontmatter `status: 'In progress'` and `last_updated: <today>`
   - Update the badge line to `![Status: In progress](https://img.shields.io/badge/status-In%20progress-yellow)`
   - Commit:
     - jj: `jj describe -m "docs: start <feature-name> implementation"` then `jj new`
     - git-only: `git add -A && git commit -m "docs: start <feature-name> implementation"`

## 3. Phase Execution Protocol

Phases run strictly in order — each phase's commit is the foundation the next builds on. For each phase:

```
1. jj repos: `jj new`                      # fresh commit for this phase (skip if one is already open)
   git-only repos: skip (`git commit` seals each phase implicitly)
2. Read the phase's tasks top to bottom
3. Execute each task; tick its checkbox immediately after it's done
4. Verify the phase's completion criteria — actually run the command/test, don't assume
5. Commit with the phase message from the plan's `**jj commit**` line:
   - jj: `jj describe -m "<type>: <phase summary>"`
   - git-only: `git add -A && git commit -m "<type>: <phase summary>"`
6. Move to the next phase
```

Rules that matter:

- **Tick checkboxes one at a time, in the plan file, as each task finishes.** The checkbox edit goes into the same phase commit as the work itself, so every commit shows exactly which tasks it contains. Never tick a box for work you haven't verified.
- **Use the commit message the plan specifies.** Each phase has a `**jj commit**:` line — use it verbatim. If the plan's message no longer describes what you actually did, write an accurate one instead and note the deviation (see §6).
- **Completion criteria are gates, not suggestions.** If the criteria say "all tests pass", run the tests and show the output. If criteria fail, fix the phase before describing the commit — don't carry broken work into the next phase.
- **Tasks within a phase are sequential by default**, but independent tasks (different files, no shared state) may be done in any order.
- **Keep git history linear.** In git-only repos, sync with upstream via rebase (`fetch` + `rebase`), not merge.

## 4. Blocked or Failing Tasks

When a task can't be completed as written (API doesn't exist, file moved, approach is wrong):

1. Don't silently skip it or invent a workaround without recording it.
2. Add an inline note below the checkbox, in the format the plan format defines:
   ```
   - [x] TASK-005: <original description>
     > Blocked: <reason>. Resolved by: <what was done instead>.
   ```
   If it's blocked with *no* resolution, leave the box unchecked, add `> Blocked: <reason>.`, and stop to ask the user — an unresolvable task usually means the plan needs revision, not heroics.
3. If the blockage invalidates later tasks, update the plan (see §6) before continuing.

## 5. Resuming a Plan In Progress

When `status` is `In progress`:

1. Find the first unchecked `- [ ] TASK-` checkbox — that's where to resume.
2. Cross-check against history: `jj log` (or `git log`) should show commits for already-completed phases. If checkboxes and commits disagree (boxes ticked but no commit, or vice versa), trust the code/history over the checkboxes, fix the checkboxes to match reality, and tell the user what you reconciled.
3. If resuming mid-phase, check whether an open working-copy commit already holds partial work for that phase before running `jj new`.

## 6. Plan Deviations

Reality wins over the plan. When implementation reveals the plan is wrong (missed dependency, better approach, changed requirement):

- Update `PLAN.md` to reflect reality **in its own commit**: `jj new` → edit plan → `jj describe -m "docs: update plan for <feature-name>"` → `jj new` to resume work. Don't bury plan edits inside implementation commits.
  - git-only equivalent: edit plan → `git add -A && git commit -m "docs: update plan for <feature-name>"`.
- Edit the affected tasks/phases; add new `TASK-NNN` entries continuing the numbering rather than renumbering existing ones.
- Bump `last_updated` and the `version` (1.0 → 1.1) in frontmatter.
- Keep deviations honest: the plan after execution should read as what *was* done, with notes explaining where and why it diverged from version 1.0.

## 7. Testing Section

The plan's `## 6. Testing` section is part of the work, not an afterthought:

- Run/write each `TEST-NNN` item and tick its checkbox like any task.
- If tests belong naturally to a phase (the phase's completion criteria already cover them), tick them when that phase completes. Otherwise treat testing as the final phase with its own commit:
  - jj: `jj describe -m "test: <feature-name>"`
  - git-only: `git add -A && git commit -m "test: <feature-name>"`

## 8. Completion

A plan is done only when every `- [ ]` is `- [x]` (or annotated as blocked with user sign-off). Then, in a final commit:

1. Set frontmatter `status: 'Completed'` and `last_updated: <today>`
2. Update the badge to `![Status: Completed](https://img.shields.io/badge/status-Completed-brightgreen)`
3. Commit:
   - jj: `jj describe -m "docs: complete <feature-name> plan"`
   - git-only: `git add -A && git commit -m "docs: complete <feature-name> plan"`

Finish with a short report to the user:

```
Plan complete: docs/<feature-name>/PLAN.md
Phases: <N> — one jj commit each (run `jj log` to review the stack)
Deviations: <none | list of blocked/changed tasks>
Verification: <what was run to prove completion criteria, e.g. "test suite passes (42 tests)">
```

If stopping *before* completion (user interrupt, blocker), leave status `In progress`, make sure every finished task is ticked and the current phase's partial work is described in a commit, and summarize where the next session should resume.
