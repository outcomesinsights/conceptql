---
id: conceptql-nut
title: Use UNION ALL where union inputs cannot overlap (a cpt_or_hcpcs wildcard pays a 2.1M-row duplicate removal)
status: captured
type: idea
created_at: 2026-10-29T20:43:43.358238+00:00
updated_at: 2026-10-30T01:24:54.630211+00:00
tags:
  - algorithm-survey
  - performance
---

## Measurement

`cpt_or_hcpcs "*"` becomes three CTEs: one each for the vocabularies CPT4, HCPCS and CPT4_HCPCS. A `UNION` (which removes duplicates) joins them. On the 5,000-patient sample, that duplicate removal is the most expensive step of the query:

```
["any_overlap",{"left":["cpt_or_hcpcs","*"],"right":["icd10cm", ...15 codes]}]
plain profile: latency 0.493s planning 0.013s exec 0.480s plan_nodes 40
  op HASH_GROUP_BY          time 1.950s card 2135616

["any_overlap",{"left":["cpt_or_hcpcs","*",{"label":"all cpts"}],"right":["any_overlap",{"left":["cpt_or_hcpcs","37227","37226"],"right":["hospitalization"]}]}]
plain profile: latency 1.807s planning 0.029s exec 1.778s plan_nodes 88
  op HASH_GROUP_BY          time 2.637s card 2135616
```

(The operator time is larger than the latency, so DuckDB probably sums it over threads.) 10 of the 20 slowest plain queries contain a `"*"` wildcard. This cost grows with the size of the data, so it matters more on production data than on the sample.

## Idea (not ruled)

Use `UNION ALL` where the inputs provably cannot overlap. For `cpt_or_hcpcs`, each branch reads the same `observations` rows with a different `clinical_code_vocabulary_id`. A row has one vocabulary, and each branch's `criterion_id` is the row's `id`, so the branches look disjoint.

## Hazard

Confirm that the branches truly cannot overlap before dropping the duplicate removal, for every data model and for code lists as well as `"*"`. For example: can a branch join produce two identical rows? The general `union` operator over arbitrary inputs can overlap (`union` of `icd9 X` and `icd9 X`), so it must keep `UNION` unless the inputs are proven disjoint. The test suite's expected results would show any change in row counts.

## Source

Source: the Jigsaw diagram editor's survey of all current production algorithms, run 2026-10-29 (JDE seed jde-c0y.1 plans per-operator counts and asked for this seed). The survey ran today's `annotate` with counts and the plain query on each of the 1,259 current algorithms (`child_id IS NULL AND deleted_at IS NULL`). Data: the SEER-Medicare sample native_sample_5000 (DuckDB, gdm_wide, 5,000 patients, 7.8M observation rows). Software: DuckDB 1.5.6, conceptql 0.4.1, threads=8, on titan. Ryan ruled on 2026-10-29: "yes, file them as seeds and we'll investigate the best way to proceed".

Survey totals:

```
statements: 1259; plain ok 1253; annotate ok 1256
annotate_s: median 0.058  p90 0.234  p99 1.005  max 57.934  sum 200.7
plain_s:    median 0.037  p90 0.123  p99 0.520  max 2.293  sum 84.4
```

RULED 2026-10-29 (Ryan, relayed by the jigsaw-diagram-editor session): this seed comes BEFORE the one-query counting mode. The question was "Fix the wildcard cost first ... ConceptQL's nut seed come before the one-query mode?", and Ryan answered "sure".

The reason is a full-dataset measurement on 2026-10-29. It was read-only, plain query, threads=8, memory_limit=8GB, on seer_medicare_all_cancer_2024_enriched_20261027/gdm.duckdb (417.1 GB, 1,747,534 patients, 2,043,400,528 observation rows).

- The 7 statements with a `cpt_or_hcpcs "*"` style wildcard took 318 to 1,044 s. Two ran out of memory, and each spilled 120 to 280 GB.
- threads=32 with memory_limit=64GB made them only 1.1 to 3 times faster (best 166 s), and they still spilled 62 to 207 GB.
- SQL build stayed under 1.3 s, so execution is the whole cost. Selective statements stayed under 1 s.
- The ratio of full to sample execution time was 164 to 927 for the wildcard statements, and 50 to 118 for the heavy statements without a wildcard.
- Statement ids: a82a4bb4, 7b49eaf0, b8e9fd6c, 0b174142, 68300d6a, 11aac29e, fdde7ce2.
- The full ruling and the table are in JDE seed jde-c0y.1 (the round 4 and round 5 updates).

This orders the work. It does not authorize building it: the change still goes through a bead.
