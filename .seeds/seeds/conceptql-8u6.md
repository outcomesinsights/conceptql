---
id: conceptql-8u6
title: 'Production Spark SQL from ConceptQL: ranked optimizations after adversarial review (2026-10-14)'
status: captured
type: exploration
created_at: 2026-10-14T17:05:51.210794+00:00
updated_at: 2026-10-15T03:40:13.075732+00:00
tags:
  - performance
  - spark
  - sql
  - t_shank
relationships:
  - target_id: conceptql-sn2
    rel_type: questioned-by
    created_at: 2026-10-14T19:22:28.940357+00:00
  - target_id: conceptql-x9w
    rel_type: questioned-by
    created_at: 2026-10-14T19:22:29.445380+00:00
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

## Ryan's responses, 2026-10-14 (verbatim)

On the ranked options:

> 1. one admission will never belong to two patients. please do this fix
> 2. don't know what you're saying, but I think the concept table is partitioned by vocabulary id, so might that help?
> 3. please look into fixing this
> 4. I'm fine with this, though I'd like to point out that we now have a new vocabulary, I think it's cpt4 underscore HCPCS, that we will be using going forward for this quote multi-vocabulary CPT or HCPCS setup. So actually, that should be a third vocabulary ID that is included in that mishmash. And we will mark multiple vocabularies as deprecated because I think CPT or hic pics is the only one. So in the future, CPT or HCPCS will just call that one unified vocabulary in the future, but not for at least another maybe year. Does that all make sense?

On the three decisions (hospitalization beads, the duplicate-row defect, the lexicon cache):

> Here's my response to decisions. Item one. Yes. Item two. Yes, that needs to be fixed. Three Three I think we had actually talked about this caching before [...]

The cache part is recorded in full in conceptql-a5f.

RULED 2026-10-14:

- Option 1 (hospitalization person filter): build it. Precondition settled by Ryan: one admission never belongs to two persons.
- The duplicate-row defect (bead conceptql-7cd): fix it.
- Option 3 (one_in_two_out triple read): investigate a fix.
- Option 4: the explicit vocabulary_id IN conjunct is accepted. CPT4_HCPCS joins CPT4 and HCPCS in "CPT or HCPCS". MultipleVocabularies will be marked deprecated. "CPT or HCPCS" moves to the CPT4_HCPCS vocabulary alone in about a year, not now.

## Follow-up findings, 2026-10-14

### Option 2: is the concept table partitioned by vocabulary_id? Yes, but these joins do not use it

- In current production Spark datasets, `concept` is a partitioned catalog table (CatalogFileIndex), and lookups that filter on vocabulary_id show PartitionFilters on it (for example `vocabulary_id = Race`, `vocabulary_id = Ethnicity`).
- The dose_con, ing_con, asc, dlc and unit joins join on concept_id only. Every one of those concept scans in the production plans has `PartitionFilters: []`, so Spark reads every partition.
- A `vocabulary_id IN (...)` conjunct on the concept side of each join would let Spark prune. But conceptql does not know which vocabularies those columns use, and they differ by dataset. On seer_2022_lung (DuckDB, real data):

```
admit_source_concept_id        SEER_SRC_IP_ADMN_CD (13 ids), "None" (1 id)
discharge_location_concept_id  SEER_DSCHRG_DST_CD (38 ids), PTNT_DSCHRG_STUS_CD (21 ids)
dose_unit_concept_id           UCUM (3 ids), CMS_MTUS_TYPE (1 id)
unit_concept_id, result_as_concept_id   "None" (1 id each)
```

- A fixed vocabulary list in conceptql would drop names on some dataset. A list per dataset needs a lookup (a round trip) or metadata from the ETL. So partitioning does not help these joins by itself. The output-identical options stay the same: a broadcast hint, or applying the window join before the concept joins.

### Option 3: one_in_two_out

- Spark experiment (local Spark 3.5.0 from the spark-image Docker image, AQE off, synthetic Parquet tables): three separately named identical CTEs and one CTE referenced three times give the same physical plan. Both scan the upstream three times. Spark inlines deterministic CTEs and reuses only the broadcast of the window table. Production runs Spark 3.3.2. Its CTE inlining is expected to behave the same, but that is not verified.
- Done: OneInTwoOut#query now evaluates its upstream once, so the SQL has one CTE where it had three. Output is unchanged. This helps Postgres, where conceptql marks CTEs MATERIALIZED, and DuckDB. It does not change the Spark plan.
- A fix that reads the upstream once on Spark must replace the EXISTS self-join with window functions over a date RANGE frame. Risks: (1) gaps in months are not symmetric at month ends (`add_months(Jan 31, 1)` is Feb 28, and `add_months(Feb 28, -1)` is Jan 28), so the "Confirming Event" side can change output at month ends. (2) RANGE frames with interval offsets differ by RDBMS. (3) The 65% duplicate-scan figure came from pre-AQE plans. AQE can reuse identical query stages at runtime, so the real duplication may be smaller.
- Recommendation: measure one production-shaped one_in_two_out statement on Spark with AQE on, and only then decide on the rewrite.

### Option 4: CPT4_HCPCS and MultipleVocabularies

- The vocabulary CPT4_HCPCS exists. ohdsi_supplemental_vocabs builds it, and vocabulation keeps it in the trimmed and test images permanently (vocabulation seed vocabulation-5, bead vocabulation-rb4).
- `config/multiple_vocabularies.csv` defines two multi-vocabulary operators, not one: "CPT or HCPCS" (CPT4, HCPCS) and "ICD10" (ICD10CM, ICD10WHO). Deprecating MultipleVocabularies needs a plan for "ICD10" too. The duplicate-row defect also affected "ICD10".
- Adding CPT4_HCPCS as a third row needs a `cpt4_hcpcs` vocabulary operator on every ConceptQL::Database. MultipleVocabularies#vocab_ops uses `fetch`, so a database whose lexicon has no CPT4_HCPCS would raise KeyError. Either every lexicon has CPT4_HCPCS, or the operator skips a vocabulary that is missing.

### The duplicate-row defect (bead conceptql-7cd)

- Fixed: MultipleVocabularies now skips the second window application (`skip_windows?` is true), because each vocabulary operator below it already applied the scope's windows.
- Test: `cpt_or_hcpcs 99232 A0425` with overlapping windows (one window per ICD9 412 event, widened by 2 years each way) now gives 470 rows, identical to `union [cpt4 99232] [hcpcs A0425]` under the same windows. The old code fails that test.

RULED 2026-10-14, second round (Ryan): remove the "ICD10" multi-vocabulary operator now (see conceptql-sn2). Add CPT4_HCPCS to "CPT or HCPCS" with a guard (see conceptql-1). The lexicon cache is created by the Database (see conceptql-a5f). Time one_in_two_out on Spark before any rewrite (see conceptql-x9w).

## UPDATE 2026-10-14: status of each option after the beads closed

Shipped, all local and unpushed:

- Option 1, the hospitalization person filter: bead conceptql-dc0, commit 39dd6c15.
- Option 3, one_in_two_out reads its upstream once: bead conceptql-3ae (one CTE, 02d2c565), then bead conceptql-7qo (single-read rewrite, d9371d12). Seed conceptql-x9w holds the measurement and the verification.
- Option 5, the lexicon cache: bead conceptql-ogh, commit bbdac88d, opt-in and off by default. Production gains nothing until t_shank passes cache_lookups: true.
- The duplicate-row defect: bead conceptql-7cd, commit 05d06e5b.
- CPT4_HCPCS as a third vocabulary of "CPT or HCPCS": bead conceptql-ydh, commit affe54fa. The "ICD10" multi-vocabulary operator is removed (seed conceptql-sn2).

Not shipped:

- Option 4, the explicit vocabulary_id IN conjunct: bead conceptql-agx is open.
- Option 4, marking MultipleVocabularies as deprecated: no bead, and lib/conceptql/operators/multiple_vocabularies.rb has no deprecation mark.
- Option 2, the concept lookup joins: not ruled. The follow-up showed that partition pruning cannot help these joins. A broadcast hint, or applying the window join before the concept joins, are still the output-identical options.
- Found later: MultipleVocabularies reports no vocabularies, so the multiple_vocabularies flag is false for "CPT or HCPCS". No bead yet.
