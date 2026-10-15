---
id: conceptql-3wy
title: 'DuckDB merges date + 30 days with date + 1 month in one SELECT list: report it upstream, and where does a workaround belong?'
status: captured
type: question
created_at: 2026-10-15T02:56:27.272642+00:00
updated_at: 2026-10-15T02:56:36.176883+00:00
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

## Not ruled

Ryan decides both questions.

1. **Report the defect to duckdb/duckdb?** This means a public GitHub issue with the reproduction above. Recommendation: report it, after a check that it still happens on the newest DuckDB release.
2. **Where should a general workaround go, if anywhere?**
   - (a) sequel-duckdb emits date arithmetic in a form that DuckDB cannot merge. One example is to wrap each month interval in a cast that DuckDB cannot fold. This protects every caller, but it is a guess about the optimizer until it is tested.
   - (b) conceptql's DateAdjuster or its DuckDB adapter does the same. This protects only conceptql.
   - (c) No workaround. Wait for an upstream fix and keep the one_in_two_out split.
     Recommendation: (c) until the upstream answer arrives, because no production path runs on DuckDB.
