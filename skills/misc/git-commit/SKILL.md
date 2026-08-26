---
name: git-commit
description: Write a conventional commit message — `type(scope): description`, the `!` breaking-change marker, body/footer rules, and the feat/fix/refactor/perf/style/test/docs/build/ops/chore type set. Trigger on "commit this", "write a commit message", "what type should this commit be", "conventional commits", "fix my commit message", or before running `git commit`. Staging and destructive-git safety stay with `git-safe`.
---

Owns the commit **message**. Staging, trailers, and destructive-op gating are `git-safe`'s — read both before committing.

## Format

```text
<type>(<optional scope>): <description>

<optional body>

<optional footer>
```

Blank lines are load-bearing — without them git folds body and footer into the subject.

## Choosing the type

From what the diff does, not what you set out to do. One type must cover the whole diff; if two apply, that's two commits.

| Type | Use for | Not for |
| ---- | ------- | ------- |
| `feat` | Adds, adjusts, or removes an API or UI feature | Restructuring no user can observe → `refactor` |
| `fix` | Corrects an API or UI bug from a preceding `feat` | A broken build → `build`; a wrong doc → `docs` |
| `refactor` | Rewrites or restructures without altering API or UI behavior | Any observable behavior change → `feat` / `fix` |
| `perf` | A `refactor` whose point is speed or memory | A rewrite done for clarity that happens to be faster → `refactor` |
| `style` | Whitespace, formatting, semicolons | Renaming for clarity → `refactor` |
| `test` | Adds or corrects tests | Changing production code to make it testable → `refactor` |
| `docs` | Documentation only | Doc comments changed with the code they describe → the code's type |
| `build` | Build tooling, dependencies, project version | CI pipeline config → `ops` |
| `ops` | Infrastructure (IaC), deployment, CI/CD, monitoring, backups | App code that talks to infrastructure → `feat` / `fix` |
| `chore` | Initial commit, `.gitignore`, what fits nothing above | A catch-all for a diff you haven't read |

A project may add types (this repo uses `plan:` for plan-status commits) — a recorded project decision, never one invented per commit.

## Subject line

`<type>(<scope>)!: <description>`, ≤72 chars — past that `git log --oneline` truncates it.

- **Description is mandatory.** Imperative present tense, completing *"This commit will …"* — "change", not "changed" or "changes". No leading capital, no trailing period.
- Say what changes for someone using the code, not which lines moved: `fix: prevent double-charge on retry`, not `fix: add a check in the retry handler`.
- **Scope** is optional context (`fix(api):`) — match scopes the repo already uses, omit it when the change isn't confined to one area, and never use an issue identifier.
- **`!`** before the colon marks a breaking change.

## Body and footer

Both optional, except that a breaking change must carry a footer. Same imperative tense as the subject.

- **Body** — motivation and contrast with previous behavior: *why*, not a restatement of the diff.
- **Footer** — issue references (`Closes #123`, `Refs JIRA-456`), and breaking changes, which start with the literal `BREAKING CHANGE:`: one space after the colon for a one-liner, two newlines for a multi-line description.

```text
feat(api)!: remove ticket list endpoint

refers to JIRA-1337

BREAKING CHANGE: ticket endpoints no longer support listing all entities.
```

The `!` is the machine-readable signal; the footer says what to migrate to when the description can't.

## Special commits

Outside the `type:` format — don't force one onto them:

```text
chore: init                     # initial commit
Merge branch '<branch name>'    # git's default merge message
Revert "<reverted subject>"     # git's default revert message
```

## Versioning

Release tooling reads the types, so mistyping one ships the wrong version — a `refactor` that was really a `feat` hides a behavior change in a patch release. `dev-release` derives its bump from exactly this:

- breaking (`!`) → **major**
- `feat` or `fix` → **minor** — the only types describing an API/UI change, which is why the table is strict about them
- otherwise → **patch**

## Writing one

Read the diff first (`git diff --staged`, or `git diff` plus `git status`) — the type and description come from what's actually there, and a diff needing two types gets split with explicit paths or `git add -p`. Then pass each paragraph as its own `-m`, which produces the blank-line separators for free:

```sh
git commit -m "fix(api): reject expired refresh tokens" \
  -m "Tokens past their exp were accepted because the check ran before the clock-skew adjustment." \
  -m "Closes #412"
```

## Enforcement

[`git-conventional-commits`](https://github.com/qoomon/git-conventional-commits) validates messages from a `commit-msg` hook, derives the version, and generates a changelog. To gate subjects in a hook or CI (`github-actions` for the workflow):

```text
^(feat|fix|refactor|perf|style|test|docs|build|ops|chore)(\(.{1,20}\))?!?: .{1,100}$
```

Allow `^Merge branch '.+'$` alongside it, or every merge commit is rejected.
