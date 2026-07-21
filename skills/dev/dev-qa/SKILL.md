---
name: dev-qa
description: Quality assurance for a feature or codebase — analyse test coverage, identify untested paths, write missing tests (unit, integration, e2e), and produce a QA report. Use when the user says "QA this", "write tests", "improve test coverage", "add tests for", "test this feature", "what's not tested", or wants a quality gate before release.
argument-hint: "[lite|full|ultra]"
---

# QA

Systematic coverage analysis + writing the missing tests. Distinct from `dev-debug` (regression test for a known bug) and `dev-code-review` (flags gaps as findings) — QA writes the tests. Assumes the code under test already exists — for building new code test-first, see `dev-tdd` instead.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — one commit, one branch, one PR for all new tests.
- `full` — one branch per module (`<feature-name>/qa-<module>`), stacked PRs.
- `ultra` — independent test suites written in parallel worktrees (subagent type `dev-tester` when available, else general-purpose — one per module, briefed with its worktree path, branch, and §3 gaps), merged and reported together.

## 1. Scope

**Feature** (named files/module) · **Diff** (`git diff main...HEAD`) · **Full codebase** (coverage-driven). Ambiguous → ask.

## 2. Measure Current Coverage

```bash
go test ./... -coverprofile=coverage.out && go tool cover -func=coverage.out | tail -1  # Go
npx vitest run --coverage                                                               # Node/TS
pytest --cov=. --cov-report=term-missing                                                # Python
```

Record overall % and the lowest-coverage files/functions. Don't write tests before knowing the gaps.

## 3. Identify Gaps

Classify per file/function — **High**: happy path, error/failure paths, boundaries (zero/empty/max/nil), auth/permission checks · **Medium**: concurrency/async, external-service integration · **Low**: unlikely edge cases already handled. List gaps before writing — an upfront test plan prevents duplicates and misses.

## 4. Write Tests

High → Low:

- One behaviour per test; name = scenario (`TestCreateUser_DuplicateEmail_Returns409`, not `TestCreateUser2`).
- Test observable behaviour through public interfaces, not implementation — see `dev-tdd`'s anti-patterns (implementation-coupled, tautological) and mocking-boundary rules, they apply here too even outside a strict red→green loop.
- Unhappy paths matter as much as happy — an untested error handler is an untested promise.
- Real dependencies where fast enough; mock only system boundaries (external HTTP, email, payments).
- Run each new test as written — confirm it passes, and fails when it should.
- Gap is E2E-shaped (a full user flow, not a single function/module)? Use `dev-e2e-testing` for the tooling/fixture/flake practices, not ad-hoc Playwright/Cypress.

## 5. Verify Improvement

Re-run §2, compare (`Before: 61% | auth/handler.go: 34%` → `After: 78% | 89%`). Remaining gaps get a reason ("dead code", "needs live Stripe webhook — manual test").

## 6. Commit

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

**`lite`**: `git add <test files> && git commit -m "test: add QA coverage for <feature>"`, push, `gh pr create --base main`. **`full`**: per module on its own stacked branch `<feature-name>/qa-<module>`. **Called by `dev-loop`**: commit only — the loop pushes and opens the PR after user approval.

## 7. QA Report

Write `docs/<feature-name>/QA.md`:

```markdown
---
date: <YYYY-MM-DD>
feature: <feature-name>
coverage_before: <N%>
coverage_after: <N%>
---

# QA Report: <feature-name>

## Coverage
| File | Before | After |
| ---- | ------ | ----- |

## Tests Added
- `TestName` — <what it covers>

## Remaining Gaps
- `path/file.go:142` — <why not covered>

## Manual Test Cases
- [ ] <steps that can't be automated — webhooks, browser flows, OAuth>
```

Report to caller: coverage before → after, tests added, remaining gaps, PR URL(s).
