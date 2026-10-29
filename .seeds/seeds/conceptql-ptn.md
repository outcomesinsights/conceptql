---
id: conceptql-ptn
title: 'provenance with an unrecognized keyword: annotate reports it, the plain query silently ignores it'
status: captured
type: question
created_at: 2026-10-29T20:43:42.285762+00:00
updated_at: 2026-10-29T20:43:42.285762+00:00
tags:
  - algorithm-survey
  - validation
---

## What fails

2 Draft algorithms give a `provenance` keyword that the vocabulary does not have:

- 3b7deef8 chemotherapy_codes_dme_med_file: `[["unrecognized keywords", "100012292"]]` (a concept ID where a keyword belongs)
- b298a95f bleomycin_pulmonary_hospitalization: `[["unrecognized keywords", "inpatient:primary_or_first"]]`

`annotate` reports the error and raises nothing. The plain query succeeds.

## What was checked (2026-10-29)

`Provenance#additional_validation` compares the keywords with the codes of the file and code provenance vocabularies (`Provenanceable#find_bad_keywords`). `inpatient:primary_or_first` does not appear anywhere in conceptql's `lib/`. It may be an older syntax, or a syntax that someone planned and never built.

The plain query does not validate. It builds `file_provenance_type IN (descendants of the matching concepts)`, and a keyword with no concept adds nothing. So the plain query silently drops the bad keyword and returns fewer rows than the user may expect. That is the conceptql question here.

## Questions (not ruled)

- Are these two Drafts only data problems for Jigsaw (fix the keyword in the statement)?
- Should the plain query refuse a statement that `annotate` marks invalid, instead of silently ignoring the bad keyword? This is the same question as in the provider_filter seed.
- Was `inpatient:primary_or_first` (primary or first-listed inpatient diagnosis position) ever a supported provenance form? If users want it, it is a feature request.

## Source

Source: the Jigsaw diagram editor's survey of all current production algorithms, run 2026-10-29 (JDE seed jde-c0y.1 plans per-operator counts and asked for this seed). The survey ran today's `annotate` with counts and the plain query on each of the 1,259 current algorithms (`child_id IS NULL AND deleted_at IS NULL`). Data: the SEER-Medicare sample native_sample_5000 (DuckDB, gdm_wide, 5,000 patients, 7.8M observation rows). Software: DuckDB 1.5.6, conceptql 0.4.1, threads=8, on titan. Ryan ruled on 2026-10-29: "yes, file them as seeds and we'll investigate the best way to proceed".

Survey totals:

```
statements: 1259; plain ok 1253; annotate ok 1256
annotate_s: median 0.058  p90 0.234  p99 1.005  max 57.934  sum 200.7
plain_s:    median 0.037  p90 0.123  p99 0.520  max 2.293  sum 84.4
```
