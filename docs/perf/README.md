# Performance reports

Each file records one performance investigation of conceptql: the question,
the code and data measured, the method, the numbers and the decision that
followed. The date in a file name is the date of the run. Raw logs stay in
`claude_stuff/` on titan, which git ignores. Each report names its logs.

Reports give timings, sizes, row counts and operator counts only. They never
contain data rows, values or code lists from the confidential data sets.

| date       | report                                                                             | subject                                                                                                 |
| ---------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 2026-10-14 | [spark-sql-options-2026-10-14.md](spark-sql-options-2026-10-14.md)                 | Ranked SQL options for production Spark: hospitalization filter, one_in_two_out single read (logs lost) |
| 2026-10-15 | [concept-name-joins-2026-10-15.md](concept-name-joins-2026-10-15.md)               | Cost of the concept-name joins on DuckDB, and the cut-down concept table                                |
| 2026-10-28 | [sql-formatter-2026-10-28.md](sql-formatter-2026-10-28.md)                         | `Query#sql(:formatted)`: external formatter processes against in-process sequel-sqlformat               |
| 2026-10-29 | [algorithm-survey-2026-10-29.md](algorithm-survey-2026-10-29.md)                   | Annotate and plain query on all 1,259 production algorithms (JDE's survey; logs in JDE)                 |
| 2026-10-30 | [annotate-profile-ac4efe58-2026-10-30.md](annotate-profile-ac4efe58-2026-10-30.md) | Profile of annotate on algorithm ac4efe58 (logs lost; seed conceptql-643 is the record)                 |
| 2026-10-30 | [concept-lists-merged-ctes-2026-10-30.md](concept-lists-merged-ctes-2026-10-30.md) | Bead conceptql-6cz: merged identical CTEs and concept lists sent once                                   |
| 2026-10-30 | [per-operator-annotate-2026-10-30.md](per-operator-annotate-2026-10-30.md)         | Bead conceptql-ahg5: per-operator annotate after caching `source_vocabulary_ids`                        |

Measurements of conceptql that other repositories made and own are not
reported here. Their seeds in this repository cite them: t_shank's lexicon
round trips (seed `conceptql-a5f`) and hospitalization-list reuse (seed
`conceptql-873`), and JDE's one-query counting prototype (bead
`conceptql-z6k`).
