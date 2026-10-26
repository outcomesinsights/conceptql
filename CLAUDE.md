# ConceptQL

## Quick Reference

- Language: Ruby
- ORM: **Sequel (~> 5.66) — NOT ActiveRecord**
- Test: `bundle exec ruby test/all.rb` or `bin/run_tests`
- Lint: `just lint` (rubocop, shellcheck, actionlint, zizmor, hadolint and cog; part of `just ci`). `mise.toml` pins the tools and `just setup` installs them. `just fmt` runs treefmt (`treefmt.toml`), which formats every tracked file, including rubocop's safe autocorrections. The suite writes new expected-results files in prettier's layout (`test/prettier_json.rb`), so they already pass `fmt-check`.
- Local CI gate: `just ci` — runs the default Postgres `gdm_wide` config (docker) AND the DuckDB suite (`just test-duckdb`, host Ruby, linux-amd64 only) before push. The two suites run in parallel (`just test-both`). Their output interleaves on the terminal, and each one writes its own log under `claude_stuff/test-logs/`. GitHub CI runs the same recipes: `just lint fmt-check hygiene`, `just test` for each Postgres config, and `just test-duckdb` on Ruby 3.3 and 3.4, each against libduckdb 1.5.x and 2.x. Local runs use 1.5.x (the justfile's `libduckdb_version`), because 2.x showed speed regressions. DuckDB runs only the gdm_wide setup, and that is enough (Ryan, 2026-10-26): it reads its vocabulary from `ohdsi_vocabs` through the OHDSI lexicon, the setup production uses. The **pre-push hook runs this automatically** at each pushed commit (see Git Hooks below). The other 2 Postgres configs + Spark stay in remote CI (billed) as the last line of defense for cross-env edge cases, not the first place a problem surfaces. If the DuckDB fixture or libduckdb is unavailable, the gate fails with a message saying what is missing; it never skips. Use `just test-full` to run all 3 Postgres configs manually.
- Git Hooks: the hooks follow gator's githooks standard. They are tracked in `.githooks/`, and `just setup` arms a checkout with `git config core.hooksPath .githooks`. Each clone, host and worktree runs `just setup` once.
  - `pre-commit`: `just pre-commit` on the working tree (lint, fmt-check, hygiene, seeds-check). If fmt-check reformats anything, the commit fails: re-stage the changes and commit again.
  - `pre-push`: `just ci` at each pushed commit, in a gate worktree under `~/.cache/gator-gate/`, then `bd-publish` to publish the beads. A commit that already passed there is not re-run.
  - The files in `.githooks/` are copies of gator's `standard/githooks/`. Never edit them here. `.beads/hooks/pre-commit` and `.beads/hooks/pre-push` forward to them, and the `pre-push` recipe stays, so a checkout that has not run `just setup` yet is still checked. Those three are removed when every checkout is armed.
  - Never skip the hooks with `--no-verify`. A failing hook is a problem to fix.

## Architecture

ConceptQL translates clinical research algorithm definitions into SQL queries against healthcare databases. The core flow is:

```
ConceptQL::Database -> Query -> Nodifier -> Operator tree -> Sequel dataset -> SQL
```

### Operators (`lib/conceptql/operators/`)

~50 operator classes, each producing a Sequel dataset. Operators self-register via `register(__FILE__, :gdm, :gdm_wide)` into `Operators.static_operators`, keyed by data model. Vocabulary operators are not registered at load: each `ConceptQL::Database` builds its own from `config/vocabularies.csv` and its own lexicon, and `Database#operators(data_model)` merges the built-ins over them. Every lookup goes through `cdb.operators`; `require 'conceptql'` touches no database. Unregistered operators return `Invalid`.

Standard output columns: `person_id`, `criterion_id`, `criterion_table`, `criterion_domain`, `start_date`, `end_date`, `value_as_number`, `value_as_string`, `value_as_concept_id`, `units_source_value`, `source_value`.

### Data Models (`lib/conceptql/data_model/`)

- `gdm` — Generalized Data Model (slim variant)
- `gdm_wide` — GDM wide variant (slim + wide schemas)
- `omopv4_plus` — OMOP CDM v4+

### RDBMS Adapters (`lib/conceptql/rdbms/`)

- `Postgres` — primary platform, uses `DISTINCT ON`, materialized CTEs
- `DuckDB` — uses `ROW_NUMBER()` in place of `DISTINCT ON`
- `Spark` — via sequel-hexspace

### Behaviors (`lib/conceptql/behaviors/`)

Mixins: `Timeless`, `Windowable`, `Utilizable`, `Labish`, `Drugish`, `Provenanceable`, `Metadatable`, `CodeLister`.

### Scope & CTEs (`lib/conceptql/scope.rb`)

Manages labeled operators and CTE creation. `Recall` operator reuses labeled sub-expressions. CTEs can be disabled via `CONCEPTQL_AVOID_CTES=true`.

## Running Tests

Tests require a **live database** with both data tables and vocabulary/lexicon tables.

### Docker Compose (preferred)

Use `docker-compose.yml` which spins up a `test_data` Postgres container with all required schemas and data. **You must set `SEQUELIZER_SEARCH_PATH` and `CONCEPTQL_DATA_MODEL`** — without them, vocab tables aren't visible and tests fail with `NoMethodError: undefined method 'concepts_table' for LexiconNoDB`.

`just test` and `just test-full` run these. The container runs as the calling user, so raw `docker compose` also needs `CONCEPTQL_UID` and `CONCEPTQL_GID` exported (`id -u`, `id -g`). The justfile exports them. Without them, `docker compose run` fails with "unable to find user run-through-just-or-export-CONCEPTQL_UID".

```bash
# GH Actions runs all 3 of these matrix configs — all must pass:

# 1. gdm_wide (default for local dev, matches bin/run_tests)
SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide docker compose run --rm conceptql

# 2. gdm with ohdsi vocabs
SEQUELIZER_SEARCH_PATH=slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm docker compose run --rm conceptql

# 3. gdm with gdm vocabs
SEQUELIZER_SEARCH_PATH=slim,gdm_vocabs CONCEPTQL_DATA_MODEL=gdm docker compose run --rm conceptql
```

The `test_data` image (`ghcr.io/outcomesinsights/misc:test_data.jumper`, pinned by digest in `docker-compose.yml`) is a private ghcr.io package: run `docker login ghcr.io` once on a new host. To move to a new build, change the digest. It contains:

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
bundle exec rake test   # as CI: data model + database from the environment
bundle exec rake test_gdm
bundle exec rake test_omopv4_plus
bundle exec rake test_cov
```

Default values from `bin/run_tests`:

- `SEQUELIZER_URL`: `postgres://ryan:r@titan.jsaw.io/test_data?search_path=wide,slim,ohdsi_vocabs`
- `CONCEPTQL_DATA_MODEL`: `gdm_wide`

### Test Framework

Minitest. Tests in `test/`, named `*_test.rb`. Runner is `test/all.rb` which globs `./test/**/*_test.rb`.

### DuckDB fixture (pin and download link)

`just test-duckdb` and CI's `Run-DuckDB-Tests` both test against `synpuf_test_data.duckdb`, which vocabulation publishes to Dropbox `Publicized/`. Each one verifies the file against `.github/synpuf_test_data.sha256`. When vocabulation republishes, two things can break:

- **Checksum mismatch** (local and CI). vocabulation's pipeline step `handoff` prints the new sha256. Re-pin the file after a green `just test-duckdb` against the new data.
- **CI downloads an HTML page** ("Not a DuckDB file … expected 'DUCK'"). The repo variable `DUCKDB_TEST_DATA_URL` points at a Dropbox shared link that the republish killed ("File Deleted"), or the link is team-only ("Log in to Dropbox"). Fix it on titan through the Dropbox API, with a fresh token from `dropbox-token` (in `~/.local/bin`; never print or store the token, and never delete anything in `~/.config/dropbox/`):
  1. `TOKEN=$(dropbox-token)`, then POST `https://api.dropboxapi.com/2/sharing/list_shared_links` with `{"path":"/Publicized/synpuf_test_data.duckdb","direct_only":true}`. If there is no link, use `sharing/create_shared_link_with_settings`.
  2. POST `sharing/modify_shared_link_settings` with `{"url":<link>,"settings":{"audience":"public","access":"viewer","allow_download":true}}`. Links are team-only by default on this business account.
  3. Swap `dl=0` for `dl=1`, download the file, and check it with `sha256sum -c .github/synpuf_test_data.sha256` from the download's directory.
  4. `gh variable set DUCKDB_TEST_DATA_URL -R outcomesinsights/conceptql --body <dl=1 url>`, then re-run the failed CI job.

### Spark fixture (pin and download link)

CI's `Run-Spark-Tests` reads parquet files from `synpuf_test_data.tgz`, which vocabulation also publishes to Dropbox `Publicized/`. The job downloads it from the repo variable `SPARK_TEST_DATA_URL` and verifies it against `.github/synpuf_test_data.tgz.sha256` before it extracts it. The cache key is the hash of that pin file. No local recipe uses the tarball. The failures and the repairs are the same as for the DuckDB fixture:

- **Checksum mismatch** (`synpuf_test_data.tgz: FAILED`). vocabulation republished the tarball. Re-pin it from the repo root with `(cd ~/Dropbox/Publicized && sha256sum synpuf_test_data.tgz) > .github/synpuf_test_data.tgz.sha256`. The Spark jobs on the next push test the new data.
- **curl fails with an HTTP error**. The shared link is dead or team-only. Do steps 1 to 3 above with the path `/Publicized/synpuf_test_data.tgz` and the pin `.github/synpuf_test_data.tgz.sha256`. Then `gh variable set SPARK_TEST_DATA_URL -R outcomesinsights/conceptql --body <dl=1 url>`.

## Releasing

Releases are tag-based. A pushed `v*` tag runs `.github/workflows/release.yml`, which publishes to rubygems.org through RubyGems trusted publishing. No API key is stored anywhere. `rake release` (from `bundler/gem_tasks`) still exists, but it skips every check below.

1. Run `just release-check`. It fails when `Gemfile.lock` is not the newest resolution, or when our own gemspec or Gemfile bound excludes the newest release of a gem. This includes the OI gems (sequelizer, sequel-duckdb, sequel-hexspace), which the Gemfile takes from their rubygems.org releases. A gem that another gem holds back is shown as `info` and does not fail. Fix every failure with `bundle update` or a bound change, and run `just ci` again, before step 2.
2. Bump `VERSION` in `lib/conceptql/version.rb`, run `bundle install` to update `Gemfile.lock`, and move the `[Unreleased]` entries in `CHANGELOG.md` under the new version.
3. Land that commit on `main` and wait for the `Run Tests` workflow to pass on the push.
4. Tag that commit and push the tag: `git tag v0.4.0 && git push origin v0.4.0`.

The workflow refuses to publish unless the tag is `v` + `ConceptQL::VERSION`, the commit is on `main`, and a push-to-`main` run of `run_tests.yml` succeeded on that exact commit. It runs no test suite itself. If the tag was pushed before CI finished, re-run the release workflow once CI is green. Before it publishes, it installs the built gem into an empty `GEM_HOME` and checks that it loads, creates a `ConceptQL::Database`, and contains every file under `config/` and `schemas/`. After it publishes, it fails unless rubygems.org lists the new version.

The older tags are date-shaped (`20.09.01`) and do not match `v*`. The first tag-based release is `v0.4.0`.

One-time setup, done by a repository owner: register the trusted publisher on rubygems.org (owner `outcomesinsights`, repository `conceptql`, workflow `release.yml`, environment `release`). The environment must match the publish job's `environment:` exactly, or the token exchange fails. In the GitHub `release` environment, allow deployments only from `v*` tags.

## Key Constraints and Gotchas

- **Sequel ORM only** — `activesupport` is included for utility helpers, NOT for ActiveRecord
- **Tests require live databases** — no mock/in-memory option
- **Operator registration is data-model-specific** — operators specify which data models they apply to
- **Postgres-specific SQL** exists in `rdbms/postgres.rb` (`DISTINCT ON`, etc.) — queries built for Postgres won't work on DuckDB/Spark without the correct adapter
- **Temp tables vs CTEs** — `CONCEPTQL_FORCE_TEMP_TABLES=true` forces temp tables; `CONCEPTQL_AVOID_CTES=true` disables CTEs
- **The OI gems come from rubygems.org releases** (sequelizer `~> 0.4.0`, sequel-duckdb `~> 0.4.1`, sequel-hexspace `~> 2.1`). To test an unreleased change, point the Gemfile entry at a checkout with `path:` for that run and do not commit it
- **`sequel-hexspace`** (Spark) is in an optional Gemfile group
- **`Algorithm` operator** fetches stored ConceptQL statements from a `concepts` table — requires that table to exist
