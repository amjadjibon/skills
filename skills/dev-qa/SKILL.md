---
name: dev-qa
description: Quality assurance for a feature or codebase — analyse test coverage, identify untested paths, write missing tests (unit, integration, e2e), and produce a QA report. Use when the user says "QA this", "write tests", "improve test coverage", "add tests for", "test this feature", "what's not tested", or wants a quality gate before release.
argument-hint: "[lite|full|ultra]"
---

# QA

Establish confidence in a feature or codebase through systematic test coverage analysis and test writing. Distinct from `dev-debug` (which adds a regression test for a known bug) and `dev-code-review` (which flags missing tests as findings) — QA actively writes the missing tests.

## Delivery Mode (`lite | full | ultra`, default `lite`)

- `lite` (default) — §6 as written: one commit, one branch, one PR for all new tests.
- `full` — one branch per module/gap category (`<feature-name>/qa-<module>`), each with its own commit and stacked PR.
- `ultra` — independent test suites written in parallel worktrees, merged and reported together.

## 1. Define Scope

- **Feature** — a named feature or set of files (e.g. "the auth module", "the payment flow")
- **Diff** — `git diff main...HEAD` — test what was changed in this branch
- **Full codebase** — run coverage and find the gaps

If scope is ambiguous, ask before proceeding.

## 2. Measure Current Coverage

```bash
go test ./... -coverprofile=coverage.out && go tool cover -func=coverage.out | tail -1  # Go
npx vitest run --coverage                                                               # Node/TS
pytest --cov=. --cov-report=term-missing                                                # Python
go tool cover -html=coverage.out   # Go — opens browser with per-line coverage
```

Record: **overall %**, and the specific **files/functions with the lowest coverage**. Don't write tests until you know where the gaps are.

## 3. Identify What Needs Testing

For each file or function in scope, classify coverage gaps:

| Gap type | Priority |
| -------- | -------- |
| Happy path not tested | High |
| Error / failure paths not tested | High |
| Boundary conditions (zero, empty, max, nil) | High |
| Auth / permission checks not tested | High |
| Concurrent or async behaviour | Medium |
| Integration with external service | Medium |
| Unlikely edge cases already handled in code | Low |

List the gaps explicitly before writing any tests. A test plan written up front prevents duplicate tests and missed paths.

## 4. Write Tests

Work through the gap list from High to Low. For each test:

- One behaviour per test — not one file per test
- Name describes the scenario: `TestCreateUser_DuplicateEmail_Returns409`, not `TestCreateUser2`
- Test the observable behaviour, not the implementation — tests that break on rename/refactor without behaviour change are noise
- Unhappy paths are as important as happy paths — an untested error handler is an untested promise
- Use real dependencies where fast enough; mock only at system boundaries (external HTTP, email, payment processor)

```bash
# Run after writing each test to confirm it passes (and fails when it should)
<test command> -run TestYourNewTest
```

## 5. Verify Coverage Improved

Re-run coverage from §2. Compare:

```
Before: 61% overall  |  auth/handler.go: 34%
After:  78% overall  |  auth/handler.go: 89%
```

If a gap remains, note why (e.g. "dead code path", "requires live Stripe webhook — marked as manual test").

## 6. Commit

**`lite` (default):**
```bash
git add <test files> && git commit -m "test: add QA coverage for <feature>"
git push -u origin <feature-name>   # skip if no remote
gh pr create --base main --title "test: add QA coverage for <feature>" --body "<summary of gaps closed>"
```

**Called by `dev-loop`:** commit only — no push, no PR. The loop pushes and opens the PR at Clean Exit after user approval.

**`full`:** for each module/gap category, on its own branch stacked off the previous one:
```bash
git checkout -b <feature-name>/qa-<module>   # base = previous qa branch or main
git add <test files for this module> && git commit -m "test: add QA coverage for <module>"
git push -u origin <feature-name>/qa-<module>
gh pr create --base <previous-branch-or-main> --title "test: add QA coverage for <module>" --body "<gaps closed in this module>"
```

## 7. QA Report

Write to `docs/<feature-name>/QA.md`:

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
| path/to/file.go | 34% | 89% |

## Tests Added

- `TestFoo_HappyPath` — <what it covers>
- `TestFoo_InvalidInput_Returns400` — <what it covers>

## Remaining Gaps

- `path/to/file.go:142` — <why not covered>

## Manual Test Cases

Steps that can't be automated (external webhooks, browser flows, third-party OAuth):

- [ ] <Step-by-step manual test>
```

Report to caller:

```
QA complete: <feature-name>
Coverage: <before>% → <after>%
Tests added: <N>
Remaining gaps: <N> (see QA.md)
PR: <url> (lite) | PRs: <url per module, stacked> (full)
```
