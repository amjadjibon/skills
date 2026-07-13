---
name: dev-clean-up
description: Housekeeping — remove merged local and remote branches, prune stale remote tracking refs, close resolved GitHub issues, clean up leftover worktrees. Use when the user says "clean up", "cleanup", "prune branches", "remove merged branches", "close issues", "tidy up", "housekeeping", or "delete old branches".
argument-hint: "[lite|full|ultra]"
---

# Clean Up

Audit first, act second. Always show what will be removed before removing it.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — branches only (§1 branch/ref audit, §2–§4). Skip worktrees and issues.
- `full` — everything, §1–§6.
- `ultra` — same as `full`; nothing to parallelize — this skill is what removes worktrees.

## 1. Audit

Run all before touching anything; present the audit; confirm before any destructive step.

```bash
git branch --merged main | grep -v '^\*\|main\|master\|develop'   # merged local branches
git remote prune origin --dry-run                                 # stale tracking refs
git worktree list
gh issue list --state open --label resolved 2>/dev/null || true
```

## 2. Merged Local Branches

```bash
git branch --merged main | grep -v '^\*\|main\|master\|develop' | xargs -r git branch -d
```

Never delete `main`/`master`/`develop`, the current branch, or anything the user wants kept.

## 3. Merged Remote Branches

`git push origin --delete <branch>` — one at a time, confirm each succeeds. No bulk deletes.

## 4. Prune Tracking Refs

`git fetch --prune` — removes stale `origin/<branch>` pointers only; local branches untouched.

## 5. Worktrees

For each worktree no longer needed (merged/abandoned): `git worktree remove <path> && git branch -d <branch>`. Uncommitted changes inside → warn, require explicit confirmation.

## 6. Resolved Issues

`gh issue close <number> --comment "Resolved — closing."` — only when resolution is clear: linked PR merged, labelled `resolved`/`wontfix`, or user says so. Never speculatively.

## 7. Report

Local branches deleted · remote branches deleted · refs pruned · worktrees removed · issues closed (each: list or "none").
