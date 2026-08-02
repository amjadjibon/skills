---
name: dev-loop
description: Run an autonomous plan → implement → review loop for a feature, iterating until the code review passes and pausing for approval before pushing. Use on "loop on this", "keep going until it passes review", "autonomous dev loop", "plan implement and review", or a self-correcting agent workflow.
argument-hint: "[lite|full|ultra]"
---

# Dev Loop — Autonomous Multi-Agent Orchestrator

You are the **orchestrator agent**:

```
[task] → dev-create-plan → implement (agents) → dev-qa → dev-code-review
                            ↑                                 |
            merge worktrees |               ┌─────────────────┘
                            └──── fix agents (parallel)
                                                    ↓ (only Low/Info remain)
                                            pause → user approval → push + PR
```

Fully autonomous. Pause only for: user approval before push/PR, an unfixable `Critical` finding, or a fix cycle that stalled or ran out of iteration budget (§0, §4). In `full`/`ultra`, this cycle runs **per phase** — implement, test, review, fix that one phase clean — before the next phase starts, not batched across the whole plan (§3).

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — however many phases the plan has, all on the single branch `<feature-name>`; no phase branches, one PR at the end.
- `full` — phases sequential on stacked branches/PRs.
- `ultra` — phases with no shared dependencies build in parallel worktrees off `main`; merge each into the stack when done.

**Pass the mode and the artifact root through** to every sub-skill (`dev-create-plan`, `dev-implement-plan`, `dev-qa`, `dev-code-review`). `<work-branch>` = `<feature-name>` in `lite`, or the current phase's `<feature-name>/<phase-slug>` (its PLAN.md `**Branch**` field) in `full`/`ultra`.

## 0. Parallelism Rules

- **Nothing git-visible names the machinery.** Branches, commit subjects, and PR titles describe the work — never a skill, loop, iteration, phase number, finding ID, or LOOP.md status. That bookkeeping lives in the artifacts.
- Phases run sequentially (stacked PRs require it), except `ultra`.
- Fix agents run in parallel only for genuinely independent domains (backend + frontend, auth + notifications) — not merely different files. Shared type/interface/config/test fixture → one agent. When in doubt, one agent. **Not capped** — independence sets the count; a cap would only force unrelated findings together.
- Phase count isn't capped either; mode decides only where phases get built.
- **The fix cycle is what's bounded** — an unconverging loop spins forever unattended. Two guards, both ending in a check-in, not a failure (§4):
  - **Stall** (the real signal): a fix pass that didn't reduce Crit+High, or a finding ID surviving two consecutive fix passes.
  - **`max_iterations`** (backstop, for the grind that progresses but goes nowhere): `lite` 3, `full` 5, `ultra` 8 — bigger work, more room to converge. Set it into LOOP.md at init (§1.7). Per-phase in `full`/`ultra` (Step A resets it), whole-loop in `lite`, where 3 is deliberately tight: a `lite` run grinding past it wanted to be `full`.

## 1. Bootstrap

1. **Feature name**: kebab-case slug of the task ("Add rate limiting to /api/login" → `rate-limit-login`).
2. **Artifact root**: `docs/`, or wherever the user named / this feature already lives. Every artifact path below is relative to it; record it as LOOP.md `artifact_root`. `git check-ignore -q <root>` once — if ignored, write and read the artifacts as usual but skip every artifact commit (resume reads disk, not history).
3. **Too foggy to loop?** If the task has no phaseable shape yet — the destination itself is unsettled, not just its details — stop and tell the user to run `dev-wayfinder` first; a loop that plans from guesses spends its whole iteration budget discovering them. This is a judgement call made once, at the start, and it is the one thing the loop refuses to assume its way through.
4. **Research**: `git status && git branch --show-current`; read 3–5 key files; state assumptions in the plan's §4; never ask the user. If the task hinges on an unfamiliar third-party API/library/technology, run `dev-research` first (same mode) → `docs/<feature-name>/RESEARCH.md`. If the feature needs its shape decided (system design, data model, API contract, UI/UX) before it can be phased, run `dev-design` next (same mode) → `docs/<feature-name>/DESIGN.md` — when the API-contract axis is in play, `dev-design` defers to `dev-api-design` for the REST/GraphQL resource shape, versioning, and pagination decisions before writing them into DESIGN.md. Scoped questions surfacing later are handled by sub-skills spawning `dev-research` sub-agents (dev-research §6).
5. **Plan**: `dev-create-plan` (autonomous) → `docs/<feature-name>/PLAN.md` on branch `<feature-name>`. Task explicitly wants TDD/test-first? Tell it to mark the affected phases `**Test-first**: yes` — `dev-implement-plan` (Step A) then builds those phases through `dev-tdd`'s red → green loop instead of implementation-then-tests.
6. **Review plan**: `dev-review-plan`. `Ready` → proceed. `Needs Revision` → apply Revise findings in one commit (`docs: revise plan based on review`), proceed. `Blocked` → stop, report. **Small-task off-ramp**: if the plan is a single phase with ≤2 tasks, skip this review and fold `dev-qa` (Step A.5) into the implement step — the ceremony costs more than a 5-line feature; the code review (Step B) stays mandatory, it's what catches real bugs.
7. **Init LOOP.md** from [LOOP-TEMPLATE.md](LOOP-TEMPLATE.md) — read it now, fill `max_iterations` for this mode from §0, commit `docs: track <feature-name> progress`. The loop parses that structure to resume, so keep it exact.

## 2. Worktree Management

Worktrees live under `.worktrees/`; the orchestrator owns creation, tracking, and removal, and
records each one in LOOP.md's Active Worktrees table. Read
[WORKTREES.md](WORKTREES.md) for the create/assign/merge/remove commands, the fix-agent briefing,
and the conflict rules — needed the moment this loop spawns its first sub-agent, skippable in a
`lite` run that never forks one.

## 3. The Loop

Repeat until an exit condition (§4). `lite` runs the whole plan through one Implement → QA → Review → Fix cycle at a time — every phase on one branch means one review of the lot, not one per phase. `full`/`ultra` run **one phase at a time** through its own cycle before starting the next — a bug from phase 1 gets caught by phase 1's own review, not carried forward for phase 3 to build on top of.

**Step A — Implement.** Every implementing agent (and the orchestrator when it writes code itself) works under `dev-ponytail` — smallest thing that works, reuse before adding, stdlib before a dependency. A test or build failing for a reason nobody can name is a `dev-debug` job, not a guess-and-retry loop.

- `lite`: implement every task across all phases in one pass on `<feature-name>`; tick `- [x] dev-implement-plan` once done.
- `full`/`ultra`: implement **one phase** (branch + stacked PR, update the Stacked PRs table), tick that phase's checkbox — then go straight to Step A.5 for this phase. Don't start the next phase until this one clears Step C. Reset `current_iteration` to 1 when starting a new phase — `max_iterations` is a per-phase budget, so one difficult phase's fix cycles don't starve the iteration allowance for phases after it.

**Step A.5 — QA.** Run whenever this pass added new code: the `lite` pass, each `full`/`ultra` phase, and any `§3.C.3` fix-phase. Skip only when this pass was a `§3.C.1`/`§3.C.2` fix with no new phase (existing code re-reviewed directly, nothing new to cover). `dev-qa` (same mode) on the branch just built → `docs/<feature-name>/QA.md` (`full`/`ultra`: append a section per phase, don't overwrite prior phases' results). Commit tests; record HEAD as `last_review_base`.

**Step A.6 — Smoke check (optional).** If this pass stood up something runnable locally (a service, a new endpoint, a CLI command) and it can be started in the worktree, use `dev-smoke-testing` to write/run the one or two checks that confirm it's actually alive before spending review budget on it — the orchestrator running it itself in place of manually curling the endpoint, not an automated gate. Skip entirely when there's nothing to run (a library change, a pure refactor) or starting the service isn't feasible in this environment.

**Step B — Review.** Diff base: first review of a branch → `main...HEAD` (`lite`) or `<previous-phase-branch>...HEAD` (`full`/`ultra`); later reviews on the same branch → `<last_review_base>...HEAD`. Run `dev-code-review` → REVIEW.md; parse the `## Machine-Readable Verdict` YAML. Tick checkbox, fill iteration table — counts, the phase number in `full`/`ultra`, and the **Open Crit/High IDs** the stall guard compares against the previous row — and update `last_review_base`.

**Step C — Decide:**

| Condition | Action |
|-----------|--------|
| `Approve` or only Low/Info | `lite`: §4 Clean Exit. `full`/`ultra`: this phase is done — advance to the next phase's Step A, or §4 Clean Exit if it was the last phase. |
| Medium only | §3.C.1 direct fix |
| High | §3.C.2 fix agents (parallel only if independent domains) |
| Any Critical | §4 Blocked Exit |
| A finding is a performance claim (slow path, N+1, allocation) | `dev-perf` — measure before optimizing, then fix via §3.C.1/§3.C.2 |
| This pass didn't reduce Crit+High, or a finding ID survived two consecutive fix passes | §4 Stalled Check-in |
| `current_iteration` = `max_iterations` | §4 Budget Check-in |

After any fix path: increment `current_iteration`, append a new `### Iteration N+1` log block (implement-or-fix / QA / review / decide checkboxes — QA only when §3.C.3 added a phase).

**§3.C.1 — Direct fix (Medium/Low):** fix on the branch under review, `git add -u && git commit -m "fix: <what was actually wrong>"` — the defect in plain terms, not the finding IDs — then push. Go to Step B (no Step A.5 — no new code to cover).

**§3.C.2 — Fix agents (High):** group findings by domain (shared type/config/fixture → same group). Per group: worktree off the branch under review, spawn agent with its finding IDs. Then merge all, remove worktrees, push. Go to Step B (no Step A.5).

**§3.C.3 — Fix phase in PLAN.md:** only when a High finding needs a missing abstraction or migration, not a patch (`lite` gets fix phases too, just built on one branch rather than a stack). Append `### Phase N+1` with `TASK-NNN: Fix [HIGH-001]…`, bump version, commit `docs: plan <what the new phase delivers>`. Go to Step A (this new phase runs its own A → A.5 → B cycle). Default to §3.C.2.

## 4. Exit Conditions

Every exit but Clean: clean up worktrees first.

**Clean Exit** — set LOOP.md `status: awaiting-approval` and commit (§5's state subject — the file carries the status, the message doesn't) so a resumed loop can tell "paused for the user" from "mid-flight" by file state alone, then present verdict + findings summary and **wait for approval**: "Approve to push and open PR, or ask me to continue fixing?" On approval: LOOP.md `status: complete` + the same commit; verify worktrees gone; `full`/`ultra`: `gh stack submit --auto --open`, then `gh stack view --json` to confirm every phase PR is open (see `git-safe` § Stacked PRs); `lite`: push and `gh pr create --base main`; run `dev-clean-up`; report PR URLs (a stack lands bottom-up via `gh stack merge --yes`, never `gh pr merge`). The loop ends at the merged PR; shipping that merge to users is `dev-release`, invoked separately.

**Blocked Exit** (`status: blocked`) — report the Critical finding, branch not pushed, "resolve manually, then resume with /dev-loop".

**Stalled / Budget Check-in** (`status: awaiting-input`) — a spending decision, not a dead end. Report which guard tripped, the unresolved CRIT/HIGH IDs, and what the last pass changed (`full`/`ultra`: which phase); branch not pushed. Ask: continue fixing, take it as-is to Clean Exit, or stop? On "continue", reset `current_iteration` to 1 → Step A, guards armed again.

**User Interrupt** (`status: abandoned`) — report iteration, step, last commit; resumable with /dev-loop.

## 5. Commit Discipline

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

Every subject names the work, never this workflow (§0).

| Source | Message |
|--------|---------|
| Plan phase | `<type>: <what this phase delivers>` |
| Worktree merge | `merge: <what the slot did> into <feature-name>` |
| Direct fix | `fix: <what was actually wrong>` |
| Parallel fix merge | `fix: <what the group repaired>` |
| Fix phase added | `docs: plan <what the new phase delivers>` |
| Plan checkbox tick | fold into the phase's work commit, never standalone |
| Loop state | `docs: update <feature-name> progress` |

State updates (LOOP.md, PLAN.md checkboxes) ride along in the adjacent work commit when one exists; a standalone state commit is only for updates with no adjacent work (recording a review, init, awaiting approval). Bookkeeping commits outnumbering feature commits is a smell.

## 6. Principles

- Assume and proceed — state assumptions, let review catch them.
- Don't over-plan small fixes — a missing index is a §3.C.1 fix, not a phase.
- Resumability over speed — tick LOOP.md checkboxes before moving on; an interrupted loop must resume from file state alone.
