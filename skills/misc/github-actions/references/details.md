# GitHub Actions Templates

Worked examples per shape for `github-actions`. Adapt names/versions, don't paste unmodified.

## 1. CI Workflow (test/lint/build, matrix)

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm
      - run: npm ci
      - run: npm test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run lint

  build:
    runs-on: ubuntu-latest
    needs: [test, lint]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
```

`build` depends on `test`/`lint` via `needs:` so a broken build doesn't waste minutes if the code already failed lint — order jobs by how cheap/fast they are to fail first.

## 2. Release / Publish Workflow (separate from CI)

```yaml
name: Release
on:
  push:
    tags: ['v*']

permissions:
  contents: write   # only this workflow needs write, not CI

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - name: Publish to npm
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      - uses: softprops/action-gh-release@de2c0eb # v2.0.8
        with:
          generate_release_notes: true
```

Triggered on tag push, not on every merge to main — a release should be a deliberate act (tag creation), not a side effect of merging.

## 3. Reusable Workflow (`workflow_call`)

`.github/workflows/reusable-test.yml`:

```yaml
name: Reusable Test
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
    secrets:
      NPM_TOKEN:
        required: false

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: npm
      - run: npm ci
      - run: npm test
```

Caller:

```yaml
jobs:
  test:
    uses: ./.github/workflows/reusable-test.yml
    with:
      node-version: '22'
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

Use `workflow_call` (not a composite action) when the shared logic is a whole job with its own `runs-on`/strategy — composite actions can't set `runs-on` or matrix, they only compose steps within a job that already has one.

## 4. Composite Action (shared steps within a job)

`.github/actions/setup-project/action.yml`:

```yaml
name: Setup Project
description: Checkout, install Node, and install dependencies with caching
inputs:
  node-version:
    default: '20'
runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: npm
    - run: npm ci
      shell: bash
```

Caller:

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: ./.github/actions/setup-project
    with:
      node-version: '22'
  - run: npm test
```

Every `run:` step inside a composite action needs an explicit `shell:` — unlike a regular job step, it isn't inferred.

## 5. Matrix with Exclusions and OS

```yaml
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    go-version: ['1.22', '1.23']
    exclude:
      - os: windows-latest
        go-version: '1.22'
runs-on: ${{ matrix.os }}
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-go@v5
    with:
      go-version: ${{ matrix.go-version }}
      cache: true
  - run: go test ./...
```

`fail-fast: false` so one OS/version combination failing doesn't cancel the others mid-run — worth it whenever you want the full matrix result, not just the first failure.

## 6. Security-Hardened Job (least privilege, pinned actions)

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write   # for OIDC cloud auth, nothing broader
    steps:
      - uses: actions/checkout@v4
      - name: Authenticate to cloud via OIDC
        uses: aws-actions/configure-aws-credentials@e3dd6a4 # v4.0.2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy-role
          aws-region: us-east-1
      - run: ./deploy.sh
```

`id-token: write` + OIDC role assumption instead of a long-lived `AWS_ACCESS_KEY_ID` secret — no static cloud credential sitting in repo secrets waiting to leak.

## 7. Validating

```bash
# Install: brew install actionlint  /  go install github.com/rhysd/actionlint/cmd/actionlint@latest
actionlint .github/workflows/*.yml

# Also lints shell inside `run:` blocks if shellcheck is installed
actionlint -shellcheck= .github/workflows/*.yml
```
