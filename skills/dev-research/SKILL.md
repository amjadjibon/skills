---
name: dev-research
description: Research a codebase, approach, or technology before planning or building — explore relevant code, compare candidate approaches, verify assumptions with runnable spikes or web/doc lookups, and write findings to docs/<feature-name>/RESEARCH.md with a recommendation. Use when the user says "research this", "investigate", "explore options", "compare approaches", "how should we implement", "which library should we use", "spike this", or wants to understand a system or evaluate alternatives before committing to a plan. Also invoked as a scoped sub-agent by dev-create-plan, dev-implement-plan, and dev-loop to answer a single question about a third-party API, library, or documentation.
argument-hint: "[lite|full|ultra]"
---

# Research

Answer a question before code gets written: how does the existing system work, which approach fits, what will break. Output is `docs/<feature-name>/RESEARCH.md` — a recommendation `dev-create-plan` can consume directly.

Research is read-mostly. The only code written is throwaway spikes, and they never merge.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — answer from reading code and docs; no spikes unless a claim can't be verified any other way.
- `full` — evaluate each candidate approach with a small runnable spike; keep the spikes in `docs/<feature-name>/spikes/` for reference.
- `ultra` — one research agent per independent question or candidate, in parallel; research is read-mostly, so plain sub-agents suffice — use a worktree only for a candidate that needs a spike. The orchestrator merges findings into a single RESEARCH.md.

## 1. Frame the Question

Turn the request into 1–3 answerable questions. "Research caching" is not answerable; "should we cache session lookups in-process or in Redis, given multi-instance deployment?" is.

- Named feature → `<feature-name>` is its kebab-case slug; findings go to `docs/<feature-name>/RESEARCH.md`
- If the question is genuinely ambiguous, ask one focused question. In autonomous mode (called before `dev-loop`/`dev-create-plan`), don't ask — state the interpretation as an assumption and proceed.

## 2. Read the Codebase First

The answer is usually constrained by what already exists. Before evaluating anything external:

```bash
git log --oneline -15                                   # recent direction
ls docs/*/PLAN.md docs/*/RESEARCH.md 2>/dev/null        # prior art — don't re-research
grep -rn "<relevant term>" --include="*.go" -l | head   # or *.ts, *.py
```

Read the 3–5 files closest to the question. Record what the codebase already does: existing utilities, patterns, dependencies that cover part of the answer. An approach that reuses what's already installed beats a better approach that adds a dependency.

## 3. Enumerate Candidates

List 2–4 realistic options, always including the do-nothing / simplest baseline. For each candidate record, in one or two lines each:

- What it is and what it costs (new dependency? migration? operational burden?)
- How it interacts with the existing code found in §2
- The main risk or unknown

Kill candidates early — a candidate eliminated by a one-line fact ("library X requires Go 1.23, we're on 1.21") needs no further research.

## 4. Verify, Don't Speculate

Every load-bearing claim in the recommendation must be verified or explicitly marked as an assumption:

- **Code behaviour** — read the actual source, not the README
- **Performance claims** — a 10-line benchmark beats a blog post
- **API/library capability** — a spike that compiles and runs; put it in `docs/<feature-name>/spikes/<candidate>/` (`full`), or a scratch dir deleted after (`lite`)
- **Third-party API contracts / library docs** — fetch the official docs (WebFetch) or search the internet (WebSearch); prefer official docs over blog posts, and record the version the docs describe — API answers rot
- **Unverifiable** (needs production data, third-party account, load) — record as `ASSUMPTION-*` with how to verify later

Spikes are throwaway: no tests, no error handling polish, never merged into application code.

## 5. Write RESEARCH.md

Save to `docs/<feature-name>/RESEARCH.md`:

````markdown
---
date: <YYYY-MM-DD>
feature: <feature-name>
status: <Concluded | Inconclusive>
recommendation: <one line>
---

# Research: <feature-name>

## Question

<The 1–3 questions from §1, as framed.>

## Recommendation

**<Chosen approach>** — <2–3 sentences: why this one, what it costs, what the main risk is.>

## Candidates

### <Candidate A> — recommended
- **Fit**: <how it uses/extends what exists>
- **Cost**: <dependency, migration, ops>
- **Verified**: <what was checked and how — file read, benchmark, spike>

### <Candidate B> — rejected
- **Why rejected**: <the one-line disqualifier or trade-off>

## Findings

- **FIND-001**: <verified fact, with file path or spike reference>

## Assumptions

- **ASSUMPTION-001**: <unverified claim> — verify by: <how>

## Open Questions

<Anything that must be answered during planning — or "none".>
````

## 6. Sub-Agent Mode (called by another skill)

`dev-create-plan`, `dev-implement-plan`, and `dev-loop` spawn research sub-agents for a single scoped question — a third-party API contract, a library's capability, an API doc, an internet search. In this mode:

- **One question, one answer.** Skip the candidate matrix (§3) unless the question is itself "which of these"; go straight to §2/§4 verification.
- **Never ask the user.** State interpretation as an assumption and proceed.
- **Write to a topic file**, not RESEARCH.md: `docs/<feature-name>/research/<topic-slug>.md` — same template, so parallel research agents never clobber each other.
- **Don't commit, push, or modify PLAN.md/LOOP.md** — the caller owns git. Return to the caller: the answer in 2–3 sentences, the topic file path, source (doc URL + version, file path, or spike), and any `ASSUMPTION-*` that survived.

Sub-agent briefing template for callers:

```
You are a research sub-agent. Answer ONE question; do not write application code.

Question: <the single scoped question>
Feature: <feature-name>
Context: <1-2 sentences on why the answer is needed>

Verify per dev-research §4: read source/official docs (WebFetch/WebSearch),
spike only if docs can't settle it. Record doc versions.
Write findings to docs/<feature-name>/research/<topic-slug>.md.
Do NOT commit, push, or modify PLAN.md/LOOP.md.
Reply with: the answer (2-3 sentences), the file path, sources, remaining assumptions.
```

## 7. Commit & Report

Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.

```bash
git add docs/<feature-name>/RESEARCH.md && git commit -m "research: <feature-name>"
```

`full`: include `docs/<feature-name>/spikes/` in the commit. No push, no PR — research artifacts travel with the feature branch `dev-create-plan` creates.

Report to caller:

```
Research written to docs/<feature-name>/RESEARCH.md
Status: <Concluded | Inconclusive>
Recommendation: <one line>
Assumptions to verify: <N>
```

If `Inconclusive`, list what's blocking a conclusion and what input would resolve it. If the recommendation is "do nothing", say so plainly — that is a valid conclusion, not a failure.
