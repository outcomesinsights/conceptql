---
id: conceptql-d16
title: Replace ConceptQL's external SQL formatters with an in-process formatter (sequel-sqlformat)
status: captured
type: decision
created_at: 2026-10-28T18:01:16.376953+00:00
updated_at: 2026-10-28T18:26:53.068529+00:00
---

## Problem

`Query#sql(:formatted)` starts one external formatter process for each statement. The JDE session measured 8.3 s for the 78-statement big algorithm (JDE spec/fixtures/conceptql/big_algo.json), against 0.10 s unformatted. The defect is bead conceptql-9ux. This seed holds the choice of formatter.

Today `SqlFormatters.format` tries, in order: the rdbms's preferred formatter, `sql-formatter` (Node), `sqlformat` (Python sqlparse), `pg_format` (Perl). Postgres prefers `sql-formatter -l postgresql`. DuckDB and Spark prefer `pg_format`. Each call also starts a `which` process for each candidate until one is found.

## Measurements (titan, 2026-10-28, big algorithm, 78 statements, about 84 KB)

Existing CLIs, one process per statement versus one process for all statements:

```
sql-formatter  78 processes= 17.87s  one process for all=  0.56s
pg_format      78 processes= 38.76s  one process for all= 35.70s
sqlformat      78 processes=  8.02s  one process for all=  1.39s
sleek          78 processes=  0.20s  one process for all=  0.01s
sqruff         78 processes= 10.37s  one process for all= 27.23s
```

pg_format is slow in itself, not only at process start. sqruff is a lint fixer, not a formatter.

In-process options, all 78 statements:

```
sqlformat crate in Ruby (prototype)  7.6 ms
pg_query 6.2.5 pretty deparse       36.6 ms
niceql                             310 ms
anbt-sql-formatter                2510 ms
```

pg_query uses the real Postgres grammar. It cannot parse 4 of the 78 DuckDB statements (`INTERVAL 7 DAY`), and it cannot parse Spark backticks. That rules it out as the only formatter.

## Candidates found by web research (not all tested)

- polyglot (Rust port of sqlglot) through the `polyglot_sql_ffi` gem: covers Postgres, DuckDB and Spark, but the gem has one release, 0 stars, and pins an old polyglot. It rebuilds the SQL from a parse tree.
- postgres-language-server `format`: Postgres only, preview.
- sql-formatter inside Ruby through mini_racer: keeps today's output, adds V8.
- DuckDB has no SQL pretty printer.

## Ruled 2026-10-28 (Ryan)

- Build a magnus + rb-sys gem that wraps the Rust `sqlformat` crate, the formatter inside the sleek CLI. It is one of the OI upstream gems.
- Name: `sleek_rb` (first proposed as `sleek-rb`). A dash means a namespace in RubyGems naming (`require "sleek/rb"`), and Bundler refuses a dashed name for an extension gem. With `sleek_rb` the gem, the require path, the module `SleekRb` and the library all match. The rubygems name `sleek` belongs to an unrelated 2013 gem, so the module is not `Sleek`.
- `sleek_rb` will be a public repo under outcomesinsights.

## sleek_rb 0.1.0 (local, not pushed)

At `jigsaw/main/gems/sleek_rb`. `SleekRb.format(sql, indent: 4, uppercase: true, lines_between_queries: 2, dialect: :generic)`. The defaults match the sleek CLI. `uppercase: nil` keeps keyword case. Dialects: generic, postgresql, sqlserver. It uses sqlformat 0.5.0, magnus 0.9, rb-sys 0.9. 13 minitest tests pass. rubocop is clean. The built gem compiles from source and loads in an empty GEM_HOME.

## Verification of sleek_rb on ConceptQL's SQL

SQL for the big algorithm was generated for Postgres (Sequel mock), DuckDB (Sequel mock) and Spark (the live thrift server at titan.jsaw.io:10000).

```
postgres  sqlglot same tree 78/78
duckdb    sqlglot same tree 78/78
spark     sqlglot same tree 78/78
stmts         only whitespace changed (uppercase: nil) 78/78  control caught=true  pg_query same tree=78
stmts-duckdb  only whitespace changed (uppercase: nil) 78/78  control caught=true
stmts-spark   only whitespace changed (uppercase: nil) 78/78  control caught=true
```

A negative control showed that the sqlglot check misses a change of identifier case in Spark (Spark identifiers are case-insensitive). The whitespace-only check covers that gap: with `uppercase: nil`, the output equals the input once all whitespace is removed.

End to end, `Query#sql(:formatted, :create_tables)` on the big algorithm with `SqlFormatters.format` replaced by `SleekRb.format(sql, indent: 2, dialect: :postgresql)`: 0.127 s, against 8.3 s today.

Known limit: the crate works on tokens and does not parse. With `uppercase: true`, an unquoted identifier that is also a keyword is uppercased. ConceptQL quotes every identifier, so this did not happen.

## Not ruled

- Whether ConceptQL replaces all four external formatters with sleek_rb (recommended), or keeps them as fallbacks.
- Which platforms sleek_rb ships precompiled native gems for, so that jigsaw's Docker image needs no Rust toolchain.

## Links

- Bead conceptql-9ux holds the defect: one formatter process per statement. This seed holds the choice of formatter that fixes it.

## RULED 2026-10-28 (Ryan): the gem is sequel-sqlformat, a Sequel extension

The name changed twice on 2026-10-28. `sleek_rb` became `sqlformat_rb`, because the gem wraps the `sqlformat` crate and not the sleek CLI. Then Ryan pivoted it to a Sequel extension, so that any Sequel database or dataset can return formatted SQL. He chose one gem over two (a separate binding gem plus a pure-Ruby extension gem): one repo, one cross-compile release pipeline.

No existing gem does this. Sequel's own `pretty_table` prints result rows, and `sequel_pretty_print` makes `pp` print model objects. Neither formats SQL text.

- Repo: `jigsaw/main/gems/sequel-sqlformat`, 5 local commits, not on GitHub yet.
- API: `DB.extension :sqlformat` adds `Database#format_sql(sql, **opts)` and `Dataset#formatted_sql(**opts)`. `Sequel::SQLFormat.format(sql, ...)` works with no database.
- The dialect comes from `database_type`: postgres → `:postgresql`, mssql → `:sqlserver`, everything else (DuckDB, Spark, SQLite) → `:generic`.
- Options: the connect hash (`Sequel.connect(url, sqlformat: {uppercase: true})`), `DB.sqlformat_options=`, or per call. Unknown keys raise ArgumentError.
- The defaults changed to the crate's own: indent 2, keyword case kept (`uppercase: nil`), 1 line between statements. ConceptQL will pass its own options.
- 29 minitest tests, rubocop and clippy clean. `just ci` passes, and so does the push gate dry run at HEAD. gitleaks finds nothing.
- It follows gator's githooks standard from its first commit. Ryan opened the migration to it; gator recorded the final name in its commit 168e53f.
- Releases: a source gem plus precompiled gems for x86_64-linux, aarch64-linux, x86_64-darwin and arm64-darwin, for Ruby 3.3, 3.4 and 4.0, through RubyGems trusted publishing.

Re-verified through the extension on the big algorithm (78 statements for each dialect):

```
stmts         dialect=postgresql only whitespace changed 78/78  pg_query same tree=78  8.8 ms for all
stmts-duckdb  dialect=generic    only whitespace changed 78/78  pg_query same tree=n/a  8.7 ms for all
stmts-spark   dialect=generic    only whitespace changed 78/78  pg_query same tree=n/a  8.4 ms for all
```

Side finding sent to gator and filed there as gator-2u7: gator's standard `cog check` line for untagged repos (`HEAD~20..HEAD`) fails below 21 commits, so a new repo cannot make its first commit.
