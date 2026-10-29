---
id: conceptql-ktc
title: Send each concept-ID list once and merge identical CTEs (planning is 0.8 s of a 1.1 s query)
status: captured
type: idea
created_at: 2026-10-29T20:43:43.871479+00:00
updated_at: 2026-10-29T20:43:43.871479+00:00
tags:
  - algorithm-survey
  - performance
---

## Measurement

On ac4efe58 warriner_8_women_6579_index_date_dr (Draft, 111 operators), DuckDB spends most of the root query's time on planning, not on execution:

```
plain profile: latency 1.087s planning 0.785s (bind 0.247 optimize 0.524 join_order 0.280) exec 0.302s plan_nodes 1333
q0 1.129s   238272 bytes  IN-lists 99  CTEs 264
q1 0.758s   214531 bytes  IN-lists 89  CTEs 239
```

The root query has 264 CTEs and 99 `IN (...)` lists of concept IDs in 238 KB of SQL. The survey also reported that one_in_two_out puts about 2,600 provenance concept IDs into its SQL four times. That last number comes from the survey report and was not re-checked here.

## Ideas (not ruled)

- (a) Send each concept-ID list to the database once: as one `VALUES` list that the CTEs join, or as a temp table. Today each CTE that uses a list carries its own `IN (...)` copy.
- (b) Merge identical CTEs. `recall` and repeated sub-expressions can produce CTEs with the same SQL under different names.

## Hazards

- A temp table adds a step before the query runs, and Spark and DuckDB handle temp tables differently from Postgres.
- A join can plan differently from an `IN` list. Measure on Postgres, DuckDB and Spark before choosing.

## Source

Source: the Jigsaw diagram editor's survey of all current production algorithms, run 2026-10-29 (JDE seed jde-c0y.1 plans per-operator counts and asked for this seed). The survey ran today's `annotate` with counts and the plain query on each of the 1,259 current algorithms (`child_id IS NULL AND deleted_at IS NULL`). Data: the SEER-Medicare sample native_sample_5000 (DuckDB, gdm_wide, 5,000 patients, 7.8M observation rows). Software: DuckDB 1.5.6, conceptql 0.4.1, threads=8, on titan. Ryan ruled on 2026-10-29: "yes, file them as seeds and we'll investigate the best way to proceed".

Survey totals:

```
statements: 1259; plain ok 1253; annotate ok 1256
annotate_s: median 0.058  p90 0.234  p99 1.005  max 57.934  sum 200.7
plain_s:    median 0.037  p90 0.123  p99 0.520  max 2.293  sum 84.4
```
