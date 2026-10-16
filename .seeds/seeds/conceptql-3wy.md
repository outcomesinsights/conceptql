---
id: conceptql-3wy
title: 'DuckDB merges date + 30 days with date + 1 month in one SELECT list: report it upstream, and where does a workaround belong?'
status: captured
type: question
created_at: 2026-10-15T02:56:27.272642+00:00
updated_at: 2026-10-16T13:28:21.437038+00:00
---

## The defect

DuckDB gives a wrong date when one expression list contains both `date + INTERVAL 30 DAY` and `date + INTERVAL 1 MONTH`. Both expressions return the value of the one that comes first. The bead conceptql-a4j records the defect itself. This seed holds the two open decisions about it.

Found 2026-10-14 during the one_in_two_out single-read rewrite (bead conceptql-7qo, seed conceptql-x9w). The differential check against the old SQL failed on DuckDB only, for minimum gap 30d with maximum gap 1m.

DuckDB compares intervals by a total that counts one month as 30 days ([DuckDB interval docs](https://duckdb.org/docs/current/sql/data_types/interval)). So `INTERVAL 30 DAY = INTERVAL 1 MONTH` is true. The optimizer evidently uses that comparison to treat the two expressions as one duplicate expression. The same happens for 60 days and 2 months, and for 360 days and 1 year.

Reproduced 2026-10-14 with the DuckDB CLI v1.5.6. The gem used libduckdb 1.5.5 and showed the same defect.

```
with t as (select date '2008-05-17' d)
select d + interval 30 day as a, d + interval 1 month as b from t
-- a = 2008-06-16, b = 2008-06-16   (b should be 2008-06-17)

with t as (select date '2008-05-17' d)
select d + interval 1 month as b, d + interval 30 day as a from t
-- b = 2008-06-17, a = 2008-06-17   (a should be 2008-06-16)

with t as (select date '2008-05-17' d, date '2008-06-17' c)
select (c >= d + interval 30 day and c <= d + interval 1 month) as both_in_one from t
-- false   (should be true)
```

A search on 2026-10-14 found no existing DuckDB issue for this. That search was one query, so it is not proof that no issue exists.

## Effect on conceptql

- one_in_two_out is protected. Commit d9371d12 computes the upper bound in its own SELECT level, which DuckDB does not merge with the lower bound.
- Other operators are not protected. Any statement on DuckDB that puts two such gaps in one expression list can return wrong dates or rows. Possible examples are time_window with start 30d and end 1m, and Nth Occurrence with at_least 30d and within 1m. Neither example was tested.
- Postgres is not affected. The 746-case differential check passed on Postgres. Spark is not known to be affected, and production runs Spark.

## Not ruled (as of the morning of 2026-10-14; see the RULED section below)

Ryan decides both questions.

1. **Report the defect to duckdb/duckdb?** This means a public GitHub issue with the reproduction above. Recommendation: report it, after a check that it still happens on the newest DuckDB release.
2. **Where should a general workaround go, if anywhere?**
   - (a) sequel-duckdb emits date arithmetic in a form that DuckDB cannot merge. One example is to wrap each month interval in a cast that DuckDB cannot fold. This protects every caller, but it is a guess about the optimizer until it is tested.
   - (b) conceptql's DateAdjuster or its DuckDB adapter does the same. This protects only conceptql.
   - (c) No workaround. Wait for an upstream fix and keep the one_in_two_out split.
     Recommendation: (c) until the upstream answer arrives, because no production path runs on DuckDB.

## RULED 2026-10-14, and findings from the same day

Ryan: "production is about to run on duckdb, so put a workaround in sequel-duckdb please." This replaces two earlier positions in this seed. "Production runs Spark" is no longer the plan. The recommendation (c), no workaround, is withdrawn. Option (a), a workaround in sequel-duckdb, is ruled. Whether to report the defect upstream is still not ruled.

### Cause

Two optimizer rules cause the merge together. `expression_rewriter` folds `INTERVAL 30 DAY` and `INTERVAL 1 MONTH` into interval constants. `common_subexpressions` then compares those constants with DuckDB's interval equality, in which 1 month equals 30 days, and computes only one of the two expressions. Disabling either rule gives the correct result for the SELECT-list case.

### A settings workaround is not enough

With `SET disabled_optimizers TO 'common_subexpressions'`, aggregates are still merged:

```
with t as (select date '2008-05-17' d)
select max(d + interval 30 day), max(d + interval 1 month) from t
-- 2008-06-16, 2008-06-16 with common_subexpressions disabled
```

Other rules that compare expressions were not all traced. Disabling them would also slow every query.

### The SQL form that works

Write month and year intervals as a subtraction of the negated value, and keep the other units as additions:

```
add 1 month  -> d - INTERVAL (-1) MONTH
sub 1 month  -> d - INTERVAL (1) MONTH
add 30 days  -> d + INTERVAL 30 DAY
sub 30 days  -> d + INTERVAL (-30) DAY
```

A `-` node then always holds a month constant, and a `+` node always holds a day or time constant. So two expressions can be judged equal only when their intervals really are equal.

This form was tested on DuckDB v1.5.6 in nine query shapes. The shapes were the SELECT list, AND in one expression, WHERE, CASE, aggregates, GROUP BY, ORDER BY, window PARTITION BY and a scalar subquery. The form was tested with and without conceptql's `cast(cast(... as timestamp) as date)` wrapper. All results were correct. Month-end values do not change: 2008-03-31 minus 1 month is 2008-02-29, and plus 1 month is 2008-04-30.

Integer days (`d + 30`) also avoid the defect. They work only for DATE input, so they were not chosen.

The form does not fix one residual case. A DAY interval and a time interval of equal length, such as 1 day and 24 hours, can still merge. That changes results only for TIMESTAMPTZ values across a daylight-saving change. conceptql uses only years, months and days.

### Handoff

The work was handed on 2026-10-14 to the live sequel-duckdb session, with the facts above. It changes `date_add_sql_append` in `lib/sequel/adapters/shared/duckdb.rb`. conceptql then needs a Gemfile.lock bump and a DuckDB suite run to pick the change up. Bead conceptql-a4j tracks that conceptql side.

No DuckDB issue was found for this defect. One web search and three GitHub issue searches were done on 2026-10-14.

## UPDATE 2026-10-14 evening: sequel-duckdb fix verified from conceptql

sequel-duckdb commit c139c5e (bead sequel-duckdb-ux7, closed) writes YEAR and MONTH intervals as a subtraction of the negated value. It is not pushed, so conceptql tested it through a temporary bundler local override and then restored Gemfile.lock.

- The conceptql DuckDB suite passed: 529 runs, 1913 assertions, 0 failures, 0 errors (log claude_stuff/test-logs/focused/duckdb-local-seqduck-suite-20261014-200854.log).
- The one_in_two_out differential harness ran 946 cases. Old and new operators gave identical results in every case that compiles. The old operator puts 30d and 1m in one SELECT list and differed on DuckDB before the fix, so this shows the fix works on SQL that conceptql generates. The other 88 cases use the invalid gap `e`, which both operators reject (log claude_stuff/oito-diff-duckdb-local-seqduck-20261014-200854.log).

Remaining: Ryan decides when sequel-duckdb is pushed. After that, conceptql bumps sequel-duckdb in Gemfile.lock and closes bead conceptql-a4j. Reporting upstream is still not ruled.

RULED 2026-10-16: Ryan, on whether conceptql reports the defect to the DuckDB project: "that's sequel duckdb's issue, not yours". conceptql does not report it. The workaround and any upstream report belong to sequel-duckdb.
