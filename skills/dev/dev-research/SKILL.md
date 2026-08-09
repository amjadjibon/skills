---
name: dev-research
description: Answer one scoped question before code is written — a third-party API contract, a library capability, a doc lookup, or which approach to take — verified with spikes and web/doc lookups, written to .spec/<feature-name>/RESEARCH.md. Trigger on "research/investigate/spike this", "explore options", "which library should we use".
argument-hint: "[lite|full|ultra]"
---

# Research

Answer a question before code gets written. Output: `.spec/<feature-name>/RESEARCH.md` — a recommendation `dev-create-plan` consumes directly. Research is read-mostly; the only code written is throwaway spikes, never merged.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — answer from reading code and docs; spike only when nothing else can verify a claim.
- `full` — spike each candidate; keep spikes in `.spec/<feature-name>/spikes/`.
- `ultra` — one agent per independent question, in parallel (plain sub-agents — worktree only for a candidate needing a spike); orchestrator merges into one RESEARCH.md.

## Artifact Location

Artifact paths below use `.spec/` as the default root. Only a custom root explicitly named by the
user overrides it; replace the `.spec/` prefix in every path and command below with that root.
`dev-loop` passes the resolved root to the skills it invokes. Never discover, migrate, or fall back to
legacy `docs/` artifacts. A gitignored or out-of-repo custom root means the artifacts are scratch —
write and read them as normal, but **never commit them**.

## 1. Frame the Question

Turn the request into 1–3 answerable questions ("should we cache session lookups in-process or in Redis, given multi-instance deployment?" — not "research caching"). Named feature → kebab-case `<feature-name>`. Genuinely ambiguous → ask one focused question; in autonomous mode, state the interpretation as an assumption and proceed. If the request has no answerable question in it yet — an open idea, not a decision — `brainstorming` comes first; research verifies a candidate, it doesn't generate the candidates.

## 2. Read the Codebase First

The answer is usually constrained by what exists:

```bash
git log --oneline -15
ls .spec/*/PLAN.md .spec/*/RESEARCH.md 2>/dev/null        # prior art — don't re-research
grep -rn "<relevant term>" --include="*.go" -l | head   # or *.ts, *.py
```

Read the 3–5 closest files. Record existing utilities, patterns, and dependencies that cover part of the answer — reusing what's installed beats a better approach that adds a dependency.

## 3. Enumerate Candidates

2–4 realistic options, always including do-nothing/simplest. Per candidate, 1–2 lines: what it costs (dependency? migration? ops?), how it interacts with §2 findings, the main risk. Kill early — a one-line disqualifier ("needs Go 1.23, we're on 1.21") ends that candidate's research.

## 4. Verify, Don't Speculate

Every load-bearing claim is verified or marked as an assumption:

- **Code behaviour** — read the source, not the README.
- **Performance** — a 10-line benchmark beats a blog post.
- **API/library capability** — a spike that compiles and runs (`.spec/<feature-name>/spikes/<candidate>/` in `full`; scratch dir deleted after in `lite`).
- **Third-party contracts/docs** — WebFetch the official docs or WebSearch; prefer official docs, record the version — API answers rot.
- **Unverifiable** (needs prod data, third-party account, load) — `ASSUMPTION-*` with how to verify later.

Spikes are throwaway: no tests, no polish, never merged.

## 5. Write RESEARCH.md

````markdown
---
date: <YYYY-MM-DD>
feature: <feature-name>
status: <Concluded | Inconclusive>
recommendation: <one line>
---

# Research: <feature-name>

## Question
<the 1–3 questions>

## Recommendation
**<Chosen approach>** — <2–3 sentences: why, cost, main risk.>

## Candidates
### <Candidate A> — recommended
- **Fit**: <how it uses what exists> · **Cost**: <dependency/migration/ops> · **Verified**: <how>
### <Candidate B> — rejected
- **Why rejected**: <one-line disqualifier or trade-off>

## Findings
- **FIND-001**: <verified fact, with file path or spike reference>

## Assumptions
- **ASSUMPTION-001**: <unverified claim> — verify by: <how>

## Open Questions
<must be answered during planning — or "none">
````

## 6. Sub-Agent Mode (called by another skill)

`dev-create-plan`, `dev-implement-plan`, and `dev-loop` spawn research sub-agents for one scoped question (third-party API contract, library capability, doc lookup, internet search). In this mode: one question, one answer — skip §3 unless the question is itself "which of these"; never ask the user; write to `.spec/<feature-name>/research/<topic-slug>.md` (same template — topic files so parallel agents never clobber each other); don't commit, push, or touch PLAN.md/LOOP.md — the caller owns git. Return: the answer (2–3 sentences), the file path, sources (doc URL + version, file path, or spike), surviving `ASSUMPTION-*`.

Briefing template for callers:

```
You are a research sub-agent. Answer ONE question; do not write application code.

Question: <the single scoped question>
Feature: <feature-name>
Context: <1-2 sentences on why the answer is needed>

Verify per dev-research §4: read source/official docs (WebFetch/WebSearch),
spike only if docs can't settle it. Record doc versions.
Write findings to .spec/<feature-name>/research/<topic-slug>.md.
Do NOT commit, push, or modify PLAN.md/LOOP.md.
Reply with: the answer (2-3 sentences), the file path, sources, remaining assumptions.
```

## 7. Commit & Report

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

`git add .spec/<feature-name>/RESEARCH.md && git commit -m "research: <feature-name>"` (`full`: include `spikes/`). No push, no PR — research travels with the feature branch.

Report: file path, status, one-line recommendation, assumption count. `Inconclusive` → list what's blocking and what input resolves it. "Do nothing" is a valid conclusion — say it plainly.
