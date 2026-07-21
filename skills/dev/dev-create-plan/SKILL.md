---
name: dev-create-plan
description: Write docs/<feature-name>/PLAN.md with phased, checkbox-driven steps for a feature, refactor, upgrade, or infrastructure change. Trigger on "create/make a plan", "plan this feature/refactor/upgrade", any request to document steps or a task checklist before coding — and proactively whenever implementation complexity warrants a written plan first.
argument-hint: "[lite|full|ultra]"
---

# Create Implementation Plan

Create `docs/<feature-name>/PLAN.md` for autonomous execution by agents or humans.

**Interactive** (user runs it): ask one focused question only if scope is truly ambiguous. **Autonomous** (called by `dev-loop`): never ask — research, assume, document.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — collapse the template into a single "Phase 1"; one branch `<feature-name>`, one PR at the end.
- `full` — one phase per unit of work; stacked branches `<feature>/phase-N` off `phase-N-1`, one PR per phase.
- `ultra` — like `full`, but phases with no shared dependencies get `**Parallel**: yes` so implement/loop can build them in worktrees off `main`.

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
2. PR titles: imperative ≤60 chars, never prefixed with `phase N`.
3. Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

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

- [ ] TASK-00X: <exact action with file path, function, or command>

**Completion criteria**: <measurable condition>

**git commit**: `git add -u && git commit -m "<type>: <phase N summary>"`

**Agent Prompt**:
```
You are a sub-agent implementing Phase N of <feature-name>.

Context: <1-2 sentences: the feature and this phase's contribution.>
Branch: <feature-name> (lite) or <feature-name>/phase-N (full/ultra)  |  Base: main or <feature-name>/phase-N-1

Tasks:
- TASK-00X: <exact description>

Key files:
- <path/to/file.ext> — <what to do>

Completion criteria: <verbatim from above>

When done: git add -u && git commit -m "<type>: <phase N summary>" — no Co-authored-by.
Reply with a one-paragraph summary and commit SHA.
Do NOT push, open PRs, or modify PLAN.md.
```

## 3. Testing

- [ ] TEST-001: <specific test with file path>

## 4. Risks & Assumptions

- **RISK-001**: <risk> — mitigation: <how>
- **ASSUMPTION-001**: <assumed true without user confirmation>
````

`lite`: one "Phase 1" covers the whole feature. `full`/`ultra`: repeat the phase block per phase.

## Process

Research (Step 0) → `git checkout -b <feature-name>` → write PLAN.md from the template (Agent Prompt in every phase) → commit → report: "Plan created at `docs/<feature-name>/PLAN.md` on branch `<feature-name>`."
