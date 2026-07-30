---
name: git-safe
description: Safety rules for destructive/history-rewriting git ops (force push, reset --hard, clean -f, branch -D, checkout over uncommitted changes, rebase/amend of pushed work) plus this repo's canonical commit hygiene. Trigger before any such command, or before any skill runs `git commit`.
---

# Git Guardrails

Destructive and history-rewriting git commands need a check before they run, not after. This skill is a pre-flight gate, not a workflow — it fires in the moment right before one of the commands below.

## Gated commands

For each, check state first, then confirm with the user before running — unless the user has already explicitly authorized this exact action in this conversation.

| Command | Check first | Why |
|---|---|---|
| `push --force` / `-f` | `git log origin/<branch>..<branch>` and `<branch>..origin/<branch>` — is anyone else's work on the remote tip? | Force push can silently discard commits others pushed. |
| `reset --hard` | `git status` — anything uncommitted? `git log` — anything on this branch not merged elsewhere? | Uncommitted and unreachable-after-reset commits are gone. |
| `clean -f` / `-fd` | `git clean -ndx` (dry run) to list what would be deleted | Untracked files are not recoverable from git after this. |
| `checkout -- <path>` / `restore <path>` | `git diff <path>` — is this discarding real edits? | No undo once the working-tree change is gone. |
| `branch -D` | `git branch --merged` — is the branch actually merged? | `-D` skips the safety check `-d` does. |
| `rebase` on a branch already pushed | `git ls-remote --heads origin <branch>` or check for open PRs on it | Rewrites history others may have already pulled or reviewed. |
| `commit --amend` on a pushed commit | Is this commit only local, or already on the remote? | Amending a published commit forces everyone downstream to rebase. |
| `filter-branch` / `filter-repo` / any full-history rewrite | Confirm scope and that all collaborators know | Rewrites every commit hash on the branch. |

## Rules

- Never chain a gated command automatically after another command "to clean up" — each one gets its own check.
- `git status` before any operation that could discard uncommitted work, every time, not just when something looks off.
- If a lock file (`.git/index.lock`) or unfamiliar branch/stash exists, investigate what put it there before removing it — it may be another process's in-progress work.
- Prefer a reversible step over a destructive one when it gets to the same result: `git stash` over `git checkout --`, rename/move over `rm`, `git revert` over `reset --hard` on shared branches.
- A user approving one destructive command once is not standing approval for the same command later in the session — confirm scope each time, unless they've said "always do X without asking" for this repo.
- Never add `--no-verify`, `--no-gpg-sign`, or skip hooks to route around a failure — fix what the hook caught.
- Never force-push to `main`/`master` — refuse and explain, even if asked, unless the user overrides explicitly after being told the risk.

## Commit hygiene

Every `git commit` in this repo's skills follows this, no exceptions:

- `git add -u` for tracked files, explicit paths for new files. Never `git add -A` — review `git status` first, stage only what the task touched.
- **No `Co-authored-by:` trailer, ever** — not even when a sub-agent or the harness did the work.
- Subject line ≤72 chars, imperative mood, why-focused not what-focused (e.g. `fix: prevent double-charge on retry`, not `fix: added a check`).
- Conventional type prefix matching the change: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `plan:`, `chore:`.
- One logical change per commit — a plan phase, a review-finding fix, a doc update — not a grab-bag.
- This is the canonical convention other skills point to instead of restating it; see `skills/dev/dev-implement-plan/SKILL.md` §3 and `skills/dev/dev-create-plan/SKILL.md` for it applied to phase commits and plan-status commits.

## What this skill does not gate

Regular commits, regular (non-force) pushes to a branch only you use, fetch, merge, and reads (`log`, `diff`, `show`, `status`) need no confirmation — gating those would just be noise.
