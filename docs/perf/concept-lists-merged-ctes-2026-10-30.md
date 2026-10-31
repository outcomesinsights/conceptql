# Merged CTEs and concept lists sent once, 2026-10-30 (bead conceptql-6cz)

> **Re-measured 2026-10-31:** [concept-list-threshold-2026-10-31.md](concept-list-threshold-2026-10-31.md)
> measured the shipped threshold of 1,000 items in one interleaved run. On
> Postgres, planning of `ac4efe58` fell from 480 ms (`e2e11ed5`) to 152 ms.
> The 2-item result below was caused by the Postgres JIT, not by a better plan.

**Answer:** Merging identical CTEs cut the SQL of algorithm `ac4efe58` from 264
to 205 CTEs and from 237 KB to 165 KB on DuckDB. DuckDB planning of the plain
query fell from 0.81 s to 0.57 s (30%). Annotate with counts fell from 2.7 s to
2.0 s. On Postgres, planning of `ac4efe58` fell from 485 ms to about 155 ms,
mostly because long concept-ID lists are now sent once. Rows and counts did not
change. The change is commit `c7a5eeb4`.

## Question

The profile of 2026-10-30 (`annotate-profile-ac4efe58-2026-10-30.md`) showed
that DuckDB planning was 70-75% of the remaining time. Ryan ruled "Do the
concept-list idea" (seed `conceptql-ktc`). The bead asked two things: (a) send
each distinct concept-ID list once, instead of an `IN (...)` copy in every CTE,
and (b) merge CTEs with identical SQL. The rule was: adopt only if planning
time drops on both DuckDB and Postgres without a latency regression.

## Setup

- **Host:** titan (2 x Xeon E5-2690 v2, 40 logical CPUs).
- **Code measured:** "base" is a copy of `lib/` from main at `e2e11ed5`
  (conceptql 0.5.0). "final" is the bead's worktree `lib/`, which became
  `c7a5eeb4`. Both ran in one checkout, selected by `$LOAD_PATH`.
- **Software:** Ruby 3.4.8. DuckDB 1.5.6 (libduckdb from
  `~/.cache/conceptql/libduckdb/v1.5.6`), duckdb gem 2.0.0.1, sequel 5.109.0,
  sequel-duckdb 0.4.2. PostgreSQL 18.6 in the `test_data.jumper` image pinned by
  digest in `docker-compose.yml`. DuckDB ran with threads=8.
- **Data sets:**
  - "seer": `ac4efe58` on native_sample_5000, the SEER-Medicare sample (DuckDB,
    gdm_wide, 5,000 patients, 7.8M observation rows, attached read-only).
  - "pg": the Postgres `test_data` fixture (gdm_wide, search path
    `wide,slim,ohdsi_vocabs`, lexicon cache on). It ran the 8 test statements
    with the largest SQL, plus `ac4efe58`.
  - "duckfix": the same 8 test statements on the DuckDB test fixture
    `synpuf_test_data.duckdb` (a read-only copy).
- **titan-lock:** held. Every iteration ran as one `perf` lock holder. The lock
  log shows 70 iterations named `conceptql-6cz-perf`, all rc=0. None was
  disturbed. Some iteration windows in the logs are long because they include
  time spent waiting for the lock while test suites ran.

## Method

- seer: one process per iteration. It built the SQL, ran the plain query 3
  times (wall), profiled it 3 times with DuckDB's JSON profiler, ran annotate
  with counts 3 times, and profiled the one-query count statement 3 times.
  Planning is `planner + all_optimizers + physical_planner` from the profile.
  A SHA-256 digest of the result rows and of the counts checked equality. The
  logs hold only the digests.
- pg: `EXPLAIN (ANALYZE, SUMMARY)` of the plain query and of the count
  statement, 3 times after one warm-up. Planning and execution times come from
  the summary.
- duckfix: the same as seer, with DuckDB's profiler.
- Runs, all interleaved (each round runs every variant once):

| run            | time        | what                                                         | other load (median / p90 CPU)        |
| -------------- | ----------- | ------------------------------------------------------------ | ------------------------------------ |
| explore DuckDB | 06:32-06:51 | seer; base, merge, lists (min 2 items); 5 rounds x 3         | 58% / 86% (shared with the next run) |
| explore pg 1   | 06:40-06:53 | pg; base, merge, lists (min 2 items); 5 rounds x 3           | 55% / 79%                            |
| explore pg 2   | 06:54-07:12 | pg; merge and 4 list forms; 1-2 rounds x 3                   | 52% / 79%                            |
| final A/B      | 07:30-10:07 | seer, pg, duckfix; base and final; 4 rounds x 3              | 30% / 61%                            |
| threshold      | 10:08-10:11 | pg, 3 statements; list threshold 100 and 1,000; 4 rounds x 3 | 10% / 12%                            |

"Other load" is `below`'s machine CPU use, sampled only inside the lock
iterations of each run. It includes the benchmark itself (up to 8 DuckDB
threads, 20% of the machine). The exploratory runs had heavy other load. The
final A/B had moderate load, and the threshold run had almost none.

## Results: DuckDB, ac4efe58 on the SEER-Medicare sample (final A/B)

Medians over 12 values (4 for build time), with the range in brackets.

| measure                    | base (`e2e11ed5`)  | final              | change |
| -------------------------- | ------------------ | ------------------ | ------ |
| SQL size                   | 237 KB             | 165 KB             | -30%   |
| CTEs / IN lists            | 264 / 99           | 205 / 94           |        |
| SQL build                  | 1.06 s [0.97-2.57] | 1.19 s [0.78-1.19] | noise  |
| plain query wall           | 1.23 s [0.98-2.19] | 0.84 s [0.66-0.98] | -31%   |
| plain query latency        | 1.08 s [1.02-1.27] | 0.86 s [0.69-1.11] | -21%   |
| plain query planning       | 0.81 s [0.76-0.99] | 0.57 s [0.48-0.77] | -30%   |
| annotate with counts, wall | 2.72 s [2.50-3.53] | 2.03 s [1.76-2.93] | -25%   |
| count statement size       | 270 KB, 265 CTEs   | 198 KB, 206 CTEs   |        |
| count statement latency    | 1.62 s [1.47-2.97] | 1.22 s [1.02-1.54] | -24%   |
| count statement planning   | 1.25 s [1.13-2.56] | 0.90 s [0.73-1.12] | -28%   |
| row digest / count digest  | same               | same               |        |

On this data set no concept-ID list in `ac4efe58` has more than 35 items. So
the list change does not apply here, and the whole DuckDB gain comes from
merging identical CTEs (59 of 264 CTEs were duplicates).

The earlier exploratory run, under heavier load, measured base planning at
1.09 s and merge-only planning at 0.61 s. The direction is the same.

## Results: Postgres test_data (final A/B, plain query)

Median planning and execution in ms, 12 values each.

| statement                                   | SQL KB base → final | plan base → final | exec base → final |
| ------------------------------------------- | ------------------- | ----------------- | ----------------- |
| `ac4efe58`                                  | 970 → 257           | 485.2 → 151.9     | 2,594 → 2,493     |
| complex/crit_out_of_order_ctes              | 232 → 50            | 133.2 → 10.8      | 8.8 → 18.4        |
| complex/count_required_columns              | 153 → 68            | 121.5 → 37.4      | 40.7 → 37.5       |
| hospice/crit_test_drug_info_works           | 53 → 52             | 30.0 → 27.2       | 2.5 → 2.5         |
| co_reported/crit_somehow_bad_columns        | 116 → 103           | 35.7 → 9.7        | 32.8 → 45.0       |
| recall/crit_1                               | 116 → 41            | 66.4 → 4.4        | 2.1 → 6.7         |
| one_in_two_out/…two_separate_windows        | 118 → 43            | 46.8 → 6.4        | 4.2 → 6.3         |
| trim_date_start/…two_separate_scope_windows | 10 → 6              | 2.2 → 1.3         | 6.1 → 3.3         |
| union/crit_somehow_bad_sql                  | 7 → 7               | 1.5 → 1.2         | 0.5 → 0.5         |

The count statements moved the same way. One exception: the hospice count
statement's execution went from 14.6 ms to 35.9 ms. The threshold run below
explains it.

## Results: DuckDB test fixture (final A/B, plain query)

| statement                            | plan ms base → final | exec ms base → final |
| ------------------------------------ | -------------------- | -------------------- |
| complex/crit_out_of_order_ctes       | 345.2 → 56.5         | 97.6 → 65.8          |
| complex/count_required_columns       | 304.8 → 103.5        | 5,678 → 2,778        |
| hospice/crit_test_drug_info_works    | 123.2 → 123.5        | 4,975 → 4,949        |
| co_reported/crit_somehow_bad_columns | 154.2 → 98.0         | 101.5 → 70.9         |
| recall/crit_1                        | 185.1 → 45.6         | 72.2 → 57.1          |
| one_in_two_out/…                     | 193.8 → 48.0         | 67.0 → 52.7          |
| trim_date_start/…                    | 12.1 → 7.8           | 13.4 → 13.0          |
| union/crit_somehow_bad_sql           | 10.5 → 12.2          | 11.0 → 11.3          |

The small union statement planned 1.7 ms slower. Its count statement planned
14.9 → 17.6 ms. These differences are a few milliseconds and within the run
to run spread.

## Results: the form of the list CTE (exploratory runs, Postgres)

- Lists of 2 or more items as materialized CTEs ("lists", min 2) gave the
  lowest planning times. But they made the hospice statement's execution go
  from 2.6 ms to 554 ms, and the union count statement's from 1.8 ms to 20 ms.
- A materialized CTE planned much faster than a non-materialized one. For
  `ac4efe58` at a 100-item threshold: materialized 178 ms, not materialized
  543 ms, plain `VALUES` without `MATERIALIZED` 258 ms.
- **Not followed up:** the 2-item arm ran `ac4efe58` on Postgres about 30 times
  faster (exec 99 ms against 3,190 ms; count statement 127 ms against 4,165
  ms). The non-materialized 2-item arm did the same (114 ms). The shipped
  threshold of 1,000 does not keep this. The cause was not investigated.

## Results: list threshold, 100 against 1,000 items (Postgres)

| statement                            | threshold | plan ms | exec ms | count plan ms | count exec ms |
| ------------------------------------ | --------- | ------- | ------- | ------------- | ------------- |
| hospice/crit_test_drug_info_works    | 100       | 29.3    | 2.4     | 33.6          | 36.6          |
| hospice/crit_test_drug_info_works    | 1,000     | 29.8    | 2.4     | 34.2          | 14.4          |
| co_reported/crit_somehow_bad_columns | 100       | 11.1    | 46.2    | 13.0          | 66.7          |
| co_reported/crit_somehow_bad_columns | 1,000     | 11.7    | 43.8    | 12.9          | 59.2          |
| `ac4efe58`                           | 100       | 151.6   | 2,356   | 175.6         | 3,535         |
| `ac4efe58`                           | 1,000     | 156.0   | 2,384   | 178.0         | 3,299         |

## The final A/B did not measure the shipped threshold

The SQL sizes in the final A/B match the 100-item arm of the threshold run
exactly (for example 256,078 bytes for `ac4efe58` on Postgres). So the final
A/B measured a list threshold of 100 items. The commit ships 1,000. The
consequences:

- DuckDB `ac4efe58`: no effect, because no list reaches 100 items.
- Postgres and the DuckDB test fixture: the final A/B numbers describe the
  100-item threshold. Only the 3 statements of the threshold run were measured
  at 1,000.
- The commit message's "485 to 156 ms" takes the base from the final A/B and
  the 156 ms from the threshold run, which ran 2 hours later under less load.
  The final A/B itself measured 485 to 152 ms at 100 items.
- The commit message says that no test statement is slower in planning plus
  execution. That is true for the 3 statements measured at 1,000. At 100 items
  it was false for the hospice count statement.

## Conclusion and decision

- The bead's rule was met: planning dropped on both DuckDB and Postgres, and
  the sampled latencies did not regress at the shipped threshold.
- Shipped in `c7a5eeb4` (merged in `5ba8c020`): identical CTEs merge, and an
  `IN` or `NOT IN` list of 1,000 or more integers reads one materialized
  `VALUES` CTE per distinct list. The threshold of 1,000 was chosen because 100
  made the hospice count statement 2.5 times slower in execution.
- Spark follow-ups: beads `conceptql-mmm` and `conceptql-qqy`, and the fix
  `4fae5a15` (keep a long `IN` list in a Spark SELECT list).

## Sources

Logs in the primary checkout on titan, under
`claude_stuff/worktrees/conceptql-6cz/` (copied from the removed worktree; the
paths inside the logs still name `.claude/worktrees/conceptql-6cz/`):

- Final A/B: `perf-final-20261030-073017.log`, `perf-final-20261030-073017-duckdb.jsonl`,
  `-pg.jsonl`, `-duckfix.jsonl`, summary `summary-final-20261030-100717.log`.
- Threshold: `perf-thresh-20261030-100803.log` and `.jsonl`, summary
  `summary-thresh-20261030-101144.log`.
- Exploratory: `perf-duckdb-20261030-063244.*` (summary
  `summary-duckdb-20261030-065128.log`), `perf-pg-20261030-064049.*` (summary
  `summary-pg-20261030-065332.log`), `perf-pg-20261030-065433.*` (summary
  `summary-pg2-20261030-072020.log`).
- SQL shape of `ac4efe58`: `shape-20261030-062445.log`.
- `below` CPU: `below-duckdb-20261030-063244.csv`, `below-final-20261030-073017.csv`.
- Scripts: `perf/` (`bench.rb`, `pg.rb`, `duck_tests.rb`, `run_*.zsh`,
  `summarize.rb`, `lists_patch.rb`). The base `lib/` copy is in `baseline/`.
