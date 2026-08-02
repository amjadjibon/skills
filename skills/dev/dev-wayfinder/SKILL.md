---
name: dev-wayfinder
description: Map a large, ambiguous project into a decision graph before planning — open questions resolved one ticket at a time in docs/<feature-name>/MAP.md until a PLAN.md is finally possible. Trigger on "this is too big to plan", "I don't know where to start", "chart this out", "map this project", "what do we need to decide first", or a request too undecided to phase.
argument-hint: "[lite|full|ultra]"
---

# Wayfinder

Some work is too foggy to plan. `dev-create-plan` needs phases with completion criteria; you can't
write those when the real question is still "should this even be a service?". Wayfinder is the step
before: name the destination, map what stands between you and it, and resolve those unknowns one at
a time until the route is obvious enough to phase.

**Plan, don't do.** Every ticket resolves a *decision*, never a deliverable. The moment the map's
fog clears, this skill ends and `dev-design`/`dev-create-plan` take over. A wayfinder session that
ships a feature has failed at its actual job.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — the map is `docs/<feature-name>/MAP.md` and nothing else; tickets are sections in it, resolved in this session.
- `full` — same map, mirrored to GitHub issues (`gh issue create --label wayfinder`), the map itself an issue labelled `wayfinder:map`. Use when the work outlives one session or more than one person is charting.
- `ultra` — `full`, plus every open Research ticket fans out to a parallel `dev-researcher` sub-agent (else general-purpose) at once instead of one at a time.

## Artifact Location

Artifact paths below are relative to the artifact root: `docs/` by default, or wherever the user (or
`dev-loop`, which passes the one it resolved) points it. A gitignored or out-of-repo root means the
artifacts are scratch — write and read them as normal, but **never commit them**.

## 1. Name the Destination

One sentence describing what "done" looks like — a written spec, a made decision, or a shipped
change. If you can't write it, you don't have a destination, you have a mood; ask the user for it
rather than guessing, because everything downstream inherits this sentence.

Then kebab-case it into `<feature-name>` and check for prior art:

```bash
ls docs/<feature-name>/ 2>/dev/null      # an existing MAP.md means resume, don't re-chart
git log --oneline -15
```

## 2. Chart the Frontier

Map **breadth-first, not depth-first**. List every question standing between here and the
destination before chasing any single one — a map with one branch explored to its leaf and five
untouched is worse than no map, because it reads as progress.

For each question, decide which kind of ticket resolves it:

| Type | Resolved by | Away-from-keyboard? |
|------|-------------|:---:|
| **Research** | `dev-research` — a third-party contract, a library capability, how the existing code behaves | yes |
| **Prototype** | `prototype` (logic or UI variants) or `dev-ui-design` (a clickable HTML screen) — the question needs something concrete to argue about | no |
| **Grilling** | `brainstorming` — a judgement call with no external right answer, decided by talking it through | no |
| **Task** | ordinary work that *unblocks* a decision (a spike migration, a measurement via `dev-perf`) — never work that delivers the destination | either |

A question you can't type a ticket for is fog: it goes under **Not yet specified** and graduates
when a neighbouring answer makes it askable.

## 3. Write MAP.md

`docs/<feature-name>/MAP.md`. This file is the single source of truth — a wayfinder session that
ends without updating it has produced nothing.

````markdown
---
feature: <feature-name>
started: <YYYY-MM-DD>
status: <charting | working | cleared>
mode: <lite|full|ultra>
---

# Map: <feature-name>

## Destination
<the one sentence from §1>

## Notes
<domain context and standing preferences — anything a future session would otherwise re-ask>

## Open Tickets
### <Ticket Name> — Research
**Question**: <the single question this resolves>
**Blocks**: <which other tickets or fog this unlocks — or "nothing yet">

### <Ticket Name> — Grilling
**Question**: <…>
**Blocks**: <…>

## Decisions So Far
- **<Ticket Name>** — <one-line gist of the answer> (`docs/<feature-name>/research/<slug>.md`)

## Not Yet Specified
- <question too foggy to ticket, and what would make it askable>

## Out Of Scope
- <consciously ruled out> — <why>
````

**Refer to tickets by name, always.** `#42, #43, #44` is illegible; *Pick the queue backend*,
*Decide retry semantics* reads at a glance. This holds in the map, in commit messages, and when
reporting to the user.

## 4. Work the Map

One ticket at a time (`ultra`: all Research tickets at once, since they don't interact):

1. **Load** MAP.md — never work a ticket from memory of a previous session.
2. **Claim** it: mark the ticket `— in progress`.
3. **Resolve** it through the skill its type names in §2.
4. **Record** the answer as a one-line gist under Decisions So Far, and delete it from Open Tickets. The long form lives in the artifact the resolving skill wrote (`RESEARCH.md`, `prototype.html`, `research/<slug>.md`); the map keeps the gist and the link, never a copy.
5. **Re-chart**: an answer usually creates new tickets, graduates fog into a ticket, or rules something Out Of Scope. Do all three where they apply — this is where the map actually earns its keep.
6. **Commit** and stop.

Resist resolving a second ticket because it "feels quick". Each answer changes the shape of the
remaining questions, and a session that burns through four tickets on the map as it looked at the
start has usually answered two of them wrong.

## 5. Exit — the Fog Clears

Wayfinder is done when Open Tickets and Not Yet Specified are both empty, or when what remains no
longer blocks a decision. Set `status: cleared` and hand off, saying which:

- Shape still undecided (services, data model, contract) → `dev-design` → `docs/<feature-name>/DESIGN.md`
- Shape already settled by the decisions → `dev-create-plan` directly
- Destination was itself a spec or a decision → the map *is* the deliverable; report it and stop

Never roll straight into implementation from here. The handoff is the point.

## 6. Commit & Report

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

`git add docs/<feature-name>/MAP.md && git commit -m "map: resolve <Ticket Name>"` — charting the
map for the first time is `map: chart <feature-name>`. No push, no PR; the map travels with the
feature branch like RESEARCH.md and DESIGN.md. `full`/`ultra`: close the mirrored issue in the same
step, so the tracker and the map never disagree.

Report: destination, tickets resolved this session (by name), decisions added, what the map now
says is next, and the count still open. `cleared` → name the handoff skill.
