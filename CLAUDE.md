# ConceptQL

## Quick Reference

- Language: Ruby
- ORM: **Sequel (~> 5.66) — NOT ActiveRecord**
- Test: `bundle exec ruby test/all.rb` or `bin/run_tests`
- Lint: `bundle exec rubocop`
- Local CI gate: `just ci` — runs the default `gdm_wide` config (~1.5 min) before push. A **pre-push git hook runs this automatically**; the other 2 Postgres configs + Spark/DuckDB stay in remote CI (billed) as the last line of defense for cross-env edge cases, not the first place a problem surfaces. Bypass with `git push --no-verify` (or `SKIP_CI_GATE=1 git push`). Use `just test-full` to run all 3 Postgres configs manually.

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

Tests require a **live database** with both data tables and vocabulary/lexicon tables.

### Docker Compose (preferred)

Use `docker-compose.yml` which spins up a `test_data` Postgres container with all required schemas and data. **You must set `SEQUELIZER_SEARCH_PATH` and `CONCEPTQL_DATA_MODEL`** — without them, vocab tables aren't visible and tests fail with `NoMethodError: undefined method 'concepts_table' for LexiconNoDB`.

```bash
# GH Actions runs all 3 of these matrix configs — all must pass:

# 1. gdm_wide (default for local dev, matches bin/run_tests)
SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide docker compose run --rm conceptql

# 2. gdm with ohdsi vocabs
SEQUELIZER_SEARCH_PATH=slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm docker compose run --rm conceptql

# 3. gdm with gdm vocabs
SEQUELIZER_SEARCH_PATH=slim,gdm_vocabs CONCEPTQL_DATA_MODEL=gdm docker compose run --rm conceptql
```

The `test_data` image (`outcomesinsights/misc:test_data.ignitor`) contains:
- `slim` schema — GDM data tables (patients, clinical_codes, etc.)
- `wide` schema — GDM wide tables (observations, supplemented_payer_reimbursements)
- `ohdsi_vocabs` schema — OHDSI vocabulary tables (concept, concept_ancestor, etc.)
- `gdm_vocabs` schema — GDM vocabulary tables (concepts, ancestors, mappings, vocabularies)

No separate `LEXICON_URL` is needed — the lexicon auto-detects vocab tables in the search path of the data database.

### Without Docker (direct)

Requires `SEQUELIZER_URL` pointing to a Postgres instance with the same schemas.

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

Default values from `bin/run_tests`:
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
