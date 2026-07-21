---
name: dev-release
description: Cut a release — derive the version bump from conventional commits since the last tag, generate a changelog, bump version files, tag, and publish a GitHub release. Use when the user says "release", "cut a release", "ship it", "tag a version", "bump the version", "publish a release", "generate a changelog", or after merged PRs need to go out.
argument-hint: "[lite|full|ultra]"
---

# Release

Turn merged work into a versioned, tagged, published release. Audit first — never tag or push without showing the user what's about to ship.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — tag + GitHub release with notes generated from commits. No file changes.
- `full` — also update `CHANGELOG.md` and bump version files, committed before tagging.
- `ultra` — `full`, but publish as a pre-release (`vX.Y.Z-rc.1`) first; promote to final on user confirmation.

## 1. Pre-flight

All must hold before anything else:

```bash
git branch --show-current          # must be main/master (or ask)
git status --porcelain             # must be clean
git fetch origin && git status -sb # must not be behind origin
gh run list --branch main --limit 1 --json conclusion   # latest CI must be success (skip if no CI)
```

Any failure → stop and report. Releasing a red or stale main ships broken code with a version number on it.

## 2. Detect Existing Release Automation

Before doing anything by hand, find out what the repo already automates:

```bash
ls .github/workflows/ 2>/dev/null
grep -rlE "tags:|goreleaser|semantic-release|release-please|changesets|npm publish|cargo publish|gh release" .github/workflows/ 2>/dev/null
ls .goreleaser.yml .goreleaser.yaml .releaserc* release-please-config.json .changeset 2>/dev/null
```

Adapt to what exists — duplicating automation produces double releases or conflicting tags:

- **Release-manager tool** (`release-please`, `semantic-release`, `changesets`) — it owns versioning and changelogs. **Do not hand-tag.** Follow its flow instead: merge its release PR, or run its command (`npx changeset version`, etc.), then verify the release appeared.
- **Tag-triggered workflow** (`on: push: tags`, goreleaser, publish steps) — the tag is the trigger. Push the tag but **skip `gh release create`** (CI does it); watch with `gh run watch` and report the workflow's release/artifacts.
- **Release-triggered workflow** (`on: release`) — `gh release create` is the trigger; proceed as written below, then watch the run.
- **Nothing found** — proceed manually as written below.

Read the matched workflow before deciding — a workflow that only runs tests on tags changes nothing.

## 3. Derive the Version

```bash
git describe --tags --abbrev=0 2>/dev/null   # last tag; none → this is v0.1.0, skip bump logic
git log <last-tag>..HEAD --oneline           # commits going into this release
```

Bump from conventional commit types since the last tag: any `!` suffix or `BREAKING CHANGE` → **major** · any `feat:` → **minor** · else (`fix:`, `perf:`, `refactor:`, …) → **patch**. Pre-1.0: breaking → minor, everything else → patch. No releasable commits (only `docs:`/`chore:`) → say so and stop; don't tag noise.

If the user named a version, use it — but flag if it disagrees with the derived bump.

## 4. Changelog

Group the `<last-tag>..HEAD` subjects: **Breaking** / **Features** (`feat:`) / **Fixes** (`fix:`) / **Performance** (`perf:`) — drop `chore:`/`docs:`/`ci:` noise and merge commits. One line per change, PR/issue refs kept (`#42`).

`full`/`ultra`: prepend to `CHANGELOG.md` under `## vX.Y.Z — YYYY-MM-DD` (create the file if missing, [Keep a Changelog](https://keepachangelog.com) shape).

## 5. Bump Version Files (`full`/`ultra` only)

Detect and update whichever exist: `package.json` (`npm version --no-git-tag-version X.Y.Z`), `Cargo.toml`, `pyproject.toml`, `VERSION`. None found → skip, note it.

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

```bash
git add CHANGELOG.md <version files> && git commit -m "chore: release vX.Y.Z"
```

## 6. Confirm, Tag, Publish

**Pause for approval** — show version, bump reasoning, and the changelog; tags and releases are public and painful to retract. On approval:

```bash
git push origin main                          # full/ultra: the release commit
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --notes "<changelog section>"   # lite: --generate-notes is fine
```

Per §2: skip `gh release create` when a tag-triggered workflow publishes the release; skip tagging entirely when a release-manager tool owns it. After publishing, if any workflow fired: `gh run watch` — a release whose pipeline failed isn't released.

`ultra`: tag `vX.Y.Z-rc.1` and `gh release create --prerelease` instead; on user confirmation ("promote"), repeat with the final tag and mark the release latest.

No remote / no `gh` → create the local tag, print the changelog, tell the user what to push.

## 7. Report

Version (and previous) · bump reason (the commit types that drove it) · commit count · release URL · automation found and how it was used (or "none — manual release") · CI run result · anything skipped (no version files, no CI). If pre-release: how to promote.
