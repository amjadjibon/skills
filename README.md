# skills

A collection of custom [Claude Code](https://claude.ai/code) skills, packaged as the `dev-skills` plugin.

## Installing the Plugin

Requires the [Claude Code CLI](https://claude.ai/code).

1. Add this repo as a marketplace:
   ```text
   /plugin marketplace add https://github.com/amjadjibon/skills
   ```
2. Install the plugin:
   ```text
   /plugin install dev-skills
   ```
3. Verify it's installed:
   ```sh
   claude plugin list
   ```
4. Invoke any skill with the `dev-skills:` namespace:
   ```text
   /dev-skills:dev-create-plan add rate limiting to the API
   /dev-skills:dev-loop add rate limiting to the API
   ```

**Try before installing** — load it for one session with no marketplace/install step, from a local clone:
```sh
claude --plugin-dir /path/to/skills
```

**Update or remove:**
```text
/plugin update dev-skills
/plugin uninstall dev-skills
```

If a skill doesn't show up after install, run `/reload-plugins` (or restart the session) and re-check with `claude plugin list`.

## Skills

| Skill | Description |
| ----- | ----------- |
| [dev-create-plan](skills/dev-create-plan/SKILL.md) | Create a structured `docs/<feature>/PLAN.md` with phases, tasks, and verifiable completion criteria. Branches, commits the plan, and integrates git at phase boundaries. |
| [dev-implement-plan](skills/dev-implement-plan/SKILL.md) | Execute a `PLAN.md` produced by `dev-create-plan` — tick checkboxes as tasks complete, commit each phase, handle deviations, and open a PR on completion. |
| [dev-code-review](skills/dev-code-review/SKILL.md) | Review a diff or branch for correctness, security, and simplification; writes findings to `docs/<feature>/REVIEW.md` with severity ratings. |
| [dev-loop](skills/dev-loop/SKILL.md) | Autonomous orchestrator — runs `dev-create-plan → dev-implement-plan → dev-code-review → fix → re-review` until clean, then pauses for approval before pushing. |
| [dev-refactor](skills/dev-refactor/SKILL.md) | Refactor code without changing behavior — extract functions, reduce duplication, simplify logic, improve naming. Verifies tests pass before and after each step. |
| [dev-debug](skills/dev-debug/SKILL.md) | Systematically debug a failing test, error, or unexpected behavior — reproduce, isolate root cause, fix minimally, verify, add a regression test. |
| [dev-perf](skills/dev-perf/SKILL.md) | Profile, optimize, and benchmark — measure baseline first, find the real bottleneck, optimize one thing at a time, confirm improvement with numbers. |
| [dev-review-plan](skills/dev-review-plan/SKILL.md) | Review a PLAN.md before implementation — catch vague tasks, missing completion criteria, risky assumptions, and scope issues. Writes findings to `docs/<feature>/PLAN-REVIEW.md`. |
| [dev-qa](skills/dev-qa/SKILL.md) | Quality assurance — measure test coverage, identify untested paths, write missing unit/integration/e2e tests, produce a QA report with before/after coverage numbers. |
| [dev-clean-up](skills/dev-clean-up/SKILL.md) | Housekeeping — remove merged local and remote branches, prune stale tracking refs, close resolved GitHub issues and merged PRs, clean up leftover worktrees. |

## Usage

See [Installing the Plugin](#installing-the-plugin) above for the recommended path (namespaced as `/dev-skills:<skill-name>`).

### As standalone skills

Prefer a single skill without the plugin namespace? Install it directly from this repository using `npx skills`:

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

Then invoke it in a Claude Code session (drop the `dev-skills:` prefix when installed standalone):

```text
/dev-create-plan add rate limiting to the API
/dev-implement-plan
/dev-code-review
/dev-loop add rate limiting to the API
```

## How Skills Compose

```text
dev-loop
  └─ dev-create-plan  →  dev-implement-plan  →  dev-code-review
                                ↑                       │
                                └── fix agents ──────────┘ (parallel, per-finding)
```

Output artifacts land in `docs/<feature>/`: `PLAN.md` (created by `dev-create-plan`, updated by `dev-implement-plan`), `PLAN-REVIEW.md` (`dev-review-plan`), `QA.md` (`dev-qa`), `REVIEW.md` (written each pass by `dev-code-review`), and `LOOP.md` (dev-loop state).

## Adding a Skill

Use the `skill-creator` skill to build and iterate on new skills with guided evals:

```text
/skill-creator
```

Or create one manually — make a new directory under `skills/` with a `SKILL.md` file:

```text
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
