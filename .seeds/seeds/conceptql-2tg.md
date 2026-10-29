---
id: conceptql-2tg
title: 'Grouped occurrence over a labeled stream fails: select_remove queries a CTE that does not exist yet'
status: captured
type: question
created_at: 2026-10-29T20:43:40.603164+00:00
updated_at: 2026-10-29T20:43:40.603164+00:00
tags:
  - algorithm-survey
  - bug
  - duckdb
---

## What fails

2 Draft algorithms fail in both the plain query and `annotate` on DuckDB:

- 58a1f715 statin_second_occurrence: `["occurrence", 2, ["gemscript", ..., {"label": "All statins"}], {"group_by_date": true, "within": "365d", "at_least": "14d", ...}]`
- 5a2d70f4 second_to_last_statin_before_another_statin: `["occurrence", -2, ["gemscript", ..., {"label": "All statins"}], {"group_by_date": true}]`, with a later `["recall", "All statins"]`

```
DuckDB::Error: Catalog Error: Table with name All_statins_977415_3_005727bc5a40123c817705e9cc9369ef does not exist!
lib/conceptql/operators/occurrence.rb:76:in 'ConceptQL::Operators::Occurrence#query'
lib/conceptql/operators/operator.rb:215:in 'ConceptQL::Operators::Operator#evaluate'
lib/conceptql/scope.rb:365:in 'block in ConceptQL::Scope#with_ctes'
```

## Cause (checked in the code 2026-10-29)

`group_by_date: true` takes the `grouped?` branch of `Occurrence#query`. Line 76 is:

```ruby
one_date_ds = ds.from_self.where(rn: 1).from_self.select_remove(:rn)
```

Sequel's `select_remove` needs the column list, so it runs a query against the database while the SQL is still being built. The upstream stream has a label, so it reads the label's CTE, and that CTE does not exist yet. Without `group_by_date`, or without a label, the code does not reach `select_remove`.

Not tested: Postgres and Spark. The same column query would read the same missing CTE there.

## Directions (not ruled)

- (a) Replace `select_remove(:rn)` with an explicit column list (the operator already knows its query columns), so no query runs during SQL building.
- (b) Search the other operators for `select_remove`, `columns` and other calls that query the database during SQL building, and fix them as one class of defect.
- (c) Add a test with a labeled upstream under `group_by_date`, on every adapter.

## Source

Source: the Jigsaw diagram editor's survey of all current production algorithms, run 2026-10-29 (JDE seed jde-c0y.1 plans per-operator counts and asked for this seed). The survey ran today's `annotate` with counts and the plain query on each of the 1,259 current algorithms (`child_id IS NULL AND deleted_at IS NULL`). Data: the SEER-Medicare sample native_sample_5000 (DuckDB, gdm_wide, 5,000 patients, 7.8M observation rows). Software: DuckDB 1.5.6, conceptql 0.4.1, threads=8, on titan. Ryan ruled on 2026-10-29: "yes, file them as seeds and we'll investigate the best way to proceed".

Survey totals:

```
statements: 1259; plain ok 1253; annotate ok 1256
annotate_s: median 0.058  p90 0.234  p99 1.005  max 57.934  sum 200.7
plain_s:    median 0.037  p90 0.123  p99 0.520  max 2.293  sum 84.4
```
