---
name: prototype
description: Build a throwaway prototype in the real codebase to answer one design question before production code — does this state model hold up, what should this screen look like. Trigger on "prototype this", "spike this", "quick prototype", "throwaway version", "let me try a few variants first". Not `dev-ui-design` (a standalone HTML mockup) or `dev-research` (verifying an approach).
---

# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

## First, name the question

Write the question down in one sentence before writing any code. If you can't — or if the honest answer is "we already know, we just haven't typed it yet" — this isn't a prototype task. Building one anyway produces code with no verdict attached, which is the expensive kind of waste: it looks like progress and settles nothing.

Skip straight past this skill when:

- **The answer is already known** and the work is just writing it properly → build the real thing.
- **The question is "which library / API / approach should we use"** and it's answered by reading docs and running a small spike → `dev-research`.
- **The question is "what should this look like" but there's no app to host it** — no route, no running frontend, and the point is a shareable static mockup → `dev-ui-design`, which writes one self-contained `.spec/<feature>/prototype.html`.

## Pick a branch

With the question written down, it — not the file type — picks the branch:

- **"Does this logic / state model feel right?"** → [LOGIC.md](LOGIC.md). Build a tiny interactive terminal app that pushes the state machine through cases that are hard to reason about on paper.
- **"What should this look like?"** → [UI.md](UI.md). Generate several radically different UI variations on a single route, switchable via a URL search param and a floating bottom bar.

The two branches produce very different artifacts — getting this wrong wastes the whole prototype. A question about *what happens* is logic even when it lives in a component; a question about *what the user sees* is UI even when the hard part is on the server.

If it's genuinely ambiguous and the user isn't reachable, default to whichever branch better matches the surrounding code (a backend module → logic; a page or component → UI) and state the assumption at the top of the prototype so the first reader can correct it cheaply.

## Rules that apply to both

1. **Throwaway from day one, and clearly marked as such.** Locate the prototype code close to where it will actually be used (next to the module or page it's prototyping for) so context is obvious — but name it so a casual reader can see it's a prototype, not production. For throwaway UI routes, obey whatever routing convention the project already uses; don't invent a new top-level structure.
2. **One command to run.** Whatever the project's existing task runner supports — `pnpm <name>`, `python <path>`, `go run <path>`, etc. The user must be able to start it without thinking.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is _checking_, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE — wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype _runnable_, no abstractions. The point is to learn something fast.
5. **Surface the state.** After every action (logic) or on every variant switch (UI), print or render the full relevant state so the user can see what changed.
6. **Capture it when done.** A prototype that ends without a written verdict was a spike the team will re-run in six months. Two separate things get captured:
   - **The answer** — the question and what it settled, in one short paragraph. It belongs wherever the follow-up work is tracked (the issue, the PR description, or the commit that folds the decision in). If a `.spec/<feature-name>/` directory already exists for this work, that's the natural home.
   - **The prototype** — as a **primary source**, on a throwaway branch out of main (`prototype/<question-slug>`), with a pointer to it next to the answer. Main keeps the validated decision and none of the scaffolding; the switcher, the TUI shell, and the losing variants rot fast and confuse the next reader.

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).
