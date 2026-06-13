# skills

A collection of custom [Claude Code](https://claude.ai/code) skills.

## Skills

| Skill | Description |
|-------|-------------|
| [create-plan](skills/create-plan/SKILL.md) | Create a structured `docs/<feature>/PLAN.md` with phases, tasks, and verifiable completion criteria. Branches, commits the plan, and integrates git at phase boundaries. |
| [implement-plan](skills/implement-plan/SKILL.md) | Execute a `PLAN.md` produced by `create-plan` — tick checkboxes as tasks complete, commit each phase, handle deviations, and open a PR on completion. |
| [grug](skills/grug/SKILL.md) | Respond as Grug from grugbrain.dev — cave-speak, complexity bad, simple good. Wisdom on over-engineering, abstractions, and software philosophy. |
| [jj](skills/jj/SKILL.md) | Work with Jujutsu (jj) version control — stack-based workflows, change IDs, jj vs git translation, and plan-driven development. |
| [kevin](skills/kevin/SKILL.md) | Respond as Kevin Malone from The Office — simple words, food metaphors, poker face, hidden genius. |

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
/kevin explain this function
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
