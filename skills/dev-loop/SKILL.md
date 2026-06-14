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

**Phases always run sequentially.** Each phase lives on its own branch stacked on the previous — parallelising phases would break the stack. Independent phases are implemented one at a time; the `Depends on:` field controls order, not parallelism.

**Fix agents may run in parallel.** When multiple High findings touch independent files, each cluster gets its own worktree and agent. They all branch off the same fix base and merge back before re-review.

| Scenario | Rule |
|----------|------|
| Plan phases | Always sequential — stacked PR model requires it |
| Fix findings (High, independent files) | Parallel fix agents via worktrees |
| Fix findings (touching same file) | Single agent |
| Phase + review | Always sequential — review must see merged result |

**Parallelism threshold:** Spawn parallel fix agents only if there are **2 or more** independent finding clusters. One cluster → fix inline.

**Hard limits (read from LOOP.md frontmatter):**
- `max_agents` (default 3) — if grouping produces more clusters than this, merge the smallest clusters together until the count is within limit.
- `max_phases` (default 5) — if `implement-plan` would create a phase that exceeds this, stop and tell the user: the plan must be split or simplified before continuing. Do not silently create extra phases.

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
max_phases: 5          # stacked PRs hard limit — plan must not exceed this many phases
max_agents: 3          # parallel fix agents hard limit per iteration
current_iteration: 1
status: running
last_review_base: ''   # SHA of HEAD at last review; empty until first review runs
---

# Dev Loop: <feature-name>

| Iter | Verdict | Crit | High | Med | Low | Mode       | Action |
|------|---------|------|------|-----|-----|------------|--------|
| 1    | —       | —    | —    | —   | —   | —          | start  |

## Stacked PRs

| Phase | Branch | PR URL | Base | Status |
|-------|--------|--------|------|--------|
| 1     | `<feature>/phase-1` | — | main | pending |

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

Phases always run sequentially (see §0). Execute each unchecked phase using `implement-plan`:

**Before starting:** count the total phases in `PLAN.md`. If the count exceeds `max_phases`, stop immediately:
```
Cannot proceed: PLAN.md has N phases but max_phases is M.
Action required: split the plan into two features, or increase max_phases in LOOP.md.
```

For each phase N:
1. `implement-plan` creates branch `<feature>/phase-N` off the previous phase branch (or `main` for phase 1), implements the tasks, and opens a stacked PR.
2. After the PR is opened, update `LOOP.md` Stacked PRs table — add a row with the branch, PR URL, and base.
3. Move to the next phase.

After all phases are done:
- Tick `- [x] implement-plan` in the log.
- Record `Mode: sequential` in the iteration table.
- Record the current HEAD SHA as `last_review_base` in LOOP.md frontmatter — the review diff will start here.

### Step B — Review

Determine the diff base:
- **Iteration 1**: `git diff main...HEAD`
- **Iteration 2+**: `git diff <last_review_base>...HEAD` — review only what changed since the last review, not the full branch

Run the `code-review` skill on that diff. It writes `docs/<feature-name>/REVIEW.md` and appends a `## Machine-Readable Verdict` YAML block.

Parse that block to extract `verdict`, `critical`, `high`, `medium`, `low`, and `blocking_ids`.

Update `LOOP.md`:
- Tick `- [x] code-review`.
- Fill in the verdict and finding counts in the iteration table.
- Update `last_review_base` to the current HEAD SHA.

### Step C — Decide

| Condition | Action |
|-----------|--------|
| `verdict: Approve` OR only Low/Info findings | → §4 Clean Exit |
| Medium findings only (no Crit/High) | → §3.C.1 Direct fix |
| High findings, all independent files | → §3.C.2 Parallel fix agents |
| High findings, some overlapping files | → §3.C.3 Clustered fix agents |
| Any Critical finding | → §4 Blocked Exit |
| `current_iteration` = `max_iterations` | → §4 Max Iterations Exit |

**After any fix path:** increment `current_iteration` in LOOP.md frontmatter and append a new log block:
```markdown
### Iteration N+1
- [ ] implement-plan (or "fix only — no re-implement")
- [ ] code-review
- [ ] decide
```

---

**§3.C.1 — Direct fix (Medium/Low only):**
- Determine the current working branch: the last phase branch (`<feature>/phase-N` where N is the highest phase).
- Fix each finding on that branch. Do not update `PLAN.md`.
- Commit: `git add -u && git commit -m "fix: address review findings from iteration N"`
- Push: `git push origin <feature>/phase-N` — the existing stacked PR updates automatically.
- Tick `- [x] decide`. Increment iteration. Go to Step B (re-review only — skip Step A).

---

**§3.C.2 — Parallel fix agents (High findings, independent files):**

The fix base is the last phase branch (`<feature>/phase-N`). All fix worktrees branch off it and merge back to it.

Group High findings by file ownership:
- Two findings touch the same file → same group.
- Two findings in different packages with no shared files → different groups.

If the number of groups exceeds `max_agents`, merge the smallest groups together until within limit.

For each group (up to `max_agents`):
1. Create a worktree branching off `<feature>/phase-N`: `.worktrees/<feature>-fix-<group-id>`
2. Spawn an agent assigned to fix that group's finding IDs (see §2 briefing template).

Run all fix agents in parallel. After all complete:
1. Merge each worktree back to `<feature>/phase-N`.
2. Remove worktrees.
3. Push: `git push origin <feature>/phase-N` — existing stacked PR updates automatically.
4. Tick `- [x] decide`. Increment iteration. Go to Step B.

---

**§3.C.3 — Clustered fix agents (some overlapping High findings):**

Same as §3.C.2 but merge conflicting findings into one group → one agent. Remaining independent groups each get their own agent. All branch off and merge back to `<feature>/phase-N`.

---

**§3.C.4 — Fix phase in PLAN.md (High findings too large for a patch):**

Use when a finding reveals a missing abstraction, schema migration, or new dependency — not just a targeted code change.

1. Check that adding a phase would not exceed `max_phases`. If it would, fall back to §3.C.2 (direct parallel fix) even if the finding is complex, and note the constraint in LOOP.md.
2. On `<feature>/phase-N`, update `PLAN.md`:
   - Append `### Phase N+1: <descriptive name of what's being fixed>` with one task per finding:
     ```
     - [ ] TASK-NNN: Fix [HIGH-001] <title> — <one-line description>
     ```
   - Bump `version` (e.g. `1.1 → 1.2`) and `last_updated`.
   - Commit: `git add -u && git commit -m "docs: add fix phase for iteration N findings"`
2. Tick `- [x] decide`. Increment iteration. Go to Step A — `implement-plan` will pick up the new phase and open a new stacked PR (`<feature>/phase-N+1`) on top of the existing stack.

**Default to §3.C.2 for most High findings.** Use §3.C.4 only when a targeted patch isn't enough.

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
4. Each phase already has its own stacked PR from `implement-plan` §3. Confirm all are open:
   ```bash
   gh pr list --head "<feature-name>/phase-*"
   ```
   If any phase PR is missing (e.g. was opened before stacking was adopted), open it now:
   ```bash
   gh pr create \
     --base <previous-phase-branch-or-main> \
     --title "<what this phase does, imperative, ≤60 chars>" \
     --body "<phase section from PLAN.md>"
   ```
5. Report:
   ```
   Loop complete: <feature-name>
   Iterations: N  |  Final verdict: Approve
   Stacked PRs (merge in order):
     phase-1: <url>  → base: main
     phase-2: <url>  → base: phase-1
     ...
   Merge phase-1 first; GitHub retargets subsequent PRs automatically.
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

## References

- [Building effective agents](https://www.anthropic.com/research/building-effective-agents) — Anthropic's canonical guide on orchestrator/subagent patterns, parallelism safety, and when to spawn vs. run inline; directly informs §0 and §3
- [git-worktree](https://git-scm.com/docs/git-worktree) — official docs for the worktree commands used in §2
- [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`, `chore:` types and imperative-mood rules referenced in §5

### Pipeline
- [`create-plan`](../create-plan/SKILL.md) — called in §1c to produce `PLAN.md`
- [`implement-plan`](../implement-plan/SKILL.md) — called in §3A to execute plan phases
- [`code-review`](../code-review/SKILL.md) — called in §3B; machine-readable verdict block drives §3C decisions

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
