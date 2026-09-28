---
id: conceptql-alj
title: require 'conceptql' connects to a database at load time -- make vocabulary operator registration lazy
status: captured
type: exploration
created_at: 2026-09-28T15:09:16.242515+00:00
updated_at: 2026-09-28T15:09:16.242515+00:00
tags:
  - load-time
  - lexicon
  - operators
  - duckdb
  - ci
---

`require 'conceptql'` opens a database connection as a side effect of loading.
`lib/conceptql.rb:67` calls `DynamicVocabularies.new.register_operators`, which
reaches `Sequelizer#db` (connection from SEQUELIZER_URL / .env / config) and
`ConceptQL::Database.lexicon(db)` to read the lexicon's vocabulary list, then
registers one operator per vocabulary. The per-data-model registries are frozen
immediately after (`Operators.operators.each_value(&:freeze)`, conceptql.rb:74).

## How it surfaced (2026-09-28)

GitHub CI on main has been red since 31e0a163 (2026-09-25), DuckDB job only.
`test/lib/conceptql/load_without_pry_byebug_test.rb` (added by an agent in
31e0a163) spawns a child ruby that does `require 'conceptql'`. The child inherits
`SEQUELIZER_URL=duckdb:///tmp/synpuf_test_data.duckdb`, and the parent test process
already holds DuckDB's exclusive file lock, so the child dies with
`Could not set lock on file ... Conflicting lock is held` (run 36438429822).
Postgres allows concurrent connections, so the Postgres/Spark jobs and the local
pre-push gate (gdm_wide Postgres only) are green.

Rejected fix: point the child at an in-memory SQLite DB. Ryan: that makes a DuckDB
job pass by quietly swapping in a different, blank database -- it stops testing
the thing the job exists to test. The test is only the messenger; the defect is
that loading the library touches a database at all.

## Measured (probe in the compose test container, 2026-09-28)

Log: claude_stuff/probe_require_db-20260928-080729.log (script alongside it).
Run from /tmp so the repo's gitignored .env is not picked up.

| SEQUELIZER_URL at require time        | result                                                                                   |
| ------------------------------------- | ---------------------------------------------------------------------------------------- |
| unset                                 | CRASH: `undefined method 'to_sym' for nil` in Sequel.adapter_class, from conceptql.rb:67 |
| `sqlite:/` (empty)                    | loads; 128 gdm operators                                                                 |
| test_data Postgres, ohdsi_vocabs path | loads; 342 gdm operators                                                                 |

Three consequences, only the first of which is the CI failure:

1. **Single-writer databases.** Any second process loading conceptql against a
   DuckDB file another process has open cannot even `require` the gem.
2. **No database, no library.** conceptql cannot be loaded at all without a
   configured connection -- not for metadata, not for `render_json`, not for a
   pry-byebug check. The 2026-09-25 pry-byebug fix made `require` work for
   consumers without pry-byebug, but only ones that also have a DB configured.
3. **The operator set is a load-time accident.** 214 of the 342 gdm operators exist
   only if a vocabulary-bearing DB was reachable at the moment of `require`, and
   the registry is then frozen. A process that later talks to a different DB (or
   whose env was not set yet at boot) keeps whatever it got. The class-level
   `ConceptQL::Database.lexicon` memoizes the first db it sees, forever.

## Consumers to keep working (read-only survey)

- jigsaw-diagram-editor: `ConceptQL::Database.new(Rails.application.lexicon_db)`
  (LEXICON_URL), config/application.rb:43-48, app/models/algorithm.rb:258.
- t_shank: `lexicon_db` from LEXICON_URL, lib/t_shank.rb:122.
- conceptql's own tests read `ConceptQL::Operators.operators[dm][name]` directly
  (gender, read, multiple_vocabularies, information_periods, vocabulary tests), and
  vocabulary_test.rb:126-137 stubs `Operators.operators` and re-runs
  `register_operators`.
- `Nodifier#operators` memoizes `Operators.operators.fetch(data_model)`.

## Ordering constraint any fix must keep

Dynamic vocabulary operators are registered FIRST, then every file in
lib/conceptql/operators/ is required, so a static operator with the same name
overwrites the dynamic one ("other operators might override some of those
dynamically generated operators", conceptql.rb:62-66). A lazy registration that
runs after the static files load must not clobber them -- register a dynamic
operator only when the name is not already taken.

## Options

(A) **Lazy, still global.** Register dynamic operators on first access to
`Operators.operators` (mutex, then freeze), skipping names a static operator
already holds. `require` should touch no DB, so the CI test should pass on DuckDB unchanged
(unverified: it never asks for an operator, but a static operator file could still reach a DB at load). Smallest change; keeps consequence 3.
Needs care: `Operators.operators` is the constant accessor used everywhere,
including tests that stub it.

(B) **Per-Database registry.** Static operators stay global; vocabulary operators
come from the lexicon of the `ConceptQL::Database` actually being queried
(`Nodifier#operators` = static + that DB's vocabularies). Fixes all three
consequences -- the operator set becomes a property of the database you query,
not of the env at boot. Larger: `to_metadata`/diagram paths need a db in hand, and
the class-level lexicon memo goes away.

(C) **Tolerate no DB at load.** Keep eager registration, fall back to CSV-only
vocabularies when no connection is configured. Fixes consequence 2 only; the DuckDB
lock and the load-time accident remain. Listed to be rejected.

Leaning: (A) now, as the fix for the red CI, with (B) as the direction if
consequence 3 has ever bitten or is likely to. Not decided; not authorized to build.

## Open questions

- Has consequence 3 ever bitten in JDE or t_shank (vocabulary operator missing
  until restart, or present for the wrong DB)? If yes, (B) is not optional.
- Does anything outside conceptql's tests read `Operators.operators` or
  `DynamicVocabularies` directly? The read-only grep of JDE and t_shank found
  no direct reads, only `ConceptQL::Database.new(...)`; conceptql_spec was not checked.
- Is DuckDB a production target or only a test matrix entry? Consequence 1 matters
  far more if production processes share a DuckDB file.
