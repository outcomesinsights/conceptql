# SQL formatter, 2026-10-28 (bead conceptql-9ux, seed conceptql-d16)

**Answer:** `Query#sql(:formatted)` was slow because it started one external
formatter process for each SQL statement. An in-process formatter (the Rust
`sqlformat` crate inside Ruby) formats all 78 statements of a big algorithm in
about 9 ms. End to end, `Query#sql(:formatted, :create_tables)` fell from about
8.3 s to about 0.13 s. conceptql 0.4.1 shipped the change (commit `c2686656`).

## Question

The JDE session reported that its slowest spec took 18.9 s. Of that,
`:formatted` cost 8.3 s for one algorithm with 78 statements. The questions
were: where does the time go, and which formatter should replace the external
processes?

## Setup

- **Host:** titan (2 x Xeon E5-2690 v2, 40 logical CPUs, 1.5 TB RAM).
- **Code measured:** conceptql 0.4.0, main at `74430844`. The fix is
  `c2686656`, released as 0.4.1 (`3e68755b`).
- **Input:** the 78 SQL statements of JDE's `spec/fixtures/conceptql/big_algo.json`,
  about 84 KB. They were generated with a Sequel mock database for Postgres and
  DuckDB, and with the Spark thrift server for Spark. No patient data is
  involved.
- **Tools:** Ruby 3.4.8. sql-formatter 15.9.0 (Node). pg_format 5.11.
  sqlformat from Python sqlparse 0.6.0. pg_query 6.2.5. niceql 0.6.2.
  anbt-sql-formatter 0.1.2. The `sqlformat` crate 0.5.0 (through the sleek_rb
  prototype, then sequel-sqlformat 0.1.0). The versions of the sleek and sqruff
  CLIs were not recorded.
- **titan-lock:** not held. The lock log has no entry from this session in the
  run window.
- **Other load (`below`):** machine CPU use from 10:41 to 11:25 had a median of
  13% and a 90th percentile of 36%. The machine was mostly idle. Each run timed
  one process, so this load matters little.

## Method

- The 8.3 s baseline is the JDE session's own measurement, inside the JDE
  container, where `sqlformat` (Python) is the formatter that conceptql chose.
- Each CLI formatter was timed two ways: one process for each of the 78
  statements (what conceptql 0.4.0 did), and one process for all statements.
- In-process formatters were timed in one Ruby process, best of 5.
- Correctness: for each output, a check confirmed that only whitespace changed
  (with keyword case kept), and that pg_query and sqlglot parse the same tree.

## Results

CLI formatters, all 78 statements:

| formatter     | 78 processes | 1 process for all |
| ------------- | ------------ | ----------------- |
| sql-formatter | 17.87 s      | 0.56 s            |
| pg_format     | 38.76 s      | 35.70 s           |
| sqlformat     | 8.02 s       | 1.39 s            |
| sleek         | 0.20 s       | 0.01 s            |
| sqruff        | 10.37 s      | 27.23 s           |

In-process formatters, all 78 statements:

| formatter                                     | time    | notes                                  |
| --------------------------------------------- | ------- | -------------------------------------- |
| `sqlformat` crate in Ruby (FFI prototype)     | 7.6 ms  | 78/78 same meaning (Postgres)          |
| pg_query 6.2.5 pretty deparse                 | 36.6 ms | fails on 4 DuckDB statements and Spark |
| niceql                                        | 310 ms  | from the seed only, no log             |
| anbt-sql-formatter                            | 2510 ms | from the seed only, no log             |
| sequel-sqlformat, dialect postgresql          | 8.8 ms  | only whitespace changed, 78/78         |
| sequel-sqlformat, dialect generic (DuckDB)    | 8.7 ms  | only whitespace changed, 78/78         |
| sequel-sqlformat, dialect generic (Spark SQL) | 8.4 ms  | only whitespace changed, 78/78         |

End to end, `Query#sql(:formatted, :create_tables)` with the sleek_rb prototype
took 0.127 s (best of 5), against about 8.3 s before.

## Conclusion and decision

- The cost was process start, not formatting. Each statement started up to 4
  `which` processes and 1 formatter process. pg_format is also slow in itself.
- Ryan ruled to wrap the Rust `sqlformat` crate in a gem. The gem became
  sequel-sqlformat, a Sequel extension. All four external formatters were
  removed, not kept as fallbacks.
- conceptql 0.4.1 calls `Sequel::SQLFormat.format`. The commit message records
  about 0.13 s for the 78-statement algorithm on Postgres, DuckDB and Spark.

## Sources

Logs in the primary checkout on titan:

- `claude_stuff/fmt-bench-20261028-104337.log` (CLI timings). The earlier
  `fmt-bench-20261028-104124.log` failed: the sql-formatter shim had no Node
  version.
- `claude_stuff/fmt-rust-20261028-104645.log` (sleek and sqruff).
- `claude_stuff/fmt-ruby-20261028-104629.log` (pg_query).
- `claude_stuff/fmt-ffi-20261028-105148.log` (crate through FFI, pg_query).
- `claude_stuff/fmt-e2e-20261028-110017.log` (end to end).
- `claude_stuff/fmt-sequel-sqlformat-20261028-112413.log` (the extension).
- Scripts and dumped statements: `claude_stuff/fmt/`.

The seed `conceptql-d16` holds the full deliberation. The bead
`conceptql-9ux` holds the defect.
