---
name: dev-ponytail-audit
description: Repo-wide over-engineering scan — the whole tree instead of a diff, ranked by what to delete, simplify, or replace with a stdlib/native equivalent. Use on "audit this codebase", "audit for over-engineering", "what can I delete from this repo", "find the bloat", "where is this over-built". Reports; applies nothing.
---

`dev-ponytail-review`, repo-wide. Same tags, same one-line format, ranked biggest
cut first.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — the ten biggest cuts, inline. Dependencies and the largest files first; that's where the mass is.
- `full` — whole tree, every finding, ranked. Writes `docs/<feature-name>/AUDIT.md`.
- `ultra` — `full` fanned out: one read-only sub-agent per top-level module in parallel (`dev-researcher` when available, else general-purpose), each returning the format below. Merge, de-duplicate, rank, write the same file.

`<feature-name>` is the audited scope — the module named in the invocation, or
`repo` for a whole-tree pass.

## Scope

Skip what isn't yours to cut: `node_modules`, `vendor`, build output, generated
code, lockfiles, migrations, anything `.gitignore`d. Vendored code is someone
else's repo, not your over-engineering.

## Hunt

In order of payoff:

1. **Dependencies** the stdlib or platform ships — one `package.json`/`requirements.txt`/`go.mod` read finds more mass than an hour of file reading.
2. **Single-implementation abstractions** — interfaces, ABCs, factories with one product.
3. **Wrappers that only delegate.**
4. **Dead config and flags** — nothing reads it, or one value at every call site.
5. **Hand-rolled stdlib** — a written-out `groupby`, `zip`, `dedent`, date math.
6. **One-export files** nothing imports.

Grep for callers before writing a finding. "Nothing uses this" is the claim most
often wrong in an audit, and a confident wrong deletion is this skill's one
expensive mistake — dynamic dispatch, reflection, DI containers, and test-only
usage all hide callers. Can't confirm → tag the line `unverified:`.

## Output

Ranked, one line per finding:
`<tag> <what to cut>. <replacement>. [path:line]`

Tags are `dev-ponytail-review`'s: `delete:`, `stdlib:`, `native:`, `yagni:`,
`shrink:`. End with `net: -<N> lines, -<M> deps possible.` Nothing to cut →
`Lean already. Ship.`

## Boundaries

Complexity only — correctness and security go to `dev-code-review`, performance
to `dev-perf`. Applies nothing in any mode: a repo-wide automated deletion pass
is exactly the confident-wrong change `dev-ponytail` warns about. To act, hand
the audit to `dev-create-plan` or fix the top items by hand.
