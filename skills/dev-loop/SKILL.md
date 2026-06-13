---
name: dev-loop
description: Run an autonomous plan → implement → review loop for a feature. Iterates until the code review passes, fixing findings between iterations and pausing for user approval before closing. Use when the user says "loop on this", "keep going until it passes review", "autonomous dev loop", "plan implement and review", or wants a self-correcting agent workflow for a feature.
---

# Dev Loop

Orchestrate a self-correcting development cycle:

```
create-plan → implement-plan → code-review
                    ↑                |
                    └── fix ←────────┘  (if findings remain)
```

Each iteration updates the existing `PLAN.md`, fixes findings, and re-reviews. The loop pauses for user approval when the review passes. State is tracked in `docs/<feature-name>/LOOP.md` so the loop is resumable if interrupted.

## 1. Start or Resume

**Starting fresh:**
1. Run the `create-plan` skill to produce `docs/<feature-name>/PLAN.md` and create the feature branch.
2. Initialise `docs/<feature-name>/LOOP.md` (see template below).
3. Proceed to §2.

**Resuming an interrupted loop:**
- Read `LOOP.md` to find the current iteration and status.
- `running` → resume from the step that was in progress (check `PLAN.md` checkbox state and `REVIEW.md` verdict).
- `waiting-for-approval` → present the last review to the user and wait.
- `complete` → tell the user the loop already finished; confirm before re-running.

## 2. LOOP.md Template

Create at `docs/<feature-name>/LOOP.md` before the first iteration. Update it after every step.

```markdown
---
feature: <feature-name>
started: <YYYY-MM-DD>
max_iterations: 3
status: running
---

# Dev Loop: <feature-name>

| Iteration | Verdict | Critical | High | Medium | Low | Action taken |
|-----------|---------|----------|------|--------|-----|--------------|
| 1         | —       | —        | —    | —      | —   | starting     |

## Log

### Iteration 1
- [ ] implement-plan
- [ ] code-review
- [ ] fix / approve
```

Fields to keep updated:
- `status`: `running` | `waiting-for-approval` | `complete` | `abandoned`
- Table row: fill in after each review
- Log checkboxes: tick as each step completes

## 3. Iteration Protocol

Repeat until exit (§4):

### Step 1 — Implement
Run the `implement-plan` skill on the current `PLAN.md`. It will execute unchecked tasks, commit each phase, and update checkboxes.

### Step 2 — Review
Run the `code-review` skill on the branch diff (`git diff main...HEAD`). It writes `docs/<feature-name>/REVIEW.md` and returns a verdict.

Update `LOOP.md`:
- Tick `- [x] code-review` in the log
- Fill in the verdict and finding counts in the table

### Step 3 — Decide

**If verdict is `Approve`** (or only `Low`/`Info` findings remain):
→ Pause. Present the review summary to the user and ask:
> "Review passed (Iteration N). Findings: X low, Y info. Approve to merge, or ask me to continue fixing?"
→ Wait for explicit approval before proceeding to §4.

**If findings are `Medium` or lower only (no Critical/High):**
→ Direct fix — do not update `PLAN.md`. Make the minimal code changes to address each finding, tick them off inline in `REVIEW.md`, commit:
  `git add -u && git commit -m "fix: address review findings from iteration N"`
→ Loop back to Step 2 (re-review the fixes).

**If any `High` or `Critical` findings exist:**
→ Append a new fix phase to `PLAN.md` under a `### Phase N+1: Fix review findings (Iteration N)` heading. Each finding becomes one task:
  ```
  - [ ] TASK-NNN: Fix [CRIT-001] <title> — <one line description of the fix>
  ```
→ Update `PLAN.md` frontmatter: bump `version` (e.g. 1.0 → 1.1), set `last_updated`.
→ Commit the plan update: `git add -u && git commit -m "docs: add fix phase for iteration N findings"`
→ Loop back to Step 1 (implement the new phase).

## 4. Exit Conditions

The loop exits when any of these are true:

| Condition | Action |
|-----------|--------|
| Verdict `Approve` and user confirms | Mark `status: complete`, push branch, open PR |
| Max iterations reached with findings remaining | Stop, report what's unresolved, ask user how to proceed |
| User says stop / interrupt | Mark `status: abandoned`, leave branch as-is, summarise state |

**On clean exit (user approved):**
1. Set `LOOP.md` `status: complete`
2. Commit: `git add -u && git commit -m "docs: loop complete for <feature-name>"`
3. Push and open PR:
   ```
   git push -u origin <branch-name>
   gh pr create \
     --title "<goal from PLAN.md frontmatter>" \
     --body "$(cat docs/<feature-name>/PLAN.md)"
   ```
4. Report to user:
   ```
   Loop complete: <feature-name>
   Iterations: N
   Final verdict: Approve
   PR: <url>
   ```

**On max iterations reached:**
```
Loop stopped: max iterations (N) reached
Unresolved findings: <list CRIT/HIGH finding IDs still open>
Branch: <branch-name> (not pushed)
Next step: review docs/<feature-name>/REVIEW.md and decide how to proceed
```

## 5. Commit Discipline

All commits in the loop follow the same rules as `implement-plan` and `create-plan`:
- `git add -u` for modified files; explicit paths for new files
- No `git add -A`
- No `Co-authored-by:` trailers
- Subject ≤ 72 chars, imperative mood, explain why not what

Commit message patterns by loop action:

| Action | Message pattern |
|--------|----------------|
| Phase implementation | `<type>: <phase summary>` |
| Direct fix (Medium/Low) | `fix: address review findings from iteration N` |
| Fix phase added to plan | `docs: add fix phase for iteration N findings` |
| Loop status update | `docs: loop complete for <feature-name>` |

## 6. Principles

- **Don't over-plan small fixes.** A missing index or an unhandled promise doesn't need a new plan phase — fix it directly and re-review.
- **Don't loop on nits.** Low and Info findings don't block progress. If all that's left is Low/Info, treat the review as passing and ask for approval.
- **Keep the human in the loop.** Never merge or push without explicit user approval after a passing review.
- **Resumability over speed.** Update `LOOP.md` and tick checkboxes before moving on — an interrupted loop should be continuable from the file state alone.
- **One concern per commit.** Fix-phase commits contain only fixes, not opportunistic refactors.
