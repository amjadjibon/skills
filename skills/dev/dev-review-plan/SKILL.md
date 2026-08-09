---
name: dev-review-plan
description: Review a PLAN.md before implementation — vague tasks, missing completion criteria, risky assumptions, wrong phase ordering, scope issues — to .spec/<feature-name>/PLAN-REVIEW.md with a verdict. Use on "review the plan", "check the plan", "is this plan ready", "validate the plan".
argument-hint: "[lite|full|ultra]"
---

# Review Plan

You are a **senior software architect** reviewing a plan before a team commits to it. Direct, specific, unimpressed by padding — a bad plan found now costs minutes; found mid-implementation it costs hours.

## Delivery Mode (`lite | full | ultra`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

No-op — this skill only writes `PLAN-REVIEW.md`; present for consistency.

## Artifact Location

Artifact paths below use `.spec/` as the default root. Only a custom root explicitly named by the
user overrides it; replace the `.spec/` prefix in every path and command below with that root.
`dev-loop` passes the resolved root to the skills it invokes. Never discover, migrate, or fall back to
legacy `docs/` artifacts. A gitignored or out-of-repo custom root means the artifacts are scratch —
write and read them as normal, but **never commit them**.

## 1. Locate the Plan

Named feature → `.spec/<feature-name>/PLAN.md`; else `ls .spec/*/PLAN.md` (prefer `status: Planned`). Do not search or fall back to `docs/`. None → offer `dev-create-plan`.

## 2. Review Checklist

Only raise real issues.

**Clarity** — vague tasks ("improve performance") with no concrete action; bundled multi-tasks; untestable completion criteria ("it should work"); missing file paths/function names where needed to act.

**Scope & structure** — phases >~5 tasks or >5 phases per feature (scope risk); tasks in the wrong phase (tests before the code, migrations before schema); `Depends on:` referencing a missing or later phase.

**Architecture** — decisions with no rationale where an alternative is materially better; abstractions for a single use case; cross-cutting concerns (auth, logging, error formatting) duplicated per-feature; hard-to-reverse data model changes without justification.

**Risks & assumptions** — undocumented external dependencies; load-bearing assumptions not listed; no rollback for irreversible steps (migrations, destructive ops, infra); no failure behaviour (timeout, partial migration, backed-up queue).

**Completeness** — no runnable test commands; security-relevant changes with no security tasks; DB changes without migration + rollback; new endpoints without contract/doc task (if the project uses specs); performance ignored on large-data/high-traffic paths.

## 3. Severity

**Block** — cannot be safely executed as written · **Revise** — executable but gaps will bite mid-implementation · **Suggest** — minor, workable without it.

## 4. Write PLAN-REVIEW.md

Save to `.spec/<feature-name>/PLAN-REVIEW.md`:

````markdown
---
date: <YYYY-MM-DD>
plan: .spec/<feature-name>/PLAN.md
plan_version: <version from frontmatter>
reviewer: Claude
verdict: <Ready | Needs Revision | Blocked>
---

# Plan Review: <feature-name>

## Verdict
**<Ready | Needs Revision | Blocked>** — <one sentence>

## Findings

### [BLOCK-001] <Title>
**Phase**: <N or "Frontmatter">
**Issue**: <what's unclear/missing and why it matters>
**Fix**: <concrete suggestion>

<!-- [REVISE-001], [SUGGEST-001] — same shape -->

## What's Good
<1-3 specifics>

## Machine-Readable Verdict

```yaml
verdict: <Ready | Needs Revision | Blocked>
block: <N>
revise: <N>
suggest: <N>
blocking_ids: [<BLOCK-001>, ...]
```
````

Verdict: `Ready` = no Block/Revise · `Needs Revision` = Revise, no Block · `Blocked` = any Block.

## 5. Report to Caller

File path, verdict, counts. If not `Ready`, list blocking finding titles inline.
