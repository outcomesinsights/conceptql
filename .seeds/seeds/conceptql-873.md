---
id: conceptql-873
title: 'Hospitalization lists: build each once per export and reuse it across statements'
status: captured
type: exploration
created_at: 2026-10-16T20:27:35.377005+00:00
updated_at: 2026-10-16T20:38:36.685688+00:00
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
