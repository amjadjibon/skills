# LOOP.md Template

Read this at Bootstrap step 5, and again on resume if the file's structure is unclear. The loop
parses this file to resume from disk alone — keep the structure exact.

Fill `max_iterations`/`max_agents` from the §0 mode table, then commit
`chore: init dev loop for <feature-name>`.

````markdown
---
feature: <feature-name>
task: <original task description>
branch: <feature-name>
mode: <lite|full|ultra>
started: <YYYY-MM-DD>
max_iterations: <3 lite | 5 full | 8 ultra>
max_agents: <3 lite | 5 full | 8 ultra>
current_iteration: 1
status: running
last_review_base: ''
---

# Dev Loop: <feature-name>

## Iterations

| Iter | Phase | Verdict | Crit | High | Med | Low | Mode | Action |
|------|-------|---------|------|------|-----|-----|------|--------|
| 1    | 1     | —       | —    | —    | —   | —   | —    | —      |

<!-- lite: Phase is always 1. full/ultra: one row per phase per review pass. -->

## Stacked PRs

| Phase | Branch | PR URL | Base | Status |
|-------|--------|--------|------|--------|
| 1     | <feature-name>/phase-1 | — | main | pending |

<!-- one row per phase from PLAN.md; `lite`: single row, branch <feature-name> -->

## Active Worktrees

| Worktree path | Branch | Purpose | Status |
|---------------|--------|---------|--------|

## Log

### Iteration 1
- [ ] dev-implement-plan
- [ ] dev-qa
- [ ] dev-code-review
- [ ] decide
````
