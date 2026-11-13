# Reading an annotated statement

`Query#annotate` returns the statement with an annotation hash in each operator. The annotation hash holds the operator's effective id, its counts, and its errors and warnings. It is the only output for errors, warnings and counts. `ConceptQL::Annotation` reads it, so a caller does not need to know where an operator keeps its inputs.

## Effective ids

Every operator gets an effective id, as the first key (`id`) of its annotation hash:

- When the statement gives the operator an `id` option, the effective id is that option.
- Otherwise the effective id is `<operator>-<n>`, where `n` counts the operators of that name in statement order: `icd9-1`, `icd9-2`. A generated id never repeats an id that the statement gives.

The options of the statement do not change. Two operators with the same name and the same arguments have different effective ids, so their errors stay apart.

## The helpers

```ruby
annotation = ConceptQL::Annotation.new(query.annotate)

annotation.valid?         # true when no operator has an error
annotation.errors         # [{ operator:, id:, message:, details: }, ...]
annotation.warnings       # the same form
annotation.each_operator  # each operator, root first: #name, #id, #annotation
```

`ConceptQL::Annotation.new` accepts the result of `annotate` and the same result parsed back from JSON (string keys), and it gives the same answer for both. Each `#annotation` hash has string keys. Warnings never make a statement invalid.

The helpers walk an operator's positional upstreams and its `left`, `right` and `window_table` options. A value is an operator only when it is an annotated operator, so an option whose value is a list of strings is not an operator.

## Window statements

`annotate` of a window statement keeps the `window` operator at the top. Its options are the window's options (for a window inside a window, the options of the inner window, which are the options that run), and its annotation hash holds its id (`window-1`) and the errors of the window options, if it has any. A window table that is a ConceptQL statement is annotated in place, in the `window_table` option, so each of its errors stays on the operator that has it:

```ruby
query = cdb.query(["window", ["icd9", "412"],
                   { "window_table" => ["provider_filter", ["icd9", "412"], { "specialties" => "*" }] }])

query.valid?  # => false
query.errors
# => [{ operator: "provider_filter", id: "provider_filter-1",
#       message: "required option not present", details: ["roles"] }]
```

When the window table has errors, the statement around it is not counted, because every count joins the window table. `query.sql` raises `ConceptQL::InvalidStatementError` with the same errors.

The errors of the window options are in the annotation hash of the `window` operator: one of `start_date` and `end_date` without the other, and an unknown `scope_by` (`ConceptQL::Window.option_errors`). Then the statement is not counted either. When the window options come from the `scope_opts` of the calling program, and not from a window statement, `annotate` puts the statement inside a `window` operator that holds the errors:

```ruby
query = cdb.query(["window", ["icd9", "412"], { "start_date" => "2010-01-01" }])

query.errors
# => [{ operator: "window", id: "window-1",
#       message: "date range needs start_date and end_date", details: ["end_date"] }]
```

## Example

```ruby
query = cdb.query(["union", ["icd9", "412", "4100"], ["icd9", "250.00", "ZZZ.99"]])

query.valid?    # => true
query.warnings
# => [{ operator: "icd9", id: "icd9-1", message: "improperly formatted code", details: ["4100"] },
#     { operator: "icd9", id: "icd9-2", message: "improperly formatted code", details: ["ZZZ.99"] }]

annotation = ConceptQL::Annotation.new(JSON.parse(query.annotate.to_json))
annotation.each_operator { |op| puts "#{op.id} #{op.annotation['counts'].to_json}" }
# union-1 {"condition_occurrence":{"rows":1084,"n":163}}
# icd9-1 {"condition_occurrence":{"rows":48,"n":37}}
# icd9-2 {"condition_occurrence":{"rows":1036,"n":162}}
```

The counts are from the DuckDB test fixture.

## Null counts

A GDM dataset can list the vocabularies of its clinical codes in the table `etl_vocabulary_ids`. A Query reads the table once, when the table exists and has rows. A vocabulary operator whose vocabulary is not in the table gets the warning "the data has no records of this vocabulary", and its counts are null: `{"rows": null, "n": null}` for each domain. A count of 0 would say that no patient has the codes, which the data cannot show. An operator whose inputs all have null counts also has null counts, without the warning. An operator with at least one input that has real counts keeps its real counts.

`cpt_or_hcpcs` and the other operators that read several vocabularies get the warning once, and null counts, only when the table lists none of their vocabularies. When it lists one of them, they get real counts and no warning.

These operators are not checked:

- the operators that read another table than the clinical codes, such as `death_type`.
- `cpt` and `hcpcs` when they already give the warning that the data stores their codes as CPT4_HCPCS. That warning has the same text and names `cpt_or_hcpcs`, so they get no second warning. Their counts are null when `etl_vocabulary_ids` does not list their vocabulary.

A dataset without `etl_vocabulary_ids`, or with an empty one, gives no warning, and its counts are real counts.

```ruby
cdb.query(["gemscript", "00003007"]).annotate
# => ["gemscript", "00003007",
#     { annotation: { id: "gemscript-1", counts: { drug_exposure: { rows: nil, n: nil } },
#                     warnings: [["the data has no records of this vocabulary"]] },
#       name: "Gemscript" }]
```

## Codes that the dataset does not contain

The lexicon of a dataset can be trimmed to the codes that the data contains, for example `ConceptQL::Lexicon.for_dataset(db)` on a DuckDB dataset. Without more information, a real code that the trimmed lexicon lacks gets the warning "unknown code(s)". To tell such a code from a code that does not exist, give the Database a reference lexicon, which is the full lexicon:

```ruby
full = ConceptQL::Lexicon.new(nil, lexicon_db, cache: true)
cdb = ConceptQL::Database.new(db, lexicon: ConceptQL::Lexicon.for_dataset(db), reference_lexicon: full)
```

The Database chooses its reference lexicon in this order:

1. The `reference_lexicon:` option.
2. When the option is not given and `LEXICON_URL` is set, a Lexicon of the `LEXICON_URL` database, with its own cache. A `LEXICON_URL` database without vocabulary tables raises `ConceptQL::Lexicon::NoVocabularyError`.
3. When neither exists, the Database has no reference lexicon.

Only the code checks of the vocabulary operators, `information_periods`, `provenance` and `place_of_service_filter` read the reference lexicon. The translation of codes to concepts, the SQL and the counts use the dataset's lexicon only, so they are the same with and without a reference lexicon. A code that the dataset's lexicon does not know gets one of these warnings, unless the 2020 rule below applies:

- "code(s) not present in this dataset", when the reference lexicon knows the code.
- "unknown code(s)", when the reference lexicon does not know the code either, or when the Database has no reference lexicon.

Both are warnings, never errors, so a statement stays valid on a dataset that lacks some of its codes. Each warning lists every code. When the operator gets the warning "the data has no records of this vocabulary" (see [Null counts](#null-counts)), that warning already says that none of its codes is in the data. So its codes get no "code(s) not present in this dataset" warning. A code that the reference lexicon does not know still gets "unknown code(s)", so a typo is not hidden. A code with more than one meaning and a code that does not have the vocabulary's format also still get their warnings.

The vocabulary operators are built from the vocabularies of both lexicons. So an operator of a vocabulary that only the reference lexicon has is valid, and it is not an "invalid operator" error.

A vocabulary that no lexicon of the Database has accepts every code (a rule from 2020), because such a lexicon cannot tell a real code from a typo. A lexicon has a vocabulary when it has at least one concept of it. For a code that the dataset's lexicon does not know:

| The dataset's lexicon has the vocabulary | Reference lexicon | It has the vocabulary | Warning                                                                              |
| ---------------------------------------- | ----------------- | --------------------- | ------------------------------------------------------------------------------------ |
| yes                                      | none              | -                     | "unknown code(s)"                                                                    |
| yes                                      | given             | yes or no             | "code(s) not present in this dataset" when it knows the code, else "unknown code(s)" |
| no                                       | none              | -                     | none (the 2020 rule)                                                                 |
| no                                       | given             | yes                   | "code(s) not present in this dataset" when it knows the code, else "unknown code(s)" |
| no                                       | given             | no                    | none (the 2020 rule)                                                                 |

`etl_vocabulary_ids` does not change this rule. `ConceptQL::Database#check_codes` applies it for every operator that checks codes.

`cpt_or_hcpcs` and the other operators that read several vocabularies check their codes as one set. A code is known when the dataset's lexicon has it in any of their vocabularies. Of the other codes, one that the reference lexicon has in any of the vocabularies is "code(s) not present in this dataset", and the rest are "unknown code(s)". A code is "improperly formatted code" only when it does not have the format of any of the vocabularies. Each warning appears once, on the operator. The 2020 rule applies to the set: the operator accepts every code only when no lexicon of the Database has any of its vocabularies.

`provenance` checks a plain keyword, such as `inpatient`, as one set across the file and the code provenance vocabularies. It checks a keyword of the form `file:code` half by half: the file keyword against the file provenance vocabularies and the code keyword against the code provenance vocabularies. A pair with an unknown half is "unknown code(s)". Else a pair with a half that only the reference lexicon knows is "code(s) not present in this dataset". A pair with more than one `:` is "unknown code(s)". `place_of_service_filter` checks its codes against CMS Place of Service. For both operators, an unknown keyword or code is a warning, and it selects no row. `provenance` with no keyword is still an error.

## The annotation cache of a Query

A `Query` keeps one result of `annotate` for each options hash. A repeated call with the same options returns the kept result and annotates nothing. A call with other options builds a fresh operator tree and annotates it, so `annotate` after `annotate(skip_counts: true)` gives real counts.

`Query#errors`, `Query#warnings` and `Query#valid?` read the kept result of `annotate(skip_counts: true)`, so they never run count SQL, and the three together annotate once.
