---
name: dev-perf
description: Profile, optimize, and benchmark code performance — measure baseline first, find the real bottleneck, optimize one thing at a time, confirm improvement with numbers. Use when the user says "it's slow", "optimize this", "improve performance", "reduce latency", "profile this", "it's taking too long", or shares timing/benchmark output.
argument-hint: "[lite|full|ultra]"
---

# Perf

Measure → profile → optimize → verify. Never optimize without a measured baseline.

## Delivery Mode (`lite | full | ultra`, default `lite`)

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

- `lite` (default) — one commit covering every optimization.
- `full` — §4/§6 as written: one commit per bottleneck fixed, same branch.
- `ultra` — independent optimization candidates get their own worktree/branch, benchmarked in parallel; merge only the ones that clear the improvement bar.

## 1. Define the Target

Before measuring, agree on what "fast enough" means: current observed behavior, target (e.g. "under 200ms"), and workload. If the user hasn't specified a target, ask — optimizing without a goal produces unmeasurable progress.

## 2. Measure Baseline

Run a reproducible benchmark before touching code. Record exact numbers.

```bash
go test -bench=. -benchmem ./...                                    # Go
npx clinic flame -- node server.js                                  # Node/TS
pytest --benchmark-only                                             # Python
hey -n 10000 -c 100 http://localhost:3000/endpoint                  # HTTP, any stack
```

Record: **p50, p95, p99 latency** or **ops/sec** and **memory**. A single average hides tail latency.

## 3. Profile — Find the Real Bottleneck

Do not optimize based on intuition. Profile first.

```bash
go test -bench=BenchmarkFoo -cpuprofile=cpu.prof && go tool pprof -http=:8080 cpu.prof  # Go
npx clinic flame -- node server.js                                                     # Node
py-spy record -o flame.svg -- python script.py && open flame.svg                       # Python
perf record -F 99 -g -- <command>                                                      # Linux, any language
```

State the bottleneck explicitly before writing any code:
> "Bottleneck: `<function>` accounts for 73% of CPU time. Cause: N+1 query inside the loop."

Trust the profile over intuition.

## 4. Optimize One Thing at a Time

Fix the top bottleneck only. Re-measure before moving to the next — earlier fixes often eliminate later ones.

| Bottleneck | Fix |
|------------|-----|
| N+1 queries | Batch with `IN (...)` or join; index the join column |
| Missing index | `EXPLAIN` the query; add index on `WHERE`/`JOIN`/`ORDER BY` column |
| Repeated computation in loop | Hoist invariant out or memoize |
| Unnecessary allocations in hot path | Reuse buffers; pool objects |
| Serialization on every request | Cache serialised form; use a faster codec |
| Blocking I/O in async context | Move to async I/O or worker thread |
| Fetching unused data | `SELECT` only needed columns; paginate |

Rules: touch only the hot path; keep the change small enough that before/after is obvious in the diff; tests must still pass.

`full` mode: re-measure and commit (§5/§6) after each bottleneck, then repeat §3–§6 for the next one. `lite` mode (default): repeat §3–§5 for each bottleneck internally, but hold the commit until every bottleneck is fixed — §6 becomes one commit at the end.

## 5. Measure Again

Re-run the exact same benchmark from §2:

```
Before: p50 450ms  p99 2100ms  12 MB
After:  p50  38ms  p99  120ms   9 MB
Delta:  -92% p50   -94% p99
```

If improvement is below 10%, revert and look elsewhere.

## 6. Commit

Commit hygiene: `git add -u` for tracked files, explicit paths for new files, never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused.

```bash
git add -u && git commit -m "perf: <what changed> — p99 2100ms → 120ms"
```

`lite`: one commit listing every optimization and its combined before/after numbers. `full`: one commit per bottleneck, each with its own before/after numbers.

## 7. Report

```
Target: <what was optimized>
Bottleneck: <root cause from profiler>
Fix: <what changed>
Before: <baseline>
After:  <new numbers>
Delta:  <% improvement>
Tests:  passing
Remaining: <next bottleneck | "target achieved">
```

If the target isn't met and no further gains are possible without a structural change (caching layer, different algorithm), say so clearly.
