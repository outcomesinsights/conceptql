---
id: conceptql-5yq
title: 'Concept lists: re-measure the shipped 1,000 threshold and explain the 30x Postgres result at 2 items'
status: captured
type: exploration
created_at: 2026-10-31T16:20:01.009924+00:00
updated_at: 2026-10-31T16:20:01.009924+00:00
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
