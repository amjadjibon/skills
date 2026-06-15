---
name: perf
description: Profile, optimize, and benchmark code performance — measure baseline first, find the real bottleneck, optimize one thing at a time, confirm improvement with numbers. Use when the user says "it's slow", "optimize this", "improve performance", "reduce latency", "profile this", "it's taking too long", or shares timing/benchmark output.
---

# Perf

Measure → profile → optimize → verify. Never optimize without a measured baseline.

## 1. Define the Target

Before any measurement, agree on what "fast enough" means:
- What is the current observed behavior? (e.g. "endpoint takes 2s")
- What is the target? (e.g. "under 200ms")
- What is the workload? (e.g. "1000 concurrent users", "10MB file", "1M rows")

If the user hasn't specified a target, ask for one. Optimizing without a goal produces unmeasurable progress.

## 2. Measure Baseline

Run a reproducible benchmark before touching any code. Record exact numbers.

```bash
# Examples — use whatever fits the stack:
# Go
go test -bench=. -benchmem ./...

# Node/TS
npx clinic flame -- node server.js
autocannon -c 100 -d 10 http://localhost:3000/endpoint

# HTTP (any stack) — hey
hey -n 10000 -c 100 http://localhost:3000/endpoint

# HTTP (any stack) — wrk
wrk -t4 -c100 -d30s http://localhost:3000/endpoint

# Python
python -m cProfile -s cumtime script.py
pytest --benchmark-only

# Single request timing
curl -o /dev/null -s -w "%{time_total}\n" http://localhost:3000/endpoint
```

Record: **p50, p95, p99 latency** or **ops/sec** and **memory** if relevant. A single average hides tail latency.

## 3. Profile — Find the Real Bottleneck

Do not optimize based on intuition. Profile first.

```bash
# Go — interactive flame graph in browser
go test -bench=BenchmarkFoo -cpuprofile=cpu.prof
go tool pprof -http=:8080 cpu.prof

# Go — flame graph via Brendan Gregg's tool
go test -bench=BenchmarkFoo -cpuprofile=cpu.prof
go tool pprof -raw -output=cpu.txt cpu.prof
stackcollapse-go.pl cpu.txt | flamegraph.pl > flame.svg && open flame.svg

# Node — flame graph
npx clinic flame -- node server.js
# or
npx 0x -- node server.js

# Python — flame graph via py-spy
py-spy record -o flame.svg -- python script.py
open flame.svg

# Python — cProfile (text output)
python -m cProfile -s cumtime script.py | head -30

# Linux — system-wide (any language)
perf record -F 99 -g -- <command>
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg && open flame.svg
```

`flamegraph.pl` and `stackcollapse-*.pl` are from [Brendan Gregg's FlameGraph repo](https://github.com/brendangregg/FlameGraph). Install once: `git clone https://github.com/brendangregg/FlameGraph && export PATH=$PATH:$PWD/FlameGraph`.

Identify the top 1–3 hotspots by time. State them explicitly before writing any code:
> "Bottleneck: `<function>` accounts for 73% of CPU time. Cause: N+1 query inside the loop."

If the profile points somewhere unexpected, trust the profile over intuition.

## 4. Optimize One Thing at a Time

Fix the top bottleneck only. Re-measure before moving to the next one — earlier fixes often eliminate later ones.

Common patterns (apply only when the profile confirms the smell):

| Bottleneck | Fix |
| ---------- | --- |
| N+1 queries | Batch with `IN (...)` or join; add index on the join column |
| Missing index | `EXPLAIN` the query; add index on `WHERE`/`JOIN`/`ORDER BY` column |
| Repeated computation in loop | Hoist invariant outside the loop or memoize |
| Unnecessary allocations in hot path | Reuse buffers; pool objects |
| Serialisation on every request | Cache serialised form; use a faster codec |
| Blocking I/O in async context | Move to async I/O or a worker thread |
| Fetching unused data | `SELECT` only needed columns; paginate |

Rules:
- Touch only the hot path. Don't rewrite surrounding code.
- Keep the change small enough that the before/after is obvious in the diff.
- Tests must still pass after each change.

## 5. Measure Again

Re-run the exact same benchmark from §2. Compare against the baseline.

```
Before: p50 450ms  p99 2100ms  12 MB
After:  p50  38ms  p99  120ms   9 MB
Delta:  -92% p50   -94% p99
```

If the improvement is below 10%, the change is noise — revert and look elsewhere.

## 6. Commit

```bash
git add -u && git commit -m "perf: <what changed> — p99 2100ms → 120ms"
```

Include before/after numbers in the commit message. Future readers need to know if it was worth it.

## 7. Report

```
Target: <what was optimized>
Bottleneck: <root cause from profiler>
Fix: <what changed>
Before: <baseline numbers>
After:  <new numbers>
Delta:  <% improvement>
Tests:  passing
Remaining: <next bottleneck if target not yet met, or "target achieved">
```

If the target from §1 isn't met, go back to §3 with the next bottleneck. If no further gains are possible without a structural change (e.g. needs caching layer, different algorithm), say so clearly rather than grinding through micro-optimizations.
