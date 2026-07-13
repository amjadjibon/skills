# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository is the `dev-skills` Claude Code plugin: 14 skills, 4 sub-agents, and the `/loop` command, distributed via the repo's own marketplace (`.claude-plugin/marketplace.json`). Skills are behavior overlays invoked via the Skill tool; agents are the parallel workers the skills spawn.

## Structure

```text
.claude-plugin/
  plugin.json        # Plugin manifest (name, description, version)
  marketplace.json   # Makes the repo installable: /plugin marketplace add amjadjibon/skills
skills/
  <skill-name>/
    SKILL.md     # The skill definition
agents/
  <agent-name>.md  # Sub-agent definitions the skills spawn
commands/
  <command-name>.md  # Slash commands (currently: loop — wraps dev-loop)
```

Each skill lives in its own directory under `skills/`. The directory name is the skill's identifier used to invoke it.

`agents/` holds sub-agent definitions (same frontmatter shape: `name` matching the filename, `description`; optional `tools`). The skills reference them by name when spawning parallel workers: `dev-researcher` (scoped research questions), `dev-implementer` (one PLAN.md phase in a worktree), `dev-fixer` (a group of REVIEW.md findings in a worktree), `dev-tester` (one module's coverage gaps in a worktree). Skills must still work without them — every spawn instruction says "when available, else general-purpose".

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

## Validation

After editing any SKILL.md, CLAUDE.md, or README.md, run:

```bash
python3 scripts/validate.py
```

It checks frontmatter (skills and agents), code-fence nesting, cross-skill/agent references, doc coverage, and the canonical convention lines (commit hygiene, mode parsing) across skills/, agents/, commands/, CLAUDE.md, and README.md. Must pass before committing.

When adding a skill, agent, or command, also bump `version` in `.claude-plugin/plugin.json` and keep its description (and marketplace.json's) in sync.

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

- **dev-research** — Investigates a codebase, approach, or technology before planning; compares candidates, verifies claims with spikes and web/doc lookups, writes `docs/<feature-name>/RESEARCH.md` with a recommendation. Also spawned as a scoped sub-agent by dev-create-plan/dev-implement-plan/dev-loop to answer single questions (third-party APIs, libraries, docs) into `docs/<feature-name>/research/<topic>.md`.
- **dev-design** — Decides a feature's shape before planning: system design, data model, API/interface contract, and UI/UX, whichever axes apply. Writes `docs/<feature-name>/DESIGN.md` that `dev-create-plan` builds phases from.
- **dev-ui-design** — Builds a clickable UI prototype as a single self-contained HTML file (inline CSS, no build step) to demo a screen or flow, turning `dev-design`'s UI/UX axis into something clickable. Writes `docs/<feature-name>/prototype.html`.
- **dev-create-plan** — Writes `docs/<feature-name>/PLAN.md` with phased, checkbox-driven steps ready for autonomous execution.
- **dev-implement-plan** — Executes a `PLAN.md` produced by `dev-create-plan`, ticking checkboxes and committing each phase.
- **dev-code-review** — Reviews a diff or branch for correctness, security, and simplification; writes findings to `docs/<feature-name>/REVIEW.md`.
- **dev-loop** — Orchestrates the full `dev-create-plan → dev-implement-plan → dev-code-review → fix → re-review` cycle autonomously, spawning parallel agents in isolated worktrees and pausing only for user approval before pushing.
- **dev-refactor** — Restructures code without changing behavior. Establishes a test baseline, applies changes in small verifiable steps, commits each step.
- **dev-debug** — Reproduce → isolate → fix → verify loop. Commits the failing test before the fix for traceable history.
- **dev-perf** — Measure baseline → profile → optimize one bottleneck at a time → benchmark. Includes before/after numbers in commit messages.
- **dev-review-plan** — Reviews a PLAN.md before implementation for vague tasks, missing criteria, bad phase ordering, and scope issues. Writes `docs/<feature-name>/PLAN-REVIEW.md` with a machine-readable verdict.
- **dev-qa** — Measures test coverage, identifies untested paths, writes missing tests, and produces `docs/<feature-name>/QA.md` with before/after coverage numbers.
- **dev-clean-up** — Housekeeping: remove merged local/remote branches, prune stale tracking refs, close resolved issues, remove leftover worktrees. Audits before acting.
- **dev-release** — Cuts a release after PRs merge: derives the version bump from conventional commits, generates a changelog, bumps version files, tags, and publishes a GitHub release. Pauses for approval before tagging.

## Skill Pipeline

Skills are designed to compose:

```text
dev-loop
  └─ dev-research  →  dev-design   →  dev-create-plan  →  dev-review-plan  →  dev-implement-plan  →  dev-qa  →  dev-code-review
     (optional)         (optional)                                                    ↑                                 │
                                                                                       └──── fix agents ─────────────────┘ (parallel, per-finding)
```

Plans live in `docs/<feature-name>/PLAN.md`; reviews in `docs/<feature-name>/REVIEW.md`.

## docs/ Artifacts

Artifacts produced during a dev-loop session accumulate under `docs/`. Each feature gets its own subdirectory:

```text
docs/
  <feature-name>/
    RESEARCH.md    # created by dev-research (optional, pre-plan)
    DESIGN.md      # created by dev-design (optional, pre-plan)
    prototype.html # created by dev-ui-design (optional, pre-plan)
    PLAN.md        # created by dev-create-plan, mutated by dev-implement-plan
    REVIEW.md   # created/overwritten each review pass by dev-code-review
```
