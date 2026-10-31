# SQL options for production Spark, 2026-10-14 (seeds conceptql-8u6, conceptql-x9w)

**Answer:** Two changes were measured as large. Filtering hospitalization rows
to the cohort's persons before the `ROW_NUMBER` made one DuckDB query on real
data 6 to 11 times faster (7.8 s to 0.72 s). Reading the upstream of
`one_in_two_out` once instead of three times cut the upper bound of its Spark
time by 56-65%. Both shipped. Other options were smaller or were refuted.

**The raw logs of these measurements are lost.** They were in the session
scratchpad, which is temporary. The seeds `conceptql-8u6` and `conceptql-x9w`
are the record, and this report repeats their numbers.

## Question

Ryan asked on 2026-10-14 where the SQL optimization work for production Spark
stood. He asked to re-evaluate it, to review it adversarially, and to look for
other opportunities.

## Setup

- **Host:** not named in the seeds. The data paths are titan's samba mounts,
  so the runs were most probably on titan.
- **Production evidence:** t_shank's diagnostics database of production exports
  (read-only). Production since 2025 is gdm_wide on Spark 3.3.2. 7,448 Spark
  algorithm tables in 102 exports took 16.5 h of CREATE time.
- **DuckDB data set:** SEER lung (`/mnt/samba/data/gdm/seer_2022_lung`, 53 GB of
  observations in Parquet). The DuckDB version was not recorded.
- **Code measured:** SQL compiled by conceptql at `75cae435` (2026-10-07).
- **Spark data set and engine:** the same SEER lung observations, both flat and
  partitioned by `clinical_code_vocabulary_id`, on a local Spark 3.5.0
  (`local[16]`, AQE on). Production runs Spark 3.3.2 on a cluster.
- **Cohorts:** window tables of 5,000 and 50,000 persons.
- **titan-lock:** did not exist yet (it started on 2026-10-20).
- **Other load:** unknown. `below` history on titan starts on 2026-10-16.

## Method

- DuckDB: each rewrite was timed against the current SQL. Equality was checked
  with row counts, `EXCEPT ALL` in both directions, the sum of row hashes and
  the column lists.
- Spark, `one_in_two_out`: three production statements from the diagnostics
  database (65334, the SEER lung median; 65482, the SEER lung slowest; 73578, a
  MarketScan median run on the SEER data). Each reads its upstream through
  three identical CTEs. Three arms: A is the statement as is. C reads the
  upstream once and materializes it. B is C plus the rest of the statement
  reading the materialized table, so B bounds any single-read rewrite from
  above. Medians of 3 runs.

## Results: DuckDB on SEER lung

| change                                                                                               | before             | after  | output    |
| ---------------------------------------------------------------------------------------------------- | ------------------ | ------ | --------- |
| hospitalization: filter to window persons before `ROW_NUMBER` (5k cohort)                            | 7.8 s              | 0.72 s | identical |
| hospitalization: the same (50k cohort)                                                               | 8.3 s              | 1.33 s | identical |
| one statement's vocabulary leaves merged into one OR'd leaf with a `vocabulary_id IN (...)` conjunct | 2.13 s             | 0.90 s | identical |
| `UNION` to `UNION ALL` inside MultipleVocabularies                                                   | no measurable gain |        | identical |

- A plain `OR` without the `vocabulary_id IN` conjunct was slower: 6.08 s on a
  3-leaf statement, because DuckDB's Parquet filter pushdown stopped.
- Most of the merged-leaf gain came from removing per-leaf concept joins, not
  from removing scans. That led to the concept-join measurement of the next day
  (`concept-name-joins-2026-10-15.md`).

## Results: Spark, `one_in_two_out` (seconds, medians of 3)

| statement | observations | window | A (as is) | B (bound) | C (one read) | A - B      |
| --------- | ------------ | ------ | --------- | --------- | ------------ | ---------- |
| 73578     | partitioned  | 5k     | 25.6      | 9.1       | 7.6          | 16.5 (64%) |
| 65334     | partitioned  | 5k     | 24.9      | 11.0      | 9.1          | 13.9 (56%) |
| 65482     | partitioned  | 5k     | 30.0      | 12.4      | 10.1         | 17.6 (59%) |
| 73578     | partitioned  | 50k    | 28.0      | 11.4      | 9.6          | 16.6 (59%) |
| 65334     | partitioned  | 50k    | 33.6      | 14.2      | 11.6         | 19.4 (58%) |
| 65482     | partitioned  | 50k    | 43.9      | 18.5      | 12.6         | 25.4 (58%) |
| 73578     | flat         | 5k     | 82.7      | 28.8      | 25.5         | 53.9 (65%) |
| 65482     | flat         | 5k     | 92.8      | 33.0      | 30.2         | 59.7 (64%) |

- A is about 3 times C in every case. So the three reads are the cost, and the
  self-join, the window and the union cost little.
- A and B returned identical rows in all 8 configurations.
- AQE did not remove the repeated reads.
- Caveats: Spark 3.5.0 is not production's 3.3.2. One node ran about 10 times
  slower than production in absolute time, so only the ratios transfer. The OS
  page cache was warm.

## What was refuted or weakened

- The admission-date join: 0 of 7,622 production Spark statements since 2025
  use it.
- Dropping the second window join in MultipleVocabularies as a speed change: it
  is cheap (a broadcast join), and it changes row counts.
- `UNION` to `UNION ALL` inside MultipleVocabularies: no gain on DuckDB.
- Scan count as the cause of time: a regression over exports says that
  partition-pruned scans add about nothing. This is correlational.

## Conclusion and decisions

Ryan ruled on 2026-10-14. What shipped:

- Hospitalization person filter: bead `conceptql-dc0`, commit `39dd6c15`.
- `one_in_two_out` reads its upstream once: beads `conceptql-3ae`
  (`02d2c565`) and `conceptql-7qo` (`d9371d12`). The single-read rewrite was
  checked against the old SQL on 746 cases each on Postgres and DuckDB, and on
  80 cases on local Spark. Its production-scale Spark time was not measured.
  The 56-65% above is an upper bound of the saving.
- The `vocabulary_id IN` conjunct for the Union combiner: bead `conceptql-agx`,
  commit `2822a16b`.
- A duplicate-row defect found on the way (MultipleVocabularies with
  overlapping windows): bead `conceptql-7cd`, commit `05d06e5b`.
- The lexicon cache (option 5, measured by t_shank, not here): bead
  `conceptql-ogh`, commit `bbdac88d`.

## Sources

- Seed `conceptql-8u6`, sections "Evidence used", "Ranked options",
  "Follow-up findings" and "UPDATE 2026-10-14".
- Seed `conceptql-x9w`, section "Measured 2026-10-14".
- The commit messages of `39dd6c15` and `2822a16b`.
- The raw logs (session scratchpad `spark-oito/logs` and the DuckDB scripts)
  no longer exist. The `claude_stuff/oito-*` logs in the primary checkout are
  the correctness checks of the `one_in_two_out` rewrite, not timings.
