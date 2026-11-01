# Concept-list threshold re-measured, 2026-10-31 (seed conceptql-5yq)

**Answer:** At the shipped threshold of 1,000 items, the concept lists cut the
Postgres planning of algorithm `ac4efe58` from 428 ms to 149 ms, and the
DuckDB planning on the test fixture from 1.81 s to 0.79 s. Rows and counts
did not change. On the Postgres test data, the plain query of `ac4efe58` is
not faster: execution grew by about the same amount that planning fell,
because Postgres JIT-compiles the query either way. The "30 times faster"
result with lists of 2 or more items was real, but its cause is JIT, not a
better plan. A threshold that low makes the plan's cost estimate fall below
`jit_above_cost` (100,000), so Postgres skips the 2.3 s JIT compile. No other
threshold was faster on every statement. 1,000 stays the best choice of the
thresholds measured.

## Question

The report of 2026-10-30 (`concept-lists-merged-ctes-2026-10-30.md`) found
three defects in the measurement of bead `conceptql-6cz`. Its final A/B
measured a threshold of 100 items, not the 1,000 that shipped. The commit's
"485 ms to 156 ms" took its two numbers from two different runs. And an
exploratory Postgres run with lists of 2 or more items ran `ac4efe58` in
99 ms against 3,190 ms, and nobody found out why. Ryan chose to re-measure
(seed `conceptql-5yq`):

1. Planning, execution and annotate at 1,000 items against the concept lists
   turned off, on Postgres and DuckDB.
2. The cause of the 2-item result, and a sweep of thresholds 2, 10, 100 and
   1,000.

## Setup

- **Host:** titan (2 x Xeon E5-2690 v2, 40 logical CPUs).
- **Code measured:** main at `a78d803d` (worktree `remeasure-5yq`). No lib
  code changed. Each measurement process set
  `ConceptQL::Scope::CONCEPT_LIST_MIN_ITEMS` to the variant's value before it
  built any SQL:
  - `off`: the threshold is 10^9, so no concept list is made. The merge of
    identical CTEs stays on.
  - `1000`, `100`, `10`, `2`: that threshold. `1000` is main as shipped.
  - `base`: the `lib/`, `config/` and `schemas/` of `e2e11ed5` (conceptql
    0.5.0 plus the round before `c7a5eeb4`), the base of the 2026-10-30
    report. Postgres only.
- **Software:** Ruby 3.4.8. PostgreSQL 18.6 in the `test_data.jumper` image
  pinned by digest in `docker-compose.yml` (its own container,
  `remeasure-5yq-test_data-1`, with the compose file's settings:
  `work_mem=4GB`, `shared_buffers=6GB`, no parallel workers, JIT at the
  PostgreSQL defaults: `jit=on`, `jit_above_cost=100000`,
  `jit_inline_above_cost` and `jit_optimize_above_cost` 500000). DuckDB 1.5.6
  (libduckdb from `~/.cache/conceptql/libduckdb/v1.5.6`), duckdb gem 2.0.0.1,
  sequel 5.109.0, sequel-duckdb 0.4.2, pg 1.7.0. DuckDB ran with threads=8.
- **Data sets:**
  - "pg": the Postgres `test_data` fixture (gdm_wide, search path
    `wide,slim,ohdsi_vocabs`, lexicon cache on). The 8 test statements of the
    6cz sweep, plus `ac4efe58`.
  - "fix": the same 8 test statements on the DuckDB test fixture
    `synpuf_test_data.duckdb` (a read-only copy, checksum verified).
  - "fixa": `ac4efe58` on the same DuckDB fixture. One of its lists has
    1,000 or more items (2,442 on Postgres), so the 1,000 threshold applies
    there.
  - "seer": `ac4efe58` on native_sample_5000, the SEER-Medicare sample
    (DuckDB, gdm_wide, 5,000 patients, attached read-only). Its lists have
    fewer than 100 items, so `off`, `1000` and `100` build identical SQL.
- **titan-lock:** held. Each iteration (one benchmark, one variant) was one
  `perf` lock holder. All 110 iterations of this session returned rc=0. No
  iteration returned 75, so no wrapped test suite ran during any of them.
- **Other load (`below`):** machine CPU use inside the 110 iterations had a
  median of 21%, a 90th percentile of 26% and a maximum of 47%. That includes
  the benchmark itself (up to 8 DuckDB threads, 20% of the machine). Over the
  whole window from 09:58 to 12:02 the median was 21% and the maximum 74%.
  The other load was light: agent sessions, a JVM and other Postgres
  containers. The load did not disturb the runs.

## Method

- One Ruby process for each iteration. For each statement it built the
  plain-query SQL and the one-query count statement, ran the plain query once
  as a warm-up and to record the row count and a SHA-256 digest of the rows,
  and then timed:
  - Postgres: `EXPLAIN (ANALYZE, SUMMARY)` of the plain query (one more
    warm-up) and of the count statement, 3 times each. Planning, execution
    and the JIT total come from the summary. "fetch" is the wall time of
    fetching the plain query's rows in Ruby, 3 times.
  - DuckDB: 3 fetches, then 3 runs each of the plain query and the count
    statement under DuckDB's JSON profiler. Planning is
    `planner + all_optimizers + physical_planner`. Execution is latency minus
    planning.
  - Annotate with counts (`Query#scope_annotate`, a new query each time), 3
    times. A digest of the counts checked equality.
- The logs hold only timings, SQL sizes, list counts, row counts and digests.
- Runs. The order of the variants reversed on each round.

| run  | time        | what                                                                                   | values per cell |
| ---- | ----------- | -------------------------------------------------------------------------------------- | --------------- |
| main | 10:09-12:01 | pg, fix, seer; `off`, `1000`, `100`, `10`, `2`; 4 rounds                               | 12              |
| jit  | 10:13-11:34 | pg; `base`, `off`, `1000`, `2` with JIT on and off, `100`, `10` with JIT off; 3 rounds | 9               |
| fixa | 10:13-11:03 | fixa; `off`, `1000`, `100`, `10`, `2`; 2 rounds of 2                                   | 4               |

"JIT off" ran `SET jit = off` on the connection. The three runs shared the
lock, so their iterations alternated and never overlapped. EXPLAIN
(ANALYZE, BUFFERS) of `ac4efe58` at `1000`, `2` and `off`, and of the
hospice statement at `1000` and `2`, ran once each under the lock at 10:08
and 10:14-10:38.

## Results: 1,000 against off

Medians in ms, with the range in brackets. "plan + exec" adds the two
medians.

### Postgres, ac4efe58 (main run, JIT on as the fixture is set)

| measure                     | off                 | 1000                |
| --------------------------- | ------------------- | ------------------- |
| SQL size / lists / IN lists | 894 KB / 0 / 90     | 246 KB / 1 / 64     |
| planning                    | 428 ms [421-721]    | 149 ms [140-155]    |
| execution                   | 2,095 [2,043-2,355] | 2,392 [2,281-2,891] |
| of which JIT                | 2,066               | 2,305               |
| plan + exec                 | 2,523               | 2,541               |
| fetch wall                  | 2,616 [2,550-2,807] | 2,541 [2,467-3,131] |
| count statement planning    | 464 [444-629]       | 169 [158-192]       |
| count statement execution   | 3,136 [2,925-3,375] | 3,327 [3,118-3,801] |
| annotate with counts        | 4,751 [4,524-5,384] | 4,497 [4,157-4,944] |
| rows / digests              | 68 / same           | 68 / same           |

The JIT compiled 1,639 functions at `1000` and 1,374 at `off` (from the
EXPLAIN runs), so the compile took about 240 ms longer. That cancels the
280 ms saved in planning.

With JIT off (jit run), the same statement planned in 429 ms at `off` and
152 ms at `1000`, and executed in 51 ms and 65 ms. Fetch wall fell from
571 ms to 234 ms, and annotate from 1,629 ms to 1,111 ms. Against `base`
(`e2e11ed5`, before merged CTEs and lists), planning fell from 480 ms
[447-682] to 152 ms [144-154] with JIT on, and from 459 ms to 152 ms with JIT
off.

### Postgres, the 8 test statements (main run, ms)

| statement                                   | KB off → 1000 | plan off → 1000 | exec off → 1000 | plan + exec | count plan + exec | annotate  |
| ------------------------------------------- | ------------- | --------------- | --------------- | ----------- | ----------------- | --------- |
| complex/crit_out_of_order_ctes              | 226 → 48      | 132 → 10.0      | 8.7 → 18.7      | 141 → 29    | 142 → 30          | 224 → 97  |
| complex/count_required_columns              | 140 → 66      | 103 → 38.9      | 32.0 → 37.7     | 135 → 77    | 138 → 82          | 262 → 195 |
| hospice/crit_test_drug_info_works           | 50 → 50       | 29.3 → 29.6     | 2.4 → 2.5       | same SQL    | same SQL          | 160 → 154 |
| co_reported/crit_somehow_bad_columns        | 112 → 101     | 34.5 → 10.3     | 31.2 → 43.8     | 66 → 54     | 83 → 72           | 167 → 162 |
| recall/crit_1                               | 113 → 40      | 63.4 → 4.2      | 2.0 → 6.8       | 65 → 11     | 66 → 13           | 106 → 54  |
| one_in_two_out/…two_separate_windows        | 115 → 42      | 44.8 → 6.1      | 4.0 → 6.2       | 49 → 12     | 48 → 13           | 98 → 62   |
| trim_date_start/…two_separate_scope_windows | 5.5 → 5.5     | 1.3 → 1.6       | 3.5 → 3.8       | same SQL    | same SQL          | 29 → 34   |
| union/crit_somehow_bad_sql                  | 6.9 → 6.9     | 1.7 → 2.0       | 0.6 → 0.7       | same SQL    | same SQL          | 32 → 36   |

Three statements have no list of 1,000 items, so their SQL is the same in
both variants, and their differences are run-to-run spread. In the five
others, execution rose by 2 to 13 ms and planning fell by more. No statement
is slower in planning plus execution, for the plain query or the count
statement. JIT did not run for any test statement at `off` or `1000`.

### DuckDB

| data set, statement | measure        | off                    | 1000                   |
| ------------------- | -------------- | ---------------------- | ---------------------- |
| fixa, ac4efe58      | planning       | 1,810 [1,692-2,132]    | 785 [699-815]          |
| fixa, ac4efe58      | execution      | 22,942 [19,696-23,122] | 20,124 [19,167-20,347] |
| fixa, ac4efe58      | count planning | 1,816 [1,670-2,025]    | 1,217 [1,068-1,383]    |
| fixa, ac4efe58      | annotate       | 23,141 [22,961-23,294] | 22,753 [22,332-23,070] |
| seer, ac4efe58      | planning       | 492 [449-666]          | 489 [447-992]          |
| seer, ac4efe58      | annotate       | 1,581 [1,511-1,909]    | 1,666 [1,534-2,064]    |

On seer the SQL is identical (161 KB, no list), so the difference is spread.
On the 8 test statements (fix), planning fell where a list applies:
crit_out_of_order_ctes 309 → 55 ms, count_required_columns 223 → 105 ms,
co_reported 139 → 90 ms, recall 175 → 45 ms, one_in_two_out 174 → 50 ms.
Execution stayed within the spread. Annotate fell or stayed the same. Rows
and counts were the same for every statement and variant.

## Results: why lists of 2 items made ac4efe58 30 times faster on Postgres

The earlier number was right. This run measured 86 ms at `2` against
2,392 ms at `1000` (the 6cz run: 99 ms against 3,190 ms). The cause is the
Postgres JIT:

| ac4efe58, plain query | plan cost estimate | JIT functions | JIT time | execution |
| --------------------- | ------------------ | ------------- | -------- | --------- |
| off                   | 121,948            | 1,374         | 2,074 ms | 2,131 ms  |
| 1000                  | 123,177            | 1,639         | 2,324 ms | 2,397 ms  |
| 2                     | 87,219             | none          | 0        | 92 ms     |

- The plans have the same shape. The JIT compiles expressions when they are
  first evaluated, so EXPLAIN shows its time inside the first node that ran:
  a `Memoize` with 73 loops in the first `icd9` CTE took 26.9 ms per loop,
  while its child index scan took 0.03 ms.
- With lists of 2 or more items, each `IN` list becomes a semi join on a
  `VALUES` CTE with an exact row count. The estimates of the `icd9` and
  `cpt4` CTEs fell (from 93,063 to 69,901 and from 21,484 to 7,500 cost
  units), so the total fell below `jit_above_cost` (100,000). Without JIT
  the query ran in 85 ms.
- With JIT off, the thresholds give nearly the same execution: 51 ms at
  `off`, 65 ms at `1000`, 67 ms at `100`, 82 ms at `10` and 84 ms at `2`.
  So no threshold gives a better plan. Only the JIT decision changes.
- The same effect works the other way. At `2`, the hospice statement's
  estimate rose from 5,801 to 141,685: an `OR` of two hashed list subplans
  has no row estimate, so Postgres guessed 14,382 rows. JIT then ran for
  495 ms on a query that executes in 3 ms (466 ms against 2.5 ms in the main
  run, and 786 ms against 14 ms for its count statement).

This fixture is small, so its real execution is short and the JIT compile is
most of the time. On production-size data the cost estimates are far above
100,000 with or without lists, so this effect does not carry over. Whether
the production Postgres servers run with JIT on was not checked.

## Results: threshold sweep

Postgres, JIT on (main run), medians in ms. The columns are `off`, `1000`,
`100`, `10`, `2`.

| statement, measure                    | off   | 1000  | 100   | 10    | 2     |
| ------------------------------------- | ----- | ----- | ----- | ----- | ----- |
| ac4efe58 plan + exec                  | 2,523 | 2,541 | 2,591 | 225   | 231   |
| ac4efe58 annotate                     | 4,751 | 4,497 | 4,707 | 1,347 | 1,328 |
| hospice exec                          | 2.4   | 2.5   | 2.4   | 2.6   | 466   |
| hospice count exec                    | 13.3  | 14.0  | 34.9  | 37.8  | 786   |
| co_reported exec                      | 31.2  | 43.8  | 43.6  | 64.6  | 65.6  |
| co_reported count exec                | 45.5  | 59.2  | 56.8  | 79.3  | 79.3  |
| union/crit_somehow_bad_sql count exec | 1.0   | 1.0   | 1.2   | 1.0   | 17.9  |
| crit_out_of_order_ctes plan           | 132   | 10.0  | 10.4  | 6.7   | 8.5   |

- On Postgres, `10` and `2` keep `ac4efe58` under the JIT cost limit. But
  `2` triggers JIT on the hospice statement, and `10`, `100` and `2` make the
  hospice count statement 2.5 to 56 times slower. `10` and `2` also make
  co_reported 50% slower. The hospice count slowdown at `100` and `10`, and
  the co_reported slowdown at `10`, also appear with JIT off, so they are real
  plan changes. Between `100` and `1000` the only difference is the hospice
  count statement (34.9 against 14.0 ms), the reason 1,000 was chosen.
- On DuckDB (fix), lower thresholds planned some small statements 9 to
  13 ms faster (recall 45 → 36 ms, one_in_two_out 50 → 40 ms at `2`). But
  `ac4efe58` planned slower as the threshold fell (fixa: 785, 828, 859,
  966 ms at `1000`, `100`, `10`, `2`), and the union statement executed
  11 → 17 ms at `2`. On seer, `2` was slower: planning 489 → 537 ms, count
  planning 735 → 849 ms, annotate 1,666 → 1,923 ms. `10` was within the
  spread.
- No threshold is faster than 1,000 on every statement. Rows and counts were
  the same at every threshold.

## Conclusion

- At 1,000, the concept lists cut planning on Postgres (`ac4efe58`: 428 to
  149 ms, from `base`: 480 to 152 ms) and on DuckDB (fixture: 1.81 to
  0.79 s). On the Postgres test data, the plain query's latency did not
  change, because the larger JIT compile used up the saving. With JIT off,
  the fetch wall fell from 571 to 234 ms.
- The 1,000 threshold stays. This report changes no code.
- The CHANGELOG's Postgres numbers now come from one interleaved run: 480 to
  152 ms (before: 485 to 156 ms from two runs). The DuckDB numbers in the
  CHANGELOG (0.81 to 0.57 s planning, 2.7 to 2.0 s annotate) stand: on the
  SEER-Medicare sample, 100 and 1,000 build identical SQL.
- The code comment on `CONCEPT_LIST_MIN_ITEMS` in `lib/conceptql/scope.rb`
  still cites 485 and 156 ms. Its 36 ms against 14 ms for the 231-item list
  matches this run (34.9 against 14.0 ms).
- **Proposal, not ruled:** on Postgres, JIT compile time was most of the
  execution time of every query whose cost estimate passed 100,000 on the
  test data. Before any change, check whether the production Postgres
  servers run with JIT on, and measure a production-size algorithm with JIT
  on and off. If JIT costs time there too, conceptql or Jigsaw could set
  `jit = off` on their connections. A lower concept-list threshold is not a
  fix for this, because it moves the cost estimate in both directions.

## Sources

Logs in the primary checkout on titan, under
`claude_stuff/worktrees/remeasure-5yq/` (copied from the worktree
`.claude/worktrees/remeasure-5yq/claude_stuff/`):

- Main run: `perf-main-20261031-100907.log` and `.jsonl`, summary
  `summary-main-20261031-120130.log`.
- JIT and base run: `perf-jit-20261031-101333.log` and `.jsonl`, summary
  `summary-jit-20261031-113447.log`.
- DuckDB fixture `ac4efe58`: `perf-fixa-20261031-101337.log` and `.jsonl`,
  summary `summary-fixa-20261031-110405.log`.
- EXPLAIN (ANALYZE, BUFFERS) plans and their SQL: `plans/` (test fixture
  only), with `explain-20261031-100800.log`, `explain-hospice-20261031-101405.log`,
  `plan-top-20261031-100920.log`, `plan-costs-20261031-101055.log`,
  `plan-costs-hospice-20261031-120448.log` and `plan-cost-jit-20261031-103848.log`.
- Machine load: `below-20261031-120139.csv` and `load-20261031-120139.log`.
- Smoke runs: `smoke-20261031-095903.log`, `smoke-base-20261031-101310.log`
  (`smoke-base-20261031-101258.log` failed before `config/` was copied).
- Scripts: `perf/` (`common.rb`, `pg.rb`, `duck.rb`, `explain.rb`,
  `run.zsh`, `run2.zsh`, `summarize.rb`, `plan_top.rb`, `plan_costs.rb`,
  `load.rb`). The `e2e11ed5` copy is in `baseline/`.
