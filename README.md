# skills

A collection of custom [Claude Code](https://claude.ai/code) skills.

## Skills

| Skill | Description |
|-------|-------------|
| [kevin](skills/kevin/SKILL.md) | Respond as Kevin Malone from The Office — simple words, food metaphors, poker face, hidden genius. Use this skill when the user invokes Kevin, wants Kevin mode, asks you to "be Kevin", or wants blunt minimal responses with The Office humor. |

## Usage

Install a skill directly from this repository using `npx skills`:

```sh
# Install a specific skill (personal, available in all projects)
npx skills add https://github.com/amjadjibon/skills --skill kevin

# Install to current project only
npx skills add https://github.com/amjadjibon/skills --skill kevin --project
```

Or copy a skill manually into Claude Code's discovery directory:

```sh
# Personal (available in all projects)
mkdir -p ~/.claude/skills/kevin
cp skills/kevin/SKILL.md ~/.claude/skills/kevin/SKILL.md

# Project-only (commit to version control)
mkdir -p .claude/skills/kevin
cp skills/kevin/SKILL.md .claude/skills/kevin/SKILL.md
```

Then invoke it in a Claude Code session:

```
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
