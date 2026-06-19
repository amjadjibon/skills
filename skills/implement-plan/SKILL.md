---
name: implement-plan
description: Execute an implementation plan from a docs/<feature-name>/PLAN.md file created by the create-plan skill. Trigger when the user says "implement the plan", "execute the plan", "run the plan", "work through the plan", "continue the plan", "resume the plan", "start phase 1", or points at any PLAN.md file and asks to build it. Also trigger when the user references a planned feature by name and wants implementation to begin, or when a plan was just created and the user says "go", "start", or "implement it". Use this skill whenever there is a PLAN.md to execute, even if the user doesn't say the word "plan".
---

# Implement Plan

Execute a `PLAN.md` produced by `create-plan`: work through phases in order, tick checkboxes as tasks complete, commit each phase, and keep the plan file an accurate progress record. Someone interrupted mid-plan must be able to resume from the file alone.

## Execution Principles

**Simplicity first — the ladder.** Stop at the first rung that satisfies the task:
1. Does this need to exist at all? Speculative need → skip, note why.
2. Stdlib or platform feature covers it? Use it.
3. Already-installed dependency solves it? Use it. Never add a new one for what a few lines can do.
4. Can it be one function or one line? Do that.
5. Only then: minimum custom code that works.

**Defensive error handling — never simplify this away.** Every error must be handled or explicitly propagated. Validate at trust boundaries (user input, external APIs, file I/O, env vars). Fail fast. Resources must close in all paths.

**Surgical changes.** Touch only what the task requires. Match existing style. Mention unrelated dead code — don't delete it. Every changed line traces to the current task.

## 1. Locate the Plan

- Named feature → `docs/<feature-name>/PLAN.md`
- Otherwise → `ls docs/*/PLAN.md`. If one exists, use it. If several, prefer `status: 'In progress'`; if none in progress, ask.
- No PLAN.md → say so, offer `create-plan` instead.

## 2. Pre-flight

Read the entire plan before touching code.

1. **Check `status`:** `Planned` → fresh start. `In progress` → resume (§5). `Completed`/`Deprecated` → stop and confirm. `On Hold` → ask before resuming.
2. **Sync (only if remote exists).** `git remote | head -1`. If configured: `git fetch origin`, rebase onto `origin/main` (or `origin/master`). Skip if no remote.
3. **Check working copy** is clean — uncommitted unrelated changes will contaminate phase commits. Warn user if found.
4. **Mark started.** Own commit before any implementation: set `status: 'In progress'`, `last_updated: <today>`, update badge. Commit: `docs: start <feature-name> implementation`

## 3. Phase Execution Protocol

Each phase runs on its own branch and gets a stacked PR.

**Branch naming:** `<feature-name>/phase-<N>` — e.g. `rate-limit-login/phase-1`.

For each phase:

```
1. git checkout -b <feature-name>/phase-<N>   # base = previous phase or main

2. Read phase tasks top to bottom
3. Execute each task; tick checkbox immediately after completion
4. Verify completion criteria — run the command/test, don't assume

5. Commit:
   git add -u && git commit -m "<type>: <phase summary>"
   # new files: git add path/to/new/file && git add -u && git commit

6. Push and open stacked PR:
   git push -u origin <feature-name>/phase-<N>
   gh pr create \
     --base <previous-branch-or-main> \
     --title "<imperative ≤60 chars>" \
     --body "<phase Goal + task list + completion criteria>"

7. Move to next phase (branches off this one)
```

Rules:
- **Tick checkboxes one at a time** in the plan file as each task finishes. The checkbox edit goes into the same phase commit. Never tick a box for unverified work.
- **Use the commit message the plan specifies.** If the plan's message no longer fits, write an accurate one and note the deviation (§6).
- **No `Co-authored-by:` trailers.**
- **Commit messages: ≤72 chars, imperative, why-focused.**
- **Check `git status` before staging** — don't commit build output or `.env`. Never `git add -A`.
- **Completion criteria are gates.** If they fail, fix the phase before committing.
- **Tasks within a phase are sequential** unless genuinely independent domains (backend + frontend, service A + service B) with no shared types or fixtures.
- **Keep history linear.** Sync via rebase, not merge.

## 4. Blocked or Failing Tasks

If a task can't be completed as written:
1. Add an inline note:
   ```
   - [x] TASK-005: <original description>
     > Blocked: <reason>. Resolved by: <what was done instead>.
   ```
2. If blocked with no resolution: leave unchecked, add `> Blocked: <reason>.`, stop and ask.
3. If blockage invalidates later tasks, update the plan (§6) before continuing.

## 5. Resuming a Plan In Progress

1. Find the first unchecked `- [ ] TASK-` — that's where to resume.
2. Cross-check: `git log --oneline` should show commits for completed phases. If checkboxes and commits disagree, trust history, fix checkboxes, tell the user.
3. Check `git status` for partial work already in progress before starting new changes.

## 6. Plan Deviations

Reality wins. When implementation reveals the plan is wrong:
- Update `PLAN.md` in its own commit: `docs: update plan for <feature-name>`. Don't bury plan edits in implementation commits.
- Add new `TASK-NNN` entries continuing the numbering — don't renumber existing ones.
- Bump `last_updated` and `version` (1.0 → 1.1).

## 7. Testing Section

Run/write each `TEST-NNN` item and tick its checkbox. If tests belong to a phase's completion criteria, tick when that phase completes. Otherwise treat as the final phase:
`git add -u && git commit -m "test: <feature-name>"`

## 8. Completion

Done when every `- [ ]` is `- [x]` (or annotated as blocked with user sign-off):

1. Set `status: 'Completed'`, `last_updated: <today>`, update badge
2. Commit on last phase branch: `docs: complete <feature-name> plan`

Report:
```
Plan complete: docs/<feature-name>/PLAN.md
Phases: <N> — one PR per phase, stacked
PRs:
  phase-1: <url>  (base: main)
  phase-2: <url>  (base: phase-1)
Deviations: <none | list>
Verification: <what was run>
```

**Merging order:** Phase 1 first — GitHub auto-retargets later PRs after phase 1 merges.

If no remote: skip push steps, tell user branches are ready locally.

If interrupted mid-plan: leave `status: 'In progress'`, ensure finished tasks are ticked and partial work committed, summarize where to resume.
