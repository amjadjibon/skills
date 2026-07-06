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

## 2. Derive the Version

```bash
git describe --tags --abbrev=0 2>/dev/null   # last tag; none → this is v0.1.0, skip bump logic
git log <last-tag>..HEAD --oneline           # commits going into this release
```

Bump from conventional commit types since the last tag: any `!` suffix or `BREAKING CHANGE` → **major** · any `feat:` → **minor** · else (`fix:`, `perf:`, `refactor:`, …) → **patch**. Pre-1.0: breaking → minor, everything else → patch. No releasable commits (only `docs:`/`chore:`) → say so and stop; don't tag noise.

If the user named a version, use it — but flag if it disagrees with the derived bump.

## 3. Changelog

Group the `<last-tag>..HEAD` subjects: **Breaking** / **Features** (`feat:`) / **Fixes** (`fix:`) / **Performance** (`perf:`) — drop `chore:`/`docs:`/`ci:` noise and merge commits. One line per change, PR/issue refs kept (`#42`).

`full`/`ultra`: prepend to `CHANGELOG.md` under `## vX.Y.Z — YYYY-MM-DD` (create the file if missing, [Keep a Changelog](https://keepachangelog.com) shape).

## 4. Bump Version Files (`full`/`ultra` only)

Detect and update whichever exist: `package.json` (`npm version --no-git-tag-version X.Y.Z`), `Cargo.toml`, `pyproject.toml`, `VERSION`. None found → skip, note it.

Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.

```bash
git add CHANGELOG.md <version files> && git commit -m "chore: release vX.Y.Z"
```

## 5. Confirm, Tag, Publish

**Pause for approval** — show version, bump reasoning, and the changelog; tags and releases are public and painful to retract. On approval:

```bash
git push origin main                          # full/ultra: the release commit
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --notes "<changelog section>"   # lite: --generate-notes is fine
```

`ultra`: tag `vX.Y.Z-rc.1` and `gh release create --prerelease` instead; on user confirmation ("promote"), repeat with the final tag and mark the release latest.

No remote / no `gh` → create the local tag, print the changelog, tell the user what to push.

## 6. Report

Version (and previous) · bump reason (the commit types that drove it) · commit count · release URL · anything skipped (no version files, no CI). If pre-release: how to promote.
