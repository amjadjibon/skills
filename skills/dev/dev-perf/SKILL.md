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
- `full` — one commit per bottleneck fixed, same branch.
- `ultra` — independent candidates benchmarked in parallel worktrees; merge only those clearing the bar.

## 1. Define the Target

Agree what "fast enough" means: current behaviour, target ("under 200ms"), workload. No target given → ask.

## 2. Measure Baseline

```bash
go test -bench=. -benchmem ./...                     # Go
npx clinic flame -- node server.js                   # Node/TS
pytest --benchmark-only                              # Python
hey -n 10000 -c 100 http://localhost:3000/endpoint   # HTTP, any stack
```

Record **p50/p95/p99** or **ops/sec** + **memory** — an average hides tail latency.

## 3. Profile

Never optimize on intuition:

```bash
go test -bench=BenchmarkFoo -cpuprofile=cpu.prof && go tool pprof -http=:8080 cpu.prof  # Go
py-spy record -o flame.svg -- python script.py       # Python
perf record -F 99 -g -- <command>                    # Linux, any language
```

State it before coding: "Bottleneck: `<function>`, 73% of CPU. Cause: N+1 query in loop." Trust the profile.

## 4. Optimize One Thing at a Time

Fix the top bottleneck only; re-measure before the next — earlier fixes often eliminate later ones.

| Bottleneck | Fix |
|------------|-----|
| N+1 queries | Batch with `IN (...)` or join; index the join column |
| Missing index | `EXPLAIN`; index the `WHERE`/`JOIN`/`ORDER BY` column |
| Repeated computation in loop | Hoist or memoize |
| Hot-path allocations | Reuse buffers; pool |
| Per-request serialization | Cache serialized form; faster codec |
| Blocking I/O in async context | Async I/O or worker thread |
| Fetching unused data | Select needed columns; paginate |

Touch only the hot path; keep before/after obvious in the diff; tests still pass. `full`: re-measure + commit per bottleneck, repeat §3–§6. `lite`: iterate internally, one commit at the end.

## 5. Measure Again

Same benchmark as §2. `Before: p50 450ms p99 2100ms 12MB → After: p50 38ms p99 120ms 9MB (-92%/-94%)`. Improvement <10% → revert, look elsewhere.

## 6. Commit

Commit hygiene and message style: see the `git-safe` skill (no `Co-authored-by:`, `git add -u` not `-A`, imperative why-focused subject).

`git add -u && git commit -m "perf: <what changed> — p99 2100ms → 120ms"` — numbers in every perf commit.

## 7. Report

Target, bottleneck (from profiler), fix, before/after/delta, tests status, remaining ("next bottleneck" or "target achieved"). If the target is unreachable without structural change (caching layer, different algorithm), say so plainly.
