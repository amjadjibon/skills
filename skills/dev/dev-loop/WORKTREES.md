# Worktree Management

Read this when the loop is about to spawn a sub-agent — a `full`/`ultra` phase, or a §3.C.2
parallel fix group. A `lite` run that never forks an agent never needs it.

All worktrees live under `.worktrees/` (gitignore it once: `grep -qx '.worktrees/' .gitignore 2>/dev/null || { echo '.worktrees/' >> .gitignore && git add .gitignore && git commit -m "chore: gitignore .worktrees"; }`). The orchestrator owns creation, tracking, removal.

**Create** (one step — checking the branch out first makes `worktree add` fail):

```bash
git worktree add .worktrees/<feature-name>-<slot> -b <feature-name>-<slot> <feature-name>
```

`<slot>`: `phase-2`, `fix-HIGH-001`, `fix-cluster-auth`. Add a LOOP.md Active Worktrees row before handoff; track `assigned → running → merged → removed`.

**Assign** — spawn with the plugin's agent types when available (`dev-implementer` for phases, `dev-fixer` for fixes, `dev-researcher` for research questions), else general-purpose. Implementation phases: use the phase's `**Agent Prompt**` from PLAN.md verbatim, prepend `Worktree path: .worktrees/<feature-name>-<slot>`. Fix agents:

```
You are a sub-agent fixing review findings in an isolated git worktree.

Worktree path: .worktrees/<feature-name>-<slot>
Branch: <feature-name>-<slot>
Base branch: <work-branch>

Findings to fix:
- [HIGH-001] <title> — <file:line> — <what to change>

Rules: stay inside the worktree; `git add -u` (explicit paths for new files) and
commit "fix: <slot description>" — no Co-authored-by; reply with a one-paragraph
summary + commit SHA; do NOT push, open PRs, or modify LOOP.md.
```

**Merge & remove**:

```bash
git checkout <feature-name>
git merge --no-ff <feature-name>-<slot> -m "merge: <slot description> into <feature-name>"
git worktree remove .worktrees/<feature-name>-<slot>
git branch -d <feature-name>-<slot>
```

Conflicts: two agents on one file → read both, merge intent; fix agent vs main branch → fix agent wins unless it reverts a passing test. Update the LOOP.md row (`removed`/`failed`). Before final push: `git worktree list` — remove leftovers.
