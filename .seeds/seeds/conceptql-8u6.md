---
id: conceptql-8u6
title: 'Production Spark SQL from ConceptQL: ranked optimizations after adversarial review (2026-10-14)'
status: captured
type: exploration
created_at: 2026-10-14T17:05:51.210794+00:00
updated_at: 2026-10-14T17:05:51.210794+00:00
tags:
  - performance
  - spark
  - sql
  - t_shank
---

Ryan asked on 2026-10-14 where the SQL optimization work stood, to re-evaluate it, to review the result adversarially, and to look for other opportunities. This seed records the ConceptQL side. The t_shank side is t_shank seed t-shank-ucq (production export timings, cohort slice, ANALYZE flag) and t_shank/docs/export_performance_review.md (September 2026 review of the test fixtures).

Not ruled. Nothing here is built.

## Evidence used

- Production SQL, timings and EXPLAIN plans: ~/dockers/outins_jb/log/t_shank/diagnostics.sqlite3, table diagnostics_v3, opened read-only. Production since 2025 is gdm_wide on Spark. 7,448 Spark algorithm tables (baseline, outcome, exclusion, inclusion, index) in 102 exports took 16.5 h of CREATE time, about 9.7 min per export.
- Production `observations` is partitioned by clinical_code_vocabulary_id, and the plans show partition pruning on every single-vocabulary leaf. Window joins are broadcast hash joins. `1 = 0` branches are pruned.
- Real-scale DuckDB timing on /mnt/samba/data/gdm/seer_2022_lung (53 GB observations), with SQL compiled by current conceptql (HEAD 75cae435). Each rewrite was checked for identical output: row counts, EXCEPT ALL both ways, sum of row hashes, column lists. DuckDB timing is not Spark timing. The single Parquet file is not partitioned the way production is.
- An adversarial review of the first draft. It refuted or weakened four of the seven first candidates. The verdicts are below.

## Ranked options

### 1. Hospitalization: filter to cohort persons before ROW_NUMBER (largest, measured)

behaviors/utilizable.rb builds ROW_NUMBER() OVER (PARTITION BY admission_detail_id) over every inpatient row in the database. Then it LEFT JOINs concept twice (asc, dlc). Only after that does the window join restrict the rows to the cohort. Spark cannot push a join below a window function. So each use shuffles and sorts every inpatient row.

- Production: statements with this Window total 3.70 h (702 Windows). The t_shank session measured 3.17 h of 8.02 h of 2026 CREATE time in 492 such tables. One export, f4f10fdf, spent 49.7 of 61 minutes on them.
- Rewrite: add `patient_id IN (SELECT person_id FROM <window table>)` to the base WHERE, below the ROW_NUMBER.
- DuckDB, real data: 7.8 s -> 0.72 s (5k cohort); 8.3 s -> 1.33 s (50k cohort). Output identical, also with overlapping windows.
- Precondition: one admission_detail_id never spans two persons. The fixture has 0 of 153. The seer parquet has no admission_detail_id column, so production is unchecked. One query against the Spark data settles it.
- Provenance statements are slow too. Provenance has no window function of its own; the inference is that its slowness comes from hospitalization upstreams.

### 2. Concept lookup joins that shuffle the whole concept table (measured shape, unmeasured gain)

- The gdm_wide DrugQueryModifier LEFT JOINs concept as dose_con and ing_con onto every leaf whenever the statement's query columns include drug columns. That includes CPT4 and HCPCS leaves. The plans show dose_con as a SortMergeJoin that scans and shuffles all of concept (about 11M rows). ing_con is already filtered, because Spark infers concept_id from the IN list.
- 4,868 dose_con/ing_con pairs in production. Those statements total 6.88 h. 3,046 of 6,673 joined leaves are not NDC.
- Other full-concept joins: asc and dlc (720 each), measurement result and unit (934 each). Statements with any of these total about 10.9 h. The saving is some fraction of that.
- Output-identical fixes: a BROADCAST hint, or a small lookup of only the concept ids that occur in those columns, or applying the window join (or a person semi-join) before these joins.
- Restricting the modifier to drug leaves CHANGES OUTPUT: CPT4/HCPCS rows currently get drug_name = the procedure's concept name. Dropping only dose_con on non-drug leaves is lower risk (fixture: 0 non-drug rows with a dose unit; production unchecked).
- In DuckDB these joins were the main cost of each leaf (about 0.5 s per hash build on 9.47M rows).

### 3. one_in_two_out reads its upstream three times (measured shape)

one_in_two_out.rb:51 is reached from lines 57 and 78, and line 78 is called twice (96, 126). Compiling it gives three identical CTEs. Spark inlines CTEs, so each one is a separate scan. In production, 3,120 of 4,818 live leaf scans in these statements are exact duplicates. The statements total 4.4 h (1,560). Fixes: materialize the upstream once (output-identical), or rewrite with one read and a window frame (moderate risk). Not timed.

### 4. MultipleVocabularies and Union merges (measured, smaller)

- MultipleVocabularies (cpt_or_hcpcs and similar) emits one scan per vocabulary, a UNION, and a second window join. Its TODO at multiple_vocabularies.rb#query already says so. Union's Combiner (union.rb) already merges direct Vocabulary children into one OR'd scan, so the general case exists.
- DuckDB, production atezolizumab statement: 2.13 s current; merged into one OR'd leaf with an explicit `clinical_code_vocabulary_id IN (...) AND concept_id IN (...)` conjunct: 0.90 s. A plain OR without that conjunct was slower (6.08 s on a 3-leaf statement), because Parquet pushdown stopped. Most of the DuckDB gain came from removing per-leaf concept joins (option 2), not from removing scans.
- On Spark the scans are already partition-pruned, so a merge saves less I/O than it does here. Whether Spark 3.3 derives partition pruning from an OR is unverified. Any merge, and the existing Combiner, should emit the explicit vocabulary IN conjunct (zero output risk).

### 5. Lexicon round trips (seed conceptql-a5f)

The t_shank session measured export 2fd73840: 618 lookups against concept at compile time, 183 distinct, 2 to 5.6 minutes per export (5-11% of wall clock) over 10 sampled exports. It argues that a cache scoped to one export in production is one code path, so it fits the 2026-09-29 rule against test-only paths. conceptql-a5f records "caching is a nightmare" and a ruling against a result cache. These two readings conflict, and only Ryan can resolve them.

## Refuted or weakened (do not pursue as written)

- Admission-date join (t-shank-ucq item 5): 0 of 7,622 Spark algorithm statements since 2025 join admission_details. The 140 s cost was 2024 Postgres on slim. The t_shank seed withdrew it.
- Dropping the second window join in MultipleVocabularies as a speed change: it is cheap (broadcast) and it changes row counts. See the defect below.
- UNION to UNION ALL inside MultipleVocabularies: output-identical on the fixture and the real data, but no measurable gain in DuckDB, and the DISTINCT runs on cohort-filtered rows.
- CTE recompute: about 9% more plan scans than text leaves. The real recompute is option 3.
- Scan count as the cause of time: a regression with export fixed effects says partition-pruned scans add about nothing, and each Window operator about doubles the time. Correlational.

## Defect found on the way

MultipleVocabularies emits duplicate rows when a person's windows overlap. Its children are windowed, the union strips window_id, and the union is windowed again, so an event in k windows appears k² times instead of k. Measured with two overlapping windows per person on the fixture:

```
hcpcs <50 codes>           rows=472  distinct_rows=472
cpt_or_hcpcs <same codes>  rows=710  distinct_rows=472
```

On the real data: 978 rows against 538, and 133,064 against 68,950. The set difference is 0, so only multiplicities differ. t_shank's \*\_agg tables group raw rows by person, so per-person counts can be inflated in studies with overlapping windows (recurrent index events). Fixing it changes output for those studies. Tracked as a bead.

## Cross-statement repetition (belongs to t_shank)

Per export, 52% of live leaf scans repeat a leaf from another statement, and ICD10CM is read about 54 times. ConceptQL compiles one statement at a time and cannot share this. It is the case for t_shank's opt-in cohort slice pilot.

## Caveats

- The t_shank session saw Spark run times vary about 5x between identical runs. spark-defaults.conf was rewritten on 2026-09-30, so the March 2026 timings came from a different configuration.
- The production EXPLAIN plans are pre-AQE. Runtime reuse of shuffles and broadcast conversion are not visible in them.
