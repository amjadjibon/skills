---
name: implement-plan
description: Execute an implementation plan from a docs/<feature-name>/PLAN.md file created by the create-plan skill. Trigger when the user says "implement the plan", "execute the plan", "run the plan", "work through the plan", "continue the plan", "resume the plan", "start phase 1", or points at any PLAN.md file and asks to build it. Also trigger when the user references a planned feature by name and wants implementation to begin, or when a plan was just created and the user says "go", "start", or "implement it". Use this skill whenever there is a PLAN.md to execute, even if the user doesn't say the word "plan".
---

# Implement Plan

Execute a `PLAN.md` produced by the `create-plan` skill: work through its phases in order, tick checkboxes as tasks complete, commit each phase with git, and keep the plan file itself an accurate record of what actually happened.

The plan file is both the instruction set and the progress tracker. Someone (human or agent) interrupted mid-plan must be able to resume from the file alone — that's why checkbox updates and status changes happen *as you go*, never batched at the end.

## Execution Principles

These apply to every task, every phase, every line of code.

**Simplicity first**
- Write the minimum code that satisfies the task. Nothing speculative.
- No abstractions, configurability, or error handling that the task doesn't require.
- If you write 200 lines and it could be 50, rewrite it.

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

Phases run strictly in order — each phase's commit is the foundation the next builds on. For each phase:

```
1. Read the phase's tasks top to bottom
2. Execute each task; tick its checkbox immediately after it's done
3. Verify the phase's completion criteria — actually run the command/test, don't assume
4. Commit with the phase message from the plan's **git commit** line:
   git add -u && git commit -m "<type>: <phase summary>"
   If new files were intentionally created, stage them explicitly by path:
   git add path/to/new/file && git add -u && git commit -m "<type>: <phase summary>"
5. Move to the next phase
```

Rules that matter:

- **Tick checkboxes one at a time, in the plan file, as each task finishes.** The checkbox edit goes into the same phase commit as the work itself, so every commit shows exactly which tasks it contains. Never tick a box for work you haven't verified.
- **Use the commit message the plan specifies.** Each phase has a `**git commit**:` line — use it verbatim. If the plan's message no longer describes what you actually did, write an accurate one instead and note the deviation (see §6).
- **No `Co-authored-by:` trailers.** Never append `Co-authored-by:` or any AI attribution to commit messages. The commit author is the human doing the work.
- **Commit messages: short and why-focused.** Subject line ≤ 72 chars, imperative mood. Explain *why* the change was made — the diff shows what changed. A 1–3 sentence body is fine for non-obvious motivation; bullet lists of changes are not.
- **Check `git status` before staging.** If new untracked files appear that shouldn't be committed (build output, `node_modules`, `.env`), verify `.gitignore` covers them before staging. Don't commit them and don't use `git add -A`.
- **Completion criteria are gates, not suggestions.** If the criteria say "all tests pass", run the tests and show the output. If criteria fail, fix the phase before committing — don't carry broken work into the next phase.
- **Tasks within a phase are sequential by default**, but independent tasks (different files, no shared state) may be done in any order.
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

A plan is done only when every `- [ ]` is `- [x]` (or annotated as blocked with user sign-off). Then, in a final commit:

1. Set frontmatter `status: 'Completed'` and `last_updated: <today>`
2. Update the badge to `![Status: Completed](https://img.shields.io/badge/status-Completed-brightgreen)`
3. Commit: `git add -u && git commit -m "docs: complete <feature-name> plan"`

Then push and open a PR if a remote exists:

```
git remote | head -1   # check if remote is configured
# if remote exists:
git push -u origin <branch-name>
gh pr create \
  --title "<goal from plan frontmatter>" \
  --body "$(cat docs/<feature-name>/PLAN.md)"
```

Do **not** use `gh pr create --fill` — it uses the last commit message as the body, which is just one phase summary. The PR body should be the PLAN.md content (or a hand-written summary of all phases and deviations). Do **not** add a `Co-authored-by:` trailer to commits or the PR description.

If `gh` is not available, output the push command and tell the user to open the PR manually.

If no remote is configured, skip the push and tell the user the branch is ready locally.

Finish with a short report to the user:

```
Plan complete: docs/<feature-name>/PLAN.md
Phases: <N> — one git commit each (run `git log --oneline` to review)
Deviations: <none | list of blocked/changed tasks>
Verification: <what was run to prove completion criteria, e.g. "test suite passes (42 tests)">
PR: <URL> | local only (no remote configured)
```

If stopping *before* completion (user interrupt, blocker), leave status `In progress`, make sure every finished task is ticked and the current phase's partial work is committed, and summarize where the next session should resume.
