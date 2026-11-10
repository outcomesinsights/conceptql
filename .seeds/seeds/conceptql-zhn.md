---
id: conceptql-zhn
title: Vocabulary operators give no warning when the data has no records of the vocabulary
status: captured
type: question
created_at: 2026-11-10T14:59:40.242561+00:00
updated_at: 2026-11-10T15:09:07.421597+00:00
---

## The gap

A vocabulary operator counts 0 rows with no warning when the dataset has no records of its vocabulary at all. The user cannot tell "no patient has this code" from "this dataset never carries this vocabulary".

Source: Mark's Claude, MCP test report 2026-11-09 (item 8), handed off from JDE seed jde-ed7. On the SEER-Medicare dataset, count_statement on the algorithm metastatic_cancer_diagnosis counts its icd9cm operator as 0 rows with no warning. The dataset has no icd9cm data: JDE's operator_catalog lists no icd9cm for it, and search_codes answers 404.

Code check, 2026-11-10 (main at 976a1195): the only "no data" warning is `NO_RECORDS_IN_DATA` in `lib/conceptql/operators/vocabulary.rb` (`warn_about_merged_vocabulary`). It fires only for the vocabularies in `MERGED_VOCABULARIES` (CPT4 and HCPCS, which production data stores as CPT4_HCPCS), and only when the merged vocabulary has records. The UNKNOWN_CODE warning checks the lexicon, not the data, so a real icd9cm code gives no warning either.

Ryan ruled 2026-11-10 that JDE passes through what conceptql generates (seed conceptql-3z1 quotes him). That points to direction 1.

## Directions (not ruled)

1. conceptql warns "the data has no records of this vocabulary" for every vocabulary operator. `warn_about_merged_vocabulary` already runs the needed check (`db[criterion_table].where(vocabulary_condition).empty?`), but only for CPT4 and HCPCS.
2. JDE adds the warning from its operator catalog after the count.

## Open questions

- Cost: direction 1 adds one existence query for each vocabulary operator, on Spark in production. Does it run only when warnings are on (`add_warnings?`), and is one query per operator acceptable there?
- Does the warning reuse the text of `NO_RECORDS_IN_DATA`, with the merged-vocabulary detail only for CPT4 and HCPCS?

## UPDATE 2026-11-10: Ryan's direction, and what the data model offers

Ryan (transcribed speech, 2026-11-10): "would it not be possible to do a single query, extra query, on the ETL metadata to see which vocabularies are in the ETL ... If we're going to report something other than a zero count. Can we report NA to record and show that something is not available?"

Findings:

- GDM defines `etl_vocabulary_ids` (generalized_data_model README): one row for each vocabulary in `clinical_codes.clinical_code_vocabulary_id`, with `n_rows`. setlr and roobetl write it beside the dataset tables.
- JDE already reads it: `Database::EtlMetadata#operator_catalog` (app/models/database.rb). That catalog is why JDE lists no icd9cm for SEER-Medicare. It returns an empty catalog when the table is absent.
- The DuckDB test fixture (synpuf_test_data.duckdb) has no etl\_\* tables. conceptql's tests cannot exercise the warning until vocabulation adds the table to the fixture, or the tests create it.
- One query per Database (or per Query) replaces the per-operator existence query that direction 1 assumed. That removes the Spark cost concern.
- The table lists CPT4_HCPCS, not CPT4 or HCPCS. So the existing NO_RECORDS_IN_DATA merged-vocabulary case can read the same source.
- The table covers clinical_codes only. Vocabulary operators that read other tables need checking.

NA in counts: a count of `{"rows": null, "n": null}` (JSON null) instead of 0. Readers of counts must then handle null: conceptql's diagram renderer (`Geometry.count_label_lines` calls `format_count` on the value), JDE's diagram and its count tool. Open: NA together with the warning, or the warning alone. Open: what conceptql does when a dataset has no etl_vocabulary_ids (no warning and real counts is the likely answer).
