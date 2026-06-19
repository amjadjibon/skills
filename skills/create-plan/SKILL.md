---
name: create-plan
description: Create a new plan file for new features, refactoring existing code or upgrading packages, design, architecture or infrastructure. Trigger when the user says "create a plan", "make an implementation plan", "plan for this feature", "write a plan before we start", "plan this refactor", "plan this upgrade", or any request to document steps before starting work. Also trigger when the user mentions wanting a structured approach, phased rollout, or task checklist for a coding task. Use this skill proactively whenever implementation complexity warrants a written plan before jumping into code.
---

# Create Implementation Plan

Create `docs/<feature-name>/PLAN.md` structured for autonomous execution by agents or humans.

**Two modes:**

| Mode | When | Behaviour |
|------|------|-----------|
| **Interactive** | User runs `/create-plan` | Ask one focused question if scope is truly ambiguous; otherwise proceed |
| **Autonomous** | Called by `dev-loop` | Never ask. Research codebase, state assumptions in §4, proceed |

---

## Step 0 — Research Before Planning

```bash
git branch --show-current
find . -type f -name "*.go" | head -30   # or *.ts, *.py
ls docs/ 2>/dev/null
```

Read 3–5 key files to understand: routing, middleware, error handling, testing patterns. Record findings as `ASSUMPTION-*` in §4. Do not ask — assume and document.

---

## Output Location

`docs/<feature-name>/PLAN.md` — kebab-case slug. Examples: `docs/rate-limit-login/PLAN.md`.

---

## Git Integration

1. **Create feature branch**: `git checkout -b <feature-name>`
2. **Commit the plan**: `git add docs/<feature-name>/PLAN.md && git commit -m "plan: <feature-name>"`
3. **Stacked PRs per phase**: phase 1 off `main`, phase 2 off phase 1, etc. Each opens a PR with `--base <previous>`.
4. **Branch naming**: `<feature-name>/phase-1`, `<feature-name>/phase-2`, …
5. **PR titles**: imperative, ≤60 chars, describe what the phase *does* — e.g. `add rate limiting middleware to /api/login`. Never prefix with `phase N`.

**Commit hygiene:** `git add -u` for tracked files, explicit paths for new. Never `git add -A`. No `Co-authored-by:`. Subject ≤72 chars, imperative, explain why not what.

---

## Status Values

| Status | Badge Color |
|--------|-------------|
| `Planned` | blue |
| `In progress` | yellow |
| `Completed` | brightgreen |
| `On Hold` | orange |
| `Deprecated` | red |

Badge: `https://img.shields.io/badge/status-<status>-<color>` (spaces → `%20`)

---

## Tracker ID Handling

If user provides a ticket ID or URL: add `ticket:` to frontmatter and a blockquote link under the badge.

- `[A-Z]+-\d+` → Jira: `https://<org>.atlassian.net/browse/<ID>`
- `LIN-456` → `https://linear.app/team/issue/<ID>`
- Full URL → use as-is

Include ticket ID in commit: `plan: <feature-name> (<ticket-id>)`. Omit if no ticket.

---

## Planning Principles

- Surface assumptions rather than asking. One focused question maximum in interactive mode.
- Name alternatives and state the chosen approach and why.
- **Cut speculative phases** — YAGNI applies to plans. Fewer phases is better.
- **Stdlib and platform before new dependencies.**
- Every phase must have a completion criterion runnable by command or observable behaviour — not "it should work".
- Each task: one sentence of what, one of why (if non-obvious). Nothing else.
- One phase = one coherent goal. "And also…" → new phase.

---

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

<!-- If a ticket exists: > **Tracker**: [TICKET-123](https://link-to-ticket) -->

<2-3 sentences: what this achieves and why.>

## 1. Requirements & Constraints

- **REQ-001**: <Functional requirement>
- **SEC-001**: <Security requirement>
- **CON-001**: <Constraint>
- **GUD-001**: <Guideline>

## 2. Implementation Steps

> **Agent instructions**: After completing all tasks in a phase, `git add -u` (plus explicit paths for new files) and commit. No `Co-authored-by:` trailers. Tick `[x]` as each task completes.

### Phase 1: <Phase Name>

**Goal**: <What this phase achieves and why it comes first.>

- [ ] TASK-001: <Exact action with file path, function, or command.>
- [ ] TASK-002: <Exact action.>

**Completion criteria**: <Measurable condition — e.g. "all tests pass", "endpoint returns 200">

**git commit**: `git add -u && git commit -m "<type>: <phase 1 summary>"` — no `Co-authored-by:` trailer

---

### Phase 2: <Phase Name>

**Goal**: <What this phase achieves.>

**Depends on**: Phase 1 complete

- [ ] TASK-003: <Exact action.>

**Completion criteria**: <Measurable condition.>

**git commit**: `git add -u && git commit -m "<type>: <phase 2 summary>"`

---

## 3. Testing

- [ ] TEST-001: <Specific test to write or run, with file path>
- [ ] TEST-002: <Integration test or manual verification>

## 4. Risks & Assumptions

- **RISK-001**: <Risk> — mitigation: <how to reduce it>
- **ASSUMPTION-001**: <Assumed true without user confirmation>
```

---

## Plan Generation Process

1. Research (Step 0) — read codebase silently
2. Determine `<feature-name>`
3. `git checkout -b <feature-name>`
4. Write `docs/<feature-name>/PLAN.md`
5. `git add docs/<feature-name>/PLAN.md && git commit -m "plan: <feature-name>"`
6. Tell the caller: "Plan created at `docs/<feature-name>/PLAN.md` on branch `<feature-name>`."

**Interactive mode:** ask one focused question if scope is genuinely ambiguous before step 1.
**Autonomous mode:** proceed directly, document assumptions in §4.
