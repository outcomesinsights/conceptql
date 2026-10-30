# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- `ConceptQL::Lexicon.for_dataset(db)` makes a DuckDB dataset its own lexicon. The returned
  Lexicon reads the OHDSI vocabulary tables (`concept`, `concept_ancestor`,
  `concept_relationship` and `vocabulary`) from `db` itself, through its search path, and
  caches its lookups. It never reads `LEXICON_URL`. Pass it as
  `ConceptQL::Database.new(db, lexicon: lexicon)`, without `cache_lookups`. When the dataset
  lacks one of the tables, it raises `ConceptQL::Lexicon::MissingVocabularyError`, whose
  message names the missing tables, the current schema and the search path. For a Postgres
  or Spark db it returns nil, and the Database chooses its lexicon as before.

### Changed

- **Breaking: the plain query raises `ConceptQL::InvalidStatementError` for a statement with
  validation errors.** `Query#query`, `#sql` and `#sql_statements`, and `#all`, `#count`,
  `#execute`, `#order` and `#analyze` through `#query`, now validate the statement first,
  as `#code_list` already did. The error's message lists each error that `annotate` shows,
  with the name of its operator. `#errors` holds the same errors as the `errors` hash of
  `scope_annotate`, and `#statement` holds the statement. Warnings, such as the `count`
  deprecation or an unknown code, do not raise. Before, an invalid statement could crash
  while it built (`provider_filter` without `roles` raised NoMethodError, and an unknown
  operator raised RuntimeError `Invalid#query called`). It could also build SQL that
  silently returned fewer rows. `provenance` ignored an unrecognized keyword, such as a
  concept ID or `inpatient:primary_or_first`, and `count` ignored every upstream after the
  first. Those statements now raise. The error is a `Query::QueryError`, and its old name
  `ConceptQL::Query::InvalidStatementError` still works. `annotate` does not change.
- **Behavior change: statements that only warned now fail validation.** A code that does not
  match its vocabulary's format (for example `["icd9", "410*"]`) is now the validation error
  `improperly formatted code`, which names the code. Before, it was only a warning, and the
  statement silently returned no rows for that code. There is no prefix matching. A bare `"*"`
  still selects every code. A `cpt_or_hcpcs`-style operator gives the error only when every one
  of its vocabularies rejects the code's format. A well-formed code that the vocabulary does not
  know is still only the warning `unknown code(s)`, also next to a malformed code. Like any
  invalid operator, an operator with a malformed code, and every operator that uses it, gets no
  counts, and the plain query and `Query#code_list` raise `ConceptQL::InvalidStatementError`.
- `union` removes exact duplicate rows: a row that arrives from more than one upstream
  comes out once, because every stream is a set. Before, `union` joined its non-vocabulary
  upstreams with `UNION ALL`, so `["union", ["first", ["icd9", "412"]], ["icd9", "412"]]`
  returned each first MI twice. Two rows are duplicates only when every column is equal,
  `label` included. The duplicate removal is expensive on large data, so `union` keeps
  `UNION ALL` when no row can come from two of its upstreams: when the upstreams are
  vocabulary operators, `cpt_or_hcpcs`-style operators and unions of them, and each pair
  has different domains or different vocabularies. Statements that union a labeled
  operator with a `recall` of it return fewer rows.
- `occurrence` with `at_least` returns each row once, because every stream is a set. Each
  earlier row of a person picks its nth row, and with `at_least` several earlier rows can pick
  the same row. Before, that row came out once for each earlier row that picked it, so
  `["occurrence", 2, ["icd9", ...], {"at_least": "30d"}]` returned 2366 rows, of which only
  1163 were distinct. The same rows come out, and only the copies are gone. Statements that
  count the rows of such an `occurrence` count fewer rows.
- `trim_date_end` and `trim_date_start` with `compare_all` return each row once, because every
  stream is a set. With `compare_all`, each left row is trimmed by every right row of the
  person, and two right rows can trim it to the same date. Before, that row came out once for
  each such right row. With `["icd9", "412"]` as both the left and the right, `trim_date_end`
  returned 60 rows, of which only 50 were distinct. The same rows come out, and only the copies
  are gone. Statements that count the rows of such a trim count fewer rows.
- `cpt_or_hcpcs` joins its vocabulary branches (CPT4, HCPCS and CPT4_HCPCS) with `UNION ALL`
  instead of `UNION`. Each branch selects the rows of a different vocabulary, so no row can
  come from two branches. The duplicate removal was the most expensive step of a
  `cpt_or_hcpcs "*"` query, and it ran out of memory on full SEER-Medicare data. A row that
  one branch repeats (for example, through a window table with repeated rows) now stays,
  as it does for `cpt` and `hcpcs`. A custom multiple-vocabularies file that lists one
  vocabulary twice keeps `UNION` for that operator.
- `Query#annotate` and `Query#scope_annotate` with counts on now count every operator with
  one SQL statement on DuckDB and Postgres. The statement holds the root query's
  `MATERIALIZED` CTEs and a `UNION ALL` of one count for each operator's CTE. An operator
  that the root query does not evaluate (a vocabulary operator that `union` combines with
  others) adds its own CTE to the statement. Before, each operator ran its own counting
  query, which evaluated all of its upstream operators again. The counts and the output
  shape do not change, and an operator with no rows still reports zeros. Spark does not
  honor `MATERIALIZED`, so it keeps one counting query for each operator. The old path is
  also used for a statement with an operator that annotate does not count (an invalid
  operator, for example) and with temp tables (`force_temp_tables`). `skip_counts: true`
  runs no counting query, as before.

### Deprecated

- The `count` operator is deprecated. Every stream is a set, so `count` returns 1 for nearly
  every row. A statement that uses `count` still runs and returns the same rows. Annotation
  adds the warning `deprecated operator` on `count`, and a later release will make it an
  error. To count the events of each person, use `numeric` 1 and then `sum`. The operator
  metadata of `count` says `deprecated: true`. The new class-level declaration `deprecated`
  marks an operator.

### Fixed

- `inner_join` and `include_rhs_columns` no longer return a row more than once. With either
  option, a temporal operator (for example `during`, `contains` or `any_overlap`) joins each
  left row to every matching right row, and it gave one copy of the left row for each match.
  On the DuckDB test data, `during` of `icd9 412` in `information_periods` with
  `include_rhs_columns: ["criterion_domain"]` gave 176 rows for 48 records. Each row now comes
  out once. With `include_rhs_columns`, rows that differ in a right-side column are different
  rows, so a left row still comes out once for each different value, such as each right
  `uuid`.
- Building a statement's SQL no longer runs a query to learn a dataset's columns. Before,
  `occurrence` with `group_by_date` over a labeled upstream failed on every database with
  "Table with name <label> does not exist" (Postgres: "relation ... does not exist"): it asked
  the database for the columns of the labeled operator's CTE, and that CTE does not exist
  while the SQL is built. A `recall` of the label later in the statement did not help. The
  same kind of query ran in three other places. `include_rhs_columns` on a temporal operator
  (for example `contains`) failed the same way when its right side was labeled. A
  `window_table` scope window and the provider columns of an operator that reads the person
  table ran the query on every build. Each of these now names its columns, so no query runs.
  The test suite now fails when building any test statement's SQL asks the database for
  columns.
- `numeric` with an upstream and a column name (`["numeric", "quantity", stream]`) now
  fails validation when the upstream's rows lack that column. The error is
  `["unknown column", "<name>"]`, so `annotate` reports it and runs no counting query.
  Before, the statement passed validation and failed at run time with a "column not found"
  error. The column is read from the rows that the upstream emits, not from the tables that
  the upstream reads. Every stream emits the same columns, so an upstream that mixes tables
  (a `union` of two domains, for example) gets the same check. The match ignores case, as
  DuckDB and Spark do. `numeric` without an upstream and a column name
  (`["numeric", "no_such_column"]`) gets the same error when the person table (`patients`
  in gdm and gdm_wide) lacks that column. That form reads the column from the person
  table, so a column that only stream rows have, such as `criterion_id`, is also an
  unknown column there.
- `filter`, `except` and `person_filter` with an `as` option now fail validation with
  `["unsupported option", "as", <value>]`. None of them has an `as` option. Before, the
  statement passed validation and ran as a plain filter, except or person_filter, so a user
  who meant to cast both streams got other rows with no warning. A blank `as` counts as not
  set. Other options that these operators read but do not declare (`ignore_dates` for
  filter and except, and the t_shank-only options) still validate.
- `Query#annotate` now gives each operator's counts (`annotation[:counts]`) in domain-name
  order, with both counting paths (one SQL statement, or a query for each operator). Before,
  the order came from the database, and the zero counts of domains with no rows came last.
  On DuckDB, the order of a multi-domain operator's domains changed from run to run, so a
  diagram drawn from the counts could change between identical runs. The keys and the
  numbers are the same as before.
- `filter` now matches a left record only to a right record with the same
  `criterion_table`, as well as the same person, `criterion_id` and `criterion_domain`. A
  `criterion_id` is an id within its table. Before, a record matched a record from another
  table of the same domain whenever their ids were equal. For example,
  `hospitalization` records (table `collections`, domain `condition_occurrence`) matched
  `icd9` records from `observations`: `filter(icd9 "*" by hospitalization, ignore_dates)`
  kept 8 such records on the test data, and now keeps none.

## [0.5.0] - 2026-10-29

### Removed

- **Breaking:** the `omopv4_plus` data model (OMOP CDM v4) is gone. ConceptQL now supports
  only `gdm` and `gdm_wide`. A `ConceptQL::Database` created with `data_model: :omopv4_plus`
  raises `ConceptQL::DataModel::UnsupportedError`, which says that the model was removed.
  The OMOP query modifiers, `schemas/omopv4_plus.yml`, the OMOP part of the `read` operator,
  the OMOP and cost vocabulary behaviors, the `omopv4_vocabulary_id` column of
  `config/vocabularies.csv` and the rake task `test_omopv4_plus` are removed with it. The
  OHDSI vocabularies (`ohdsi_vocabs`) are not affected. The SQL for `gdm` and `gdm_wide` does
  not change.

### Added

- The gem ships the specification, `doc/spec.md`. `ConceptQL.spec_path` returns its path, so
  applications can serve it without building a path into the gem directory. The Jigsaw
  diagram editor serves it to agents over MCP.
- Annotate warns about a selected code that has more than one meaning in the vocabulary, with
  the warning "code(s) with more than one meaning". Each item names the code and all of its
  distinct names, for example DRG 410, which meant chemotherapy until 2007-09-30 and a biliary
  tract procedure after that. `Lexicon#code_meanings` is the new cached lookup behind it.

### Changed

- The `co_reported` description now says that a source record is kept only if every upstream
  stream has an event in it, and that the events of all streams in any other record are
  dropped without a warning. It no longer mentions OMOP visits. The spec has a new `co_reported` section that says the same. The
  operator's behavior does not change. Applications that show operator descriptions (the
  Jigsaw diagram editor) show the new text.
- The specification (`doc/spec.md` and its source `doc/spec.md.cql`) now describes GDM
  instead of OMOP CDM v4. Every example statement now validates on `gdm_wide`. Each example
  table comes from the DuckDB test fixture, with the columns `criterion_table` and
  `criterion_domain` instead of `criterion_type`. The diagrams are drawn again from the same
  data. Examples that used removed operators (`intersect`, `complement`, `primary_diagnosis`,
  `place_of_service_code`, `visit_occurrence`, `procedure_cost`, `payer`, `value`,
  `greater_than`) now use `filter`, `provenance`, `hospitalization`, `co_reported` and
  `numeric_filter`, or are removed. The removed sections are "Intersect", "Complement",
  "Casting to a visit_occurrence", "Cast all the Things!", the intersect question in
  "Discussion about Set Operators", and "How to Handle fact_relationship Table from CDMv5".
  The new sections are "Filter" and "Casting to death". The Appendix C proposal "Filter
  Operator" is now "`as` Option for Filter", because the filter operator exists. "Time Windows" is now a `##` section,
  so that no section is larger than about 23 KB.

## [0.4.1] - 2026-10-28

### Changed

- `Query#sql(:formatted)` formats SQL inside the Ruby process with the new runtime dependency
  sequel-sqlformat (`~> 0.1`), a binding to the Rust `sqlformat` crate. It no longer starts
  sql-formatter, pg_format or sqlformat once per statement. A large algorithm (78 statements)
  now formats in about 0.13 s instead of about 8.3 s. Formatting changes only whitespace and
  keyword case, for Postgres, DuckDB and Spark SQL. sequel-sqlformat ships precompiled gems
  for Linux and macOS, so no Rust toolchain is needed.
- The development dependency sequel-duckdb is now `~> 0.4.2` (was `~> 0.4.1`). 0.4.2 fixes
  `create_or_replace_view` and drops support for the duckdb gem 1.5.x, which conceptql
  already did not use.

### Removed

- `ConceptQL::SqlFormatters`, every adapter's `preferred_formatter`, and
  `ConceptQL::Utils.timed_capture`. The external formatter programs are no longer used.
- The test Docker image no longer installs the `sqlformat` package.

## [0.4.0] - 2026-10-26

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

- `ConceptQL.metadata` marks every option that an operator requires as `required`, not only the
  first. `right` on each two-stream operator, `end` on `date_range` and `roles` on
  `provider_filter` were not marked. Marking a subclass's options no longer changes its parent
  class's option hashes
- `trim_date_end` and `trim_date_start` accept `join_columns` from a JSON statement. The column
  names arrived as strings and became string literals in the SQL, so the query failed
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
- `occurrence` with a blank or whitespace-only `at_least` or `within` (as an editor can send for
  an empty field) gives the same rows as without the option. It used to take the timed query,
  which returns other rows
- `match` without `only_columns` compared every column with `=`, so two NULL values never matched
  and a stream matched with itself kept nothing. It now compares the key columns (`person_id`,
  `criterion_id`, `criterion_table`, `criterion_domain`, `start_date`, `uuid`, `window_id`) with
  `=` and the other columns NULL-safe (`IS NOT DISTINCT FROM`, `<=>` on Spark). `match` also
  ignored `join_columns`. It now compares only the person and the listed columns, as the other
  two-stream operators do, and rejects `join_columns` next to `only_columns` or `except_columns`
- An option that lists columns (`only_columns`, `except_columns` and `join_columns` on `match`,
  and `join_columns` on the temporal operators and `trim_date_start`/`trim_date_end`) also
  accepts a comma-separated string, such as `"uuid, start_date"`. A blank string is an unset
  option. Before, a string raised NoMethodError
- `match` with `invert_match` set to the string `"false"` (in any case), or to an empty string,
  no longer inverts the match. Before, any value other than `false` and `nil` inverted it

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
- `first` and `last` reject the `at_least` and `within` options with the validation error
  "unsupported option". With either option they returned every upstream row instead of one row
  per person. The two options are no longer in the `first` and `last` metadata. A blank value
  counts as not set. `occurrence` keeps both options

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
- The `pass_thru` operator name, which never worked. `PassThru` had no query method, so a
  statement that used it failed to generate SQL. A `pass_thru` statement is now an invalid
  operator. The `PassThru` class stays as the base class of union, count, sum, numeric, dedup,
  episode, time_window and co_reported.
- `ConceptQL::Vocabularies::Entry#is_source?`, `Entry#is_standard?` and `Entry::STANDARD_VOCABS`
  (breaking for a caller of these). Their only use was the `Sourcish` include removed with the
  query optimizer. Neither t_shank nor jigsaw-diagram-editor calls them.
- The `only_columns`, `except_columns` and `query_columns` options of `dedup` (breaking). No
  statement could use them: with any column left out, the query failed, and from JSON they did
  nothing or broke the SQL. Like any option an operator does not read, they are now ignored, and
  dedup groups by every column.

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
