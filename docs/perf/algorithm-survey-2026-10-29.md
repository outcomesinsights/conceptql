# Production algorithm survey, 2026-10-29 (JDE seed jde-c0y.1)

**Answer:** On the 5,000-patient sample, almost every current production
algorithm builds and runs in well under 1 s. The median annotate with counts
took 0.058 s and the median plain query took 0.037 s. One algorithm, `ac4efe58`
(111 operators), was the exception: annotate took about 58 s, and most of that
time was in Ruby. On the full dataset, execution is the whole cost, and
statements with a `cpt_or_hcpcs "*"` wildcard took 5 to 17 minutes or ran out
of memory.

The JDE session ran this survey. Its raw logs are in the JDE repository, not
here. The records in this repository are the seeds `conceptql-ptn`,
`conceptql-643`, `conceptql-ktc` and `conceptql-nut`, which all quote the same
totals. JDE seed `jde-c0y.1` (rounds 3 and 4) holds the full write-up.

## Question

JDE plans to show per-operator counts on demand (seed `jde-c0y.1`). Ryan asked
to survey every algorithm in the algorithm database first, to find the slow
ones, and to look for optimizations.

## Setup

- **Host:** titan (2 x Xeon E5-2690 v2, 40 logical CPUs).
- **Code measured:** conceptql 0.4.1 (`3e68755b`), as bundled by JDE. In 0.4.1,
  annotate counts each operator with its own query (the per-operator path).
- **Statements:** all 1,259 current algorithm versions in the production
  algorithm database (`child_id IS NULL AND deleted_at IS NULL`): 826 Draft,
  360 Finalized and 73 Retired. They were read from a read-only copy.
- **Sample data set:** native_sample_5000, the SEER-Medicare sample
  (`gdm.duckdb`, 1.6 GB, gdm_wide, 5,000 patients, 7,785,687 observation rows),
  attached read-only. Its own OHDSI vocabulary tables served as the lexicon.
- **Full data set:** `seer_medicare_all_cancer_2024_enriched_20261027/gdm.duckdb`,
  417.1 GB, 1,747,534 patients, 2,043,400,528 observation rows, on spinning
  disks.
- **Software:** DuckDB 1.5.6, threads=8, memory_limit=8GB (some full-data runs
  used threads=32 and memory_limit=64GB). The Ruby version and the duckdb gem
  version were not recorded in the seeds.
- **titan-lock:** held. The sample survey ran as 7 `perf` iterations from 13:03
  to 13:30 (one failed with rc=1 and was run again). The full-data runs were 8
  `perf` iterations from 13:43 to 15:58. All were clean: no test suite forced
  its way in.
- **Other load (`below`):** machine CPU use inside the sample iterations had a
  median of 32% and a 90th percentile of 70% (maximum 99%). Inside the full-data
  iterations, the median was 48% and the 90th percentile 72%. These figures
  include the survey itself: 8 DuckDB threads are 20% of the machine, and 32
  threads are 80%. So other load was moderate and sometimes heavy.

## Method

- For each statement: today's `annotate` with counts, then the plain query
  (`Query#query` executed). Each was timed once.
- For `ac4efe58`, a second script wrapped `Sequel::Dataset#sql` to split the
  annotate time into database execution, SQL building and other Ruby.
- On the full data set, 15 statements ran: the 10 slowest by sample execution,
  `ac4efe58`, and 4 statements near the sample median. Only the plain query ran
  for most of them.

## Results: sample data set

Over the 1,256 statements that annotate without an exception:

| measure                    | median  | p90     | p99     | max     | sum     |
| -------------------------- | ------- | ------- | ------- | ------- | ------- |
| annotate with counts       | 0.058 s | 0.234 s | 1.005 s | 57.93 s | 200.7 s |
| plain query (1,253 ran ok) | 0.037 s | 0.123 s | 0.520 s | 2.293 s | 84.4 s  |

- Finalized algorithms: median 0.067 s, maximum 0.71 s.
- Only `ac4efe58` took more than 5 s. Its split:

```
ac4efe58 annotate 62.06 s = db exec 11.94 s + literalize 10.70 s (53,170 top-level selects, 2,988.6 MB of SQL) + other Ruby 39.42 s
19c6b6f9 annotate  2.12 s = db exec  1.20 s + literalize  0.30 s (1,588 top-level selects, 17.1 MB of SQL) + other Ruby 0.62 s
```

- The plain query of `ac4efe58` took 0.76 s to build and about 1.1 s to run.
  On DuckDB, about 0.8 s of that was query planning (seed `conceptql-ktc`).
- A `cpt_or_hcpcs "*"` wildcard sends about 2.1M rows through a `UNION` that
  removes duplicates. In one statement, that HASH_GROUP_BY step took 1.95 s of
  operator time. 10 of the 20 slowest plain queries contain a `"*"` wildcard.
- 7 statements failed or reported errors. Those are conceptql defects and JDE
  data problems, recorded in other seeds. They are not performance results.

## Results: full data set (plain query, threads=8, memory_limit=8GB)

| statements (operators)                                | sample exec | full exec                    | spill      |
| ----------------------------------------------------- | ----------- | ---------------------------- | ---------- |
| 4 near the sample median (1-3)                        | 0.02 s      | 0.03-0.66 s                  | 0          |
| `75cd0682` (4)                                        | 0.89 s      | 44 s                         | 2 GB       |
| `503e6b7e` (4)                                        | 0.43 s      | 50 s                         | 0          |
| `ac4efe58` (111)                                      | 1.08 s      | 127 s                        | 39 GB      |
| `fc9921b6` (1)                                        | 1.35 s      | 129 s                        | 65 GB      |
| 7 with a `cpt_or_hcpcs "*"` style wildcard (3-5 each) | 0.40-2.11 s | 318-1,044 s, 2 out of memory | 123-281 GB |

- SQL build time stayed under 1.3 s. Execution is the whole cost at full size.
- threads=32 with memory_limit=64GB made the wildcard statements only 1.1 to 3
  times faster (best 166 s). They still spilled 62 to 207 GB.
- Annotate with counts (0.4.1) on the full data set: under 0.2 s for the median
  statements, 549 s for `fdde7ce2`, and out of memory for `11aac29e`.

## What was later shown wrong

- The JDE write-up first estimated full-data times by scaling the sample times
  by file size (about 264 times). The full-data runs showed that this is wrong
  in both directions. Selective statements stay under 1 s. Statements without
  a wildcard grew 50 to 118 times. Wildcard statements grew 164 to 927 times.
- The JDE write-up first said that `Scope#sort_extracted_ctes` caused the 48 s
  of Ruby time in `ac4efe58`. The survey did not show that: it split the time
  only into SQL building (10.7 s) and other Ruby (39.4 s). The profile on
  2026-10-30 (`annotate-profile-ac4efe58-2026-10-30.md`) then measured
  `sort_extracted_ctes` at 29.4 s of the per-operator path.

## Conclusion and decisions

- Ryan ruled to file the findings as conceptql seeds (2026-10-29):
  `conceptql-643` (CTE sort cost), `conceptql-ktc` (send each concept list once,
  merge identical CTEs), `conceptql-nut` (UNION ALL where inputs cannot overlap)
  and several defect seeds.
- Ryan ruled that the wildcard fix (`conceptql-nut`) comes before the one-query
  counting mode. Bead `conceptql-5pz` built it (`493cd61b`): `cpt_or_hcpcs`
  joins its vocabulary branches with UNION ALL. The commit shows that EXPLAIN
  on the DuckDB fixture has no HASH_GROUP_BY for `cpt_or_hcpcs "*"` any more.
  No full-data timing after that change was found.
- One-query counting (bead `conceptql-z6k`, `741f84b4`) replaced the
  per-operator path on DuckDB and Postgres.
- `conceptql-ktc` became bead `conceptql-6cz`
  (`concept-lists-merged-ctes-2026-10-30.md`).

## Sources

- The seeds `conceptql-ptn`, `conceptql-643`, `conceptql-ktc` and
  `conceptql-nut` in this repository.
- JDE seed `jde-c0y.1`, rounds 3 and 4.
- Raw logs, in the JDE repository's `claude_stuff/algorithm-survey/`:
  `survey-20261029-130842.csv`, `run-20261029-130115/results.jsonl`,
  `fullsize-20261029-134246.csv` and the `fullrun-20261029-134246-t8` and
  `-t32` directories. This repository's `claude_stuff/` has no survey logs.
