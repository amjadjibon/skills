---
name: implement-plan
description: Execute an implementation plan from a docs/<feature-name>/PLAN.md file created by the create-plan skill. Trigger when the user says "implement the plan", "execute the plan", "run the plan", "work through the plan", "continue the plan", "resume the plan", "start phase 1", or points at any PLAN.md file and asks to build it. Also trigger when the user references a planned feature by name and wants implementation to begin, or when a plan was just created and the user says "go", "start", or "implement it". Use this skill whenever there is a PLAN.md to execute, even if the user doesn't say the word "plan".
---

# Implement Plan

Execute a `PLAN.md` produced by the `create-plan` skill: work through its phases in order, tick checkboxes as tasks complete, commit each phase with git, and keep the plan file itself an accurate record of what actually happened.

The plan file is both the instruction set and the progress tracker. Someone (human or agent) interrupted mid-plan must be able to resume from the file alone — that's why checkbox updates and status changes happen *as you go*, never batched at the end.


## Execution Principles

These apply to every task, every phase, every line of code.

**Think before coding**
- Before starting each task, state your assumptions. If a task is ambiguous, surface it — don't guess.
- If a simpler approach exists than what the task describes, say so before implementing.
- If something is unclear, stop and ask. Charging ahead on a wrong assumption costs more than a short pause.

**Simplicity first — the ladder**
Stop at the first rung that satisfies the task:
1. Does this need to exist at all? Speculative need → skip it, note why.
2. Stdlib or platform feature covers it? Use it.
3. Already-installed dependency solves it? Use it. Never add a new one for what a few lines can do.
4. Can it be one function or one line? Do that.
5. Only then: the minimum custom code that works.

- No abstractions, configurability, or error handling the task doesn't require.
- No boilerplate "for later" — later can add it when it's needed.
- Shortest working diff wins. If you write 200 lines and it could be 50, rewrite it.

**Defensive error handling — never simplify this away**
- Every error must be handled or explicitly propagated. No silent swallows (`catch {}`, `_ = err`, `except: pass`).
- Validate at trust boundaries: user input, external API responses, file I/O, env vars. Never assume the shape is correct.
- Fail fast and loud. A function that receives invalid input should error immediately, not silently produce a wrong result downstream.
- Resources (files, connections, streams) must close in all paths — not just the happy path.
- The simplicity ladder applies to features, not to error handling. Cutting boilerplate is good; cutting error handling creates incidents.

**Surgical changes**
- Touch only what the task requires. Don't improve adjacent code, comments, or formatting.
- Match the existing style even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Every changed line should trace directly to the current task.

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
2. **Enforce linear history (only if a remote exists).** Check first: `git remote | head -1`. If a remote is configured, run:
   - `git fetch origin`
   - rebase current branch onto `origin/main` when it exists, otherwise `origin/master`
   - resolve conflicts before continuing; do not create merge commits for sync
   - If no remote is configured, skip this step entirely.
3. **Check the working copy is clean enough to start** — uncommitted unrelated changes will get swept into phase commits. If `git status` shows unrelated dirty files, tell the user before proceeding.
4. **Mark the plan started.** In its own commit, before any implementation:
   - Set frontmatter `status: 'In progress'` and `last_updated: <today>`
   - Update the badge line to `![Status: In progress](https://img.shields.io/badge/status-In%20progress-yellow)`
   - Commit: `git add -u && git commit -m "docs: start <feature-name> implementation"`

## 3. Phase Execution Protocol

Each phase runs on its own branch and gets its own PR that stacks on the previous phase. This keeps PRs small and independently reviewable.

**Branch naming:** `<feature-name>/phase-<N>` — e.g. `rate-limit-login/phase-1`, `rate-limit-login/phase-2`.

For each phase:

```
1. Create and switch to the phase branch (base = previous phase branch, or main for phase 1):
   git checkout -b <feature-name>/phase-<N>

2. Read the phase's tasks top to bottom
3. Execute each task; tick its checkbox immediately after it's done
4. Verify the phase's completion criteria — actually run the command/test, don't assume
5. Commit:
   git add -u && git commit -m "<type>: <phase summary>"
   (new files: git add path/to/new/file && git add -u && git commit -m "...")

6. Push and open a stacked PR:
   git push -u origin <feature-name>/phase-<N>
   gh pr create \
     --base <previous-branch-or-main> \
     --title "<what this phase does, imperative, ≤60 chars — e.g. 'add rate limiting middleware to /api/login'>" \
     --body "<phase Goal + task list + completion criteria from PLAN.md>"

7. Move to the next phase (it will branch off this phase's branch)
```

Rules that matter:

- **Tick checkboxes one at a time, in the plan file, as each task finishes.** The checkbox edit goes into the same phase commit as the work itself, so every commit shows exactly which tasks it contains. Never tick a box for work you haven't verified.
- **Use the commit message the plan specifies.** Each phase has a `**git commit**:` line — use it verbatim. If the plan's message no longer describes what you actually did, write an accurate one instead and note the deviation (see §6).
- **No `Co-authored-by:` trailers.** Never append `Co-authored-by:` or any AI attribution to commit messages. The commit author is the human doing the work.
- **Commit messages: short and why-focused.** Subject line ≤ 72 chars, imperative mood. Explain *why* the change was made — the diff shows what changed. A 1–3 sentence body is fine for non-obvious motivation; bullet lists of changes are not.
- **Check `git status` before staging.** If new untracked files appear that shouldn't be committed (build output, `node_modules`, `.env`), verify `.gitignore` covers them before staging. Don't commit them and don't use `git add -A`.
- **Completion criteria are gates, not suggestions.** If the criteria say "all tests pass", run the tests and show the output. If criteria fail, fix the phase before committing — don't carry broken work into the next phase.
- **Tasks within a phase are sequential by default.** Only treat tasks as parallelisable when they are in genuinely independent domains (e.g. backend + frontend, service A + service B) with no shared types, interfaces, configs, or test fixtures. Different files in the same domain is not enough — do those sequentially.
- **Keep git history linear.** Sync with upstream via rebase (`fetch` + `rebase`), not merge.

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
2. Cross-check against history: `git log --oneline` should show commits for already-completed phases. If checkboxes and commits disagree (boxes ticked but no commit, or vice versa), trust the code/history over the checkboxes, fix the checkboxes to match reality, and tell the user what you reconciled.
3. If resuming mid-phase, check `git status` for partial work already in progress before starting new changes.

## 6. Plan Deviations

Reality wins over the plan. When implementation reveals the plan is wrong (missed dependency, better approach, changed requirement):

- Update `PLAN.md` to reflect reality **in its own commit**: edit plan → `git add -u && git commit -m "docs: update plan for <feature-name>"` → continue work. Don't bury plan edits inside implementation commits.
- Edit the affected tasks/phases; add new `TASK-NNN` entries continuing the numbering rather than renumbering existing ones.
- Bump `last_updated` and the `version` (1.0 → 1.1) in frontmatter.
- Keep deviations honest: the plan after execution should read as what *was* done, with notes explaining where and why it diverged from version 1.0.

## 7. Testing Section

The plan's `## 6. Testing` section is part of the work, not an afterthought:

- Run/write each `TEST-NNN` item and tick its checkbox like any task.
- If tests belong naturally to a phase (the phase's completion criteria already cover them), tick them when that phase completes. Otherwise treat testing as the final phase with its own commit:
  `git add -u && git commit -m "test: <feature-name>"`

## 8. Completion

A plan is done only when every `- [ ]` is `- [x]` (or annotated as blocked with user sign-off). Then:

1. Set frontmatter `status: 'Completed'` and `last_updated: <today>`
2. Update the badge to `![Status: Completed](https://img.shields.io/badge/status-Completed-brightgreen)`
3. Commit on the last phase branch: `git add -u && git commit -m "docs: complete <feature-name> plan"`

By this point every phase already has its own PR open (created in §3). The stack looks like:

```
main ← phase-1 PR ← phase-2 PR ← phase-3 PR
```

Report to the user:

```
Plan complete: docs/<feature-name>/PLAN.md
Phases: <N> — one PR per phase, stacked
PRs:
  phase-1: <url>  (base: main)
  phase-2: <url>  (base: phase-1)
  ...
Deviations: <none | list>
Verification: <what was run>
```

**Merging order:** Phase PRs must merge in order — phase 1 first. After phase 1 merges, GitHub automatically re-targets phase 2's base to `main`. Tell the user to merge in sequence.

If no remote is configured, skip the push steps in §3 and tell the user the branches are ready locally.

If stopping *before* completion (user interrupt, blocker), leave status `In progress`, make sure every finished task is ticked and the current phase's partial work is committed, and summarize where the next session should resume.
