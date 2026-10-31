# Per-operator annotate on algorithm ac4efe58, 2026-10-30 (bead conceptql-ahg5)

**Answer:** Caching `source_vocabulary_ids` in the gdm data model made the
per-operator annotate of `ac4efe58` 17% faster: 35.85 s to 29.86 s (medians).
The normal one-query annotate did not change: 1.83 s and 1.85 s, which is
noise. The generated SQL is byte-identical. The change is commit `17729407`
(merged in `82868b2d`).

## Question

The profile of 2026-10-30 (`annotate-profile-ac4efe58-2026-10-30.md`) found
hot spots on the per-operator counting path. That path still runs on Spark,
with forced temp tables, and for statements that one query cannot count. Ryan
ruled "Fix the hot spot": compare CTE names as strings in the CTE sort, and
cache two values that were computed again on every call.

When the bead started, bead `conceptql-6cz` had already rewritten the CTE sort
to compare quoted names as strings. So the sort hot spot was gone. A new
stackprof run on the bead's base put `Gdm#source_vocabulary_ids` at 20.5% of
the per-operator CPU samples. The bead cached that value. It kept the second
`Operator#evaluate` in `OneQueryCounts#build_dataset`, because reusing the
first one would rename the root CTEs and change the SQL.

## Setup

- **Host:** titan (2 x Xeon E5-2690 v2, 40 logical CPUs).
- **Code measured:** "base" is a copy of `lib/` from main at `a1c6b5b0`
  (conceptql 0.5.0 plus the unreleased round, with `c7a5eeb4` in it). "new" is
  the bead's worktree `lib/`, which became `17729407`.
- **Statement and data:** production algorithm `ac4efe58` on
  native_sample_5000, the SEER-Medicare sample (DuckDB, gdm_wide, 5,000
  patients, 7.8M observation rows), attached read-only.
- **Software:** Ruby 3.4.8, DuckDB 1.5.6 (libduckdb from
  `~/.cache/conceptql/libduckdb/v1.5.6`), duckdb gem 2.0.0.1, sequel 5.109.0,
  sequel-duckdb 0.4.2, stackprof 0.2.28.
- **titan-lock:** held. Each of the 12 measured iterations was one `perf` lock
  holder, and all returned rc=0, so none was disturbed. Three iterations waited
  4 to 6 minutes for the lock while another session's perf job and this
  bead's own test suites ran. The waits are inside the logged windows, not
  inside the timings.
- **Other load (`below`):** machine CPU use inside the 12 iterations had a
  median of 23%, a 90th percentile of 36% and a maximum of 47%. That includes
  the benchmark (up to 8 DuckDB threads, 20%). The load was light. Over the
  whole window from 20:39:58 to 21:03:09 the mean was 31% and the maximum 84%.

## Method

- One Ruby process per iteration. Each process warmed up once (one
  `Query#sql`), then ran annotate with counts twice. `GC.start` ran before each
  timing.
- Two modes: "one" is the normal path. "perop" forces one-query counting off,
  so every operator counts with its own query.
- Each annotate also recorded the time in `Scope#sorted_ctes_with_sql`
  ("sort") and the time and number of SQL statements sent to DuckDB ("db"),
  from the Sequel logger.
- 3 rounds. The order of base and new alternated on each round. Each round ran
  both modes for both variants, so each cell has 6 values.
- The counts were compared by SHA-256 digest. All 12 iterations gave the same
  digest.
- The SQL of every test statement was dumped before and after the change
  (Postgres and DuckDB) and compared. It was identical.

## Results

Medians of 6 annotate runs, with the range in brackets.

| mode  | variant | annotate wall            | CTE sort | DuckDB time | statements sent |
| ----- | ------- | ------------------------ | -------- | ----------- | --------------- |
| one   | base    | 1.825 s [1.716-1.885]    | 0.162 s  | 1.058 s     | 94              |
| one   | new     | 1.850 s [1.612-2.079]    | 0.179 s  | 1.077 s     | 94              |
| perop | base    | 35.850 s [33.717-36.354] | 7.871 s  | 7.838 s     | 188             |
| perop | new     | 29.858 s [27.072-30.447] | 8.178 s  | 8.236 s     | 188             |

- The per-operator path fell by 6.0 s (17%). The CTE sort and the DuckDB time
  did not change, so the saving is in other Ruby work.
- The per-operator path is still about 16 times slower than the one-query
  path.
- Compared with the profile on `8a1aaa85` (78-83 s per operator, 29.4 s in the
  sort), the base here is already much faster. Most of that came from bead
  `conceptql-6cz`. The two runs are not a controlled comparison: the profile
  ran under much heavier machine load.

## Conclusion and decision

- Merged as `82868b2d`. The full local checks passed (1,037 runs per
  configuration, 0 failures).
- Not ruled, recorded for later: the per-operator path is quadratic. Each
  operator's count runs `with_ctes` again and evaluates its whole subtree
  again. After this bead, `evaluate` is 32% of the per-operator CPU samples. A
  large speed-up needs evaluation reuse across counting queries. Seed
  `conceptql-dkc` (Spark counting) now holds that question. Nobody counts per
  operator in production today.

## Sources

Logs in the primary checkout on titan, under
`claude_stuff/worktrees/conceptql-ahg5/` (copied from the removed worktree):

- `perf-ab-20261030-203958.log` and `.jsonl`: the measured A/B run.
- `perf-ab-20261030-203612.log` and `.jsonl`: a first attempt. Its base
  iterations failed with rc=1, so it holds only "new" values. It is not used
  above.
- `perf-summary-20261030-210313.log`: the summary table above.
  `perf-summary-20261030-210311.log` is an identical copy.
- `below-ab-window-20261030-210321.log`: machine CPU over the A/B window.
- `prof-perop-lib-748458.dump` and `prof-perop-lib-833221.dump`: stackprof
  dumps of the per-operator path.
- `sql-identity-*.log`, `sql-compare-20261030-203602.log`: the SQL identity
  check.
- Scripts: `perf/` (`bench.rb`, `run_ab.zsh`, `summarize.rb`, `split_*.rb`).
  The base `lib/` copy is in `baseline/`.
