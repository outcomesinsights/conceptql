# ConceptQL

## Quick Reference

- Language: Ruby
- ORM: **Sequel (~> 5.66) — NOT ActiveRecord**
- Test: `bundle exec ruby test/all.rb` or `bin/run_tests`
- Lint: `bundle exec rubocop`

## Architecture

ConceptQL translates clinical research algorithm definitions into SQL queries against healthcare databases. The core flow is:

```
ConceptQL::Database -> Query -> Nodifier -> Operator tree -> Sequel dataset -> SQL
```

### Operators (`lib/conceptql/operators/`)

~50 operator classes, each producing a Sequel dataset. Operators self-register via `register(__FILE__, :gdm, :gdm_wide)` into an `OPERATORS` hash keyed by data model. Unregistered operators return `Invalid`.

Standard output columns: `person_id`, `criterion_id`, `criterion_table`, `criterion_domain`, `start_date`, `end_date`, `value_as_number`, `value_as_string`, `value_as_concept_id`, `units_source_value`, `source_value`.

### Data Models (`lib/conceptql/data_model/`)

- `gdm` — Generalized Data Model (slim variant)
- `gdm_wide` — GDM wide variant (slim + wide schemas)
- `omopv4_plus` — OMOP CDM v4+

### RDBMS Adapters (`lib/conceptql/rdbms/`)

- `Postgres` — primary platform, uses `DISTINCT ON`, materialized CTEs
- `Presto` — Presto/Trino SQL dialect
- `Spark` — via sequel-hexspace

### Behaviors (`lib/conceptql/behaviors/`)

Mixins: `Timeless`, `Windowable`, `Utilizable`, `Labish`, `Drugish`, `Provenanceable`, `Metadatable`, `CodeLister`.

### Scope & CTEs (`lib/conceptql/scope.rb`)

Manages labeled operators and CTE creation. `Recall` operator reuses labeled sub-expressions. CTEs can be disabled via `CONCEPTQL_AVOID_CTES=true`.

## Running Tests

Tests require a **live database**. Both `LEXICON_URL` and `SEQUELIZER_URL` must point to real Postgres instances.

### Required Environment Variables

- `LEXICON_URL` — URL for the lexicon database
- `SEQUELIZER_URL` — URL for the test database
- `CONCEPTQL_DATA_MODEL` — one of `gdm`, `gdm_wide`, `omopv4_plus`

### Test Commands

Tests **must pass for both `gdm` AND `gdm_wide`** data models:

```bash
# Using bin/run_tests (has defaults for titan.jsaw.io)
bin/run_tests

# Manual per-model testing
CONCEPTQL_DATA_MODEL=gdm bundle exec ruby test/all.rb
CONCEPTQL_DATA_MODEL=gdm_wide bundle exec ruby test/all.rb

# Rake tasks
bundle exec rake test_gdm
bundle exec rake test_omopv4_plus
bundle exec rake test_cov
```

### Default Values from bin/run_tests

- `SEQUELIZER_URL`: `postgres://ryan:r@titan.jsaw.io/test_data?search_path=wide,slim,ohdsi_vocabs`
- `CONCEPTQL_DATA_MODEL`: `gdm_wide`

### Test Framework

Minitest. Tests in `test/`, named `*_test.rb`. Runner is `test/all.rb` which globs `./test/**/*_test.rb`.

## Key Constraints and Gotchas

- **Sequel ORM only** — `activesupport` is included for utility helpers, NOT for ActiveRecord
- **Tests require live databases** — no mock/in-memory option
- **Operator registration is data-model-specific** — operators specify which data models they apply to
- **Postgres-specific SQL** exists in `rdbms/postgres.rb` (`DISTINCT ON`, etc.) — queries built for Postgres won't work on Presto/Spark without the correct adapter
- **Temp tables vs CTEs** — `CONCEPTQL_FORCE_TEMP_TABLES=true` forces temp tables; `CONCEPTQL_AVOID_CTES=true` disables CTEs
- **`sequelizer` loaded from GitHub `main` branch** (not a stable release pin)
- **`sequel-hexspace`** also from GitHub — Spark support may be experimental
- **`Algorithm` operator** fetches stored ConceptQL statements from a `concepts` table — requires that table to exist
