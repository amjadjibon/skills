---
name: dev-loop
description: Run an autonomous plan → implement → review loop for a feature. Iterates until the code review passes, fixing findings between iterations and pausing for user approval before closing. Use when the user says "loop on this", "keep going until it passes review", "autonomous dev loop", "plan implement and review", or wants a self-correcting agent workflow for a feature.
argument-hint: "[lite|full|ultra]"
---

# Dev Loop — Autonomous Multi-Agent Orchestrator

You are the **orchestrator agent**. Given a task description, drive the full cycle:

```
[task] → dev-create-plan → implement (agents) → dev-code-review
                            ↑                      |
            merge worktrees |       ┌──────────────┘
                            └──── fix agents (parallel)
                                                    ↓ (only Low/Info remain)
                                            pause → user approval → push + PR
```

**Fully autonomous by default.** Only pause for:
- User approval before pushing/opening a PR
- A `Critical` finding that cannot be auto-fixed
- `max_iterations` reached with unresolved findings

---

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — single branch `<feature-name>`, no phase branches, one PR at the end.
- `full` — phases run sequentially on stacked branches/PRs, as in §0–§4 below.
- `ultra` — phases with no shared dependencies get their own worktree off `main` and build in parallel (extends §2 Worktree Management beyond fix agents to implementation phases); merge each into the stack once done.

**Pass the loop's mode straight through** to every sub-skill it calls — `dev-create-plan`, `dev-implement-plan`, `dev-qa`, `dev-code-review` — they all honor the same `lite`/`full`/`ultra` semantics. Below, `<work-branch>` means `<feature-name>` in `lite`, or the current phase's `<feature>/phase-N` in `full`/`ultra`.

---

## 0. Parallelism Rules

**Phases always run sequentially** — stacked PRs require it. (`ultra` mode is the exception — see Delivery Mode above.) Phase + review is always sequential too.

**Fix agents run in parallel only when domains are genuinely independent** — different service boundaries (backend API + frontend UI, auth + notifications), not just different files. If fixes share a type, interface, config, or test fixture → single agent. Spawn parallel agents only for 2+ findings in genuinely independent domains; when in doubt, use one agent.

**Hard limits (from LOOP.md frontmatter):**
- `max_agents` (default 3) — merge smallest clusters until within limit
- `max_phases` (default 5) — if a phase would exceed this, stop and tell the user; do not create extra phases silently

---

## 1. Bootstrap

### 1a. Derive the feature name

Slug the task into kebab-case `<feature-name>`. E.g. "Add rate limiting to /api/login" → `rate-limit-login`.

### 1b. Research the codebase

```bash
git status && git branch --show-current
find . -name "*.md" -path "*/docs/*" | head -20
```

Read 3–5 key files to understand existing patterns. State assumptions in the plan's §4. Do not ask the user.

If the task hinges on an unfamiliar third-party API, library, or technology choice, run `dev-research` first (same mode) → `docs/<feature-name>/RESEARCH.md`. For single scoped questions surfacing later in the loop, sub-skills spawn `dev-research` sub-agents themselves (dev-research §6).

### 1c. Create the plan

Run `dev-create-plan` in autonomous mode → `docs/<feature-name>/PLAN.md` on branch `<feature-name>`.

### 1c.5. Review the plan

Run `dev-review-plan`. Parse the verdict:
- `Ready` → proceed to §1d
- `Needs Revision` → apply all Revise findings in a single commit (`docs: revise plan based on review`), then proceed
- `Blocked` → stop, report blocking findings; do not proceed

### 1d. Initialise LOOP.md

Create `docs/<feature-name>/LOOP.md` from this template — the loop parses it to resume, so keep the structure exact:

````markdown
---
feature: <feature-name>
task: <original task description>
branch: <feature-name>
started: <YYYY-MM-DD>
max_iterations: 3
max_phases: 5
max_agents: 3
current_iteration: 1
status: running
last_review_base: ''
---

# Dev Loop: <feature-name>

## Iterations

| Iter | Verdict | Crit | High | Med | Low | Mode | Action |
|------|---------|------|------|-----|-----|------|--------|
| 1    | —       | —    | —    | —   | —   | —    | —      |

## Stacked PRs

| Phase | Branch | PR URL | Base | Status |
|-------|--------|--------|------|--------|
| 1     | <feature-name>/phase-1 | — | main | pending |

<!-- one row per phase from PLAN.md; `lite` mode: single row, branch <feature-name> -->

## Active Worktrees

| Worktree path | Branch | Purpose | Status |
|---------------|--------|---------|--------|

## Log

### Iteration 1
- [ ] dev-implement-plan
- [ ] dev-qa
- [ ] dev-code-review
- [ ] decide
````

Commit: `git add docs/<feature-name>/LOOP.md && git commit -m "chore: init dev loop for <feature-name>"`

---

## 2. Worktree Management

All worktrees live under `.worktrees/`. The orchestrator owns all creation, tracking, and removal.

Before creating the first worktree, make sure `.worktrees/` is gitignored (once per repo):

```bash
grep -qx '.worktrees/' .gitignore 2>/dev/null || { echo '.worktrees/' >> .gitignore && git add .gitignore && git commit -m "chore: gitignore .worktrees"; }
```

### Create a worktree

```bash
# creates the branch and checks it out in the worktree in one step —
# checking the branch out first would make `git worktree add` fail with "already checked out"
git worktree add .worktrees/<feature-name>-<slot> -b <feature-name>-<slot> <feature-name>
```

`<slot>` is descriptive: `phase-2`, `fix-HIGH-001`, `fix-cluster-auth`. Add a row to LOOP.md "Active Worktrees" before handing off. Track status: `assigned → running → merged → removed`.

### Assign an agent

**For implementation phases:** read the phase's `**Agent Prompt**` block from `PLAN.md` and use it verbatim — it is already self-contained. Prepend the worktree path:

```
Worktree path: .worktrees/<feature-name>-<slot>
[paste Agent Prompt block from PLAN.md phase here]
```

**For fix agents** (no Agent Prompt in PLAN.md): compose the briefing manually:

```
You are a sub-agent fixing review findings in an isolated git worktree.

Worktree path: .worktrees/<feature-name>-<slot>
Branch: <feature-name>-<slot>
Base branch: <work-branch>

Findings to fix:
- [HIGH-001] <title> — <file:line> — <one-line description of what to change>
- [MED-001]  <title> — <file:line> — <one-line description>

Rules:
- All work stays inside the worktree path. Do not touch files outside it.
- Use `git add -u` (or explicit paths for new files) and commit after completing your task.
- Commit message: "fix: <slot description>" — no Co-authored-by trailers.
- When done, write a one-paragraph summary of changes and the commit SHA.
- Do NOT push, open PRs, or modify LOOP.md.
```

### Merge and remove

```bash
git checkout <feature-name>
git merge --no-ff <feature-name>-<slot> -m "merge: <slot description> into <feature-name>"
git worktree remove .worktrees/<feature-name>-<slot>
git branch -d <feature-name>-<slot>
```

Conflicts: parallel agent fixing the same file → read both, merge intent. Fix agent vs main branch → fix agent wins unless it reverts a passing test. Update LOOP.md row to `removed` (or `failed` if the agent failed).

Before final push: `git worktree list` — remove any remaining.

---

## 3. The Loop

Repeat until an exit condition (§4).

### Step A — Implement

Check total phases in `PLAN.md` against `max_phases` before starting. If exceeded:
```
Cannot proceed: PLAN.md has N phases but max_phases is M.
Action required: split the plan or increase max_phases in LOOP.md.
```

Phases run sequentially. For each phase N:
1. `dev-implement-plan` — `full`: creates branch `<feature>/phase-N`, implements tasks, opens stacked PR. `lite` (default): stays on branch `<feature-name>`, implements tasks, no PR yet (opened once at Clean Exit).
2. `full` only: update LOOP.md Stacked PRs table (branch, PR URL, base)

After all phases: tick `- [x] dev-implement-plan`, record `Mode: sequential` in iteration table.

### Step A.5 — QA (iteration 1 only)

Run `dev-qa` (same mode) on `<work-branch>` → `docs/<feature-name>/QA.md`. QA runs once after first implementation only. Commit QA tests, then record HEAD SHA as `last_review_base` in LOOP.md.

### Step B — Review

Diff base:
- Iteration 1: `git diff main...HEAD`
- Iteration 2+: `git diff <last_review_base>...HEAD`

Run `dev-code-review` (same mode) → `docs/<feature-name>/REVIEW.md`. Parse `## Machine-Readable Verdict` YAML for `verdict`, `critical`, `high`, `medium`, `low`, `blocking_ids`.

Update LOOP.md: tick `- [x] dev-code-review`, fill iteration table, update `last_review_base` to current HEAD.

### Step C — Decide

| Condition | Action |
|-----------|--------|
| `verdict: Approve` OR only Low/Info | → §4 Clean Exit |
| Medium only (no Crit/High) | → §3.C.1 Direct fix |
| High, independent domains | → §3.C.2 Parallel fix agents |
| High, overlapping domains | → §3.C.2 (single agent per cluster) |
| Any Critical | → §4 Blocked Exit |
| `current_iteration` = `max_iterations` | → §4 Max Iterations Exit |

After any fix path: increment `current_iteration` in LOOP.md, append:
```markdown
### Iteration N+1
- [ ] dev-implement-plan (or "fix only — no re-implement")
- [ ] dev-code-review
- [ ] decide
```

---

**§3.C.1 — Direct fix (Medium/Low only):**

Fix on `<work-branch>`. Do not update `PLAN.md`.
```bash
git add -u && git commit -m "fix: address review findings from iteration N"
git push origin <work-branch>
```
Tick `- [x] decide`. Increment iteration. Go to Step B (skip Step A).

---

**§3.C.2 — Parallel fix agents (High findings):**

Fix base is `<work-branch>`. Group findings by work domain — same domain (e.g. two backend handlers) → one group; genuinely independent domains (backend + frontend) → separate groups. Findings sharing a type, interface, config, or test fixture → same group.

If groups exceed `max_agents`, merge smallest until within limit.

For each group:
1. Create worktree off `<work-branch>`: `.worktrees/<feature>-fix-<group-id>`
2. Spawn agent for that group's finding IDs

After all complete: merge all worktrees to `<work-branch>`, remove worktrees, push. Tick `- [x] decide`. Increment iteration. Go to Step B.

---

**§3.C.3 — Fix phase in PLAN.md (High findings too large for a patch):**

Use when a finding reveals a missing abstraction or schema migration — not a targeted code change. First check adding a phase won't exceed `max_phases`; if it would, fall back to §3.C.2. `lite` has no phases to add to — fall back to §3.C.2 there too.

On `<work-branch>`, append to `PLAN.md`:
```
### Phase N+1: <descriptive name>
- [ ] TASK-NNN: Fix [HIGH-001] <title> — <one-line description>
```
Bump `version` and `last_updated`. Commit: `docs: add fix phase for iteration N findings`. Tick decide, increment, go to Step A.

**Default to §3.C.2.** Use §3.C.3 only when a patch isn't sufficient.

---

## 4. Exit Conditions

Every exit but Clean starts with cleaning up worktrees (`git worktree list` → remove any remaining).

### Clean Exit

Present, then wait for approval:
```
Review passed (Iteration N).
Verdict: Approve
Findings: X critical, X high, X medium, X low
Mode: <sequential | parallel (N agents)>

Approve to push and open PR, or ask me to continue fixing?
```

On approval:
1. Set LOOP.md `status: complete`; commit: `chore: dev loop complete for <feature-name>`
2. Verify `git worktree list` is clean
3. `full`: confirm all phase PRs are open: `gh pr list --head "<feature-name>/phase-*"`. Open any missing ones. `lite`: push `<feature-name>` and open the single PR if not already open: `gh pr create --base main --title "<imperative ≤60 chars>" --body "<summary>"`
4. Run `dev-clean-up`
5. Report (`full`):
```
Loop complete: <feature-name>
Iterations: N  |  Final verdict: Approve
Stacked PRs (merge in order):
  phase-1: <url>  → base: main
  phase-2: <url>  → base: phase-1
```
Report (`lite`):
```
Loop complete: <feature-name>
Iterations: N  |  Final verdict: Approve
PR: <url>  → base: main
```

### Blocked Exit — set `status: blocked`

```
Loop blocked on Critical finding (Iteration N).
Finding: [CRIT-001] <title>
Issue: <one-line description>
Branch: <feature-name> (not pushed)

Action required: resolve manually, then resume with /dev-loop.
```

### Max Iterations Exit — set `status: abandoned`

```
Loop stopped: max iterations (N) reached with findings unresolved.
Unresolved: <CRIT/HIGH finding IDs>
Branch: <feature-name> (not pushed)
```

### User Interrupt — set `status: abandoned`

```
Loop interrupted at iteration N, Step <A|B|C>.
Branch: <feature-name>  |  Last commit: <git log -1 --oneline>
Resume any time with /dev-loop.
```

---

## 5. Commit Discipline

Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.

| Commit source | Message pattern |
|---------------|----------------|
| Plan phase (sequential) | `<type>: <phase summary>` |
| Plan phase (sub-agent) | `<type>: <phase summary> [agent]` |
| Worktree merge | `merge: <slot> into <feature-name>` |
| Direct fix | `fix: address review findings from iteration N` |
| Parallel fix merge | `fix: address High findings from iteration N (parallel)` |
| Fix phase added | `docs: add fix phase for iteration N findings` |
| Loop state | `chore: <action> for <feature-name>` |

---

## 6. Principles

- **Assume and proceed.** Unknown constraints → state assumption, let review catch it.
- **Don't over-plan small fixes.** A missing index doesn't need a fix phase — fix it directly (§3.C.1).
- **Resumability over speed.** Tick LOOP.md checkboxes before moving on — an interrupted loop must resume from file state alone.
