---
name: dev-ponytail-debt
description: Harvest every `TODO`/`FIXME` marker into one ledger with ceiling, trigger, owner, and age, flagging the ones that name no trigger. Use on "ponytail debt", "yagni debt", "what did we defer", "list the shortcuts", "collect the TODOs", "TODO ledger". Reports; changes no code.
---

Every deliberate `dev-ponytail` shortcut leaves an owner-tagged comment naming
its ceiling and upgrade path. This collects them so a deferral can't quietly
become permanent.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — the ledger inline, grouped by file.
- `full` — plus `git blame` age per row, oldest first. Writes `.spec/<feature-name>/DEBT.md`.
- `ultra` — `full`, then read the code around each row and mark whether the stated trigger has already fired (`FIRED` / `not yet` / `unclear`). A shortcut whose condition is already true is the point of the whole ledger.

`<feature-name>` is the scanned scope — the module named in the invocation, or
`repo` for a whole-tree scan.

## Artifact Location

Artifact paths below use `.spec/` as the default root. Only a custom root explicitly named by the
user overrides it; replace the `.spec/` prefix in every path and command below with that root.
`dev-loop` passes the resolved root to the skills it invokes. Never discover, migrate, or fall back to
legacy `docs/` artifacts. A gitignored or out-of-repo custom root means the artifacts are scratch —
write and read them as normal, but **never commit them**. Application code must never reference,
import, or link to `.spec/` artifacts — they are workflow scratch, not part of the product, and may
be gitignored or deleted by the time anyone else reads the code.

## Scan

```sh
rg -n --no-heading '(#|//|--|/\*) ?(TODO|FIXME|HACK|XXX):' \
  -g '!{vendor,dist,build,target}/'
```

`rg` honours `.gitignore` and skips `.git`, so `node_modules` and `.venv` need no
exclusion. Add your stack's comment prefixes if they differ; requiring one keeps
prose that merely mentions the convention out of the ledger.

Each hit is one row. Owner is the `[name]` after the tag; missing → take it from
`git blame -L<line>,<line> -- <file>` and mark it `(blame)`.

## Output

One row per marker, grouped by file:

`<file>:<line> [<owner>] <what was simplified>. ceiling: <the limit>. trigger: <what should make us revisit>.`

The convention is `TODO: [owner] <ceiling>, <upgrade path>` — pull both straight
from the comment, invent neither. Flag the rows that rot:

- `no-trigger` — a ceiling but no condition to revisit. "Later" undefined.
- `no-ceiling` — neither. Somebody wrote `TODO: fix this` and moved on; needs an owner decision, not a ledger row.

End with `<N> markers, <M> no-trigger, <K> no-ceiling.` Name the oldest row and
its age — a three-year-old `TODO` is a decision, not a deferral, and should be
done or deleted. Nothing found → `No deferred shortcuts. Clean ledger.`

## Boundaries

Reads and reports; changes no code and edits no comments in any mode. `lite`
writes nothing unless asked. To act on a row: `dev-create-plan` for a deferral
coming due, `dev-debug` for a `FIXME` that's now biting.
