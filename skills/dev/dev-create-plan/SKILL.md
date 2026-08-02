---
name: dev-create-plan
description: Write docs/<feature-name>/PLAN.md with phased, checkbox-driven steps for a feature, refactor, upgrade, or infrastructure change. Trigger on "create/make a plan", "plan this feature/refactor/upgrade", any request to document steps before coding, and proactively when complexity warrants a written plan.
argument-hint: "[lite|full|ultra]"
---

# Create Implementation Plan

Create `docs/<feature-name>/PLAN.md` for autonomous execution by agents or humans.

**Interactive** (user runs it): ask one focused question only if scope is truly ambiguous. **Autonomous** (called by `dev-loop`): never ask — research, assume, document.

If the work is so undecided that phases would be guesses — the shape, the boundaries, even the goal still open — `dev-wayfinder` maps and resolves those decisions first, then hands back here. One unknown is an assumption to state; a dozen is a map.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

Mode picks the branch topology, never the number of phases — phase count comes from the work, and every mode takes as many as the work has.

- `lite` (default) — however many phases the work needs, all built on one branch `<feature-name>`, one PR at the end.
- `full` — same phases, one branch each: stacked `<feature-name>/<phase-slug>` off the previous phase's branch, one PR per phase (built with `gh-stack` — `git-safe` § Stacked PRs).
- `ultra` — like `full`, plus phases with no shared dependencies get `**Parallel**: yes` so implement/loop can build them in separate worktrees off `main` and merge each into the stack.

Any phase whose tasks should be built test-first gets `**Test-first**: yes` — `dev-implement-plan` builds that phase through `dev-tdd`'s red → green loop instead of implementation-then-tests. Ask when the task doesn't say either way; default to no marker (implement, then `dev-qa`/review catch gaps) unless TDD was requested or the phase is complex enough that tests-first meaningfully reduces risk.

## Artifact Location

Artifact paths below are relative to the artifact root: `docs/` by default, or wherever the user (or
`dev-loop`, which passes the one it resolved) points it. A gitignored or out-of-repo root means the
artifacts are scratch — write and read them as normal, but **never commit them**.

## Step 0 — Research First

```bash
git branch --show-current
find . -type f -name "*.go" | head -20   # or *.ts, *.py
ls docs/ 2>/dev/null
```

Read 3–5 key files (routing, middleware, error handling, tests). Record findings as `ASSUMPTION-*` in §4. If `docs/<feature-name>/RESEARCH.md` or `docs/<feature-name>/DESIGN.md` exists, read them — the plan follows the recommendation/shape they settled and inherits their assumptions.

**Unknown externals → research sub-agents, not guesses.** If the plan hinges on a third-party API, unfamiliar library, or anything a doc/internet lookup can settle, spawn one research sub-agent per question (subagent type `dev-researcher` when available, else general-purpose with the template in dev-research §6; parallel when independent). Reference answers as `research/<topic-slug>.md`; commit the topic files with the plan.

## Git

1. `git checkout -b <feature-name>`, then `git add docs/<feature-name>/PLAN.md && git commit -m "plan: <feature-name>"`.
2. Phase branches (`full`/`ultra`): `<feature-name>/<phase-slug>` — 2–4 kebab words for what the phase does (`auth-service/token-refresh`, not `.../phase-2`), unique within the feature, written into each phase's `**Branch**` field. Order lives in PLAN.md and each branch's base, not the name.
3. PR titles and commit subjects: imperative ≤60 chars, describing the work — never a phase number, iteration count, finding ID, or skill name. That bookkeeping stays in the artifacts.
4. Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

## Status Badges & Tracker IDs

`Planned` blue · `In progress` yellow · `Completed` brightgreen · `On Hold` orange · `Deprecated` red — `https://img.shields.io/badge/status-<status>-<color>` (spaces → `%20`).

Ticket given? Add `ticket:` to frontmatter + blockquote link under the badge (`[A-Z]+-\d+` Jira · `LIN-\d+` Linear · URL as-is); include in commit: `plan: <feature-name> (<id>)`.

## Planning Principles

- Assume, don't ask; name the chosen approach and why.
- Cut speculative phases — fewer is better. One phase = one goal; "and also…" → new phase.
- Stdlib/platform before new dependencies.
- Completion criteria = runnable command or observable behaviour, never "it should work".
- Each task: one sentence what, one why (if non-obvious).

## Agent Prompt Rules

Every phase carries a self-contained `**Agent Prompt**` block — a sub-agent receives it with no other context. No "as discussed". Include: goal, branch, base, exact tasks, key file paths from Step 0, completion criteria, git instructions. The agent must not push, open PRs, or modify PLAN.md.

## Mandatory Template

````markdown
---
goal: <Concise title>
version: 1.0
date_created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
owner: <team or individual>
status: 'Planned'
tags: [feature|upgrade|refactor|chore|architecture|migration|bug]
# ticket: <JIRA-123 | LIN-456 | URL>
---

# <Plan Title>

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

<2-3 sentences: what this achieves and why.>

## 1. Requirements & Constraints

- **REQ-001**: <Functional requirement>
- **SEC-001**: <Security requirement>
- **CON-001**: <Constraint>

## 2. Implementation Steps

> After each phase: `git add -u` and commit. No `Co-authored-by:`. Tick `[x]` as each task completes.

### Phase N: <Phase Name>

**Goal**: <what this phase achieves and why it's ordered here>

**Depends on**: Phase N-1 complete (omit for Phase 1)

**Branch**: `<feature-name>` (lite) or `<feature-name>/<phase-slug>` (full/ultra) — base: `main` or the previous phase's branch

<!-- **Test-first**: yes — include only when this phase should be built via dev-tdd's red → green loop -->

- [ ] TASK-00X: <exact action with file path, function, or command>

**Completion criteria**: <measurable condition>

**git commit**: `git add -u && git commit -m "<type>: <what this phase delivers>"`

**Agent Prompt**:
```
You are a sub-agent implementing Phase N of <feature-name>.

Context: <1-2 sentences: the feature and this phase's contribution.>
Branch: <the phase's **Branch** value, spelled out in full>  |  Base: <the branch it forks from>

Tasks:
- TASK-00X: <exact description>

Key files:
- <path/to/file.ext> — <what to do>

Completion criteria: <verbatim from above>

When done: git add -u && git commit -m "<type>: <what this phase delivers>" — no Co-authored-by.
Reply with a one-paragraph summary and commit SHA.
Do NOT push, open PRs, or modify PLAN.md.
```

## 3. Testing

- [ ] TEST-001: <specific test with file path>

## 4. Risks & Assumptions

- **RISK-001**: <risk> — mitigation: <how>
- **ASSUMPTION-001**: <assumed true without user confirmation>
````

Repeat the phase block per phase in every mode; only the branch/base lines differ (`lite` keeps them all on `<feature-name>`).

## Process

Research (Step 0) → `git checkout -b <feature-name>` → write PLAN.md from the template (Agent Prompt in every phase) → commit → report: "Plan created at `docs/<feature-name>/PLAN.md` on branch `<feature-name>`."
