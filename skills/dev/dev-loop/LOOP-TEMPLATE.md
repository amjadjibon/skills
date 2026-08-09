# LOOP.md Template

Read this at Bootstrap step 7, and again on resume if the file's structure is unclear. It lives at
`<artifact_root>/<feature-name>/LOOP.md` — `.spec/` unless §1.2 records an explicit custom root. The loop
parses this file to resume from disk alone — keep the structure exact.

Fill `max_iterations` from the §0 mode table, then commit
`docs: track <feature-name> progress` — the commit names the work, not this workflow (§0).

````markdown
---
feature: <feature-name>
task: <original task description>
branch: <feature-name>
mode: <lite|full|ultra>
artifact_root: .spec/   # or an explicit custom root from §1.2; gitignored root → never commit these files
started: <YYYY-MM-DD>
max_iterations: <3 lite | 5 full | 8 ultra>
current_iteration: 1
status: running   # running | awaiting-input | awaiting-approval | complete | blocked | abandoned
last_review_base: ''
---

# Dev Loop: <feature-name>

## Iterations

| Iter | Phase | Verdict | Crit | High | Med | Low | Open Crit/High IDs | Mode | Action |
|------|-------|---------|------|------|-----|-----|--------------------|------|--------|
| 1    | 1     | —       | —    | —    | —   | —   | —                  | —    | —      |

<!-- lite: Phase is always 1. full/ultra: one row per phase per review pass.
     Open Crit/High IDs is what the stall guard (§0) reads — REVIEW.md is
     overwritten each pass, so this table is the only record of what survived. -->

## Stacked PRs

| Phase | Branch | PR URL | Base | Status |
|-------|--------|--------|------|--------|
| 1     | <feature-name>/<phase-slug> | — | main | pending |

<!-- one row per phase from PLAN.md, in plan order — Branch is that phase's **Branch**
     field (<feature-name>/<2-4-word-slug>, no phase number); `lite`: single row,
     branch <feature-name> -->

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
