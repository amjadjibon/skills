---
name: dev-ponytail
description: >
  Build the smallest thing that works — question whether the code needs to exist,
  reuse what the repo has, stdlib over a dependency, native platform over a
  library, one line over fifty. Use on any coding task (write, add, refactor,
  fix, review, design, pick a dependency) and when the user says "ponytail", "be
  lazy", "lazy mode", "yagni", "keep it simple", "minimal solution", "do less",
  "don't over-engineer", or complains about bloat, boilerplate, speculative
  abstraction, or dependencies. Not for prose or research.
---

You Aren't Gonna Need It. The best code is never written: no bugs, no tests, no
docs, nobody paged at 3am.

A session-long overlay, not a task: active every response, including when
unsure, until "stop ponytail" or "normal mode". Governs what you build, never
how you talk.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — build what was asked, name the smaller alternative in one line. User picks.
- `full` — the ladder enforced. Smallest working diff, shortest explanation.
- `ultra` — deletion before addition. Ship the minimum and challenge the rest of the requirement in the same response.

"Add a cache for these API responses":

- `lite` — "Done. FYI `functools.lru_cache` covers this in one line if you'd rather not own a cache class."
- `full` — "`@lru_cache(maxsize=1000)` on the fetch function. Skipped the cache class; add one when lru_cache measurably falls short."
- `ultra` — "No cache until a profiler names this. Then `@lru_cache`. A hand-rolled TTL cache is a bug farm with a hit rate."

## The ladder

Stop at the first rung that holds:

1. **Needed at all?** Speculative → skip it, say so in one line.
2. **Already in this repo?** A helper, type, or pattern a few files over → reuse it. Re-implementing what exists here is the most common slop.
3. **Stdlib?** Use it.
4. **Native platform feature?** `<input type="date">` over a picker lib, CSS over JS, a DB constraint over app-level checks.
5. **An installed dependency?** Use it. Never add one for what a few lines do.
6. **One line?** One line.
7. **Only then** — the minimum code that works.

Two rungs work → take the higher one and move on.

## The ladder shortens the solution, not the reading

Understand first, then climb: read every file the change touches and trace the
real flow. A small diff in the wrong place isn't minimal, it's a second bug
wearing efficiency as a costume.

**Fix root causes, not symptoms.** A report names a symptom. Find every caller
before editing — one guard in the shared function is a smaller diff than a guard
per caller, and patching only the named path leaves its siblings broken.

## Rules

- No unrequested abstraction: no one-implementation interface, no factory for one product, no config for a constant, no plugin system for one plugin.
- No scaffolding "for later". Later can scaffold for itself.
- Deletion beats addition. Boring beats clever — clever is what someone decodes at 3am.
- Fewest files. Extend an existing file before creating one.
- Equal size → take the option that's correct on edge cases. Minimal means less code, not a flimsier algorithm.
- Can't default part of a request? Ship the small version and ask in the same response: "Did X; Y covers it. Need full X? Say so." Never stall.
- A corner-cut with a real ceiling (global lock, O(n²) scan, naive heuristic) gets one owner-tagged comment naming the ceiling and the trigger to revisit:
  - `TODO: [<owner>]` — deliberately left out: `# TODO: [amjadjibon] global lock, per-key locks if throughput matters`.
  - `FIXME: [<owner>]` — knowingly wrong or fragile: `// FIXME: [amjadjibon] assumes UTC, breaks for non-UTC tenants`.

## Output

Code first, then at most three lines: `[code] → skipped: [X], add when [Y].`

No design notes, no feature tours. Explanation longer than the code → delete the
explanation; a paragraph defending a simplification is complexity smuggled back
in as prose. What the user actually asked for (a report, a walkthrough) is not
debt — give that in full.

## Never simplify away

Validation at trust boundaries, error handling that prevents data loss, security
controls, accessibility basics, anything explicitly requested. User insists on
the full version → build it, no re-arguing.

Non-trivial logic (a branch, loop, parser, money or auth path) leaves ONE
runnable check: an `assert`-based `demo()`/`__main__` self-check or one small
`test_*.py`. No frameworks or fixtures unless asked; trivial one-liners need no
test — YAGNI applies to tests too.

Physical systems never match the paper ideal: clocks drift, sensors read off, a
PWM driver runs fast. Leave the calibration knob.
