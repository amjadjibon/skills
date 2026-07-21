---
name: dev-smoke-testing
description: Write and run smoke tests — fast, thin, one-check-per-file sanity scripts (bash or Python under scripts/test-<check-name>.sh|py, e.g. scripts/test-user-create.sh) that answer one question, is the build/deploy alive, so an agent or user can run one command instead of manually clicking around to check. Not a CI/CD pipeline gate and not full regression coverage. Trigger on "smoke test", "sanity check this deploy", "is the build healthy", "quick check this is working", or when a scripts/test-*.{sh,py} check needs adding or updating.
---

# Smoke Testing

A smoke test exists to answer exactly one question fast: is this thing alive right now? It's a script an agent or a human runs on demand — after a deploy, after starting a service locally, before spending time debugging something that turns out to just be down — instead of manually curling endpoints or clicking through the app by hand. It is not a regression suite and not a pipeline gate: no CI job, no CD step, just a command run when someone actually wants to know. A smoke check that takes 10 minutes has stopped being a smoke test; it's just a slow, worse E2E suite.

Keep it to the one or two essential checks, each its own small script — when more than one is needed, run them together with a simple loop (`for f in scripts/test-*.sh; do "$f" "$BASE_URL" || FAILED=1; done`), no aggregator file to maintain.

## 1. What Belongs in a Smoke Test

Keep the list short enough to name from memory:

- **A health/readiness endpoint** — the service process is up and its immediate dependencies (DB connection, cache connection) respond.
- **One or two critical paths**, read-only where possible — "can a user log in," "does the homepage return 200 with expected content," not every route.
- **A version/build-identifier check** when deploys are easy to get wrong — confirms the expected build actually shipped, not a stale cache serving the old one.

**Does not belong:** edge cases, error-path coverage, anything requiring realistic test data setup, anything slow. That's `dev-e2e-testing`'s job.

## 2. Location and Form

One check, one file, named for what it checks: `scripts/test-create-user.sh`, `scripts/test-get-user-session.py` — not a shared `smoke-test.sh` grab-bag. Bash if `curl` and exit codes are enough, which is most of the time. Reach for Python instead when a check needs something bash makes awkward: parsing a JSON response body, hitting a gRPC/websocket endpoint, or matching the language/tooling the rest of the repo's scripts already use — don't reach for it out of habit when bash already covers the need. Either way it's a plain script, not a test-framework suite.

Two worked examples (bash and Python) are in `references/details.md`.

## 3. Safe Against Production

Smoke tests often run against real, live environments — sometimes production, right after a deploy — so every check must be safe to run there:

- **Read-only by default.** If a write path genuinely needs checking, use a dedicated synthetic/canary account whose data is expected and excluded from real metrics — never a real user's data or a real transaction.
- **Short timeouts, no retries that mask a real outage.** `--max-time 5` on every request — a smoke test hanging defeats "fast."
- **Fail loud, fail fast.** First failing check exits non-zero immediately (`set -e`) — don't run every check and summarize at the end; the point is the fastest possible "something's wrong" signal, not a report.

## 4. Run It, Don't Wire It

This is a script you or an agent runs by hand when you want to know something's working — `./scripts/test-user-create.sh <url>` (or `python3 scripts/test-get-user-session.py <url>`) after a deploy, after a local `docker compose up`, before diving into a bug report that might just be an outage. Report the result plainly (which checks passed/failed) rather than assuming success. Don't add it to a GitHub Actions workflow or any other automated pipeline as part of this skill — if the project later wants an automated deploy gate, that's a deliberate separate decision, not something this skill does by default.

## 5. Verify Before Handing Back

Run the script against a known-good environment (must pass) and confirm each check actually fails when its target is broken (stop the service, hit a wrong port, or point at a nonexistent path) — a check that can't fail isn't checking anything.
