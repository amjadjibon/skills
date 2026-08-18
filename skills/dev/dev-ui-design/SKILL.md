---
name: dev-ui-design
description: Build a clickable UI prototype as one self-contained HTML file (inline CSS, no build step, no framework) at .spec/<feature-name>/prototype.html, opened straight in a browser. Trigger on "prototype this UI", "mock up this screen", "show me what this would look like", or wanting to click through a layout first.
argument-hint: "[lite|full|ultra]"
---

# UI Prototype

A prototype answers "does this layout/flow feel right?" faster than real components can — no build step, no routing, no state library, just one HTML file someone opens in a browser and clicks through. If `dev-design` already wrote a UI/UX axis in `.spec/<feature-name>/DESIGN.md`, this skill turns that text wireframe into something clickable; if not, it starts fresh from the request.

**Throwaway by design.** Nothing here becomes production code — inline styles, no components, no build tooling, copy-pasted markup over reusable abstractions. The moment it's approved, real implementation starts from scratch using the project's actual stack; the prototype's job is to be looked at and clicked, not maintained.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` — one screen or one flow, one state each (happy path).
- `full` — the flow's key states too (empty, loading, error, filled) as separate views the user can jump between (anchor links or a simple tab toggle — still no framework).
- `ultra` — light and dark variants, plus a couple of viewport breakpoints (mobile/desktop) demoed via CSS `@media`, not separate files.

## Artifact Location

Artifact paths below use `.spec/` as the default root. Only a custom root explicitly named by the
user overrides it; replace the `.spec/` prefix in every path and command below with that root.
`dev-loop` passes the resolved root to the skills it invokes. Never discover, migrate, or fall back to
legacy `docs/` artifacts. A gitignored or out-of-repo custom root means the artifacts are scratch —
write and read them as normal, but **never commit them**. Application code must never reference,
import, or link to `.spec/` artifacts — they are workflow scratch, not part of the product, and may
be gitignored or deleted by the time anyone else reads the code.

## 1. Ground It in the Real Product

A prototype that looks like nothing else in the app is a worse prototype, not a bolder one.

```bash
ls .spec/<feature-name>/DESIGN.md 2>/dev/null
grep -rln "<related component/screen name>" --include="*.css" --include="*.tsx" --include="*.html" | head
```

Read the `## UI / UX` section of `DESIGN.md` if it exists. Skim 2-3 existing screens/components for the real product's spacing scale, type scale, color palette, and component conventions (buttons, cards, form fields) — match them loosely so the prototype reads as "this app" rather than a generic template. Don't chase pixel-perfect fidelity; that's what real implementation is for.

## 2. Build One File

Everything inline — `<style>` in `<head>`, no external stylesheet, no CDN script tags, no JS framework. A few lines of vanilla `<script>` are fine for tab-toggling between states; nothing that needs `npm install` or a bundler.

- Use real-looking placeholder content (names, numbers, dates), not "Lorem ipsum" or "Item 1" — fake data that could pass for real makes the layout easier to judge.
- Use semantic HTML (`<button>`, `<nav>`, `<label>`) so it's actually clickable/keyboard-navigable, not just `<div>` soup.
- Match the codebase's existing color/spacing values where you found them in §1; invent reasonable ones only where nothing exists to match.
- Responsive basics (relative units, `max-width`, flex/grid) so it doesn't visibly break at normal window sizes — skip exhaustive breakpoint tuning unless `ultra`.

## 3. Self-Review Before Handing Off

Open the mental checklist, not the file: does every interactive element look clickable, do the states requested in Delivery Mode all exist, does it visually belong next to the app's real screens. Fix what's off before reporting done — the point is to save the user a round trip, not create one.

## 4. Save and Report

Save to `.spec/<feature-name>/prototype.html`. Report the file path and how to view it (`open .spec/<feature-name>/prototype.html` or equivalent for the user's OS), which states/variants it covers, and one line on what it was matched against in §1.

## 5. Commit

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

`git add .spec/<feature-name>/prototype.html && git commit -m "prototype: <feature-name> UI"`. No push, no PR — the prototype travels with the feature branch, same as research and design.
