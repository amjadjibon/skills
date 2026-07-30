---
name: dev-tdd
description: Test-driven development — the red → green loop, done so the resulting tests are worth keeping. Use when building a feature or fixing a bug test-first, or on "red-green-refactor", "TDD", or integration tests that survive refactors.
argument-hint: "[lite|full|ultra]"
---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle — consult them before and during the loop, not after.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — cycle through red → green in-session across all agreed seams, one commit at the end covering the tests and the implementation together.
- `full` — commit after every red → green cycle (one commit per seam/slice), so the TDD progression is visible in history rather than squashed into one commit.
- `ultra` — when the agreed seams are genuinely independent (no shared types/fixtures), TDD each one in a separate worktree in parallel; merge each once its own red → green cycle is green.

When exploring the codebase, read `CLAUDE.md`/`AGENTS.md` (if either exists, at the repo root or nearest to the code being touched) so test names and interface vocabulary match the project's own conventions and domain language, rather than terms invented from scratch.

## What a Good Test Is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists — and survives refactors because it doesn't care about internal structure.

See `references/tests.md` for worked good/bad examples and `references/mocking.md` for mocking guidelines — each covers TypeScript, Go, Rust, and Python.

## Seams — Where Tests Go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam. You can't test everything — agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.

Ask: "What's the public interface, and which seams should we test?"

## Anti-patterns

- **Implementation-coupled** — mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological** — the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth — a known-good literal, a worked example, the spec.
- **Horizontal slicing** — writing all tests first, then all implementation. Bulk tests verify *imagined* behavior: you test the *shape* of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead — one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the Loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is not part of the loop.** It belongs to the review stage (see `dev-code-review` or `dev-refactor`), not the red → green implementation cycle.
