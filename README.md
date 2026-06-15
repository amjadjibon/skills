# skills

A collection of custom [Claude Code](https://claude.ai/code) skills.

## Skills

| Skill | Description |
|-------|-------------|
| [create-plan](skills/create-plan/SKILL.md) | Create a structured `docs/<feature>/PLAN.md` with phases, tasks, and verifiable completion criteria. Branches, commits the plan, and integrates git at phase boundaries. |
| [implement-plan](skills/implement-plan/SKILL.md) | Execute a `PLAN.md` produced by `create-plan` — tick checkboxes as tasks complete, commit each phase, handle deviations, and open a PR on completion. |
| [code-review](skills/code-review/SKILL.md) | Review a diff or branch for correctness, security, and simplification; writes findings to `docs/<feature>/REVIEW.md` with severity ratings. |
| [dev-loop](skills/dev-loop/SKILL.md) | Autonomous orchestrator — runs `create-plan → implement-plan → code-review → fix → re-review` until clean, then pauses for approval before pushing. |

## Usage

Install a skill directly from this repository using `npx skills`:

```sh
# Install a specific skill (personal, available in all projects)
npx skills add https://github.com/amjadjibon/skills --skill <skill-name>

# Install to current project only
npx skills add https://github.com/amjadjibon/skills --skill <skill-name> --project
```

Or copy a skill manually into Claude Code's discovery directory:

```sh
# Personal (available in all projects)
mkdir -p ~/.claude/skills/<skill-name>
cp skills/<skill-name>/SKILL.md ~/.claude/skills/<skill-name>/SKILL.md

# Project-only (commit to version control)
mkdir -p .claude/skills/<skill-name>
cp skills/<skill-name>/SKILL.md .claude/skills/<skill-name>/SKILL.md
```

Then invoke it in a Claude Code session:

```
/create-plan add rate limiting to the API
/implement-plan
/code-review
/dev-loop add rate limiting to the API
```

## Adding a Skill

Use the `skill-creator` skill to build and iterate on new skills with guided evals:

```
/skill-creator
```

Or create one manually — make a new directory under `skills/` with a `SKILL.md` file:

```
skills/
  <skill-name>/
    SKILL.md
```

Each `SKILL.md` requires a YAML frontmatter header:

```markdown
---
name: <skill-name>
description: <one-line description used for skill discovery>
---

# Skill instructions here
```
