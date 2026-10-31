---
id: conceptql-dkc
title: 'Spark counting: annotate falls back to one query per operator, which grows with the square of the statement size'
status: captured
type: exploration
created_at: 2026-10-31T12:50:58.523097+00:00
updated_at: 2026-10-31T12:50:58.523097+00:00
---

## Question

How should annotate count each operator on Spark, where one-query counting is turned off?

## What is true today (2026-10-31)

- OneQueryCounts counts every operator with one SQL statement, which needs MATERIALIZED CTEs so that each CTE runs once. Spark does not honor MATERIALIZED (`supports_materialized?` is false), so on Spark annotate falls back to one query per operator (`Operator#domain_counts`). The same fallback runs with forced temp tables, CONCEPTQL_AVOID_CTES, share_utilization, and uncountable operators.
- The fallback grows with the square of the statement size, in two ways. Ruby: each operator's count re-runs with_ctes and evaluates its whole subtree again (evaluate was 32% of the per-operator CPU samples after bead conceptql-ahg5). Database: each count query recomputes its whole subtree, so the database also does quadratic work.
- Measured on production algorithm ac4efe58 (111 operators, DuckDB with the fallback forced): about 30 s after conceptql-ahg5, against about 1.8 s with one query.
- Nobody counts on Spark in production today: JDE runs no SQL on Spark, and t_shank exports do not annotate. Ryan asked on 2026-10-31: "any thoughts on how to address this in Spark?"

## Directions (not ruled)

- (a) Measure first: run the one-query count statement on Spark as it is. Spark does not materialize CTEs, but its plan may reuse repeated subplans (exchange reuse), so the statement may be fast enough without MATERIALIZED. If it is, allow one-query counting on Spark and stop here. t_shank runs Spark locally in Docker and could time it.
- (b) Cache on Spark: write each shared intermediate once as a cached temporary view (`CACHE TABLE name AS SELECT ...`), then run the same one-query count over the views. This makes both Ruby and Spark work linear. It needs session-scoped cleanup, and it depends on what sequel-hexspace allows.
- (c) Make the Ruby side linear only: evaluate the tree once and build each operator's count query from the shared CTE definitions it needs. This removes the Ruby cost but not the repeated Spark work. The count SQL gets new CTE names, which changes no result.

Recommendation: (a) first, because it costs one measurement and may make the rest unnecessary. Then (b) if Spark counting gets a user.
