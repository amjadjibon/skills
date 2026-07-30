---
name: github-actions
description: Create/review GitHub Actions workflows — CI, release pipelines, reusable workflows, composite actions, matrix builds, caching, security hardening (least-privilege permissions, pinned SHAs). Trigger on "set up CI", "add a GitHub Actions workflow", or editing `.github/workflows/*.yml`.
---

# GitHub Actions Workflow Creator

Write workflows that run fast, fail clearly, and don't hold more privilege than the job needs.

## 1. Pick the Shape

| Need | Shape |
|---|---|
| Run tests/lint/build on every push and PR | Single CI workflow, one job per concern (test, lint, build) so failures are attributable at a glance |
| Publish a release, push an image, deploy | Separate workflow triggered on tag push or a manual `workflow_dispatch`, not bundled into the CI workflow |
| Same job logic needed across several workflows or repos | Reusable workflow (`workflow_call`) — not copy-pasted YAML |
| Same few steps needed across several jobs in one repo | Composite action (`.github/actions/<name>/action.yml`) |
| Test against multiple versions/OSes | `strategy.matrix` on one job, not duplicated jobs |

A full worked template for each shape is in `references/details.md` — read the section for the chosen shape before writing the workflow file.

## 2. Core Structure

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read      # default to read-only; widen per-job only where needed
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./run-tests.sh
```

- **`permissions` at the workflow level, narrowed further per-job when a job needs more** (e.g. `contents: write` only on the job that creates a release, not the whole workflow). The default `GITHUB_TOKEN` grant is broader than almost any job needs — an unpinned workflow with a compromised action gets that token's full scope.
- **Trigger on exactly what should run the workflow.** `pull_request` (not `pull_request_target`) for anything that checks out and runs PR code — `pull_request_target` runs with base-branch permissions and secrets against untrusted PR code, which is how repos get their secrets exfiltrated by a malicious PR. Only use `pull_request_target` when the job genuinely doesn't check out or execute PR code (e.g. commenting on the PR).
- **One job per independently-failing concern** (test, lint, typecheck, build) so a red X on the PR tells you what actually broke without opening logs.

## 3. Caching and Speed

Cache dependencies (`actions/cache`, or the built-in caching in `actions/setup-node`/`setup-go`/`setup-python` via `cache:`), keyed on the lockfile hash so a dependency change invalidates it automatically:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: npm
```

Don't hand-roll a cache key from scratch when the setup action already offers one — it gets the invalidation logic right (lockfile hash) so a stale cache doesn't silently serve old dependencies.

## 4. Security Hardening

- **Pin third-party actions to a full commit SHA**, not a mutable tag: `uses: some-org/some-action@a1b2c3d # v2.1.0` — a tag can be moved to point at malicious code after you've reviewed it; a SHA can't. First-party `actions/*` at a version tag is the common, accepted exception (still fine to pin to SHA if the repo's policy demands it).
- **Secrets never go into `run:` as an interpolated string in a way that lands in shell history or logs** — pass via `env:` and reference the env var inside the script, not `${{ secrets.X }}` inlined directly into a shell command, which can be exploited via script injection if the value contains shell metacharacters.
- **`GITHUB_TOKEN` permissions default to read-only** (set at the org or workflow level) and widen only the specific job that needs `contents: write`, `pull-requests: write`, etc.
- **Don't echo secrets, even for debugging** — masked in logs by GitHub only when the exact string is referenced through `secrets.*`; a transformed or partial value (base64'd, substringed) can leak past the masking.

## 5. Validate Before Handing It Back

```bash
actionlint .github/workflows/*.yml
```

`actionlint` catches invalid syntax, unknown context references (`${{ github.event.foo }}` typos), shellcheck issues inside `run:` blocks, and matrix misconfigurations — the equivalent of a compiler check for a workflow file that would otherwise only fail on push. Run it before presenting the workflow as done; a workflow that only reveals its syntax error on the next PR is a worse failure mode than a lint catching it now.

## 6. Output

Write to `.github/workflows/<name>.yml` (or `.github/actions/<name>/action.yml` for a composite action) using kebab-case filenames. Keep `name:` in the workflow matching what should show up in the GitHub Actions UI and PR checks — that's what a reviewer sees, not the filename.
