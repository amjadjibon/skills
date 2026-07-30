---
name: dev-ponytail-review
description: Review a diff or branch for over-engineering only — reinvented stdlib, dependencies the platform covers, one-implementation abstractions, dead flexibility, code that shrinks. Use on "review for over-engineering", "is this over-engineered", "what can we delete", "simplify review". Correctness, security, and performance stay with `dev-code-review`.
---

Review the diff for unnecessary complexity, nothing else. Its best outcome is
getting shorter.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — the five biggest cuts. Report only.
- `full` — every finding, ranked biggest cut first. Report only.
- `ultra` — `full`, then apply the unambiguous findings (a stdlib swap, a one-implementation interface inlined) and leave them uncommitted. Judgement calls stay findings.

## Scope

Named target → review it. Otherwise the working diff (`git diff` + staged), and
if that's empty, the branch against its merge base.

Read the surrounding code, not just the hunks: "this abstraction has one
implementation" is a claim about the whole repo, and a wrong finding costs more
than a missed one.

## Format

`<file>:L<line>: <tag> <what>. <replacement>.` — `L<line>:` alone for a
single-file diff.

- `delete:` dead code, unused flexibility, speculative feature. Replacement: nothing.
- `stdlib:` hand-rolled thing the stdlib ships. Name the function.
- `native:` dependency or code doing what the platform does. Name the feature.
- `yagni:` abstraction with one implementation, config nobody sets, layer with one caller.
- `shrink:` same logic, fewer lines. Show the shorter form.

Not a hedged paragraph — "this EmailValidator might be more complex than
necessary, have you considered..." — but:

- `L12-38: stdlib: 27-line validator class. "@" in email; the confirmation mail is the real validation.`
- `L4: native: moment.js for one format call. Intl.DateTimeFormat, zero deps.`
- `repo.py:L88: yagni: AbstractRepository with one implementation. Inline until a second exists.`
- `L52-71: delete: retry wrapper around an idempotent local call. Nothing replaces it.`
- `L30-44: shrink: manual loop builds a dict. dict(zip(keys, values)), one line.`

End with `net: -<N> lines possible.` (deleted minus what replacements add).
Nothing to cut → `Lean already. Ship.` A tight diff is a pass, not a failed hunt.

## Boundaries

Complexity only. A real bug spotted while reading gets one line at the end under
`out of scope:` and goes to `dev-code-review` — don't swallow it, don't expand
into a full review.

One smoke test or `assert` self-check is the `dev-ponytail` minimum, not bloat.
Never flag it for deletion.
