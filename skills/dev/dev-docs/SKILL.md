---
name: dev-docs
description: Write documentation someone will actually read — READMEs, guides, API references, runbooks — short, scannable, example-first, and verified against the code. Trigger on "write docs", "document this", "write a README", "explain how to use this", "our docs are too long/confusing", or a doc that needs rewriting for humans.
argument-hint: "[lite|full|ultra]"
---

# Write Docs

Documentation is read by someone stuck, in a hurry, halfway through something else. It succeeds when they leave sooner than they expected — not when it covers everything. Every rule here serves that.

This is prose for humans; `openapi-spec` writes the machine-readable spec, `mermaid-diagram` draws the picture a doc embeds, and inline code comments stay with the code.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` — one document, written and cut once.
- `full` — a small set (README + one guide + reference), cross-linked, each with its own reader.
- `ultra` — one general-purpose sub-agent per document, written in parallel from a shared outline, then merged and de-duplicated by the orchestrator. (No doc-writing agent type exists; `dev-researcher` is read-only and writes only research notes — don't spawn it to write docs.)

## Artifact Location

Docs go where the project already keeps them — `README.md` at the root, `docs/`, a wiki directory. Nothing new gets invented; if the repo has no convention, `docs/` and say so. A gitignored root means the doc is scratch: write it, don't commit it.

These are published docs for the product's readers, so `docs/` remains a valid destination. Internal workflow artifacts such as PLAN.md and REVIEW.md belong under `.spec/<feature-name>/` instead; `dev-docs` must not place them in the published documentation tree.

## 1. Name the Reader and the Job

Before a word of prose, answer in one line each: **who** is reading (someone evaluating this? installing it? debugging it at 2am? extending it?) and **what they need to leave with**. Ambiguous and the user is present → ask. Ambiguous and you're autonomous → pick the most likely reader, write for them, say which one you picked.

One document, one reader, one job. A README that also teaches architecture serves neither.

**Rewriting an existing doc?** Read all of it first and sort it into three piles: still true (keep, tighten), stale or wrong (fix against the code, §3), and never needed (delete, §5). Keep the headings and anchors people have linked to unless they're actively misleading — a rewrite that silently breaks every bookmark reads as a broken site. Say what you removed in the report; deletion is the point, and it's also the part someone may want back.

## 2. Pick One Shape

| Shape | Reader's question | Ceiling |
|---|---|---|
| README | "What is this and should I use it?" | one screen before the first working example |
| How-to / guide | "How do I do X?" | the steps for X, nothing adjacent |
| Reference | "What are the exact arguments?" | as long as the surface, tables not prose |
| Explanation | "Why is it built this way?" | one idea per page |
| Runbook | "It's broken at 2am, what do I do?" | numbered commands, no theory |

Don't blend shapes in one document. A tutorial interrupted by API tables loses both readers.

## 3. Read the Code First

Never document from the name of a function. Read the real signatures, flags, defaults, and error paths; run the command and paste what it actually printed. Every example must be copy-pasteable and correct — an invented flag is worse than no documentation, because it costs the reader trust in everything else on the page.

Uncertain about behaviour you can't run? Say what you verified and what you didn't, rather than writing a confident guess.

## 4. Write It

- **Working example first.** Show it doing the thing before explaining what it is. Concept-then-example loses people who came to copy a command.
- **Second person, present tense, active voice.** "Run `make build`", not "the build can be run by the user".
- **Descriptive headings** — a reader scanning only headings should find their answer. "Handling expired tokens", not "Advanced usage".
- **Short paragraphs, one idea each.** A wall of text reads as "not for me".
- **Tables for anything with the same shape repeated** — flags, fields, env vars, error codes.
- **Name the gotchas.** The thing that silently fails, the flag that must come first, the setting that breaks in Docker. This is what people search for, and it's what most docs omit.
- **Link instead of repeating.** Duplicated prose is prose that will go stale in one place and mislead.

## 5. Cut

Do a deletion pass — this is what makes the difference, and it's the step that gets skipped. Delete on sight:

- Preambles: "In this section we will…", "This document describes…". Start with the content.
- Headings restated as the first sentence under them.
- Anything true of software in general ("errors should be handled").
- Marketing adjectives — powerful, robust, seamless, simple, blazing. Show the benchmark or drop the claim.
- Options and edge cases nobody asked about, kept "for completeness". Completeness is what reference docs are for.
- Every sentence that survives only because it was already written.

Then ask: **if a reader only read the first screen, would they get what they came for?** If not, reorder until they would.

## 6. Verify

Run every command in the doc, in order, from a clean state, and fix what doesn't match. Check every link and file path resolves. Confirm the version and defaults still match the code.

Some commands can't be run here — they deploy, cost money, or destroy something. Don't fake it: verify those against the code, mark them as unverified in the report, and never present output you didn't see.

`full`/`ultra`: read the set end to end as one reader would — no contradictions between documents, no concept explained twice, every cross-link landing somewhere real.

## 7. Commit & Report

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

`git add <doc paths> && git commit -m "docs: <what a reader can now do>"`.

Report: what was written, the reader it targets, what you verified by running, and anything deliberately left out — a stated omission is a decision, a silent one is a gap.
