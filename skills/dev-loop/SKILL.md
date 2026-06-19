---
name: dev-loop
description: Run an autonomous plan → implement → review loop for a feature. Iterates until the code review passes, fixing findings between iterations and pausing for user approval before closing. Use when the user says "loop on this", "keep going until it passes review", "autonomous dev loop", "plan implement and review", or wants a self-correcting agent workflow for a feature.
---

# Dev Loop — Autonomous Multi-Agent Orchestrator

You are the **orchestrator agent**. Given a task description, drive the full cycle:

```
[task] → create-plan → implement (agents) → code-review
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

## 0. Parallelism Rules

**Phases always run sequentially** — stacked PRs require it.

**Fix agents run in parallel only when domains are genuinely independent** — different service boundaries (backend API + frontend UI, auth + notifications), not just different files. If fixes share a type, interface, config, or test fixture → single agent.

| Scenario | Rule |
|----------|------|
| Plan phases | Always sequential |
| Fix findings in independent domains | Parallel fix agents via worktrees |
| Fix findings in the same domain / sharing types | Single agent |
| Phase + review | Always sequential |

**Parallelism threshold:** Spawn parallel agents only for 2+ findings in genuinely independent domains. When in doubt, use a single agent.

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

### 1c. Create the plan

Run `create-plan` in autonomous mode → `docs/<feature-name>/PLAN.md` on branch `<feature-name>`.

### 1c.5. Review the plan

Run `review-plan`. Parse the verdict:
- `Ready` → proceed to §1d
- `Needs Revision` → apply all Revise findings in a single commit (`docs: revise plan based on review`), then proceed
- `Blocked` → stop, report blocking findings; do not proceed

### 1d. Initialise LOOP.md

Create `docs/<feature-name>/LOOP.md` with:
- Frontmatter: `feature`, `task`, `branch`, `started`, `max_iterations: 3`, `max_phases: 5`, `max_agents: 3`, `current_iteration: 1`, `status: running`, `last_review_base: ''`
- Iteration table (cols: Iter / Verdict / Crit / High / Med / Low / Mode / Action) — row 1 all `—`
- Stacked PRs table (cols: Phase / Branch / PR URL / Base / Status) — one row per phase, Status: `pending`
- Active Worktrees table (cols: Worktree path / Branch / Purpose / Status) — initially empty
- Log section: `### Iteration 1` with four unchecked items: `implement-plan`, `qa`, `code-review`, `decide`

Commit: `git add docs/<feature-name>/LOOP.md && git commit -m "chore: init dev loop for <feature-name>"`

---

## 2. Worktree Management

All worktrees live under `.worktrees/`. The orchestrator owns all creation, tracking, and removal.

### Create a worktree

```bash
git checkout <feature-name>
git checkout -b <feature-name>-<slot>        # e.g. rate-limit-login-phase-2
git worktree add .worktrees/<feature-name>-<slot> <feature-name>-<slot>
```

`<slot>` is descriptive: `phase-2`, `fix-HIGH-001`, `fix-cluster-auth`. Add a row to LOOP.md "Active Worktrees" before handing off. Track status: `assigned → running → merged → removed`.

### Assign an agent

Spawn with:
```
You are a sub-agent working in an isolated git worktree.

Worktree path: .worktrees/<feature-name>-<slot>
Branch: <feature-name>-<slot>
Base branch: <feature-name>

Your task:
<one-paragraph description — which PLAN.md tasks or REVIEW.md finding IDs to fix>

Rules:
- All work stays inside the worktree path. Do not touch files outside it.
- Use `git add -u` (or explicit paths for new files) and commit after completing your task.
- Commit message: "<type>: <slot description>" — no Co-authored-by trailers.
- When done, write a one-paragraph summary of changes and commit SHA produced.
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
1. `implement-plan` creates branch `<feature>/phase-N`, implements tasks, opens stacked PR
2. Update LOOP.md Stacked PRs table (branch, PR URL, base)

After all phases: tick `- [x] implement-plan`, record `Mode: sequential` in iteration table.

### Step A.5 — QA (iteration 1 only)

Run `qa` on the feature branch → `docs/<feature-name>/QA.md`. QA runs once after first implementation only. Commit QA tests, then record HEAD SHA as `last_review_base` in LOOP.md.

### Step B — Review

Diff base:
- Iteration 1: `git diff main...HEAD`
- Iteration 2+: `git diff <last_review_base>...HEAD`

Run `code-review` → `docs/<feature-name>/REVIEW.md`. Parse `## Machine-Readable Verdict` YAML for `verdict`, `critical`, `high`, `medium`, `low`, `blocking_ids`.

Update LOOP.md: tick `- [x] code-review`, fill iteration table, update `last_review_base` to current HEAD.

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
- [ ] implement-plan (or "fix only — no re-implement")
- [ ] code-review
- [ ] decide
```

---

**§3.C.1 — Direct fix (Medium/Low only):**

Fix on the last phase branch (`<feature>/phase-N`). Do not update `PLAN.md`.
```bash
git add -u && git commit -m "fix: address review findings from iteration N"
git push origin <feature>/phase-N
```
Tick `- [x] decide`. Increment iteration. Go to Step B (skip Step A).

---

**§3.C.2 — Parallel fix agents (High findings):**

Fix base is `<feature>/phase-N`. Group findings by work domain — same domain (e.g. two backend handlers) → one group; genuinely independent domains (backend + frontend) → separate groups. Findings sharing a type, interface, config, or test fixture → same group.

If groups exceed `max_agents`, merge smallest until within limit.

For each group:
1. Create worktree off `<feature>/phase-N`: `.worktrees/<feature>-fix-<group-id>`
2. Spawn agent for that group's finding IDs

After all complete: merge all worktrees to `<feature>/phase-N`, remove worktrees, push. Tick `- [x] decide`. Increment iteration. Go to Step B.

---

**§3.C.4 — Fix phase in PLAN.md (High findings too large for a patch):**

Use when a finding reveals a missing abstraction or schema migration — not a targeted code change. First check adding a phase won't exceed `max_phases`; if it would, fall back to §3.C.2.

On `<feature>/phase-N`, append to `PLAN.md`:
```
### Phase N+1: <descriptive name>
- [ ] TASK-NNN: Fix [HIGH-001] <title> — <one-line description>
```
Bump `version` and `last_updated`. Commit: `docs: add fix phase for iteration N findings`. Tick decide, increment, go to Step A.

**Default to §3.C.2.** Use §3.C.4 only when a patch isn't sufficient.

---

## 4. Exit Conditions

### Clean Exit

Present:
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
3. Confirm all phase PRs are open: `gh pr list --head "<feature-name>/phase-*"`. Open any missing ones
4. Run `clean-up`
5. Report:
```
Loop complete: <feature-name>
Iterations: N  |  Final verdict: Approve
Stacked PRs (merge in order):
  phase-1: <url>  → base: main
  phase-2: <url>  → base: phase-1
```

### Blocked Exit

Clean up worktrees, set `status: blocked`, report:
```
Loop blocked on Critical finding (Iteration N).
Finding: [CRIT-001] <title>
Issue: <one-line description>
Branch: <feature-name> (not pushed)

Action required: resolve manually, then resume with /dev-loop.
```

### Max Iterations Exit

Clean up worktrees, set `status: abandoned`:
```
Loop stopped: max iterations (N) reached with findings unresolved.
Unresolved: <CRIT/HIGH finding IDs>
Branch: <feature-name> (not pushed)
```

### User Interrupt

Clean up worktrees. Set `status: abandoned`:
```
Loop interrupted at iteration N, Step <A|B|C>.
Branch: <feature-name>  |  Last commit: <git log -1 --oneline>
Resume any time with /dev-loop.
```

---

## 5. Commit Discipline

- `git add -u` for tracked files; explicit paths for new files. Never `git add -A`
- No `Co-authored-by:` trailers
- Subject ≤ 72 chars, imperative mood, explain why not what

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

- **Assume and proceed.** Unknown constraints → state assumption, proceed, let review catch it.
- **Default to parallel.** Two+ independent units → agents. One unit → inline.
- **Orchestrator owns worktrees.** Sub-agents work inside their worktree only.
- **Don't over-plan small fixes.** A missing index doesn't need a fix phase — fix it directly (§3.C.1).
- **Low/Info never block.** If only Low/Info remain, the review passes.
- **Resumability over speed.** Tick LOOP.md checkboxes before moving on — an interrupted loop must resume from file state alone.
