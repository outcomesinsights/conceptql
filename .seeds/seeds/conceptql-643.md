---
id: conceptql-643
title: sort_extracted_ctes builds SQL for every CTE to find dependencies (about 50 s of Ruby on one algorithm)
status: captured
type: idea
created_at: 2026-10-29T20:43:42.822503+00:00
updated_at: 2026-10-29T20:43:42.822503+00:00
tags:
  - algorithm-survey
  - performance
---

## Measurement

The slowest `annotate` in the survey is ac4efe58 warriner_8_women_6579_index_date_dr (Draft, 111 operators, 23,415 bytes of JSON). `annotate` takes 58-66 s, and most of that time is in Ruby, not in DuckDB. The survey wrapped `Sequel::Dataset#sql` to time SQL building:

```
ac4efe58 annotate 62.06s = db exec 11.94s + literalize 10.70s (53170 top-level selects, 2988.6 MB) + other ruby 39.42s
19c6b6f9 annotate 2.12s = db exec 1.20s + literalize 0.30s (1588 top-level selects, 17.1 MB) + other ruby 0.62s
```

The plain query of ac4efe58 takes 0.76 s to build.

## Suspected cause (not confirmed)

`Scope#sort_extracted_ctes` (scope.rb, added 2026-03-18 in 5d0983aa "Fix DuckDB full statement suite support") calls `ds.sql` on every extracted CTE. Then it searches each SQL string for the quoted name of every other CTE to find the dependencies. `annotate` builds one query per operator, so each of these steps repeats for every operator. That fits 53,170 SQL builds and 3 GB of SQL strings.

The survey measured only the split above. It did not attribute the 39 s of "other ruby" to `sort_extracted_ctes`. A profiler run (for example stackprof on ac4efe58) must confirm the cause before any change.

## Idea (not ruled)

Record each CTE's dependencies while `recursive_extract_ctes` walks the operator tree, because the walk already knows which dataset reads which CTE. Then the sort needs no SQL strings. This would help the plain query build as well.

Relation: the one-query counting mode that JDE seed jde-c0y.1 plans would also remove the per-operator repetition. This idea is independent of it and also helps the plain query.

## Source

Source: the Jigsaw diagram editor's survey of all current production algorithms, run 2026-10-29 (JDE seed jde-c0y.1 plans per-operator counts and asked for this seed). The survey ran today's `annotate` with counts and the plain query on each of the 1,259 current algorithms (`child_id IS NULL AND deleted_at IS NULL`). Data: the SEER-Medicare sample native_sample_5000 (DuckDB, gdm_wide, 5,000 patients, 7.8M observation rows). Software: DuckDB 1.5.6, conceptql 0.4.1, threads=8, on titan. Ryan ruled on 2026-10-29: "yes, file them as seeds and we'll investigate the best way to proceed".

Survey totals:

```
statements: 1259; plain ok 1253; annotate ok 1256
annotate_s: median 0.058  p90 0.234  p99 1.005  max 57.934  sum 200.7
plain_s:    median 0.037  p90 0.123  p99 0.520  max 2.293  sum 84.4
```
