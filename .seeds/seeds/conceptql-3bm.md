---
id: conceptql-3bm
title: A Draft algorithm uses usrds_first_transplant, an operator conceptql never had
status: captured
type: question
created_at: 2026-10-29T20:43:41.783357+00:00
updated_at: 2026-10-29T20:43:41.783357+00:00
tags:
  - algorithm-survey
  - validation
---

## What fails

1 Draft algorithm, aee70262 usrds_kidney_transplant, is the whole statement `[["usrds_first_transplant", "FIRST_TRANSPLANT"]]`.

`annotate` reports `[["invalid operator", "usrds_first_transplant"]]`. The plain query raises:

```
RuntimeError: Invalid#query called.  [["invalid operator", "usrds_first_transplant"]]
lib/conceptql/operators/invalid.rb:21:in 'ConceptQL::Operators::Invalid#query'
```

## What was checked (2026-10-29)

- `git log -S usrds_first_transplant` and `git log -S usrds -- lib` find nothing. conceptql never had this operator.
- The algorithm is a Draft. It may be a placeholder for a USRDS data source that was never built.

A survey neighbour, be152e71 acute_pancreatitis (Draft), has an empty statement (`EmptyStatement`). That is a data problem in Jigsaw, not in conceptql.

## Questions (not ruled)

- Is USRDS (the United States Renal Data System) support planned? If not, this Draft is a data problem for Jigsaw and conceptql has nothing to do.
- conceptql's behaviour is already correct for an unknown operator. The open question is the error the plain query gives (see the provider_filter seed about one clear validation error).

## Source

Source: the Jigsaw diagram editor's survey of all current production algorithms, run 2026-10-29 (JDE seed jde-c0y.1 plans per-operator counts and asked for this seed). The survey ran today's `annotate` with counts and the plain query on each of the 1,259 current algorithms (`child_id IS NULL AND deleted_at IS NULL`). Data: the SEER-Medicare sample native_sample_5000 (DuckDB, gdm_wide, 5,000 patients, 7.8M observation rows). Software: DuckDB 1.5.6, conceptql 0.4.1, threads=8, on titan. Ryan ruled on 2026-10-29: "yes, file them as seeds and we'll investigate the best way to proceed".

Survey totals:

```
statements: 1259; plain ok 1253; annotate ok 1256
annotate_s: median 0.058  p90 0.234  p99 1.005  max 57.934  sum 200.7
plain_s:    median 0.037  p90 0.123  p99 0.520  max 2.293  sum 84.4
```
