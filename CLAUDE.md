# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository is the `dev-skills` Claude Code plugin: 30 skills, 4 sub-agents, and the `/dev-skills-loop` command, distributed via the repo's own marketplace (`.claude-plugin/marketplace.json`). Skills are behavior overlays invoked via the Skill tool; agents are the parallel workers the skills spawn.

## Structure

```text
.claude-plugin/
  plugin.json        # Plugin manifest (name, description, version)
  marketplace.json   # Makes the repo installable: /plugin marketplace add amjadjibon/skills
skills/
  dev/
    <skill-name>/
      SKILL.md     # The skill definition
.agents/
  <agent-name>.md  # Sub-agent definitions the skills spawn
commands/
  <command-name>.md  # Slash commands (currently: dev-skills-loop — wraps dev-loop)
hooks/
  hooks.json         # SessionStart hook that wires up the status line
scripts/
  validate.py        # the pre-commit gate (see Validation)
  render-statusline.py  # redraws docs/statusline.png from real output
statusline/
  statusline.sh      # 2-line status line: repo/model/context + session usage
  auto-install.sh    # the hook body — installs on first session, refreshes after
  install.sh         # manual install/uninstall of the same thing
  tests/             # <case>.json + <case>.expected pairs, diffed by validate.py
```

Plugin `settings.json` only supports the `agent` and `subagentStatusLine` keys, so a plugin
cannot declare the user's main `statusLine` — the SessionStart hook writes it into their
settings instead. That makes it the one component that mutates user state, so it is
deliberately conservative: it never overwrites a foreign `statusLine`, and if the user deletes
the one it installed it writes `.dev-skills.statusline-optout` and stays gone. Keep those
guarantees intact when changing `statusline/auto-install.sh` — `scripts/validate.py` exercises
both installers against sandboxed `CLAUDE_CONFIG_DIR`s and asserts each one.

Each skill lives in its own directory under `skills/dev/`. The directory name is the skill's identifier used to invoke it. Because skills are nested one level deeper than the plugin-loader default, `.claude-plugin/plugin.json` lists each skill path explicitly in its `skills` array — keep that array in sync when adding, removing, or renaming a skill directory.

Two costs to keep separate when editing a skill. The **`description` is always loaded** — all 29 of
them sit in every session's context whether or not a skill is invoked, so it holds trigger phrases
and nothing else; prose explaining what to do once invoked belongs in the body, where it is free
until someone actually runs the skill. The **body loads only on invoke**, so repeated boilerplate
across skills (the mode-parsing line, the git-safe pointer) costs nothing worth optimising. When one
body grows past ~10KB, split the parts needed at one specific step into sibling `.md` files the
skill links and reads on demand — `dev-loop`'s `LOOP-TEMPLATE.md` and `WORKTREES.md`, `prototype`'s
`LOGIC.md` and `UI.md`. `scripts/validate.py` checks those companions' fences and references too.

`.agents/` holds sub-agent definitions (same frontmatter shape: `name` matching the filename, `description`; optional `tools`). Since it isn't the plugin-loader default (`./agents`), `.claude-plugin/plugin.json` points at it explicitly via the `agents` field — an array of individual `.md` file paths, unlike `skills`, which takes directories. A bare directory path there fails manifest validation and the whole plugin refuses to load, so add the file when you add an agent; `scripts/validate.py` checks both directions. The skills reference them by name when spawning parallel workers: `dev-researcher` (scoped research questions), `dev-implementer` (one PLAN.md phase in a worktree), `dev-fixer` (a group of REVIEW.md findings in a worktree), `dev-tester` (one module's coverage gaps in a worktree). Skills must still work without them — every spawn instruction says "when available, else general-purpose".

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

It checks frontmatter (skills and agents), code-fence nesting, cross-skill/agent references, doc coverage, and the canonical convention lines (commit hygiene, mode parsing) across skills/, .agents/, commands/, CLAUDE.md, and README.md. It also renders every `statusline/tests/*.json` fixture through `statusline/statusline.sh` under `/bin/bash` and diffs it against the matching `.expected` file — add a fixture pair whenever you change what the status line prints. Must pass before committing.

When adding a skill, agent, or command, also bump `version` in `.claude-plugin/plugin.json` and keep its description (and marketplace.json's) in sync.

## Adding a New Skill

Use the `skill-creator` skill to create and iterate on new skills:

```text
/skill-creator
```

It will guide you through drafting the skill, writing test cases, running evals, and refining based on results.

To add manually:

1. Create `skills/dev/<skill-name>/SKILL.md`
2. Add the YAML frontmatter (`name`, `description`)
3. Write the skill instructions in the body — be explicit about voice, rules, and examples
4. The description should capture trigger phrases and use cases precisely
5. Add `"./skills/dev/<skill-name>"` to the `skills` array in `.claude-plugin/plugin.json`

## Existing Skills

Each skill's `description` frontmatter is the source of truth and is already in the
always-loaded skill listing — read `skills/*/*/SKILL.md` rather than duplicating it here.
README.md carries the human-facing list.

## Skill Pipeline

Skills are designed to compose:

```text
dev-wayfinder (optional — only when the task is too undecided to phase)
  ↓
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
    MAP.md         # created by dev-wayfinder (optional, pre-everything)
    RESEARCH.md    # created by dev-research (optional, pre-plan)
    DESIGN.md      # created by dev-design (optional, pre-plan)
    prototype.html # created by dev-ui-design (optional, pre-plan)
    PLAN.md        # created by dev-create-plan, mutated by dev-implement-plan
    REVIEW.md   # created/overwritten each review pass by dev-code-review
```
