---
id: conceptql-873
title: 'Hospitalization lists: build each once per export and reuse it across statements'
status: resolved
type: exploration
created_at: 2026-10-16T20:27:35.377005+00:00
updated_at: 2026-10-26T17:23:58.378970+00:00
resolved_at: 2026-10-26T17:23:58.378961+00:00
resolution: "Shipped as share_utilization (bead conceptql-98p, merge 511edda9): ConceptQL::Database.new(db, share_utilization: true) and Database#shared_tables in lib/conceptql/database.rb; shared tables listed in Query#sql_statements per the 2026-10-16 ruling. Efficacy: significant tweak (create-on-read ruled first, then corrected to sql_statements because t_shank never reads rows through conceptql); a planning miss, catchable by checking the only caller's code path."
---

## Origin

Handoff from the t_shank session (2026-10-16). Ryan's ruling, as relayed: "yes, so ship that need to conceptql to create a seed->bead->implement".

## The need

conceptql should build each hospitalization list once per export and reuse it across the export's statements.

Operator#evaluate wraps each operator's query in a CTE. Scope#cte_name names it from the table prefix, the PID, a counter and SecureRandom.hex. So two statements that contain the same ["hospitalization"] operator never share its result.

## Facts measured in t_shank (DuckDB only, 2026-10-16)

- One study has 40 criteria that contain ["hospitalization"]. In one export run they took 117 s of 264 s of SQL.
- Bench prototype: t_shank .claude/skills/export-bench/hospitalization_cache.rb. It prepends to Operator#evaluate for operators that include Behaviors::Utilizable. The key is the SQL of select_it(query(db)). The first evaluation runs CREATE TABLE <scratch>.\<table_prefix>_hospcache_\<md5[0,16]> AS <query>. Later evaluations read that table. A mutex guards the map.
- Total minutes, without -> with: 2.42 -> 2.18, 6.85 -> 5.10, 3.35 -> 3.40. Each export created 4-6 tables and reused them 37 times. Output was byte-identical apart from discharge_date and length_of_stay, which the bench excluded. (conceptql-evk has since made those two columns deterministic in gdm_wide.)
- Postgres and Spark were not measured.

## Hazards

- The key must separate windows. restrict_to_window_persons filters to the window table's persons. A key on the SQL text does this. A key on the operator's arguments would mix windows.
- Table names must carry the export's table_prefix, so t_shank's cleanup of scratch tables also drops them.
- Found in conceptql (2026-10-16): the prototype creates the table during SQL generation, because Operator#evaluate runs when the query is built. Calling Query#sql, for display or for annotation, would create tables. conceptql's own force_temp_tables path (Scope#with_ctes) creates its temp tables only when the dataset is read (each, to_hash, to_hash_groups) and drops them afterwards.
- With force_temp_tables on, Scope#with_ctes extracts CTEs into temp tables and drops them after the read. A shared table must not be in that drop list.
- On Spark, CREATE TABLE AS writes to the warehouse. That may cost more than it saves.

## Questions for Ryan

1. Option shape. Recommended: opt-in on ConceptQL::Database, off by default, like cache_lookups and name_concepts_table. Without it the SQL is unchanged.
2. When the table is built. (a) At SQL generation, as in the prototype: simplest, but building SQL has a side effect. (b) When the query is first read, through the same hook that force_temp_tables uses: no side effect from Query#sql, more code. Recommended: (b).
3. Cleanup. Recommended: names carry table_prefix, and the Database also lists the tables it created, so the caller can drop them explicitly. conceptql never drops them itself.
4. Spark. Recommended: allow it on every database. The caller decides whether to turn it on. The CHANGELOG says Spark is not measured.

RULED 2026-10-16 (Ryan, all four as recommended):

1. Opt-in option on ConceptQL::Database, off by default. Without it the SQL is unchanged.
2. Build the shared table when the query's rows are first read, through the same hook that force_temp_tables uses. Building or printing SQL creates no table.
3. Table names carry the export's table_prefix. The Database lists the tables it created. The caller drops them. conceptql never drops them.
4. Allowed on every database, Spark included. The CHANGELOG says Spark is not measured.

CORRECTION and RULED 2026-10-16: ruling 2 (create on first read) does not fit t_shank, the only caller. t_shank never reads rows through conceptql. Runner#recreate takes Query#sql_statements and runs each statement as CREATE TABLE AS itself (t_shank lib/t_shank/runner.rb:78, lib/t_shank/table.rb:166). The parent recommended read-time creation without checking that path. The first build (bead conceptql-98p, 6576da88) passed every suite but was held, not merged.

Ryan ruled: list the shared table in sql_statements, so the caller creates it.

Parent's design pick inside that ruling: sql_statements lists a shared table, before the statements that read it, only when the table does not exist yet (one table_exists? check at SQL generation). No claim state is kept, so a sql_statements call made only for logging or diagnostics does not hide the table from the next call. Checked in t_shank: one ConceptQL::Database per exporter (exporter.rb:130) with table_prefix set, and no threads in t_shank/lib, so statements on one Database are generated and run one after another. Two threads that generate SQL on one Database at the same time could both list the table; that case is documented, not handled. The read hook stays for callers that read rows through conceptql.
