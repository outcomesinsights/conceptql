---
id: conceptql-5yq
title: 'Concept lists: re-measure the shipped 1,000 threshold and explain the 30x Postgres result at 2 items'
status: captured
type: exploration
created_at: 2026-10-31T16:20:01.009924+00:00
updated_at: 2026-11-01T04:04:12.997933+00:00
---

## Question

Was the shipped concept-list threshold (1,000 items) ever measured, and why did lists of 2 or more items make production algorithm ac4efe58 about 30 times faster on Postgres?

## What is true (2026-10-31)

The perf-report agent that wrote docs/perf/concept-lists-merged-ctes-2026-10-30.md re-read bead conceptql-6cz's logs (claude_stuff/worktrees/conceptql-6cz/ in the primary checkout on titan) and found:

- The final before/after run measured a threshold of 100 items, not the 1,000 that shipped (`CONCEPT_LIST_MIN_ITEMS`): its SQL sizes match the 100 arm of the threshold sweep exactly.
- The commit's "Postgres planning 485 ms to 156 ms" takes its two numbers from two different runs.
- "No statement slower" was measured on only 3 statements at 1,000.
- An exploratory Postgres run with lists of 2 or more items ran ac4efe58 in about 99 ms against 3,190 ms. Nobody looked into the cause, and the 1,000 threshold does not keep that gain.

The CHANGELOG [Unreleased] entry for the concept lists cites these numbers.

## Ryan, 2026-10-31

Chose "Concept-list re-measure" from a list: re-measure the shipped 1,000 threshold on Postgres and DuckDB, and find out why lists of 2 or more items ran 30x faster on Postgres.

## Plan (not ruled beyond the measurement)

1. Re-measure at the shipped threshold on current main: planning and execution, plain query and annotate, Postgres and DuckDB, ac4efe58 plus the statements of the 6cz sweep. Hold titan-lock; record the window and the below load. Run only when no test suites are running.
2. Explain the 2-item result: EXPLAIN (ANALYZE) on Postgres at threshold 2 against 1,000, to find which plan change made the difference (join order, a hash semi join over the VALUES CTE, or estimates).
3. Correct the CHANGELOG numbers and the perf report with the measured values.
4. If a lower threshold (or another rule) is faster everywhere and keeps rows identical, propose it for a ruling. Do not change the threshold without one.

RESULT 2026-10-31 (re-measure, docs/perf/concept-list-threshold-2026-10-31.md, commit 70963ed6, merged 409ebae0; titan-lock held for all 110 iterations; machine CPU median 21%, max 47% inside iterations; no disturbance):

- At the shipped 1,000, Postgres planning of ac4efe58 fell 428 -> 149 ms (base e2e11ed5 vs 1,000: 480 -> 152 ms; CHANGELOG corrected), but execution with JIT on rose 2,095 -> 2,392 ms, so plain-query latency on the Postgres test data did not change. DuckDB fixture planning fell 1,810 -> 785 ms. On the SEER sample, 100 and 1,000 give identical SQL. Rows identical in every variant.
- The 30x result at 2 items was Postgres JIT, not a better plan: at 1,000 the plan's cost estimate (123,177) passes jit_above_cost (100,000) and JIT compiles 1,639 functions (2,324 ms); at 2 the estimate is 87,219, so no JIT. With JIT off every threshold runs ac4efe58 in 51-84 ms. The effect also runs the other way: at 2 the hospice statement's estimate rises to 142k and JIT makes it 2.5 -> 466 ms.
- Threshold sweep: no threshold beats 1,000 everywhere (100/10 slow the hospice count 2.5x on Postgres even with JIT off; lower thresholds plan slower on DuckDB).

PROPOSAL (not ruled): keep 1,000. Find out whether production Postgres runs with JIT on; if so, measure a production-size algorithm with JIT on and off before considering SET jit = off for conceptql or Jigsaw connections. Left open: the scope.rb comment on CONCEPT_LIST_MIN_ITEMS still cites 485/156 ms.
