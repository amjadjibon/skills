---
name: dev-loop
description: Run an autonomous plan → implement → review loop for a feature. Iterates until the code review passes, fixing findings between iterations and pausing for user approval before closing. Use when the user says "loop on this", "keep going until it passes review", "autonomous dev loop", "plan implement and review", or wants a self-correcting agent workflow for a feature.
argument-hint: "[lite|full|ultra]"
---

# Dev Loop — Autonomous Multi-Agent Orchestrator

You are the **orchestrator agent**:

```
[task] → dev-create-plan → implement (agents) → dev-code-review
                            ↑                      |
            merge worktrees |       ┌──────────────┘
                            └──── fix agents (parallel)
                                                    ↓ (only Low/Info remain)
                                            pause → user approval → push + PR
```

Fully autonomous. Pause only for: user approval before push/PR, an unfixable `Critical` finding, or `max_iterations` reached.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — single branch `<feature-name>`, no phase branches, one PR at the end.
- `full` — phases sequential on stacked branches/PRs.
- `ultra` — phases with no shared dependencies build in parallel worktrees off `main`; merge each into the stack when done.

**Pass the mode through** to every sub-skill (`dev-create-plan`, `dev-implement-plan`, `dev-qa`, `dev-code-review`). `<work-branch>` = `<feature-name>` in `lite`, or the current `<feature>/phase-N` in `full`/`ultra`.

## 0. Parallelism Rules

- Phases run sequentially (stacked PRs require it), except `ultra`.
- Fix agents run in parallel only for genuinely independent domains (backend + frontend, auth + notifications) — not merely different files. Shared type/interface/config/test fixture → one agent. When in doubt, one agent.
- Limits from LOOP.md frontmatter: `max_agents` (3) — merge smallest clusters to fit; `max_phases` (5) — if exceeded, stop and tell the user.

## 1. Bootstrap

1. **Feature name**: kebab-case slug of the task ("Add rate limiting to /api/login" → `rate-limit-login`).
2. **Research**: `git status && git branch --show-current`; read 3–5 key files; state assumptions in the plan's §4; never ask the user. If the task hinges on an unfamiliar third-party API/library/technology, run `dev-research` first (same mode) → `docs/<feature-name>/RESEARCH.md`. If the feature needs its shape decided (system design, data model, API contract, UI/UX) before it can be phased, run `dev-design` next (same mode) → `docs/<feature-name>/DESIGN.md`. Scoped questions surfacing later are handled by sub-skills spawning `dev-research` sub-agents (dev-research §6).
3. **Plan**: `dev-create-plan` (autonomous) → `docs/<feature-name>/PLAN.md` on branch `<feature-name>`.
4. **Review plan**: `dev-review-plan`. `Ready` → proceed. `Needs Revision` → apply Revise findings in one commit (`docs: revise plan based on review`), proceed. `Blocked` → stop, report. **Small-task off-ramp**: if the plan is a single phase with ≤2 tasks, skip this review and fold `dev-qa` (Step A.5) into the implement step — the ceremony costs more than a 5-line feature; the code review (Step B) stays mandatory, it's what catches real bugs.
5. **Init LOOP.md** from this template (the loop parses it to resume — keep the structure exact), commit `chore: init dev loop for <feature-name>`:

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

<!-- one row per phase from PLAN.md; `lite`: single row, branch <feature-name> -->

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

## 2. Worktree Management

All worktrees live under `.worktrees/` (gitignore it once: `grep -qx '.worktrees/' .gitignore 2>/dev/null || { echo '.worktrees/' >> .gitignore && git add .gitignore && git commit -m "chore: gitignore .worktrees"; }`). The orchestrator owns creation, tracking, removal.

**Create** (one step — checking the branch out first makes `worktree add` fail):

```bash
git worktree add .worktrees/<feature-name>-<slot> -b <feature-name>-<slot> <feature-name>
```

`<slot>`: `phase-2`, `fix-HIGH-001`, `fix-cluster-auth`. Add a LOOP.md Active Worktrees row before handoff; track `assigned → running → merged → removed`.

**Assign** — spawn with the plugin's agent types when available (`dev-implementer` for phases, `dev-fixer` for fixes, `dev-researcher` for research questions), else general-purpose. Implementation phases: use the phase's `**Agent Prompt**` from PLAN.md verbatim, prepend `Worktree path: .worktrees/<feature-name>-<slot>`. Fix agents:

```
You are a sub-agent fixing review findings in an isolated git worktree.

Worktree path: .worktrees/<feature-name>-<slot>
Branch: <feature-name>-<slot>
Base branch: <work-branch>

Findings to fix:
- [HIGH-001] <title> — <file:line> — <what to change>

Rules: stay inside the worktree; `git add -u` (explicit paths for new files) and
commit "fix: <slot description>" — no Co-authored-by; reply with a one-paragraph
summary + commit SHA; do NOT push, open PRs, or modify LOOP.md.
```

**Merge & remove**:

```bash
git checkout <feature-name>
git merge --no-ff <feature-name>-<slot> -m "merge: <slot description> into <feature-name>"
git worktree remove .worktrees/<feature-name>-<slot>
git branch -d <feature-name>-<slot>
```

Conflicts: two agents on one file → read both, merge intent; fix agent vs main branch → fix agent wins unless it reverts a passing test. Update the LOOP.md row (`removed`/`failed`). Before final push: `git worktree list` — remove leftovers.

## 3. The Loop

Repeat until an exit condition (§4).

**Step A — Implement.** If PLAN.md phases > `max_phases`: stop, ask user to split or raise the limit. Per phase: `dev-implement-plan` (`full`: branch + stacked PR, update the Stacked PRs table; `lite`: stays on `<feature-name>`, PR deferred to Clean Exit). After all phases tick `- [x] dev-implement-plan`.

**Step A.5 — QA (iteration 1 only).** `dev-qa` (same mode) on `<work-branch>` → `docs/<feature-name>/QA.md`. Commit tests; record HEAD as `last_review_base`.

**Step B — Review.** Diff base: iteration 1 `main...HEAD`; later `<last_review_base>...HEAD`. Run `dev-code-review` → REVIEW.md; parse the `## Machine-Readable Verdict` YAML. Tick checkbox, fill iteration table, update `last_review_base`.

**Step C — Decide:**

| Condition | Action |
|-----------|--------|
| `Approve` or only Low/Info | §4 Clean Exit |
| Medium only | §3.C.1 direct fix |
| High | §3.C.2 fix agents (parallel only if independent domains) |
| Any Critical | §4 Blocked Exit |
| `current_iteration` = `max_iterations` | §4 Max Iterations Exit |

After any fix path: increment `current_iteration`, append a new `### Iteration N+1` log block (implement-or-fix / review / decide checkboxes).

**§3.C.1 — Direct fix (Medium/Low):** fix on `<work-branch>`, `git add -u && git commit -m "fix: address review findings from iteration N"`, push. Go to Step B.

**§3.C.2 — Fix agents (High):** group findings by domain (shared type/config/fixture → same group; merge smallest groups to fit `max_agents`). Per group: worktree off `<work-branch>`, spawn agent with its finding IDs. Then merge all, remove worktrees, push. Go to Step B.

**§3.C.3 — Fix phase in PLAN.md:** only when a High finding needs a missing abstraction or migration, not a patch — and only if it won't exceed `max_phases` (`lite` has no phases). Append `### Phase N+1` with `TASK-NNN: Fix [HIGH-001]…`, bump version, commit `docs: add fix phase for iteration N findings`. Go to Step A. Default to §3.C.2.

## 4. Exit Conditions

Every exit but Clean: clean up worktrees first.

**Clean Exit** — set LOOP.md `status: awaiting-approval` and commit (`chore: await approval for <feature-name>`) so a resumed loop can tell "paused for the user" from "mid-flight" by file state alone, then present verdict + findings summary and **wait for approval**: "Approve to push and open PR, or ask me to continue fixing?" On approval: LOOP.md `status: complete` + commit `chore: dev loop complete for <feature-name>`; verify worktrees gone; `full`: ensure every phase PR is open (`gh pr list --head "<feature-name>/phase-*"`); `lite`: push and `gh pr create --base main`; run `dev-clean-up`; report PR URLs (merge order: phase-1 first — GitHub auto-retargets).

**Blocked Exit** (`status: blocked`) — report the Critical finding, branch not pushed, "resolve manually, then resume with /dev-loop".

**Max Iterations Exit** (`status: abandoned`) — report unresolved CRIT/HIGH IDs, branch not pushed.

**User Interrupt** (`status: abandoned`) — report iteration, step, last commit; resumable with /dev-loop.

## 5. Commit Discipline

Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.

| Source | Message |
|--------|---------|
| Plan phase | `<type>: <phase summary>` (`[agent]` suffix if sub-agent) |
| Worktree merge | `merge: <slot> into <feature-name>` |
| Direct fix | `fix: address review findings from iteration N` |
| Parallel fix merge | `fix: address High findings from iteration N (parallel)` |
| Fix phase added | `docs: add fix phase for iteration N findings` |
| Plan checkbox tick | fold into the phase's work commit, never standalone |
| Loop state | `chore: <action> for <feature-name>` |

State updates (LOOP.md, PLAN.md checkboxes) ride along in the adjacent work commit when one exists; a standalone `chore:` state commit is only for updates with no adjacent work (recording a review, init, awaiting approval). Bookkeeping commits outnumbering feature commits is a smell.

## 6. Principles

- Assume and proceed — state assumptions, let review catch them.
- Don't over-plan small fixes — a missing index is a §3.C.1 fix, not a phase.
- Resumability over speed — tick LOOP.md checkboxes before moving on; an interrupted loop must resume from file state alone.
