---
id: conceptql-x9w
title: Should one production-shaped one_in_two_out statement be timed on Spark with AQE on before deciding on the single-read rewrite (RANGE frames, possible month-end output changes)?
status: resolved
type: question
created_at: 2026-10-14T19:22:29.443544+00:00
updated_at: 2026-10-15T02:56:36.810969+00:00
resolved_at: 2026-10-14T21:23:19.941116+00:00
relationships:
  - target_id: conceptql-8u6
    rel_type: questions
    created_at: 2026-10-14T19:22:29.445380+00:00
---

RULED (Ryan, 2026-10-14): "yes, before we rewrite a bunch of code, test if its worth it." Measure on Spark first. No rewrite until the measurement shows a saving worth the output risk.

## Measured 2026-10-14: a single read is worth it

Setup:

- Spark 3.5.0 local[16], AQE on.
- Real SEER lung observations (53 GB), both flat and partitioned by clinical_code_vocabulary_id.
- Window tables of 5k and 50k persons.
- Three production one_in_two_out statements, chosen from diagnostics_v3: 65334 (SEER lung median), 65482 (SEER lung slowest) and 73578 (marketscan median, run against the SEER data). Each statement reads its upstream (an ICD9CM plus ICD10CM union joined to the window) through three identical CTEs.

What was timed:

- A: the statement as is.
- C: one read of the upstream, materialized.
- B: C plus the rest of the statement, reading the materialized table. B bounds any single-read rewrite from above.

Medians of 3 runs, in seconds:

```
statement obs  win   A     B     C     A-B
73578     part 5k    25.6  9.1   7.6   16.5 (64%)
65334     part 5k    24.9  11.0  9.1   13.9 (56%)
65482     part 5k    30.0  12.4  10.1  17.6 (59%)
73578     part 50k   28.0  11.4  9.6   16.6 (59%)
65334     part 50k   33.6  14.2  11.6  19.4 (58%)
65482     part 50k   43.9  18.5  12.6  25.4 (58%)
73578     flat 5k    82.7  28.8  25.5  53.9 (65%)
65482     flat 5k    92.8  33.0  30.2  59.7 (64%)
```

Results:

- A is about 3C in every case, so the self-join, window and union cost little. The three reads are the cost.
- A and B returned identical rows in all 8 configurations: equal counts, and EXCEPT ALL of 0 both ways.
- AQE did not remove the repeated reads.

Caveats:

- Spark 3.5.0, not production's 3.3.2.
- One node, with absolute times about 10 times production's, so only the ratios transfer.
- Warm OS page cache.
- B writes the upstream to Parquet. A real rewrite avoids that write but adds RANGE frames.

Rough scale: 2025+ one_in_two_out statements total about 4.4 h over about 102 exports. A 60% cut is about 2.6 h, about 1.5 min per export.

Verdict: the rewrite is worth doing, but only if output stays identical. The test that matters is gaps given in months at month ends ("Confirming Event" side). Logs: session scratchpad spark-oito/logs (temporary).

## UPDATE 2026-10-14: built (bead conceptql-7qo, commit d9371d12)

- The rewrite needs no RANGE frames. A CROSS JOIN with a four-row tag table copies each event (lower bound, event, upper bound, inpatient). Running window sums over the copies, ordered by date and then tag, replace the EXISTS self-join. Bounds come from DateAdjuster as before, so the month-end question does not arise: each bound is computed forward from the initial event, exactly as the old SQL computed it.
- Differential check of old against new SQL: 746 cases on Postgres and 746 on DuckDB, identical valid-event sets and final outputs. Local Spark 3.5: 80 cases with identical valid-event sets. Final outputs differed only for persons whose first valid event had two output rows with the same start_date and criterion_id, so the start_date-then-criterion_id tie breaker could not separate them. The synthetic Spark data caused this: it copied each source row up to nine times with the same id, and it let one row count as both inpatient and outpatient. In GDM data the id is unique and a row has one file provenance type, so these ties cannot occur. The Postgres and DuckDB checks used the real fixture, and their final outputs were identical.
- Found on the way: DuckDB merges date + 30 days and date + 1 month in one SELECT list (bead conceptql-a4j). The operator computes the upper bound in its own SELECT level to avoid it.
- Not measured yet: the production-scale Spark time of the new SQL. The 56-65% figure above bounds it from above.
