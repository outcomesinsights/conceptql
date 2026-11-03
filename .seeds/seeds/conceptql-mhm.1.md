---
id: conceptql-mhm.1
title: 'Operator documentation as code: desc, options, returns and examples in each operator class'
status: resolved
type: idea
parent: conceptql-mhm
created_at: 2026-11-03T16:32:58.027724+00:00
updated_at: 2026-11-03T18:15:06.911375+00:00
resolved_at: 2026-11-03T18:15:06.911367+00:00
resolution: Superseded on 2026-11-03 by conceptql-mdo.2 (operator documentation as code), which carries the reviewed deliberation and Ryan's rulings from conceptql_spec seed conceptql-spec-6sm.2.
---

Child of the seed "One ConceptQL specification, built inside conceptql". Captured 2026-11-03. Ryan agreed in discussion. Not yet permission to build.

## Proposal

Each operator class holds its own reference documentation, through the Metadatable DSL that already holds `desc` and option `instructions:`:

```ruby
desc "Merges each patient's records into episodes..."
allows_one_upstream
option :gap_of, type: :integer, default: 0,
       instructions: "The largest gap in days between ..."
returns "One record for each episode. Its start_date is ..."
example "Episodes of diabetes diagnoses",
        ["episode", ["icd9", "250.00"], { gap_of: 90 }]
```

- `ConceptQL.metadata` carries these items, so JDE gets them without a new file or reader.
- The spec build makes each operator's reference section from the metadata, in a fixed order: summary (`desc`), upstream, arguments, options (each with its meaning), returns, examples (with generated result tables and diagrams).
- Text about more than one operator stays in markdown: the overview, streams and types, shared rules of the temporal operators, casting, the showcase algorithms. Longer explanations of one operator also stay in markdown (for example the A-A-B-A-B-A explanation of `before`). The build places that text after the generated block.

## Why

- The code already holds the structural facts, because validation needs them: upstream counts, argument and option names, types, required options and defaults. Text beside each `option` call cannot name an option that does not exist.
- One source for each text. Today `desc`, `instructions:`, the README's first paragraph, the README's option lists and the quick-reference table (Appendix E) all describe the same operators.
- A test can validate every `example` statement of every operator, hidden or published. This keeps the check that conceptql's `just spec` gives today.

## Rules to enforce with tests

- Every published operator has a non-empty `desc`, a `returns` text, a text for each option and argument, and at least one example.
- Every example validates with no errors.
- The 84 vocabulary operators share one section and keep their generated text (standard_description, multiple_vocabularies' desc). They need one special case in the build.

## Costs and open points

- Long text in Ruby strings is harder to read in a diff than markdown. Use heredocs.
- Plain text or markdown in `desc` and `instructions:`: JDE shows them as tooltips and form help. The recommendation was plain text with backticks for names.
- The quick-reference table (Appendix E) has a third short text per operator and groups several operators in a row. Generate it from `desc` or remove it.
- The README's per-operator sentences must make sense alone (for example, define LHR where it is used).
- Supersedes bead conceptql-o29p (derive desc from the spec) and the YAML design.
