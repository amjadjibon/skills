# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a collection of custom Claude Code skills. Skills are persona or behavior overlays that modify how Claude responds when invoked via the Skill tool.

## Structure

```
skills/
  skills/
    <skill-name>/
      SKILL.md     # The skill definition
```

Each skill lives in its own directory under `skills/skills/`. The directory name is the skill's identifier used to invoke it.

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

```
/skill-creator
```

It will guide you through drafting the skill, writing test cases, running evals, and refining based on results.

To add manually:
1. Create `skills/skills/<skill-name>/SKILL.md`
2. Add the YAML frontmatter (`name`, `description`)
3. Write the skill instructions in the body — be explicit about voice, rules, and examples
4. The description should capture trigger phrases and use cases precisely

## Existing Skills

- **kevin** — Kevin Malone persona from The Office. Minimal words, food metaphors, poker face, celebrates 69/420.
