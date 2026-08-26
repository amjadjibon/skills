# skills

A collection of custom [Claude Code](https://claude.ai/code) skills, packaged as the `dev-skills` plugin — one install delivers 32 skills, 4 sub-agents, and the `/dev-skills-loop` orchestrator command.

> [!CAUTION]
> **Read every skill before you install it. Nothing here is guaranteed.**
>
> These skills are instructions that steer an agent with real tool access — they run commands, edit files, create branches and commits, and open PRs on your behalf. A skill that reads fine can still do the wrong thing in your repo.
>
> Before installing, open the `SKILL.md` files (and `.agents/*.md`, `hooks/hooks.json`, `statusline/*.sh`) and check what they actually do. Note that the plugin's `SessionStart` hook writes a `statusLine` entry into your `~/.claude/settings.json` — see [Status Line](#status-line) for exactly what it touches and how to opt out.

## Installing the Plugin

Requires the [Claude Code CLI](https://claude.ai/code).

1. Add this repo as a marketplace:

   ```text
   /plugin marketplace add amjadjibon/skills
   ```

2. Install the plugin:

   ```text
   /plugin install dev-skills@amjadjibon-skills
   ```

3. Verify it's installed — skills and command with `claude plugin list`, agents with `/agents`:

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

## Installing the Plugin in Codex

Requires the [Codex CLI](https://developers.openai.com/codex/cli/).

1. Add this repository as a plugin marketplace:

   ```sh
   codex plugin marketplace add amjadjibon/skills
   ```

2. Install the plugin:

   ```sh
   codex plugin add dev-skills@amjadjibon-skills
   ```

3. Confirm that it is installed and enabled:

   ```sh
   codex plugin list
   ```

Invoke a skill using its `dev-skills:` namespace:

```text
/dev-skills:dev-create-plan add rate limiting to the API
/dev-skills:dev-loop add rate limiting to the API
```

**Update or remove:** `codex plugin add` reuses whatever the marketplace has already cloned — it will not
pull new commits on its own. Refresh the marketplace snapshot first, then reinstall:

```sh
codex plugin marketplace upgrade amjadjibon-skills
codex plugin add dev-skills@amjadjibon-skills
codex plugin remove dev-skills@amjadjibon-skills
```

## Skills

| Skill | Description |
| ----- | ----------- |
| [dev-wayfinder](skills/dev/dev-wayfinder/SKILL.md) | Chart work too ambiguous to plan — name the destination, map the open questions as named tickets in `.spec/<feature>/MAP.md`, and resolve them one at a time until `dev-create-plan` becomes possible. Plans decisions, never deliverables. |
| [dev-research](skills/dev/dev-research/SKILL.md) | Research a codebase, approach, or technology before planning — compare candidates, verify claims with spikes and web/doc lookups, write `.spec/<feature>/RESEARCH.md` with a recommendation. Also spawned as a scoped sub-agent by the plan/implement skills for single questions (third-party APIs, libraries, docs). |
| [dev-design](skills/dev/dev-design/SKILL.md) | Decide a feature's shape before planning — system design, data model, API/interface contract, UI/UX, whichever axes apply. Writes `.spec/<feature>/DESIGN.md` that `dev-create-plan` builds phases from. |
| [dev-api-design](skills/dev/dev-api-design/SKILL.md) | REST and GraphQL API design principles — resource/URL design, pagination, versioning, GraphQL schema-first design, DataLoader/N+1 prevention, Relay pagination. Hands off to `openapi-spec` for the actual spec document. |
| [dev-ui-design](skills/dev/dev-ui-design/SKILL.md) | Build a clickable UI prototype as one self-contained HTML file (inline CSS, no build step) to demo a screen or flow before real frontend code is written. Writes `.spec/<feature>/prototype.html`. |
| [dev-create-plan](skills/dev/dev-create-plan/SKILL.md) | Create a structured `.spec/<feature>/PLAN.md` with phases, tasks, and verifiable completion criteria. Branches, commits the plan, and integrates git at phase boundaries. |
| [dev-implement-plan](skills/dev/dev-implement-plan/SKILL.md) | Execute a `PLAN.md` produced by `dev-create-plan` — tick checkboxes as tasks complete, commit each phase, handle deviations, and open a PR on completion. |
| [dev-e2e-testing](skills/dev/dev-e2e-testing/SKILL.md) | Write and maintain end-to-end tests (`tests/e2e/`) — what earns an E2E test, Playwright/Cypress setup, fixture independence, and treating flake as a bug, not weather. |
| [dev-smoke-testing](skills/dev/dev-smoke-testing/SKILL.md) | Write fast, thin, one-check-per-file sanity scripts (`scripts/test-<check-name>.sh\|py`) — is it alive right now, run on demand instead of manually testing by hand. Not a CI/CD pipeline gate; safe against production. |
| [dev-tdd](skills/dev/dev-tdd/SKILL.md) | The red → green TDD loop — what a good test is, seams, anti-patterns, and the rules of the cycle. Used by `dev-implement-plan` for test-first phases; `dev-qa` backfills coverage on existing code instead. |
| [dev-code-review](skills/dev/dev-code-review/SKILL.md) | Review a diff or branch for correctness, security, and simplification; writes findings to `.spec/<feature>/REVIEW.md` with severity ratings. |
| [dev-loop](skills/dev/dev-loop/SKILL.md) | Autonomous orchestrator — runs `dev-create-plan → dev-implement-plan → dev-code-review → fix → re-review` until clean, then pauses for approval before pushing. |
| [dev-refactor](skills/dev/dev-refactor/SKILL.md) | Refactor code without changing behavior — extract functions, reduce duplication, simplify logic, improve naming. Verifies tests pass before and after each step. |
| [dev-debug](skills/dev/dev-debug/SKILL.md) | Systematically debug a failing test, error, or unexpected behavior — reproduce, isolate root cause, fix minimally, verify, add a regression test. |
| [dev-perf](skills/dev/dev-perf/SKILL.md) | Profile, optimize, and benchmark — measure baseline first, find the real bottleneck, optimize one thing at a time, confirm improvement with numbers. |
| [dev-review-plan](skills/dev/dev-review-plan/SKILL.md) | Review a PLAN.md before implementation — catch vague tasks, missing completion criteria, risky assumptions, and scope issues. Writes findings to `.spec/<feature>/PLAN-REVIEW.md`. |
| [dev-qa](skills/dev/dev-qa/SKILL.md) | Quality assurance — measure test coverage, identify untested paths, write missing unit/integration/e2e tests, produce a QA report with before/after coverage numbers. |
| [dev-docs](skills/dev/dev-docs/SKILL.md) | Write documentation someone will actually read — one reader, one shape, working example first, examples verified by running them, then a deletion pass that cuts the preambles, the marketing words, and everything kept "for completeness". |
| [dev-clean-up](skills/dev/dev-clean-up/SKILL.md) | Housekeeping — remove merged local and remote branches, prune stale tracking refs, close resolved GitHub issues, clean up leftover worktrees. |
| [dev-release](skills/dev/dev-release/SKILL.md) | Cut a release — derive the version bump from conventional commits, generate a changelog, bump version files, tag, and publish a GitHub release. |
| [dev-ponytail](skills/dev/dev-ponytail/SKILL.md) | Session-long minimalism overlay — climb a ladder (does it need to exist → already in the codebase → stdlib → native platform → installed dependency → one line) and ship the smallest working diff, with a short note on what was skipped and when to add it. |
| [dev-ponytail-review](skills/dev/dev-ponytail-review/SKILL.md) | Review a diff for over-engineering only — one line per finding tagged `delete:`/`stdlib:`/`native:`/`yagni:`/`shrink:`, ending in `net: -<N> lines possible`. Correctness and security stay with `dev-code-review`. |
| [dev-ponytail-audit](skills/dev/dev-ponytail-audit/SKILL.md) | The same pass repo-wide — dependencies and single-implementation abstractions first, callers verified before anything is called dead, ranked into `.spec/<feature-name>/AUDIT.md`. Reports; applies nothing. |
| [dev-ponytail-debt](skills/dev/dev-ponytail-debt/SKILL.md) | Harvest every `TODO: [owner]` / `FIXME: [owner]` marker into one ledger with ceiling, trigger, owner, and age — flagging the ones that name no trigger, since those are what rot. Writes `.spec/<feature-name>/DEBT.md`. |
| [dev-caveman](skills/dev/dev-caveman/SKILL.md) | Session-long terseness overlay — drop articles, filler, pleasantries, hedging, and tool-call narration while keeping every technical fact, symbol, and error string verbatim. `dev-ponytail` shrinks the code; this shrinks the prose. |
| [brainstorming](skills/misc/brainstorming/SKILL.md) | Continuous interactive ideation partner — spreads ideas across safe/middle/bold, defaults to critical engagement over agreement, no hand-off or convergence point. |
| [git-commit](skills/misc/git-commit/SKILL.md) | Write a conventional commit message following [qoomon's cheat sheet](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13) — picking the type from the diff, scope rules, the `!` breaking-change marker, and body/footer conventions. Staging and destructive-op safety stay with `git-safe`. |
| [git-safe](skills/misc/git-safe/SKILL.md) | Pre-flight gate for destructive git commands (force push, reset --hard, clean -f, branch -D, rebase/amend on pushed branches) and the canonical staging/commit-hygiene rules the other skills reference. Hands the message format itself to `git-commit`. |
| [openapi-spec](skills/misc/openapi-spec/SKILL.md) | Write and validate OpenAPI 3.1 spec documents — `$ref`-based reusable components, Spectral/Redocly lint rules. No code generation; assumes `dev-api-design` already decided the shape. |
| [mermaid-diagram](skills/misc/mermaid-diagram/SKILL.md) | Generate Mermaid diagrams (flowchart, sequence, architecture, deployment, class, state, ER) from a description or source code, with high-contrast styling and `mmdc` validation before handoff. |
| [github-actions](skills/misc/github-actions/SKILL.md) | Create and review GitHub Actions workflows — CI, release/publish, reusable workflows, composite actions, matrix builds, caching, and security hardening. Validates with `actionlint`. |
| [prototype](skills/misc/prototype/SKILL.md) | Build a throwaway prototype in the real codebase to answer one design question — a driveable TUI for a state/logic question, or several structurally different UI variants on a real route switchable via `?variant=`. Adapted from [mattpocock/skills](https://github.com/mattpocock/skills/tree/main/skills/engineering/prototype). |

`dev-wayfinder` is adapted from the [`wayfinder` skill](https://github.com/mattpocock/skills/tree/main/skills/engineering/wayfinder) by Matt Pocock, same source as `prototype`.
The four `dev-ponytail*` skills are inspired by the [`ponytail` skill](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert, and `dev-caveman` by the [`caveman` skill](https://github.com/JuliusBrussee/caveman) by Julius Brussee.

## Agents

The plugin also ships four sub-agent definitions under `.agents/`, used by the skills when they spawn parallel workers (skills fall back to general-purpose agents when installed standalone without the plugin):

| Agent | Spawned by | Role |
| ----- | ---------- | ---- |
| [dev-researcher](.agents/dev-researcher.md) | dev-create-plan, dev-implement-plan, dev-loop, dev-research (ultra) | Answers one scoped research question (API contract, library, docs, web) into `.spec/<feature>/research/<topic>.md`. Read-only + web tools. |
| [dev-implementer](.agents/dev-implementer.md) | dev-implement-plan (ultra), dev-loop | Implements one PLAN.md phase in an isolated worktree from its Agent Prompt block. Commits; never pushes. |
| [dev-fixer](.agents/dev-fixer.md) | dev-loop | Fixes a group of REVIEW.md findings in an isolated worktree, in parallel with other fixers. |
| [dev-tester](.agents/dev-tester.md) | dev-qa (ultra), dev-loop | Writes missing tests for one module's coverage gaps in an isolated worktree; reports suspected bugs instead of changing app code. |

## Commands

The plugin ships one slash command under `commands/` — a direct entry point to the orchestrator:

```text
/dev-skills:dev-skills-loop add rate limiting to the API ultra
```

`loop` invokes the `dev-loop` skill with your arguments (trailing `lite|full|ultra` = mode) and runs the full plan → implement → review → fix cycle, pausing only at the approval gate before pushing.

## Status Line

The plugin installs a two-line status line under your prompt — repo, model, context, and session usage:

![The dev-skills status line, two lines. First: [dev-skills] skills(main) · Opus 5 medium · ctx 324k/1M 32% · statusline polish · 45fdd1e0-af3f-46b4-be2e-9f8f802398a0. Second: usage: 5h 40% [resets in 3h53m] · 7d 20% [resets in 3d9h] · cost: ~$71.99 · time: 13h34m[api 1h11m] · edits: +1098/-259](docs/statusline.png)

Claude Code plugins cannot set the main `statusLine` declaratively, so a `SessionStart` hook (`hooks/hooks.json` → `statusline/auto-install.sh`) wires it up on the first session after install: it copies the script to `~/.claude/dev-skills.statusline.sh`, points `settings.json` at that path, and refreshes the copy later so plugin upgrades land. **This is the only thing in the plugin that writes to your settings**, and it only ever acts on its own line:

| Your `settings.json` | What the hook does |
| -------------------- | ------------------ |
| No `statusLine` | Installs ours, records `.dev-skills.statusline-installed` |
| Someone else's `statusLine` | Nothing — never overwrites it |
| Ours | Refreshes the script copy only |
| Ours, then you delete it | Treats that as a decision: writes `.dev-skills.statusline-optout` and never reinstalls |

To opt out before installing at all, `touch ~/.claude/.dev-skills.statusline-optout`. To manage it by hand:

```sh
bash statusline/install.sh              # install now (clears the opt-out)
bash statusline/install.sh --uninstall  # remove it and opt out
```

What each segment means, why it's ordered and coloured that way, and how it's tested: [docs/statusline.md](docs/statusline.md).

## Standalone Skills (no plugin)

Prefer a single skill without the plugin namespace? Install it directly from this repository using `npx skills`. Note this path carries only the skill — not the agents or the `/dev-skills-loop` command; skills fall back to general-purpose sub-agents when the plugin's agents aren't installed:

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
cp skills/dev/<skill-name>/SKILL.md ~/.claude/skills/<skill-name>/SKILL.md

# Project-only (commit to version control)
mkdir -p .claude/skills/<skill-name>
cp skills/dev/<skill-name>/SKILL.md .claude/skills/<skill-name>/SKILL.md
```

Then invoke it in a Claude Code session (drop the `dev-skills:` prefix when installed standalone):

```text
/dev-create-plan add rate limiting to the API
/dev-implement-plan
/dev-code-review
/dev-loop add rate limiting to the API
```

## Delivery Modes

Every skill accepts an optional trailing mode argument — `lite` (default, fastest), `full` (thorough), or `ultra` (maximum depth, often parallel agents):

```text
/dev-code-review full
/dev-loop add rate limiting to the API ultra
```

## How Skills Compose

```text
dev-wayfinder (optional — only when the task is too undecided to phase)
  ↓
dev-loop
  └─ dev-research  →  dev-design   →  dev-create-plan  →  dev-review-plan  →  dev-implement-plan  →  dev-qa  →  dev-code-review
     (optional)         (optional)                                                    ↑                                 │
                                                                                       └──── fix agents ─────────────────┘ (parallel, per-finding)
```

Full map — every skill, overlay, agent, and artifact edge: [docs/SKILL-MAP.md](docs/SKILL-MAP.md).

Output artifacts land in `.spec/<feature>/`: `MAP.md` (`dev-wayfinder`, optional, before everything else), `RESEARCH.md` (`dev-research`, optional pre-plan), `DESIGN.md` (`dev-design`, optional pre-plan), `prototype.html` (`dev-ui-design`, optional pre-plan), `PLAN.md` (created by `dev-create-plan`, updated by `dev-implement-plan`), `PLAN-REVIEW.md` (`dev-review-plan`), `QA.md` (`dev-qa`), `REVIEW.md` (written each pass by `dev-code-review`), and `LOOP.md` (dev-loop state). `AUDIT.md` (`dev-ponytail-audit`) and `DEBT.md` (`dev-ponytail-debt`) land there too, under the audited scope's name — `.spec/repo/` for a whole-tree pass.

`.spec/` is the default root. An explicitly requested custom root overrides it; `dev-loop` resolves that root once and passes it to the skills it calls. Gitignored or out-of-repo custom roots are scratch: artifacts are still written and read on resume, but never committed. The workflow does not discover, migrate, or fall back to legacy artifacts under `docs/`.

## Adding a Skill

Use the `skill-creator` skill to build and iterate on new skills with guided evals:

```text
/skill-creator
```

Or create one manually — make a new directory under `skills/dev/` with a `SKILL.md` file, and add its path to the `skills` array in `.claude-plugin/plugin.json`:

```text
skills/
  dev/
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

After editing any `SKILL.md` (or this README / `CLAUDE.md`), validate before committing:

```sh
python3 scripts/validate.py
```
