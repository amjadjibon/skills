---
name: dev-create-plan
description: Create a new plan file for new features, refactoring existing code or upgrading packages, design, architecture or infrastructure. Trigger when the user says "create a plan", "make an implementation plan", "plan for this feature", "write a plan before we start", "plan this refactor", "plan this upgrade", or any request to document steps before starting work. Also trigger when the user mentions wanting a structured approach, phased rollout, or task checklist for a coding task. Use this skill proactively whenever implementation complexity warrants a written plan before jumping into code.
argument-hint: "[lite|full|ultra]"
---

# Create Implementation Plan

Create `docs/<feature-name>/PLAN.md` for autonomous execution by agents or humans.

**Interactive mode** (user runs `/create-plan`): ask one focused question if scope is truly ambiguous; otherwise proceed.
**Autonomous mode** (called by `dev-loop`): never ask — research, assume, document.

## Delivery Mode (`lite | full | ultra`, default `lite`)

- `lite` (default) — one phase, one branch, single PR at the end. Collapse the template into a single "Phase 1".
- `full` — current behavior: one phase per unit of work, stacked branches (`<feature>/phase-N` off `phase-N-1`), one PR per phase.
- `ultra` — like `full`, but mark phases with no shared dependencies `**Parallel**: yes` so `dev-implement-plan`/`dev-loop` can build them in separate worktrees off `main` instead of stacking.

## Step 0 — Research First

```bash
git branch --show-current
find . -type f -name "*.go" | head -20   # or *.ts, *.py
ls docs/ 2>/dev/null
```

Read 3–5 key files (routing, middleware, error handling, tests). Record findings as `ASSUMPTION-*` in §4.

## Git

1. `git checkout -b <feature-name>`
2. Commit plan: `git add docs/<feature-name>/PLAN.md && git commit -m "plan: <feature-name>"`
3. Stacked PRs: phase 1 off `main`, phase N off phase N-1. PR titles: imperative ≤60 chars, never prefix with `phase N`.
4. Branches: `<feature-name>/phase-1`, `<feature-name>/phase-2`, …

Commit hygiene: `git add -u` for tracked files, explicit paths for new. Never `git add -A`. No `Co-authored-by:`. Subject ≤72 chars.

## Status badges

`Planned` → blue · `In progress` → yellow · `Completed` → brightgreen · `On Hold` → orange · `Deprecated` → red

`https://img.shields.io/badge/status-<status>-<color>` (spaces → `%20`)

## Tracker IDs

If user provides a ticket: add `ticket:` to frontmatter + blockquote link under badge.
`[A-Z]+-\d+` → Jira · `LIN-\d+` → Linear · full URL → use as-is. Include in commit: `plan: <feature-name> (<id>)`.

## Planning Principles

- Assume, don't ask. Name the chosen approach and why.
- Cut speculative phases — YAGNI. Fewer phases is better.
- Stdlib/platform before new dependencies.
- Completion criteria must be a runnable command or observable behaviour, not "it should work".
- Each task: one sentence of what, one of why (if non-obvious).
- One phase = one goal. "And also…" → new phase.

## Agent Prompt Rules

Every phase must include a self-contained `**Agent Prompt**` block — the orchestrator hands it to a sub-agent with no other context.

- No "as discussed" — the agent starts cold
- Include: goal, branch, base branch, exact tasks, key files (specific paths from Step 0 research), completion criteria, git instructions
- Agent must not push, open PRs, or modify PLAN.md

## Mandatory Template

```markdown
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

> After completing all tasks in a phase, `git add -u` and commit. No `Co-authored-by:`. Tick `[x]` as each task completes.

### Phase N: <Phase Name>

**Goal**: <What this phase achieves and why it's ordered here.>

**Depends on**: Phase N-1 complete (omit for Phase 1)

- [ ] TASK-00X: <Exact action with file path, function, or command.>

**Completion criteria**: <Measurable condition>

**git commit**: `git add -u && git commit -m "<type>: <phase N summary>"`

**Agent Prompt**:
```
You are a sub-agent implementing Phase N of <feature-name>.

Context: <1-2 sentences: what the feature does and what this phase contributes.>

Branch: <feature-name>/phase-N  |  Base: <feature-name>/phase-N-1 (main for Phase 1)

Tasks:
- TASK-00X: <exact description>

Key files:
- <path/to/file.ext> — <what to do>

Completion criteria: <verbatim from above>

When done: git add -u && git commit -m "<type>: <phase N summary>" — no Co-authored-by
Write a one-paragraph summary of changes and commit SHA.
Do NOT push, open PRs, or modify PLAN.md.
```

Repeat this block per phase.

---

## 3. Testing

- [ ] TEST-001: <Specific test with file path>
- [ ] TEST-002: <Integration test or manual step>

## 4. Risks & Assumptions

- **RISK-001**: <Risk> — mitigation: <how>
- **ASSUMPTION-001**: <Assumed true without user confirmation>
```

## Process

1. Research (Step 0)
2. `git checkout -b <feature-name>`
3. Write `docs/<feature-name>/PLAN.md` using the template above — include Agent Prompt for every phase
4. `git add docs/<feature-name>/PLAN.md && git commit -m "plan: <feature-name>"`
5. Tell the caller: "Plan created at `docs/<feature-name>/PLAN.md` on branch `<feature-name>`."
