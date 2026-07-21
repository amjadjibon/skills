---
name: dev-e2e-testing
description: Write and maintain Playwright end-to-end tests that drive the whole system through its real UI/API, living under tests/e2e (or tests/). Covers Playwright setup, test independence and fixtures, flake handling, and CI wiring. Trigger on "write e2e tests", "set up Playwright", "test the full user flow", "our e2e tests are flaky", or when tests/e2e needs new coverage or maintenance. Distinct from `dev-tdd` (the red-green loop at any seam) and `dev-qa` (coverage backfill) — this is specifically the E2E layer's tooling and practices.
argument-hint: "[lite|full|ultra]"
---

# End-to-End Testing

E2E tests are the slowest, most realistic, and most expensive tests in the pyramid — they earn their keep only by covering what integration tests structurally can't: the assembled system behaving correctly through its real UI or public API. Write few, make them count, keep them from rotting into a flaky tax on every PR.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — the one critical happy-path flow for the feature, one test.
- `full` — happy path + the realistic failure/edge flows (invalid input, permission denied, empty state) worth the E2E cost.
- `ultra` — `full`'s coverage run across environments/browsers/viewports in parallel (subagent type `dev-tester` when available, else general-purpose, one per target), merged and reported together.

## 1. Decide What Earns an E2E Test

Not every path deserves one — E2E tests are slow and worth writing only for what genuinely needs the real system:

- **A user-facing flow spanning multiple pages/screens or a full request lifecycle** (signup → verify → first action) — the kind of bug that only shows up when the pieces are wired together for real.
- **A critical business path** (checkout, payment, auth) where a regression is expensive enough to justify the cost.
- **Skip it** for anything a unit or integration test already proves — an E2E test re-verifying validation logic already covered lower in the pyramid is redundant cost with no new signal.

## 2. Location and Structure

Tests live under `tests/e2e/` (or `tests/` if the project has no unit/integration split yet) — never inside `src/` or colocated with implementation. Name by user-facing flow, not by page: `checkout-with-saved-card.spec.ts`, not `cart-page.spec.ts`.

## 3. Tooling

Playwright. Run headless in CI, headed locally for debugging.

Config, a fixture-backed test, and a page-object example are in `references/details.md`.

## 4. Independence and Fixtures

- **Each test creates its own data.** A test that depends on another test's leftover state (a specific user, a specific record) breaks the moment tests run in a different order or in parallel — seed what the test needs in its own setup.
- **Isolate the environment.** A dedicated test/staging environment or ephemeral per-run environment, never against production — an E2E test that mutates real user data is a production incident waiting to happen, not a test.
- **Clean up after, but design for survivable failure.** A test that crashes mid-run shouldn't leave orphaned data poisoning the next run — prefer generating uniquely-namespaced data (timestamped/UUID'd) over relying on teardown always executing.

## 5. Flake Is a Bug, Not Weather

A flaky E2E test that gets re-run until green trains everyone to ignore red — treat flake as seriously as a functional bug:

- **Wait for state, never for time.** `waitFor(selector/condition)`, not `sleep(2000)` — a fixed sleep is either too short (still flaky) or too long (slow for no reason). Playwright's built-in auto-waiting already handles most of this; a manual sleep added on top is almost always working around a different, unfixed race.
- **Assert on the outcome the user would see**, not an implementation-adjacent side effect (a specific network call count, an internal state variable) — the E2E layer's whole value is verifying what's actually visible.
- **A test that fails intermittently gets root-caused, not retried into passing.** A retry-until-green config hides real races; use retries only as a last-resort CI stabilizer for a known, understood source of nondeterminism (e.g. a third-party sandbox's occasional slowness), never as the fix for an unexplained flake.
- **Quarantine, don't delete, a test that's flaky for an unknown reason** — mark it skipped with a tracking note, keep the coverage gap visible, don't silently lose the signal.

A flake-troubleshooting checklist is in `references/details.md`.

## 6. CI Wiring

E2E suites are usually the slowest CI stage — run them on a separate job/stage from unit+integration so a slow E2E run doesn't block fast feedback, and shard across workers when the suite is large enough to benefit (sharding example in `references/details.md`). See the `github-actions` skill for the workflow/matrix setup itself.

## 7. Verify Before Handing Back

Run the new test and confirm it fails against a broken version of the flow (comment out the fix, or run against `main` before the feature) as well as passing against the real one — an E2E test that never fails might be testing nothing.
