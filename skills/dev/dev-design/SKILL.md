---
name: dev-design
description: Decide a feature's shape before planning — system design, data model, API contract, UI/UX, whichever axes apply — and write docs/<feature-name>/DESIGN.md with the decisions and tradeoffs a plan builds on. Trigger on "design this feature/API/schema/UI", "how should we structure this", or between dev-research and dev-create-plan when shape needs deciding before a PLAN.md exists.
argument-hint: "[lite|full|ultra]"
---

# Design

Decide the shape of a feature before `dev-create-plan` turns it into steps. `dev-research` picks an *approach* ("use Redis, not in-process cache"); `dev-design` picks the *shape* that approach takes — the modules/services involved, the data model, the API contract, the screens/components. Skip this skill when the shape is obvious from one glance at the codebase (add a field, add a CLI flag); use it when getting the shape wrong would mean redoing the plan.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` — one pass through §2, only the axes that apply, one round of self-review.
- `full` — same axes, plus 2–3 sentences per axis on the alternative considered and why it lost.
- `ultra` — one research sub-agent per open question (existing API conventions, a library's capabilities, a platform's UI guidelines), parallel, merged into one DESIGN.md; use when an axis hinges on something unverified from reading the repo alone.

## 1. Frame the Feature

Named feature → kebab-case `<feature-name>`. If `docs/<feature-name>/RESEARCH.md` exists, read it — the design follows its recommendation and inherits its assumptions rather than re-deciding approach.

```bash
ls docs/<feature-name>/ 2>/dev/null
grep -rln "<related term>" --include="*.go" --include="*.ts" --include="*.tsx" --include="*.py" | head
```

Read the 3–5 files closest to where this feature will live — existing services, existing endpoints, existing components. A design that ignores the surrounding shape produces a plan nobody wants to implement.

## 2. Pick the Axes That Apply

Not every feature touches all three. Skip an axis entirely rather than padding it — an empty "UI/UX" section on a backend-only feature is noise.

**System design** — new feature touches multiple services/modules, introduces a new boundary, or changes how existing pieces talk to each other. Decide: what owns this responsibility, what calls what, sync or async, where state lives. Draw the shape as a short list of components and their relationships, not prose.

**Data model** — feature adds or changes persisted state. Decide: fields, types, nullability, indexes, relationships to existing tables/structs. Call out migrations and backward compatibility explicitly — a field rename is a bigger decision than it looks.

**API / interface contract** — feature adds or changes something other code or another team calls: HTTP endpoints, RPC methods, CLI flags, public function signatures, event schemas. Decide: request/response shape, error cases, versioning if it's public. Write the contract as a signature or schema snippet, not a description of one.

**UI/UX** — feature has a user-facing screen or component. Decide: what the user sees and does, states (empty/loading/error), and which existing component/pattern in the codebase this should match — reuse an existing design pattern before inventing one. A wireframe as an indented text sketch is enough here; if the user wants something clickable to look at, hand off to `dev-ui-design` to turn this axis into `docs/<feature-name>/prototype.html`.

For each axis used, name the alternative that was rejected and why in one line — the plan reviewer and implementer both need to know a choice was made on purpose, not defaulted into.

## 3. Verify, Don't Guess

Same discipline as `dev-research` §4: a claim about an existing API's behavior, a library's capability, or a platform's UI convention gets checked (read the source, WebFetch the docs, or a throwaway spike), not assumed. Mark anything unverified as `ASSUMPTION-*` with how to verify later — the plan inherits these and someone has to close them before or during implementation.

## 4. Write DESIGN.md

````markdown
---
date: <YYYY-MM-DD>
feature: <feature-name>
axes: [system, data-model, api, ui-ux]  # only the ones actually used
---

# Design: <feature-name>

## Summary
<2-3 sentences: what's being built and the shape it takes>

## System Design
<components/services involved, what owns what, how they talk — omit if not applicable>

## Data Model
<fields/types/relationships/migrations — omit if not applicable>

```
<schema or struct sketch>
```

## API / Interface
<contract — omit if not applicable>

```
<signature, endpoint, or schema sketch>
```

## UI / UX
<screens/components/states, matched to existing patterns — omit if not applicable>

```
<indented text wireframe>
```

## Decisions
- **<Axis>**: chose <X> over <Y> — <one-line why>

## Assumptions
- **ASSUMPTION-001**: <unverified claim> — verify by: <how>

## Open Questions
<must be resolved during planning — or "none">
````

## 5. Sub-Agent Mode (`ultra`, called by another skill)

Same contract as `dev-research` §6: one question, one answer, write to `docs/<feature-name>/research/<topic-slug>.md`, never ask the user, don't commit or touch DESIGN.md/PLAN.md — the caller owns git and merges the answer into the relevant axis.

## 6. Commit & Report

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

`git add docs/<feature-name>/DESIGN.md && git commit -m "design: <feature-name>"`. No push, no PR — design travels with the feature branch, same as research.

Report: file path, axes used, one-line summary, assumption count, then hand off to `dev-create-plan`.
