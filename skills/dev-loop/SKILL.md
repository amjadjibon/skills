---
name: dev-loop
description: Run an autonomous plan → implement → review loop for a feature. Iterates until the code review passes, fixing findings between iterations and pausing for user approval before closing. Use when the user says "loop on this", "keep going until it passes review", "autonomous dev loop", "plan implement and review", or wants a self-correcting agent workflow for a feature.
---

# Dev Loop — Autonomous Multi-Agent Orchestrator

You are the **orchestrator agent**. Given a task description you drive the full cycle, spawning parallel sub-agents in isolated git worktrees whenever work can be parallelised:

```
[task] → create-plan ──→ implement (agents) ──→ code-review
                               ↑                       |
              merge worktrees  |       ┌───────────────┘
                               └──── fix agents (parallel)
                                                       ↓ (only Low/Info remain)
                                               pause → user approval → push + PR
```

**Default mode is fully autonomous.** Do not ask clarifying questions between steps. The only permitted pauses are:
- User approval before pushing and opening a PR.
- A `Critical` finding that cannot be auto-fixed (e.g. leaked secret in git history) — stop and explain.
- `max_iterations` reached with unresolved findings — report and stop.

---

## 0. Parallelism Rules

Apply these rules at every decision point to decide whether to spawn parallel agents.

### When to parallelise

| Scenario | Condition | Action |
|----------|-----------|--------|
| Plan phases | Phase has no `Depends on:` linking it to an earlier phase | Run independent phases in parallel agents |
| Fix findings | High findings touch non-overlapping files/packages | Fix each cluster in a parallel agent |
| Plan phase + review | Never — review must see the merged result | Always sequential |

### When to stay sequential

- Phase B lists `Depends on: Phase A` → A must finish before B starts.
- Two findings touch the same file → assign both to the same agent.
- Only one phase / one finding → no benefit; run inline.

### Parallelism threshold

Spawn parallel agents only if there are **2 or more** independent units of work. One unit → do it yourself inline.

---

## 1. Bootstrap

### 1a. Derive the feature name

Slug the task into kebab-case `<feature-name>`. E.g. "Add rate limiting to /api/login" → `rate-limit-login`.

### 1b. Research the codebase

Run silently before planning:

```bash
git status
git branch --show-current
find . -name "*.md" -path "*/docs/*" | head -20
```

Read 3–5 key files to understand existing patterns (routing, middleware, error handling, testing). **Do not ask the user.** State assumptions in the plan's §7.

### 1c. Create the plan

Run the `create-plan` skill in autonomous mode. It creates `docs/<feature-name>/PLAN.md` and commits it on a new feature branch `<feature-name>`.

### 1d. Initialise LOOP.md

Create `docs/<feature-name>/LOOP.md`:

```markdown
---
feature: <feature-name>
task: <original task description>
branch: <feature-name>
started: <YYYY-MM-DD>
max_iterations: 3
current_iteration: 1
status: running
---

# Dev Loop: <feature-name>

| Iter | Verdict | Crit | High | Med | Low | Mode       | Action |
|------|---------|------|------|-----|-----|------------|--------|
| 1    | —       | —    | —    | —   | —   | —          | start  |

## Active Worktrees

| Worktree path | Branch | Purpose | Status |
|---------------|--------|---------|--------|
| (none)        |        |         |        |

## Log

### Iteration 1
- [ ] implement-plan
- [ ] code-review
- [ ] decide
```

Commit: `git add docs/<feature-name>/LOOP.md && git commit -m "chore: init dev loop for <feature-name>"`

---

## 2. Worktree Management

All worktrees live under `.worktrees/` in the repo root. The orchestrator (you) owns this directory and is responsible for creating, tracking, and removing every worktree.

### Creating a worktree for an agent

```bash
# Sub-branch off the feature branch
git checkout <feature-name>
git checkout -b <feature-name>-<slot>        # e.g. rate-limit-login-phase-2

# Create the worktree
git worktree add .worktrees/<feature-name>-<slot> <feature-name>-<slot>
```

`<slot>` is descriptive: `phase-2`, `fix-HIGH-001`, `fix-cluster-auth`.

### Updating LOOP.md "Active Worktrees" table

Add a row for every created worktree before handing it to an agent. Update `Status` as work progresses: `assigned → running → merged → removed`.

### Assigning an agent

Spawn a sub-agent (using the Agent tool) with this briefing template:

```
You are a sub-agent working in an isolated git worktree.

Worktree path: .worktrees/<feature-name>-<slot>
Branch: <feature-name>-<slot>
Base branch: <feature-name>

Your task:
<one-paragraph description — which PLAN.md tasks to execute, or which REVIEW.md finding IDs to fix>

Rules:
- All work happens inside the worktree path above. Do not touch files outside it.
- Use `git add -u` (or explicit paths for new files) and commit after completing your task.
- Commit message: "<type>: <slot description>" — no Co-authored-by trailers.
- When done, write a one-paragraph summary of what you changed and what commit SHA you produced.
- Do NOT push, open PRs, or modify docs/<feature-name>/LOOP.md.
```

### Merging a worktree back

After the agent reports completion, from the main feature branch:

```bash
git checkout <feature-name>
git merge --no-ff <feature-name>-<slot> \
  -m "merge: <slot description> into <feature-name>"
```

If there are conflicts:
- Conflicts in the same file across two parallel agents → resolve by hand (read both versions, merge intent).
- Conflicts between a fix agent and the main branch → the fix agent's version wins unless it reverts a passing test.

### Removing a worktree

After a successful merge:

```bash
git worktree remove .worktrees/<feature-name>-<slot>
git branch -d <feature-name>-<slot>
```

Update the LOOP.md row to `removed`. If the agent failed, set `Status: failed` and handle inline instead.

### Cleaning up all worktrees on exit

Before pushing the final PR, verify no worktrees remain:

```bash
git worktree list
```

Remove any that are still listed.

---

## 3. The Loop

Repeat until an exit condition (§4) is met.

### Step A — Implement

**Analyse PLAN.md for parallelism:**

```
for each unchecked phase in PLAN.md:
  if phase has no "Depends on:" → independent
  if phase lists "Depends on: Phase N" → dependent on N
```

Build a dependency graph. Identify sets of phases that can run concurrently.

**Single phase (or all phases sequential):**
- Run `implement-plan` inline. No worktree needed.

**Multiple independent phases:**
1. For each independent phase, create a worktree and spawn an agent (§2).
2. Run all agents **in parallel** — spawn them all before waiting for any.
3. Wait for all agents to report completion.
4. Merge each worktree back into the feature branch in dependency order.
5. Remove all worktrees.
6. Run dependent phases sequentially after their dependencies are merged.

Update `LOOP.md`:
- Fill in the `Active Worktrees` table during execution.
- Tick `- [x] implement-plan` after all merges complete.
- Record `Mode: parallel (N agents)` or `Mode: sequential` in the iteration table.

### Step B — Review

Run the `code-review` skill on `git diff main...HEAD`. It writes `docs/<feature-name>/REVIEW.md`.

Parse the `## Machine-Readable Verdict` block to extract `verdict`, `critical`, `high`, `medium`, `low`, and `blocking_ids`.

Update `LOOP.md`:
- Tick `- [x] code-review`.
- Fill in the verdict and finding counts in the iteration table.

### Step C — Decide

| Condition | Action |
|-----------|--------|
| `verdict: Approve` OR only Low/Info findings | → §4 Clean Exit |
| Medium findings only (no Crit/High) | → §3.C.1 Direct fix |
| High findings, all independent | → §3.C.2 Parallel fix agents |
| High findings, some overlapping | → §3.C.3 Clustered fix agents |
| Any Critical finding | → §4 Blocked Exit |
| `current_iteration` = `max_iterations` | → §4 Max Iterations Exit |

---

**§3.C.1 — Direct fix (Medium/Low only, ≤ 3 findings):**
- Fix each finding inline. Do not update `PLAN.md`.
- Commit: `git add -u && git commit -m "fix: address review findings from iteration N"`
- Tick `- [x] decide`.
- New iteration: append log block, increment `current_iteration`, go to Step B (re-review only).

---

**§3.C.2 — Parallel fix agents (High findings, independent files):**

Group High findings by file ownership:
- Two findings touch the same file → same group.
- Two findings in different packages with no shared files → different groups.

For each group:
1. Create a worktree: `.worktrees/<feature-name>-fix-<group-id>`
2. Spawn an agent assigned to fix that group's finding IDs.

Run all fix agents in parallel. After all complete:
1. Merge each worktree back.
2. Remove worktrees.
3. Commit: `git add -u && git commit -m "fix: address High findings from iteration N (parallel)"`
4. Tick `- [x] decide`.
5. New iteration: append log block, increment `current_iteration`, go to Step B.

---

**§3.C.3 — Clustered fix agents (some overlapping High findings):**

Same as §3.C.2 but merge conflicting findings into one group → one agent. Remaining independent groups each get their own agent. Run in parallel.

---

**§3.C.4 — Fix phase in PLAN.md (High findings, complex changes needing plan structure):**

Use this when a High finding requires more than a targeted code patch — e.g. it reveals a missing abstraction, a schema migration, or a new dependency.

- Append `### Phase N+1: Fix review findings (Iteration N)` to `PLAN.md`. Each finding is one task:
  ```
  - [ ] TASK-NNN: Fix [HIGH-001] <title> — <one-line description>
  ```
- Bump `PLAN.md` `version` (e.g. `1.1 → 1.2`), update `last_updated`.
- Commit: `git add -u && git commit -m "docs: add fix phase for iteration N findings"`
- New iteration: go to Step A (re-plan, then implement and review).

**Default to §3.C.2 for most High findings.** Use §3.C.4 only when a finding reveals a gap too large for a targeted patch.

---

## 4. Exit Conditions

### Clean Exit — review passed

Present to the user:
```
Review passed (Iteration N).
Verdict: Approve
Findings: X critical, X high, X medium, X low
Mode this run: <sequential | parallel (N agents)>

Approve to push and open PR, or ask me to continue fixing?
```

Wait for explicit approval, then:
1. Set `LOOP.md` `status: complete`.
2. Commit: `git add -u && git commit -m "chore: dev loop complete for <feature-name>"`
3. Verify no worktrees remain: `git worktree list`
4. Push and open PR:
   ```bash
   git push -u origin <feature-name>
   gh pr create \
     --title "<goal from PLAN.md frontmatter>" \
     --body "$(cat docs/<feature-name>/LOOP.md)"
   ```
5. Report:
   ```
   Loop complete: <feature-name>
   Iterations: N  |  Final verdict: Approve
   PR: <url>
   ```

### Blocked Exit — Critical finding

Stop immediately. Do not fix and continue. Clean up any open worktrees first:
```bash
git worktree list   # remove any active ones
```
Then report:
```
Loop blocked on Critical finding (Iteration N).
Finding: [CRIT-001] <title>
Issue: <one-line description>
Branch: <feature-name> (not pushed)

Action required: resolve this finding manually, then resume with /dev-loop.
```
Set `LOOP.md` `status: blocked`.

### Max Iterations Exit

Clean up worktrees, then:
```
Loop stopped: max iterations (N) reached with findings unresolved.
Unresolved: <CRIT/HIGH finding IDs from REVIEW.md>
Branch: <feature-name> (not pushed)

Next step: review docs/<feature-name>/REVIEW.md and decide how to proceed.
```
Set `LOOP.md` `status: abandoned`.

### User Interrupt

Clean up any open worktrees. Set `LOOP.md` `status: abandoned`. Report:
```
Loop interrupted at iteration N, Step <A|B|C>.
Branch: <feature-name>  |  Last commit: <git log -1 --oneline>
Active worktrees at interrupt: <list or "none">
Resume any time with /dev-loop.
```

---

## 5. Commit Discipline

All commits (orchestrator and sub-agents alike) follow these rules:
- `git add -u` for tracked files; explicit paths for new files
- Never `git add -A`
- No `Co-authored-by:` trailers
- Subject ≤ 72 chars, imperative mood, explain why not what

| Commit source | Message pattern |
|---------------|----------------|
| Plan phase (sequential) | `<type>: <phase summary>` |
| Plan phase (sub-agent) | `<type>: <phase summary> [agent]` |
| Worktree merge | `merge: <slot> into <feature-name>` |
| Direct fix (Med/Low) | `fix: address review findings from iteration N` |
| Parallel fix merge | `fix: address High findings from iteration N (parallel)` |
| Fix phase added to plan | `docs: add fix phase for iteration N findings` |
| Loop state update | `chore: <action> for <feature-name>` |

---

## 6. Principles

- **Assume and proceed.** Unknown constraints → state the assumption, proceed, let the review catch it.
- **Default to parallel.** Two or more independent units of work → spawn agents. One unit → do it inline.
- **Orchestrator owns worktrees.** Sub-agents work inside their assigned worktree and nothing else. The orchestrator creates, merges, and removes every worktree.
- **Don't over-plan small fixes.** A missing index or unhandled promise doesn't need a fix phase — fix it directly (§3.C.1).
- **Don't loop on nits.** Low and Info findings never block. If only Low/Info remain, the review passes.
- **One concern per commit.** Fix commits contain only fixes, not opportunistic refactors.
- **Clean worktree list before PR.** Never push with dangling worktrees.
- **Resumability over speed.** Tick LOOP.md checkboxes and update the Active Worktrees table before moving on — an interrupted loop must be continuable from file state alone.
- **Human in the loop at the exit gate only.** Save the user's attention for the final approval, not mid-loop decisions.
