# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- `conceptql render_json STATEMENT_FILE [--counts] [--data-model=...]` prints statements as a
  `conceptql-diagram/v1` render tree for the diagram renderer (`ConceptQL::Diagram`), plus
  `ConceptQL::Diagram::JigsawTree`, a port of the diagram editor's ConceptqlAdapter
- `ConceptQL::Database#operators(data_model = own)`: each Database's own operator registry, with
  vocabulary operators built from that Database's lexicon and the built-in operators merged over
  them. Every operator lookup goes through it.
- `ConceptQL::Database.new(db, name_concepts_table: name)` and
  `ConceptQL::Database#create_name_concepts_table`: the display-name joins (drug name and dose
  units, lab units and result concept, admission source and discharge location) read a table of
  only the concept rows that the data references, instead of the whole concept table. The caller
  builds the table once, before its queries run, and drops it afterwards. Off by default.
- `ConceptQL::Database.new(db, share_utilization: true)` and `ConceptQL::Database#shared_tables`:
  the statements of one Database share each hospitalization, SNF and hospice list (the
  `Utilizable` operators) as a table named `<table_prefix>_util_<hash>`, in `scratch_database`
  when that is set. While the table does not exist, `Query#sql_statements` lists it as an entry
  before the entries that read it, so a caller that runs the entries in order (as CREATE TABLE AS,
  then the query) creates it first. A caller that reads rows through conceptql gets the table
  created at the first read. Building SQL creates no table. Two threads that generate SQL on one
  Database at the same time can both list the same table: this is not handled. The key is the SQL
  of the list, so each window gets its own table, and a list shares only when its lookup ids come
  in one order: use the option with `cache_lookups: true`. The option needs a `table_prefix` in
  `scope_opts`. conceptql never drops these tables: the caller drops `shared_tables`. Off by
  default. On DuckDB, a t_shank prototype of this change cut one export with 40 hospitalization
  criteria from 6.85 to 5.10 minutes. Spark and Postgres timing are not measured.
- `ConceptQL::Database.new(db, cache_lookups: true)`: each vocabulary lookup reaches the database
  once per distinct argument list for the life of the Database. This includes the empty-vocabulary
  check behind the unknown-code warnings, the Race operator's name lookup, the Provenance
  operator's keyword check, and the checks that the data model's source tables and the concept
  table exist (once per table and database). Off by default.
- Tag-based releases: pushing a `v*` tag runs `.github/workflows/release.yml`, which publishes the
  gem to rubygems.org through RubyGems trusted publishing (no stored API key). It refuses unless the
  tag equals `v` + `ConceptQL::VERSION`, the commit is on `main`, and the `Run Tests` workflow passed
  on a push to `main` for that commit. Before publishing, it installs the built gem into an empty
  `GEM_HOME` and checks that it loads and ships `config/` and `schemas/`. After publishing, it checks
  that rubygems.org lists the version. See "Releasing" in `CLAUDE.md`.

### Fixed

- `Query#code_list` on a statement with validation errors raises `Query::InvalidStatementError`
  (a `Query::QueryError` that names the errors) instead of NoMethodError or a partial code list
- `require 'conceptql'` no longer connects to a database. It used to connect to whatever
  Sequelizer was configured for, to register an operator per vocabulary, so it crashed with no
  database configured and, on DuckDB, a second process could not load the library while another
  held the file
- Bug with PlaceOfServiceFilter and other procedure_cost-based operators (#84)
- Spark CI downloads its test data from the repo variable `SPARK_TEST_DATA_URL` and checks it
  against `.github/synpuf_test_data.tgz.sha256` before it extracts it. The hardcoded Dropbox link
  it used was dead
- CLI: `conceptql metadata` raised ArgumentError when it wrote metadata.json, and
  `CONCEPTQL_PARQUET_TEST_DIR` raised NoMethodError (`String#glob`) for every command that
  connects to a database. It now makes the parquet files of each directory in its glob ready.
  `conceptql scope_annotate` ignored the connection options, and `conceptql help` listed
  `simple_visit` as `extract_metadata`
- A vocabulary statement with `*` no longer warns about the format of its other codes. The check
  for `*` never ran, because `Vocabulary#select_all?` is private

### Changed

- Set RUNTIME_FILTER_MODE only if asked
- `ConceptQL::Operators.operators` is removed. Built-in operators are in
  `ConceptQL::Operators.static_operators`; vocabulary operators come from each Database
  (`ConceptQL::Database#operators`). `ConceptQL::Database.lexicon` (class method) is removed;
  use `Database#lexicon`
- The sequelizer dependency now admits 0.4.x (`>= 0.3.0, < 0.5`). The previous `< 0.4` bound
  rejected the released sequelizer 0.4.0. Gemfile.lock now resolves sequelizer 0.4.0.
- Development dependencies are updated to their newest releases (2026-10-26), including the
  duckdb gem 2.0.0.1, pg 1.7.0, rubocop 1.92.1, and the newest sequelizer, sequel-duckdb 0.4.1
  and sequel-hexspace 2.1.0. The test suites pass on Postgres and DuckDB. `just test-duckdb`
  pins the libduckdb library to 1.5.6 (override with `LIBDUCKDB_VERSION`). GitHub CI runs the
  DuckDB suite against libduckdb 1.5.6 and 2.0.0
- `just release-check` fails when a dependency is behind its newest allowed release. The release
  procedure runs it first
- Docker test runs use the ghcr `test_data.jumper` image pinned by digest, the same one as CI, and
  run as the calling user, so they leave no root-owned files. The runner image drops Chrome's libraries
- On DuckDB, operator CTEs are now `AS MATERIALIZED`, as on Postgres
  (`ConceptQL::Rdbms::DuckDB#supports_materialized?` is true). DuckDB accepts the keyword since
  v0.8.0. `just test-duckdb` passes against libduckdb 1.5.6
- The provenance and utilization operators (`provenance`, `one_in_two_out`, `hospitalization`,
  `hospice`, `snf`) are now GDM-only. On omopv4_plus they fail validation as an invalid operator
  instead of raising NoMethodError, and they are not in its metadata
- Code format checks ("improperly formatted code") use the vocabulary_formats validator patterns.
  CPT4, CPT4_HCPCS, HCPCS, ICD10, ICD10CM and ICD9Proc changed: CPT4 now accepts M0201, HCPCS
  needs a leading letter, and the ICD patterns need a real dot. ATC, DRG, ICD03_Morphology,
  ICD03_Topography, NDC, RxNorm and SNOMED are checked for the first time. ICD10PCS accepts only 7-character billable codes
  with a real section character first (row ICD10PCS.BILLABLE), so Z561123 is now improperly
  formatted
- A `cpt_or_hcpcs` code gets a warning when every vocabulary rejects it, for any reason. It is
  "improperly formatted" only when every vocabulary says so, and otherwise "unknown"

### Removed

- Presto support (breaking). `ConceptQL::Rdbms::Presto` and `database_type: :presto` are gone, so
  `ConceptQL::Rdbms.generate(:presto)` raises "Unknown database_type". Its `primary_concepts`
  emitted `DISTINCT ON`, which Presto does not support. The Rakefile's Presto scaffolding
  (`test_script` and `driftr_script` namespaces, `convert`, `prestofy`, the Presto `cdb`) is
  removed too. The default rake task is now `test` instead of `test_omopv4_plus`
- The `conceptql selection_operators` command, which had raised NameError since 2016.
- The unused query optimizer (breaking for a caller of these methods). `Query#optimized`,
  `Operator#optimized`, `Operator#unionable?`, `Operator#dup_values` and the
  `ConceptQL::Vocabularies::Behaviors::Sourcish` module are gone. Nothing in conceptql called
  `optimized`, so its union merging never ran, and the generated SQL does not change.

## [0.3.0] - 2016-11-08

### Added

- New operators
  - PlaceOfServiceFilter
  - Provenance
  - ProviderFilter
  - CoReported
- Support for :impala_mem_limit option
- Initial support for dynamic columns
- Additional columns for observation domains and drug domains
- Support for :within, :occurrences, :at_least

### Changed

- Format of this [CHANGELOG](http://keepachangelog.com/en/0.3.0/)
- Read searches Condition, Procedure, Drug, Observation
- Rewrote OneInTwoOut to produce faster queries
- Except operator uses different strategy under Impala

### Fixed

- Fixed date casting and other issues for Impala compatibility.
- Fixed ConditionType to accept concept_ids

## [0.2.0] - 2015-12-11

### Added

- Optimized After/Before nodes when multi-person results are in the right stream.
- Set end_date as coalesce(end_date, start_date) to make range if end_date missing.
- Nodes
  - AnyOverlap
  - Contains
  - Filter
  - Ndc
  - ObservationPeriod
  - OneInTwoOut
  - OverlappedBy
  - Overlaps
  - TrimDateEnd
  - TrimDateStart
- Nodes for CPRD
  - Medcode
  - MedcodeProcedure
  - ObservationByEnttype
  - Prodcode
- Nodes for SEER
  - FromSeerVisits
  - ToSeerVisits
- Ability to limit results to a set of patients by setting Tree#person_ids
- "units_source_value" and "source_value" columns in results
- TimeWindow supports date literals
- ConditionType supports search for "primary"
- Nodifier#to_metadata

### Changed

- Except now allows :ignore_date option
  - Comparison is only done on criterion_id/type
- DateRange START/END use observation_period instead of visit_occurrence
- Operator#columns value_as_numeric => value_as_number
- Syntax is now more "lispy"
- Recall now uses any labeled operator as if that operator was fed to "Define" operator
- Nodes now called Operators

### Removed

- Let/Define operators

### Fixed

- Many broken specs.
- Union calls #from_self on incoming streams to avoid column issues
- Concept node now works again
- Define ensures tables are built

## [0.1.1] - 2014-09-18

### Fixed

- Calling Query#sql no longer creates a bunch of temporary tables.

## [0.1.0] - 2014-09-04

### Added

- Support for numeric, string, and concept_ids returned in results.
- Many updates to the ConceptQL Specification document.
- Added doc/implementation_notes.md to capture thoughts and bad ideas.

### Fixed

- "Fake" graphs are now drawn correctly.
- bin/conceptql doesn't bomb out drawing "fake" graphs

## [0.0.9] - 2014-09-03

### Added

- Support for MSSQL (SQL Server).

### Fixed

- Removed debug output from Node#namify

## [0.0.8] - 2014-08-28

### Added

- Support for Oracle.

### Fixed

- DateAdjuster/TimeWindow use Sequel's date_arithmetic extension to produce database agnostic date manipulation.
- Breakage from Node#tree in GraphNodifier.
- All tests are back to passing.
- Changed from SHA1 to CRC32 hash since Oracle can't handle table names longer than 30 characters.

## [0.0.6] - 2014-08-23

### Added

- Support for Oracle
- Tree#defined to pass type information between Define and Recall.
- Node#sql to produce SQL for each node.
- Graph includes row count on each edge in the diagram.

### Fixed

- Bug in CastingNode that generate SQL returning multiple columns in a subquery.
- Made ruby-graphviz a dependency so calling programs don't bomb out.
- Define now passes rows on through like any other node!
- DateAdjuster/TimeWindow use Sequel's date_arithmetic extension to produce database agnostic date manipulation.
- All tests are back to passing.

## [0.0.5] - 2014-08-19

### Fixed

- Bug in GraphNodifier not displaying types for `recall` nodes.

## [0.0.4] - 2014-08-19

### Added

- Support for 5 instead of 13 column internal representation of results.
- `define` node, used to create "variables" in ConceptQL.
- `recall` node, used to pull results from "variables" in ConceptQL.

### Removed

- Support for 13 column results.
- Dependency on a set of views to run SQL queries.

### Fixed

- Bug where `place_of_service_code` wasn't limited to vocabulary_id 14

## [0.0.3] - 2014-08-12

### Added

- FakeGrapher class to make it easier to generate diagrams with experimental nodes
- fake_graph command has returned to the `conceptql` program
- GraphNodifier now supports:
  - condition_type as condition_occurrence
  - drg as procedure_occurrence
  - vsac as misc

### Fixed

- Tree now runs #deep_symbolize_keys on incoming statements

## [0.0.2] - 2014-07-11

### Removed

- Several commands from `conceptql` program
  - fake_graph
  - show_db_graph
  - show_and_tell_db

## [0.0.1] - 2014-07-11

### Added

- This project.
