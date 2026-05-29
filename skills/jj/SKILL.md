---
name: jj
description: Understand and work with Jujutsu (jj) version control system. Use when the user mentions commits, changes, version control, or working with jj repositories. Helps with stack-based commit workflows, change curation, and jj best practices. Trigger whenever the user mentions jj, jujutsu, stacking commits, jj log, jj status, jj describe, change IDs, or asks about version control in a jj repo. Also trigger when the user asks how to do something that in git would be git commit, git checkout, git log, or similar — they may be in a jj repo without realizing they should use jj commands.
---

# Working with Jujutsu Version Control

## Core Concepts

Jujutsu (jj) is a Git-compatible VCS with a different mental model:

- **Change-based**: Every commit has a unique change ID that persists through rewrites (unlike git's content-addressed hashes)
- **Auto-snapshotting**: The working copy is snapshotted before each jj operation — you never lose work
- **Stack-based**: Build a series of commits as a stack, not a single blob
- **Undoable**: All operations are recorded in `jj op log`; use `jj op restore <id>` to time-travel
- **vs Git**: No staging area (`git add` doesn't exist), you can edit any commit with `jj edit`, and conflicts are stored in commits rather than blocking progress

## Working Copy (`@`)

The current commit is always `@`:

```
jj log -r @          # Current commit
jj log -r @-         # Parent commit
jj log -r 'ancestors(@, 5)'  # Recent stack
```

### Working copy states

| State | Meaning |
|-------|---------|
| Empty, no description | Ready for new changes |
| Has changes, no description | Needs a description before stacking |
| Has description + changes | Can stack with `jj new` |
| Has description, no changes | Ready for new work |

## Stack-Based Workflow

1. Make changes in `@` (new files are tracked automatically)
2. Describe: `jj describe -m "message"` or use `/jj:commit`
3. Stack: `jj new`
4. Repeat

**Why stack?** Individual commits can be reviewed separately, reordered easily, shipped incrementally, and keep history clean.

## Plan-Driven Workflow

When starting a substantial task:

1. **Start**: Create a `"plan:"` commit describing intent
2. **Work**: Implement the plan
3. **End**: Replace `"plan:"` with actual work using `/jj:commit`

One commit per major todo item, `jj new` between todos.

## Automatic Snapshotting

Every `jj` command auto-snapshots the working copy. To undo or time-travel:

```
jj undo                    # Undo last operation
jj op log                  # See all operations
jj op restore <id>         # Restore to any previous state
```

## When to Suggest Commands

### Viewing state
```
jj status    # What changed
jj log       # Commit history
jj show      # Show a commit's diff
jj diff      # Show working copy diff
```

### Creating commits
- Prefer `/jj:commit` over `jj describe` directly
- Suggest when the user has substantial changes or a plan commit needs updating

### Organizing commits
- `/jj:split <pattern>` — when a commit mixes concerns (tests + code, docs + implementation)
- `/jj:squash` — when there are multiple WIP commits to merge
- Don't suggest for simple, already-focused changes

### Undoing
```
jj undo                  # Undo last op
jj op restore <id>       # Restore specific op
jj abandon               # Abandon a change
```

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/jj:commit [message]` | Stack a commit with message generation |
| `/jj:split <pattern>` | Split by pattern (test, docs, config) |
| `/jj:squash [revision]` | Merge commits |
| `/jj:cleanup` | Remove empty workspaces |

## Describe Message Template

When writing a commit description with `jj describe`, use this structure:

```
<type>: <short summary in imperative mood>

<optional body — explain the why, not the what>
```

**Types:**
- `feat` — new feature
- `fix` — bug fix
- `refactor` — restructuring without behavior change
- `test` — adding or updating tests
- `docs` — documentation only
- `chore` — tooling, deps, config
- `plan` — planning commit (replaced before review)

**Examples:**

```
feat: add JWT authentication middleware
```

```
fix: prevent race condition in request handler

The handler was reading from a shared map without a lock.
Concurrent requests could corrupt state under load.
```

```
plan: implement rate limiting

Steps:
- Add token bucket per IP
- Wire middleware into router
- Add config for limits
```

Good descriptions answer "what and why", not "how" — the diff already shows the how.

## Git Translation

If the repository blocks git write commands via hook, prefer jj equivalents:

| git | jj |
|-----|----|
| `git status` | `jj status` |
| `git commit` | `/jj:commit` |
| `git log` | `jj log` |
| `git checkout -b` | `jj new` |
| `git add -p` | `jj split` |
| `git rebase -i` | `jj rebase` / `jj edit` |

## Best Practices

**Do:**
- Stack commits — each logical unit gets its own commit
- Describe clearly: what changed and why
- Use the plan-driven workflow for larger tasks
- Leverage `jj op log` to stay fearless — everything is undoable
- Split commits when they mix concerns

**Don't:**
- Mix git and jj write commands in the same repo
- Leave work undescribed for long
- Create monolithic commits that do too many things
- Forget that conflicts are stored, not blocking — you can continue working
