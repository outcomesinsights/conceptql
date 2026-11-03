# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- An operator class can say `hidden`. A hidden operator still runs, but `ConceptQL.metadata`
  leaves it out. An operator is not hidden unless it says so, and a subclass does not inherit
  the mark. `invalid`, `from`, `numeric`, `dedup`, `sum` and `count` are hidden. Before,
  `ConceptQL.metadata` left out each operator without a category, and these six were the only
  such operators. Now every operator has a category from `ConceptQL.categories`. The metadata
  has no `hidden` key, and it publishes the same 119 operators on `gdm` as before.
- Operator reference documentation in the operator classes. `ConceptQL.metadata` serves two new
  keys for each operator: `returns`, a text that says which records the operator returns, and
  `examples`, a list of `{title, statement, help}`. An option or an argument can have a
  `meaning` key, a text that says what it does. `instructions` stays the hint for typing a
  value. The `label` option and the `left` and `right` options have a `meaning`. The Metadatable
  DSL has `returns`, `example` and `option_meaning`, which replaces the meaning of one inherited
  option. A subclass does not inherit `returns` or the examples. The vocabulary operators serve
  the `returns` text and the examples of `ConceptQL::Operators::Vocabulary`, each operator
  only the examples whose statement starts with its own name. All texts are plain text.

### Changed

- The `inpatient_length_of_stay` and `outpatient_event_to_return` options of `one_in_two_out`
  serve their text as `meaning`. Before, it was a `desc` key that the diagram editor did not
  read.
- **Breaking:** a code lookup raises `ConceptQL::CodeCaseMismatchError` for a code that its
  vocabulary stores only in another case. Since 0.6.0 a lookup compares codes case-exactly, so
  `data_model.concept_ids(db, "GDM_PROV", ["line"])` returned `[]` without a word, because the
  vocabulary stores `LINE`. t_shank made that call and lost every line row of an export. Now it
  raises, and the message names the vocabulary, each such code and its stored spellings. The
  error's `mismatches` attribute holds the same facts. It is an `ArgumentError`. The lookups
  that take codes raise it: `concept_ids`, `known_codes`, `concepts_to_codes`,
  `concepts_to_codes_in_class`, `code_meanings`, `concepts` and `concepts_ds`, on the
  `Lexicon` and on the data model. `concepts` and `concepts_ds` check when they build the
  dataset. A code that a lookup vocabulary stores in this case is no error, and neither is a
  code that matches nothing in any case: it still finds no concept. A vocabulary whose
  vocabulary_formats row declares `(?i:...)` already ignores case, so it never raises. Each
  of these lookups takes `check_case: false`, which skips the check and keeps the 0.6.0
  answer. A statement does not raise: a vocabulary operator, `provenance` and
  `place_of_service_filter` pass `check_case: false`. So `["icd10cm", "i16.5"]` still gets
  the warning `improperly formatted code` and selects no rows. The utilization operators
  (`hospitalization`, `hospice`, `snf`) look up their own codes with the check.
- A positional upstream is a validation error (`has upstreams`) on `after`, `any_overlap`,
  `before`, `contains`, `during`, `equal`, `except`, `filter`, `match`, `person_filter`,
  `trim_date_end`, `trim_date_start` and `read`. The first twelve take their operands from the
  `left` and `right` options, and `read` takes codes. Before, each of them ignored a positional
  upstream without a word.
- The specification moved to `docs/spec/README.md`, and `ConceptQL.spec_path` returns it. Its
  text comes from the conceptql_spec repository, which held the published spec, and it replaces
  the copy that was `doc/spec.md`. `just spec` builds it from `docs/spec/README.cql.md` on the
  DuckDB test data. The gem does not ship its diagram images.

### Removed

- The `hidden` column of `config/vocabularies.csv`, with `Vocabularies::Entry#hidden?` and
  `Vocabularies::Entry#visible?`. No code used them. The column did not hide any operator, and
  it is not connected to the new `hidden` mark of an operator.

### Fixed

- `min_upstreams` and `max_upstreams` in `ConceptQL.metadata` say how many positional
  upstreams pass validation (99 means no limit). Before, `min_upstreams` always equalled
  `max_upstreams`. `union`, `first`, `last`, `co_reported` and `occurrence` served 99/99 and now
  serve 1/99. `person` and `death` served 1/1 and now serve 0/1. `trim_date_end` and
  `trim_date_start` served 1/1 and now serve 0/0.

- A vocabulary whose domain is blank has no domain, so its operators select
  `condition_occurrence` records. The GDM vocabulary table (`gdm_vocabs.vocabularies` in the
  test data) gives 40 of its 41 vocabularies the domain `''`. Before, their operators, such as
  `cms_place_of_service`, got `criterion_domain` `''`, their predominant domain in the
  metadata was `''`, and their annotation counts were keyed by `''`. The OHDSI vocabulary
  tables give no domain, so they were not affected.

## [0.6.0] - 2026-11-02

### Added

- `provenance` takes keywords of the form `<file keyword>:<code keyword>` again (the form
  existed from 2019 until the lexicon rewrite of 2023). `"inpatient:primary_or_first"` keeps
  the records whose file provenance is in the descendants of `inpatient` AND whose code
  provenance is in the descendants of `primary_or_first`. A plain keyword keeps its meaning:
  it keeps a record when either column is in the descendants of its concept. Several keywords
  in one operator are still ORed, so `["inpatient:primary", "outpatient:first"]` keeps the
  records of either pair. The left half must be a file provenance keyword and the right half
  a code provenance keyword. Any other keyword with a `:` (a swapped pair, an unknown half, an
  empty half or a second `:`) is the validation error `unrecognized keywords`, with the
  keyword as written, and the plain query raises `ConceptQL::InvalidStatementError` for it.
  Before, annotate reported every keyword with a `:` as that error. The test statement
  `provenance/count_2.json` (`carrier_claim:primary_or_first`) is now valid. It has no
  results, because no carrier claim record in the test data has a primary or first code.
- `provenance` takes the keyword `"*"`. `["provenance", <stream>, "*"]` keeps the records
  whose file provenance or code provenance is any provenance concept, and drops the records
  with neither. It builds the SQL that `provenance` with no keyword built before. Keywords are
  ORed, so `"*"` with other keywords keeps the same records and builds the same SQL as `"*"`
  alone. The other keywords are still checked, so an unrecognized one beside `"*"` is still
  the error `unrecognized keywords`. A `"*"` half in a `<file keyword>:<code keyword>`
  keyword, such as `"inpatient:*"`, is that error too.
- `place_of_service_filter` takes the code `"*"`. `["place_of_service_filter", <stream>, "*"]`
  keeps the records whose place of service is any concept of the CMS Place of Service
  vocabulary. It drops the records with no place of service, and the records whose place of
  service is a concept of another vocabulary. This is the meaning of `"*"` in `provenance`.
  Codes are ORed, so `"*"` with other codes keeps the same records as `"*"` alone. The other
  codes are still checked, so an unknown code beside `"*"` is still the error
  `unknown code(s)`. Before, `"*"` was itself that error.
- `ConceptQL::Lexicon.for_dataset(db)` makes a DuckDB dataset its own lexicon. The returned
  Lexicon reads the OHDSI vocabulary tables (`concept`, `concept_ancestor`,
  `concept_relationship` and `vocabulary`) from `db` itself, through its search path, and
  caches its lookups. It never reads `LEXICON_URL`. Pass it as
  `ConceptQL::Database.new(db, lexicon: lexicon)`, without `cache_lookups`. When the dataset
  lacks one of the tables, it raises `ConceptQL::Lexicon::MissingVocabularyError`, whose
  message names the missing tables, the schemas that it searched and the search path. The
  error's `missing_tables` attribute holds the missing tables, and its `schemas` attribute
  holds the searched schemas, each as `catalog.schema`. `for_dataset` returns nil for a
  Postgres or Spark db, and the Database chooses its lexicon as before.
- `sum` takes the boolean option `group_by_person`. With it, `sum` gives one person result
  for each person (and window): `person_id`, `criterion_domain` `person`, `criterion_table`
  of the person table (as a cast to `person` gives them), `criterion_id` 0, the earliest
  `start_date`, the latest `end_date`, and the sum of `value_as_number`. The other columns
  are NULL. `["sum", ["numeric", 1, <stream>], {"group_by_person": true}]` counts the events
  of each person. Without the option, `sum` groups as before: by every column except the
  dates, `criterion_id` and `value_as_number`, so one person can get several rows. A value
  other than true or false is the validation error `wrong option format`.
- The operators `ms_drg` and `cms_drg` select DRG events by DRG system. CMS renumbered the
  DRG codes on 2007-10-01, when MS-DRG replaced CMS-DRG, and reused most codes for new
  meanings. An event row does not record which meaning applied, so each operator selects the
  DRG code and the event dates of its system: `ms_drg` selects the events whose `start_date`
  is on or after 2007-10-01, and `cms_drg` the events before that day. The day is the
  constant `ConceptQL::Vocabularies::DrgSystems::MS_DRG_START_DATE`. Both operators look up
  concept IDs in the DRG vocabulary as `drg` does, so they work with the OHDSI and the GDM
  lexicons. They check codes against the DRG format of vocabulary_formats (3 digits) and warn
  about unknown codes as `drg` does. They never give the warning
  `code(s) with more than one meaning`. A code list names each code by its meaning in the
  operator's system when the lexicon keeps OHDSI concept classes (`MS-DRG` or `DRG`), and by
  all of its names otherwise. The operator metadata lists both operators in the category of
  `drg`, with the preferred names `MS-DRG` and `CMS-DRG`.

### Changed

- **Breaking:** codes match case-exactly. A code selects a concept only when it has the case
  of the concept's `concept_code`, so `["icd10cm", "I16.5"]` selects I16.5 as before and
  `["icd10cm", "i16.5"]` selects no rows. A code in the wrong case also gets the warning
  `improperly formatted code`, because the format check no longer ignores case. Before, the
  lookup compared `lower(concept_code)` with the code in lower case, and the format check
  compiled each vocabulary_formats pattern with an ignore-case flag. A vocabulary can still
  ignore case: its vocabulary_formats row declares it with the scoped flag `(?i:...)`. Then
  the format check honors the flag, and the lookup compares `lower(concept_code)`. No row
  declares it today. The unknown-code warning compared case exactly before and still does.
  A survey of the 1,259 production algorithms (2026-10-31) found no code that matches only
  when case is ignored. Its 150 lower-case codes, all SEER staging codes such as `cX` and
  `M1a`, match their concept codes exactly. The `snf` operator looked up its file provenance
  with the code `SNF`, which found the concept `snf` only while the lookup ignored case. It now
  uses `snf`, so it selects the same records as before.
- **Breaking:** the pinned vocabulary_formats table (`config/vocabulary_formats.tsv`) is
  vocabulary_formats commit `dbd670ae17be0afa3002ce40e5e327c509e62f9c`, which makes every row
  case-exact. The default rows of ICD10CM, ICD10, ICD10PCS, HCPCS, CPT4, CPT4_HCPCS, the
  `*_MODIFIER` vocabularies, ATC, ICDO3, ICD03_Topography and EDI no longer accept lower-case
  letters, and the rows that used `\w` accept only digits and upper-case letters in its place.
- Provenance keywords and the codes of `place_of_service_filter` match case-exactly too,
  because their vocabularies have no vocabulary_formats row. `"Inpatient"` is the validation
  error `unrecognized keywords`, as in 0.5.0, and the plain query raises
  `ConceptQL::InvalidStatementError` for it. Every provenance concept code is in lower case.
  The unreleased change that made the keyword validation ignore case is withdrawn.
- **Breaking:** `episode` merges a record that starts inside an episode and ends after it. A
  record now stays in the episode when its start_date is no more than `gap_of` days after the
  latest end_date of the episode's earlier records. A NULL end_date counts as the start_date.
  Before, the operator compared that end plus `gap_of` with the latest end_date including the
  record itself, so a record that ended more than `gap_of` days after the episode began a new
  episode, even when it started inside the episode. For example, the records 2020-01-01 to
  2020-01-10 and 2020-01-05 to 2020-03-01 gave two overlapping episodes with `gap_of` 0 or
  30, and now give one episode from 2020-01-01 to 2020-03-01. The result changes only for
  records that last more than one day. Records of one day give the same episodes as before,
  so the test statement `episode/results_icd9_episodes_w_30d_gap.json` returns the same rows.
  Statements that make episodes of records with durations, such as drug exposures or
  hospital stays, return fewer and longer episodes.
- **Breaking:** `provenance` with no keyword fails validation with
  `["no provenance keywords; use \"*\" for any provenance"]`, and its plain query raises
  `ConceptQL::InvalidStatementError`. The error does not need a database. Before,
  `["provenance", <stream>]` kept every record with any provenance. Write
  `["provenance", <stream>, "*"]` for that. No production algorithm used the empty form on
  2026-10-31.
- **Breaking:** a Database on a real database without vocabulary raises
  `ConceptQL::Lexicon::NoVocabularyError`. `ConceptQL::Database.new(db)` raises it when `db`
  is a real database (not nil and not a Sequel mock) and neither `db` nor the `LEXICON_URL`
  database has all the OHDSI vocabulary tables (`concept`, `concept_ancestor`,
  `concept_relationship`, `vocabulary`) or all the GDM ones (`ancestors`, `concepts`,
  `mappings`, `vocabularies`). Before, such a Database silently used no vocabulary: every code
  matched no rows and the unknown-code warnings turned off, so `["icd9", "412"]` returned 0
  rows instead of 48. Code lists are not exempt. The message names the data database (never
  its user or password), its search path on Postgres and DuckDB, the missing tables of each
  kind in each database searched, whether `LEXICON_URL` is set, and the fixes. `#searches`
  holds the same facts. A Database with no db or a Sequel mock (diagram and SQL rendering)
  still uses no vocabulary, and a Database given `lexicon:` (for example
  `ConceptQL::Lexicon.for_dataset(db)`) is unaffected. `Lexicon::MissingVocabularyError` is a
  subclass of `NoVocabularyError`, so one `rescue` covers both.
- **Breaking:** the plain query raises `ConceptQL::InvalidStatementError` for a statement with
  validation errors. `Query#query`, `#sql` and `#sql_statements`, and `#all`, `#count`,
  `#execute`, `#order` and `#analyze` through `#query`, now validate the statement first,
  as `#code_list` already did. The error's message lists each error that `annotate` shows,
  with the name of its operator. `#errors` holds the same errors as the `errors` hash of
  `scope_annotate`, and `#statement` holds the statement. Warnings do not raise. Examples of
  warnings are the `count` and `drg` deprecations, an unknown code and an improperly formatted
  code. Before, an invalid statement could crash while it built (`provider_filter` without
  `roles` raised NoMethodError, and an unknown operator raised RuntimeError
  `Invalid#query called`). It could also build SQL that silently returned fewer rows.
  `provenance` ignored an unrecognized keyword, such as a concept ID or
  `inpatient:primary_or_first`, and `count` ignored every upstream after the first. Those
  statements now raise. An invalid window table and an empty statement also raise it (see
  Fixed). The error is a `Query::QueryError`, and its old name
  `ConceptQL::Query::InvalidStatementError` still works. `annotate` does not raise.
- **Breaking:** `numeric` without an upstream fails validation when its column name is not a
  column of the person table. That form (`["numeric", "<name>"]`) reads the column from the
  person table (`patients` in gdm and gdm_wide). A name that the table lacks is now the
  validation error `["unknown column", "<name>"]`, and `annotate` runs no counting query for
  the operator. This includes a column that only stream rows have, such as `criterion_id`. In
  0.5.0 on DuckDB, `["numeric", "criterion_id"]` ran and returned 249 rows on the test data.
  Now it fails validation, and its plain query raises `ConceptQL::InvalidStatementError`. A
  name that is neither a column of the person table nor an output column, such as
  `no_such_column`, also failed in 0.5.0, but only at run time. The match ignores case, as
  DuckDB and Spark do.
- **Breaking:** `filter`, `except` and `person_filter` with an `as` option fail validation with
  `["unsupported option", "as", <value>]`. None of them has an `as` option. In 0.5.0, the
  statement passed validation and ran as a plain filter, except or person_filter, so a user
  who meant to cast both streams got other rows with no warning. Now the plain query of such a
  statement raises `ConceptQL::InvalidStatementError`. A blank `as` counts as not set. Other
  options that these operators read but do not declare (`ignore_dates` for filter and except,
  and the t_shank-only options) still validate.
- **Breaking:** `union` removes exact duplicate rows. A row that arrives from more than one
  upstream comes out once, because every stream is a set. Before, `union` joined its
  non-vocabulary upstreams with `UNION ALL`, so
  `["union", ["first", ["icd9", "412"]], ["icd9", "412"]]` returned each first MI twice. Two
  rows are duplicates only when every column is equal, `label` included. The duplicate
  removal is expensive on large data, so `union` keeps `UNION ALL` when no row can come from
  two of its upstreams: when the upstreams are vocabulary operators, `cpt_or_hcpcs`-style
  operators and unions of them, and each pair has different domains or different
  vocabularies. Statements that union a labeled operator with a `recall` of it return fewer
  rows.
- **Breaking:** `trim_date_end` and `trim_date_start` with `compare_all` return one row for
  each left row. With `compare_all`, each left row is compared with every right row of the
  person (and of the `join_columns`). `trim_date_end` now trims the end_date to the earliest
  right start_date on or after the left start_date. `trim_date_start` trims the start_date to
  the latest right end_date on or before the left end_date (each date as `within` moves it,
  when `within` is given). Before, the left row came out once for each such
  right row: trimmed by each one, and also untrimmed when a right row started after the left
  row ended. For example,
  `["trim_date_end", {"left": ["icd9", "412"], "right": ["cpt", "99214"], "compare_all": true}]`
  returned event 523 twice, with the end dates 2008-03-17 and 2008-03-21, and now returns it
  once, with 2008-03-17. With `["icd9", "412"]` as both the left and the right, `trim_date_end`
  returned 60 rows for 48 left events, and now returns 48. Which left rows come out does not
  change: a left row is dropped only when it has right rows and none of them passes, and a
  left row without right rows passes through unchanged. t_shank sets `compare_all` for its
  baseline windows. Statements that count the rows of such a trim count fewer rows.
- **Breaking:** `trim_date_end` and `trim_date_start` with `join_columns` and without
  `compare_all` trim each left row by the first (`trim_date_end`) or last (`trim_date_start`)
  right row of its person and its `join_columns` values. That is the grouping that
  `compare_all` uses. Before, the operator took the person's first or last right row and only
  then joined on the `join_columns`, so a left row whose join values differed from that row's
  found no right row and passed through untrimmed. For example, `trim_date_end` with
  `["icd9", "412", {"uuid": true}]` as the left, the same events 30 days earlier as the right,
  and `"join_columns": ["uuid"]` returned 11 of the 48 events, one for each event that was
  not the first of its person, and now returns none. t_shank sets `compare_all` whenever it
  gives `join_columns`, so its exports do not change.
- **Breaking:** the `uuid` column (the option `uuid`) gives a NULL part as an empty string.
  The uuid joins `person_id`, `criterion_id`, `criterion_table`, `start_date` and `end_date`
  with `/`. Before, one NULL part, such as an event without an `end_date`, made the whole uuid
  NULL. A NULL uuid matches nothing, so `trim_date_end` or `trim_date_start` with
  `"join_columns": ["uuid"]` passed such a window through untrimmed. Now an event without an
  `end_date` has a uuid such as `1/2/observations/2008-03-10/`. A uuid without a NULL part
  does not change.
- **Breaking:** a date adjustment that is a bare number now acts as the same number of days
  with the unit `d`. With an `r`, `e` or `s` prefix, `R365` means 365 days back from the origin, `E30` means `end_date` +
  30 days, and `S7` means `start_date` + 7 days, the same as `R365d`, `E30d` and `S7d`. In
  0.5.0, these strings gave no adjustment and no error. t_shank puts `R` before lookbacks and
  blackout periods, so a lookback of `R365` was a lookback of zero days. ConceptQL now also
  reverses a bare number where it reverses an adjustment with a unit, such as `365d`. Those
  places are the `within` of a temporal operator, the `at_least` of `before`, and the `start`
  of `concurrent_within`. In 0.5.0, these options added a bare number to the date, and now
  they count it back from the date. So a statement with such a value selects a different date
  range than in 0.5.0. `DateAdjuster#adjustments` also no longer returns the result of an
  earlier call that had a different `reverse` value.
- The code formats come from vocabulary_formats. conceptql no longer keeps its own format
  patterns. A code that does not match its vocabulary's format is still the warning
  `improperly formatted code`, which names the code, as in 0.5.0. The statement stays valid:
  `annotate` counts the operator, the plain query and `Query#code_list` run, and the
  malformed code matches no rows. A code is never a prefix (`["icd9", "410*"]` does not
  select `410.00`), and a bare `"*"` still selects every code. A `cpt_or_hcpcs`-style operator
  gives the warning only when every one of its vocabularies rejects the code's format.
  `config/vocabulary_formats.tsv` is a copy of the published table of the public repository
  `outcomesinsights/vocabulary_formats`, and `config/vocabulary_formats.sha` records its
  commit. `just vocabulary-formats <ref>` refreshes both. Each vocabulary uses its default row
  (the row whose `vocabulary_id` is the vocabulary's id), anchored as `\A(?:pattern)\z`. A
  vocabulary without a row gets no format check, and an unknown code in it is still the warning
  `unknown code(s)`. Compared with 0.5.0: LOINC and Gemscript are no longer checked, so
  standard LOINC codes such as `20-8` and `1-8` no longer get the format warning. ICD10PCS
  accepts the hierarchy codes of 1 to 7 characters (`0016`). NDC accepts only the 11-digit
  claims form, so the 9-digit product codes (`003630641`) and the alphanumeric codes
  (`00019N068`) now get the format warning. RxNorm Extension, ICDO3 and EDI, which come from
  the lexicon, are now checked. The other patterns are unchanged. `config/vocabularies.csv`
  has no `format_regexp` column, and a `format_regexp` column in a custom vocabularies file is
  ignored. The `format_regexp` of a vocabulary entry's metadata is the anchored pattern from
  vocabulary_formats.
- The format warning of an NDC code says why the code matches nothing:
  `improperly formatted code (claims use 11-digit package NDCs, so it matches no rows)`. The
  claims carry the 11-digit package NDC, so a code in another form selects no rows. The
  warning keeps its shape, the message and then the codes, and the message still starts with
  `improperly formatted code`. The other vocabularies keep the plain text.
- `occurrence` with `at_least` returns each row once, because every stream is a set. Each
  earlier row of a person picks its nth row, and with `at_least` several earlier rows can pick
  the same row. Before, that row came out once for each earlier row that picked it, so
  `["occurrence", 2, ["icd9", ...], {"at_least": "30d"}]` returned 2366 rows, of which only
  1163 were distinct. The same rows come out, and only the copies are gone. Statements that
  count the rows of such an `occurrence` count fewer rows.
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
  also used when the statement has an operator that annotate does not count (an invalid
  operator, for example), when temp tables replace the CTEs (`force_temp_tables`), and when
  `CONCEPTQL_AVOID_CTES=true` turns the CTEs off. It is also used when the Database has the
  `share_utilization` option and the statement has a `hospitalization`, `snf` or `hospice`
  operator, because the shared tables are not CTEs. `skip_counts: true` runs no counting
  query, as before.
- `annotate` with one counting query for each operator (Spark, temp tables and the other
  cases above) builds its SQL faster. The data model found the vocabulary column of each
  table again each time it built an operator's columns, and now finds it once. The SQL and the
  counts do not change. On a 111-operator production algorithm on DuckDB, that `annotate`
  fell from 36 s to 30 s.
- The gemspec accepts sequelizer 0.5 (`>= 0.3.0, < 0.6`; before, `< 0.5`), so an
  application can use sequelizer 0.5's `dataset_db` and `with_dataset` with conceptql.
  conceptql calls neither of them, and the parts of sequelizer that conceptql uses did not
  change in 0.5. In sequelizer 0.5, an unqualified table name reads a dataset only inside
  `with_dataset`, so call `ConceptQL::Lexicon.for_dataset` and run the queries inside that
  block. conceptql's own Gemfile stays on the sequelizer 0.4 release.
- The SQL of a statement is smaller and takes less time to plan. The rows do not change.
  - CTEs with the same SQL and the same WITH options merge into one. A statement evaluates
    some operators more than once (a `recall`, for example), and each evaluation used to add
    its own copy.
  - An IN or NOT IN list of at least `ConceptQL::Scope::CONCEPT_LIST_MIN_ITEMS` (1,000)
    integers, such as a list of provenance concept IDs, goes to the database once. It becomes
    a `VALUES` CTE that each copy of the list reads. The CTE is `MATERIALIZED` on the
    databases that support it, which excludes Spark. A shorter list stays an IN list. On
    Spark, a list in a SELECT-list expression (the CASE flags of `one_in_two_out`) stays an
    IN list, because Spark accepts an IN subquery only in a filter or a join. On Spark, a
    NOT IN list also stays a NOT IN list, because Spark rejects a NOT IN subquery in a nested
    condition, such as the `IS NULL OR NOT IN` of `gender`.
  - On a 111-operator production algorithm, DuckDB planning of the plain query fell from
    0.81 s to 0.57 s and `annotate` with counts from 2.7 s to 2.0 s. Postgres planning of the
    same statement on the test data fell from 480 ms to 152 ms.
- The specification (`doc/spec.md`) describes the changed `union` and `filter`, the new
  `ms_drg` and `cms_drg`, the `count` and `drg` deprecations, and `sum` with
  `group_by_person`. It gives the full format of a date adjustment, with the unit `w` and the
  prefixes `r`, `e` and `s`. New sections describe `trim_date_end` and `trim_date_start`
  (with `compare_all`) and the `window` statement with a window table. It says that ConceptQL
  raises an error when it finds no vocabulary for a real database.

### Deprecated

- The `count` operator is deprecated. Every stream is a set, so `count` returns 1 for nearly
  every row. A statement that uses `count` still runs and returns the same rows. Annotation
  adds the warning `deprecated operator` on `count`, and a later release will make it an
  error. To count the events of each person, use
  `["sum", ["numeric", 1, <stream>], {"group_by_person": true}]`. Without `group_by_person`,
  `sum` splits the count of one person over several rows when the events have different
  source values. `ConceptQL::Operators::Count.to_metadata` says `deprecated: true`.
  `ConceptQL.metadata` does not list `count`, because it lists only the operators that have a
  category, and `count` has none. The new class-level declaration `deprecated` marks an
  operator.
- The `drg` operator is deprecated. A DRG code can have two meanings, and `drg` selects the
  events of both. A statement that uses `drg` still runs and returns the same rows.
  Annotation adds the warning `deprecated operator` on `drg`, and a later release will make
  it an error. Use `ms_drg` for the MS-DRG meaning (events from 2007-10-01) or `cms_drg` for
  the CMS-DRG meaning (events before 2007-10-01). The operator metadata of `drg` says
  `deprecated: true`.

### Removed

- **Breaking:** the `concurrent_within` operator is gone. A statement that names it gets the
  validation error `invalid operator`, as any unknown operator does, and its plain query
  raises `ConceptQL::InvalidStatementError`. No production algorithm used it on 2026-10-31:
  none of the 1,652 algorithm rows (current, old and deleted) named it. Its test statements
  and expected results are removed with it. The SQL of every other operator does not change.
- The unused methods `query_cols` of the `race` and `ethnicity` operators and the unused class
  method `Operator.query_columns` are removed. Nothing called them, and the two `query_cols`
  methods would have raised `NoMethodError`. The `race` and `ethnicity` operators are not
  affected: their SQL and their results do not change. `Query#query_cols` is a different
  method and stays.
- The hidden vocabulary operators `place_of_service` (alias `place of service`) and
  `specialty` are removed, with their rows in `config/vocabularies.csv`. Neither one worked.
  Their rows named the vocabularies `Place of Service` and `Specialty`, but the OHDSI and the
  GDM lexicons name them `CMS Place of Service` and `Medicare Specialty`. So
  `place_of_service` selected no record and gave no warning. `specialty` read the column
  `clinical_code_vocabulary_id` from `practitioners`, which has no such column, so its query
  failed with a database error. No production algorithm used either name. Now each name is
  the validation error `invalid operator`. The lexicon's own operators for these
  vocabularies, `cms_place_of_service` (also written `cms place of service`) and
  `medicare_specialty`, do not change. To keep records by their place of service or their
  provider's specialty, use `place_of_service_filter` or `provider_filter`. The SQL of every
  other statement is unchanged.

### Fixed

- `place_of_service_filter` selects records again. It looked up its codes in the vocabulary
  `Place of Service`, but the OHDSI and the GDM lexicons name that vocabulary
  `CMS Place of Service`. So no code became a concept ID, and the operator kept no record on
  any data. Now `["place_of_service_filter", <stream>, "21"]` keeps the records whose place of
  service (`pos_concept_id` of the record's context in gdm, of the observation in gdm_wide)
  is the concept of code 21, Inpatient Hospital. A record with no place of service is still
  dropped. A code that is not in the vocabulary is now the validation error
  `unknown code(s)`, with the code as written, and the plain query raises
  `ConceptQL::InvalidStatementError` for it. A code can never match a record when it names no
  concept, so this is an error and not a warning. The codes have two digits, so the number
  `1` is an unknown code and `"01"` is Pharmacy. Without a lexicon, no code is checked. The
  argument metadata names the vocabulary `CMS Place of Service`. The SQL of the operator now
  has the concept IDs of its codes. The SQL of every other statement is unchanged.
- `CONCEPTQL_AVOID_CTES=true` works again. Since 2022, each operator read its rows from a CTE
  of its own, but in this mode the statement had no WITH list. So the database refused the
  SQL of every statement because the CTE did not exist. Now each operator is a
  subquery in this mode, and a long concept list stays an IN list. The operators `occurrence`
  (with `at_least` or `within`) and `co_reported` still use CTEs of their own, inside their
  subquery. With the Database's `share_utilization` option, the statement reads the shared
  table as in the default mode. The SQL of the default mode is unchanged.
- An empty statement (`[]`) is now an invalid statement. `validation_errors` and
  `scope_annotate` report the error `{"invalid" => [["empty statement"]]}`, and `query`, `sql`
  and the other methods that build SQL raise `ConceptQL::InvalidStatementError`. This also
  applies to an empty operand (`["union", [], ["icd9", "412"]]`), to `[[]]`, to a `window`
  around `[]`, and to an `algorithm` whose stored statement is `[]`. Before, each of these
  raised `ArgumentError` in `Nodifier#create`.
- The statement `[nil]` or `[""]` reports its error under the key `invalid`:
  `{"invalid" => [["invalid operator", ""]]}`. Before, the key was `""`.
- `Operators::Invalid#operator_name` gives the operator name of the statement (`nope_op` for
  `["nope_op", "412"]`), and `invalid` when the statement has no name. Before, it removed the
  first code from the arguments and gave that code (`412`).
- A `ConceptQL::Database` on a Sequel mock (`Sequel.mock`) now reads its vocabulary from the
  `LEXICON_URL` database. A mock answers yes to every table check, so the Lexicon chose the
  mock as an OHDSI vocabulary that has no rows, and every vocabulary from the lexicon was an
  invalid operator. Now the Lexicon never searches a mock data database for vocabulary tables.
  Without `LEXICON_URL`, a mock gets `LexiconNoDB`, and `ConceptQL::Database.new` raises no
  `NoVocabularyError` for it.
- `annotate` reports the errors of a window table that is an invalid ConceptQL statement.
  `scope_annotate` reports them under the key `window_table`, and each message starts with
  the name of its operator (for example
  `["provider_filter: required option not present", "roles"]`). `annotate` then counts
  nothing, because every count joins the window table. The plain query of the outer
  statement raises `InvalidStatementError` with these errors and the outer statement. In
  0.5.0, `annotate` did not validate the window table, so it reported no error for it, and a
  counted `annotate` built the window table's SQL without a check.
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
  DuckDB and Spark do. `numeric` without an upstream gets the same check against the person
  table (see Changed).
- `numeric` with a column name in another case than the column's own
  (`["numeric", "Value_As_Number", stream]`) now runs on Postgres. Before, the SQL quoted the
  name as written, and Postgres found no such column. The SQL now uses the column's own name,
  so validation and the SQL agree on every database.
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
- `DataModel::Base#table_columns` no longer prints its result and its table names to
  stdout. The two `p` calls were debug output from 2019. No statement in the test suite
  calls this method, so the SQL and the results are unchanged.
- `ConceptQL.metadata` serves the `desc` of each operator again. Since 2024-12, every
  operator served the vocabulary text, for example "Selects records based on the After
  vocabulary." for `after`. The diagram editor showed this text to users. Now an operator
  serves the text that it sets with `desc`, and an operator that sets `no_desc` serves an
  empty text. A vocabulary operator, which sets no `desc`, still serves "Selects records
  based on the <name> vocabulary." The SQL is unchanged.
- In `ConceptQL.metadata`, each vocabulary operator serves `predominant_domains` as a flat
  list, for example `["condition_occurrence"]`, as the other operators do. Before, it served
  the list inside another list (`[["condition_occurrence"]]`). The SQL is unchanged.
- The diagram editor shows the `desc` of each operator to its users, so 14 texts are
  rewritten to say what the operator does. `dedup` served the text of `count`. `numeric` read
  like a code comment. `provenance` now says that it needs at least one keyword, that `*`
  matches any provenance, and that `<file keyword>:<code keyword>` matches the file AND the
  code. `information_periods` claimed that it takes an upstream stream, which it refuses.
  `concurrent_within` said that the date ranges overlap, but the other record must lie
  inside the record's date range. `provider_filter` now names its required `roles` option.
  `death`, `person` and `sum` now describe all of their inputs, and `occurrence`, `recall`,
  `hospice`, `hospitalization` and `snf` were fixed for typos or a missing final period.
  Every served `desc` now ends with a period. Also, every operator serves
  `predominant_domains` as strings. Before, a vocabulary without a domain and an operator that
  declares its domains, such as `death`, served symbols (`:condition_occurrence`, `:death`)
  to Ruby callers. The JSON and the SQL are unchanged.

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
