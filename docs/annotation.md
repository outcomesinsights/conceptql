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

`annotate` of a window statement keeps the `window` operator at the top. Its options are the window's options, and its annotation hash holds only its id (`window-1`). A window table that is a ConceptQL statement is annotated in place, in the `window_table` option, so each of its errors stays on the operator that has it:

```ruby
query = cdb.query(["window", ["icd9", "412"],
                   { "window_table" => ["provider_filter", ["icd9", "412"], { "specialties" => "*" }] }])

query.valid?  # => false
query.errors
# => [{ operator: "provider_filter", id: "provider_filter-1",
#       message: "required option not present", details: ["roles"] }]
```

When the window table has errors, the statement around it is not counted, because every count joins the window table. `query.sql` raises `ConceptQL::InvalidStatementError` with the same errors.

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

These operators are not checked:

- the operators that read another table than the clinical codes, such as `death_type`.
- `cpt_or_hcpcs` and the other operators that read several vocabularies.
- `cpt` and `hcpcs` when they already give the warning that the data stores their codes as CPT4_HCPCS. That warning has the same text and names `cpt_or_hcpcs`, so they get no second warning. Their counts are null when `etl_vocabulary_ids` does not list their vocabulary.

A dataset without `etl_vocabulary_ids`, or with an empty one, gives no warning, and its counts are real counts.

```ruby
cdb.query(["gemscript", "00003007"]).annotate
# => ["gemscript", "00003007",
#     { annotation: { id: "gemscript-1", counts: { drug_exposure: { rows: nil, n: nil } },
#                     warnings: [["the data has no records of this vocabulary"]] },
#       name: "Gemscript" }]
```

## The annotation cache of a Query

A `Query` keeps one result of `annotate` for each options hash. A repeated call with the same options returns the kept result and annotates nothing. A call with other options builds a fresh operator tree and annotates it, so `annotate` after `annotate(skip_counts: true)` gives real counts.

`Query#errors`, `Query#warnings` and `Query#valid?` read the kept result of `annotate(skip_counts: true)`, so they never run count SQL, and the three together annotate once.
