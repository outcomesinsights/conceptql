# Concept-name joins on DuckDB, 2026-10-15 (seed conceptql-8u6, option 2)

**Answer:** The joins that add concept names (drug, dose unit, lab result and
unit) took about half to two thirds of each statement's time on DuckDB. Each
join cost about 0.3 to 0.45 s, and the cost did not grow with the cohort.
Joining a cut-down concept table of only the concept IDs that the data uses
removed that cost with identical output. Ryan chose to have conceptql build
that table once for each Database. It shipped in `e1c308a1`.

## Question

The 2026-10-14 review (`spark-sql-options-2026-10-14.md`) found that conceptql
LEFT JOINs the whole concept table several times in a statement to add names.
Ryan asked for a DuckDB measurement on 2026-10-15, because production is
moving to DuckDB.

## Setup

- **Host:** not named in the seed. The data path is titan's samba mount, so
  the runs were most probably on titan.
- **Data set:** SEER lung (`/mnt/samba/data/gdm/seer_2022_lung`), DuckDB views
  over the Parquet files. The concept table has 9,466,414 rows. The data
  references 162,891 of them (1.7%).
- **Code measured:** SQL compiled by conceptql at `2822a16b` (gdm_wide), wrapped
  in a window table with `precalculated_window_id`, as t_shank does.
- **Cohorts:** 5,000 and 50,000 persons.
- **Engine:** the DuckDB CLI, 16 threads, a new process for each variant. The
  DuckDB version was not recorded.
- **titan-lock:** did not exist yet (it started on 2026-10-20).
- **Other load:** unknown. `below` history on titan starts on 2026-10-16.

## Method

- Four statements. Each one contains a drug or lab vocabulary, which adds the
  name joins to every leaf in the statement:
  - ndc: six frequent NDC codes.
  - hcpcs_ndc: three HCPCS codes plus the six NDC codes.
  - icd_ndc: two ICD-9 codes plus the six NDC codes.
  - hcpcs_lab: the HCPCS codes plus two LOINC codes.
- Variants:
  - cur: the current SQL.
  - none: the joins read an empty concept table. This shows the cost of the
    joins. It changes output, because the names are empty.
  - used: the joins read only the concept rows that the data references. Output
    is identical. Building that table took 15 s, once for the data set.
  - ingids: the ingredient-name join reads only the concept IDs that the leaf
    selects. Output is identical. The dose-unit join is unchanged.
  - sj: each observations scan keeps only cohort persons before the joins.
  - sj_used: sj and used together.
- Each variant ran 6 times. The tables use the median of runs 2 to 6.
- Output: each variant was compared with cur by `EXCEPT ALL` in both
  directions.
- A hospitalization statement was also tried. It failed, because the SEER files
  have no `admission_detail_id` column, so hospitalization was not measured.

## Results

Median time of cur in seconds, and every other variant as a fraction of cur:

| statement | cohort | rows      | cur s | none | used | ingids | sj   | sj_used |
| --------- | ------ | --------- | ----- | ---- | ---- | ------ | ---- | ------- |
| ndc       | 5k     | 7,108     | 1.13  | 0.45 | 0.38 | 0.67   | 1.57 | 0.46    |
| ndc       | 50k    | 68,344    | 0.98  | 0.49 | 0.39 | 0.76   | 1.06 | 0.50    |
| hcpcs_ndc | 5k     | 10,950    | 2.56  | 0.44 | 0.32 | 0.60   | 0.82 | 0.32    |
| hcpcs_ndc | 50k    | 98,538    | 2.44  | 0.34 | 0.35 | 0.68   | 1.41 | 0.41    |
| icd_ndc   | 5k     | 228,939   | 3.25  | 0.43 | 0.31 | 0.56   | 0.64 | 0.25    |
| icd_ndc   | 50k    | 2,265,824 | 3.66  | 0.53 | 0.41 | 0.64   | 0.70 | 0.36    |
| hcpcs_lab | 5k     | 3,842     | 1.35  | 0.44 | 0.43 | -      | 1.29 | 0.67    |
| hcpcs_lab | 50k    | 30,194    | 1.62  | 0.37 | 0.37 | -      | 0.83 | 0.39    |

- The joins cost about half to two thirds of each statement. The cost does not
  grow with the cohort, because DuckDB builds a hash table over the whole
  concept table for each join.
- used removes all of that cost with identical output.
- ingids removes about half of the drug-join cost. It does not help the
  dose-unit or lab joins.
- sj does not help on DuckDB. It was sometimes slower, because the cost is on
  the concept side of the join, not in the number of event rows.

## Errors in the summaries

There are two summaries of the same run log. They disagree on the sj_used
rows:

- The first summary (06:13) marks every sj_used row as DIFF. The second (06:16)
  marks every one as identical. The logs do not show why. The seed does not
  report sj_used.
- The second summary gives 0.23 s and 0.18 s for hcpcs_lab sj_used (5k and
  50k). The raw run log gives 0.91 s and 0.63 s (fractions 0.67 and 0.39),
  which the table above uses. The 0.18-0.23 s values match no logged run. The
  seed called those values "unexplained, treat as noise". They are most
  probably an error in the second summary.

## Follow-up: t_shank's measurement of a cut-down table on a real export

The t_shank session measured the same idea on 2026-10-15 and relayed the
result. These are t_shank's numbers, recorded in t_shank seed `t-shank-ucq`.
Export `f4f10fdf` on a MarketScan Medicaid data set, DuckDB, conceptql
`64447c52`. The cut-down table had 57,715 of 10,971,106 concept rows and
built in 0.4 s. 416 name joins were rewritten.

| arm                    | runs | SQL phase, minutes (median, range) |
| ---------------------- | ---- | ---------------------------------- |
| production, unsliced   | 7    | 10.4 (10.0-11.8)                   |
| slice                  | 4    | 5.0 (4.9-5.2)                      |
| slice + cut-down table | 3    | 3.6 (3.4-3.6)                      |

The cut-down table saved 1.4 minutes, about 0.2 s per rewritten join. All 236
output column hashes and the row counts were identical across all 21 runs.

## Conclusion and decision

- Ryan sent option (b), a cut-down concept table that ships with each data set,
  to roobetl (roobetl seed `roobetl-825`).
- Ryan ruled "C please" on 2026-10-15: conceptql builds the cut-down table once
  for each Database (option c). Options (a) (ingids) and (d) were dropped.
- Shipped in `e1c308a1` (bead `conceptql-auu`): the Database option
  `name_concepts_table:` and `Database#create_name_concepts_table`.

## Sources

Logs in the primary checkout on titan, under `claude_stuff/`:

- `concept-joins-run-20261015-060748.log`: every timed run except ingids.
- `concept-joins-run-ingids-20261015-061517.log`: the ingids runs.
- `concept-joins-summary-20261015-061357.log` and
  `concept-joins-summary-20261015-061616.log`: the two summaries.
- `concept-joins-setup-20261015-060705.log`: the build of the used-concepts
  table.
- `concept-joins-vocabcounts-20261015-060500.log` and
  `concept-joins-topcodes-20261015-060517.log` hold data-level counts of the
  confidential data set. They were used to choose the statements. Nothing from
  them is in this report.
- The scripts were in the session scratchpad (`exp2`), which is gone.
- Seed `conceptql-8u6`, sections "Option 2 measured on DuckDB, 2026-10-15" and
  "Option (c) measured by t_shank on a real export, 2026-10-15".
