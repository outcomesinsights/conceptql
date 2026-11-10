---
id: conceptql-zhn
title: Vocabulary operators give no warning when the data has no records of the vocabulary
status: captured
type: question
created_at: 2026-11-10T14:59:40.242561+00:00
updated_at: 2026-11-10T19:12:37.460561+00:00
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

## UPDATE 2026-11-10: Ryan's second round

Ryan: "we'll need conceptql to be aware of the relevant etl\_\* tables when dealing with GDM to make this check. we'll need to have roobetl (or something) enhance the synpuf250 test dataset to have the etl\_\* tables, yes? are you comfortable with NULL being passed to JDE? is there a more sensible value? I'm a fan of null, but I know a lot of programming practices try to avoid that. agree that in the absence of etl\_\* tables, no warning and a count of 0 works"

RULED: with no etl\_\* tables, no warning and a count of 0.

Fixture: vocabulation builds synpuf_test_data.duckdb (scripts/duckdb_build.py) by copying a declared table list (SCHEMA_TABLES) from titan's test_data Postgres. roobetl computes etl_vocabulary_ids (lib/roobetl/metadata.rb). The fixture has no etl\_\* tables today. The Postgres source (titan test_data, port 5432) has slim.etl_info, etl_information_types, etl_tables and etl_vocabulary_ids, all with 0 rows, and its etl_vocabulary_ids has only (vocabulary_id, n_rows) (verified by the vocabulation session, 2026-11-10). The earlier connection failure was a wrong port, 6432. The work routes to vocabulation: add the etl\_\* tables to the fixture, computed by roobetl's metadata code or copied from the source.

Candidate values for "not available", assessed:

- JSON null for rows and n. JSON's own "no value", the same as SQL NULL and R NA. The advice against null concerns code paths in Ruby or Java, not data exchanged between programs.
- Leave the counts out. JDE's JS diagram (js/lib/conceptql-diagram/src/geometry.js) and conceptql's renderer already draw no label when counts are absent. But "absent" also means "not counted", so it says less than null.
- A string such as "NA". It mixes strings and numbers in one field, and every reader must test the type. Rejected.
- A sentinel such as -1. Summing or comparing gives wrong results with no error. Rejected.
  Recommended: null, with the warning that says why.

## RULED 2026-11-10

Ryan: "zhn: null with warning please and the rest as discussed". conceptql reads etl_vocabulary_ids once for GDM data. An absent vocabulary gets the warning and null counts. No etl\_\* tables means no warning and counts of 0. Bead: conceptql-d1bd. The fixture work was sent to the live vocabulation session (vocabulation-b9) on 2026-11-10.

## UPDATE 2026-11-10: fixture bead and the empty-table case

vocabulation filed vocabulation-xd6: add a populated slim.etl_vocabulary_ids to synpuf_test_data.duckdb, filled from slim.clinical_codes. conceptql-d1bd depends on it. Open in vocabulation: fill the table in Postgres too (so the docker image and parquet carry it), or only in the DuckDB build.

The Postgres test_data already has an empty etl_vocabulary_ids. conceptql-d1bd now treats an empty table like a missing one (no warning, normal counts), which follows the ruling for missing tables. Without that rule, the Postgres test configs would warn on every vocabulary.

## UPDATE 2026-11-10: measured on SEER-Medicare; fixture ready locally

On seer_medicare_all_cancer_2024_enriched_20261103 (80 vocabularies in etl_vocabulary_ids), about 444 user-visible vocabulary operators in 385 of the 1,256 current algorithms read a vocabulary that the dataset does not have (corrected by the adversarial review, claude_stuff/adversarial-review-annotate-plan-20261110-093509.md; the first count, 1,323 operators in 780 algorithms, wrongly included the inner CPT4 and HCPCS operators of 452 cpt_or_hcpcs operators, whose vocabulary CPT4_HCPCS is present). By vocabulary: ICD9CM 341, ICD9Proc 37, Gemscript 20, LOINC 14, CPRD_TEST_ENTITY 8, MARCLA_OBS_TYPE 6, CPRD_ENTTYPE 5, USRDS_MODALITY 5, USRDS_DIALYSIS_START 1. Log: claude_stuff/two-lexicon-measure-20261110-090153.log (seed conceptql-d9w has the method).

vocabulation-xd6 is closed: the local fixture /home/ryan/projects/outins/vocabulation/synpuf_test_data.duckdb (sha256 a4926bed...) has the 4 slim etl\_\* tables, filled by roobetl (roobetl-wu4). etl_vocabulary_ids has 7 rows (ICD9CM, CPT4, NDC, HCPCS, ICD9Proc, DRG, LOINC) with NULL source_table and source_column. It is not published to Dropbox yet; Ryan decides when.

## UPDATE 2026-11-10: Adversarial review 2026-11-10 (claude_stuff/adversarial-review-annotate-plan-20261110-093509.md, probes in claude_stuff/review-annotate-plan/)

Findings for bead conceptql-d1bd (not yet acted on):

- CONFIRMED: d1bd cannot pass just ci as written. The Postgres and DuckDB suites compare against one expected-results file (test/statement_tests.rb:253-257 chooses by data model and lexicon strategy, not by database). The DuckDB fixture now has 7 rows in etl_vocabulary_ids, the Postgres test_data image has 0, so their annotations differ. Three anno tests use a vocabulary outside the 7: gemscript/anno_no_format_check, place_of_service_filter/anno_2, drug_text_string/anno_1. Either the Postgres test image gets the same filled table (roobetl filled titan's test_data.slim, bead roobetl-wu4, but the docker image is pinned by digest), or results get a per-database directory.
- CONFIRMED: ConceptQL::Diagram turns a null count into 0 (lib/conceptql/diagram.rb:113, Integer(c[:rows] || 0)). So Diagram.render, the CLI and the spec show 0. Drawing NA in the Ruby renderer also breaks the rule that the JavaScript renderer's output is the reference (docs/diagram_renderer.md); JDE's JavaScript renderer needs the same change.
- NA appears only on the operator that reads the absent vocabulary. On SEER-Medicare, 141 algorithms read only absent vocabularies; their top operator still shows a real 0 with no warning.
- Read is not a Vocabulary class and is never validated: 34 read operators in production, and SEER has no Read data.
- MultipleVocabularies (cpt_or_hcpcs) drops a warning that has no details (aggregate_messages, multiple_vocabularies.rb:164), so cpt_or_hcpcs would never warn.
- cpt and cpt4 get the existing merged-vocabulary warning and the new one with the same text: 2 operators in production.
- The corrected SEER count: about 444 user-visible operators in 385 algorithms (fixed above).

## RULED 2026-11-10 (after the adversarial review)

1. Test data: the Postgres test image gets the same filled etl\_\* tables as the DuckDB fixture, so both suites keep one set of expected results (option a).
2. Renderer: Ryan, transcribed: "There is only one renderer we're supporting now going forward and that is ... ConceptQL's Ruby renderer. The JavaScript renderer in my mind is dead. So yeah, I think that that's an internal change to ConceptQL, right?" So NA is drawn by conceptql's Ruby renderer only. ConceptQL::Diagram must pass null through (it turns nil into 0 today, diagram.rb:113). New renderer cases get reference output from the Ruby renderer; the JavaScript references stay for the existing 70 fixtures.
3. NA in parents: Ryan: "If upstream is NA, then I would assume that the downstream would also be NA ... So that seems good." An operator whose inputs are all NA also reports NA counts. The warning stays on the vocabulary operator that reads the absent vocabulary.

Fixture: vocabulation republished synpuf_test_data.duckdb to Dropbox at 2026-11-10 09:43 with the etl\_\* tables. Its sha256 is a675a69bc61e29aa1d38b953ace704a926a7fc0dafd49e246a9be4c1229dd5fd, the same as vocabulation's local build of 09:40 (the a4926bed... sum it reported came from an earlier build). conceptql's pin (.github/synpuf_test_data.sha256, d90fc4c9...) is now stale, so just test-duckdb refuses to run until the pin is updated after a green run.

## UPDATE 2026-11-10: Postgres test image

Ryan: "please ask vocabulation to rebuild -- I think it should be doing so already". The vocabulation session vocabulation-b9 was asked to rebuild ghcr.io/outcomesinsights/misc:test_data.jumper with the filled etl\_\* tables (ruling 1 above). conceptql then pins the new digest in docker-compose.yml.
