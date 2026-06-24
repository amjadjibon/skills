# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a collection of custom Claude Code skills. Skills are persona or behavior overlays that modify how Claude responds when invoked via the Skill tool.

## Structure

```text
skills/
  <skill-name>/
    SKILL.md     # The skill definition
```

Each skill lives in its own directory under `skills/`. The directory name is the skill's identifier used to invoke it.

## SKILL.md Format

Every `SKILL.md` must begin with YAML frontmatter:

```markdown
---
name: <skill-name>
description: <one-line description used for skill discovery and triggering>
---

# Skill content here
```

The `description` field is critical — it's what Claude Code uses to match user intent to the skill and decide when to invoke it automatically.

## Adding a New Skill

Use the `skill-creator` skill to create and iterate on new skills:

```text
/skill-creator
```

It will guide you through drafting the skill, writing test cases, running evals, and refining based on results.

To add manually:

1. Create `skills/<skill-name>/SKILL.md`
2. Add the YAML frontmatter (`name`, `description`)
3. Write the skill instructions in the body — be explicit about voice, rules, and examples
4. The description should capture trigger phrases and use cases precisely

## Existing Skills

- **create-plan** — Writes `docs/<feature-name>/PLAN.md` with phased, checkbox-driven steps ready for autonomous execution.
- **implement-plan** — Executes a `PLAN.md` produced by `create-plan`, ticking checkboxes and committing each phase.
- **code-review** — Reviews a diff or branch for correctness, security, and simplification; writes findings to `docs/<feature-name>/REVIEW.md`.
- **dev-loop** — Orchestrates the full `create-plan → implement-plan → code-review → fix → re-review` cycle autonomously, spawning parallel agents in isolated worktrees and pausing only for user approval before pushing.
- **refactor** — Restructures code without changing behavior. Establishes a test baseline, applies changes in small verifiable steps, commits each step.
- **debug** — Reproduce → isolate → fix → verify loop. Commits the failing test before the fix for traceable history.
- **perf** — Measure baseline → profile → optimize one bottleneck at a time → benchmark. Includes before/after numbers in commit messages.
- **review-plan** — Reviews a PLAN.md before implementation for vague tasks, missing criteria, bad phase ordering, and scope issues. Writes `docs/<feature-name>/PLAN-REVIEW.md` with a machine-readable verdict.
- **qa** — Measures test coverage, identifies untested paths, writes missing tests, and produces `docs/<feature-name>/QA.md` with before/after coverage numbers.
- **clean-up** — Housekeeping: remove merged local/remote branches, prune stale tracking refs, close resolved issues and merged PRs, remove leftover worktrees. Audits before acting.

## Skill Pipeline

Skills are designed to compose:

```text
dev-loop
  └─ create-plan  →  review-plan  →  implement-plan  →  qa  →  code-review
                                            ↑                         │
                                            └──── fix agents ─────────┘ (parallel, per-finding)
```

Plans live in `docs/<feature-name>/PLAN.md`; reviews in `docs/<feature-name>/REVIEW.md`.

## docs/ Artifacts

Artifacts produced during a dev-loop session accumulate under `docs/`. Each feature gets its own subdirectory:

```text
docs/
  <feature-name>/
    PLAN.md     # created by create-plan, mutated by implement-plan
    REVIEW.md   # created/overwritten each review pass by code-review
```
