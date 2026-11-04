---
id: conceptql-mdo.2
title: 'Operator documentation as code: desc, two texts per option, returns and examples in each operator class'
status: resolved
type: decision
parent: conceptql-mdo
created_at: 2026-11-03T18:14:50.728093+00:00
updated_at: 2026-11-04T15:11:22.873251+00:00
resolved_at: 2026-11-04T15:11:22.873241+00:00
resolution: 'Shipped by conceptql-jwsv.1 and .6 to .10. The Metadatable DSL has option_meaning, returns and example (lib/conceptql/behaviors/metadatable.rb:90-107). All 119 published operators have a returns text, and each spec_id has at least one example. Efficacy: minor tweak, caught in planning. Review finding 4 moved the example rule from each operator to each spec_id before the beads were written.'
tags:
  - spec
  - metadata
  - operators
---

Child of the seed on moving the spec, operator documentation and example results into conceptql. Carried from conceptql_spec seed conceptql-spec-6sm.2 on 2026-11-03. Ryan agreed to documentation in the operator classes and ruled that each option has two texts.

## Proposal

Each operator class holds its reference documentation through the Metadatable DSL, which already holds `desc` and option `instructions:`:

```ruby
desc "Merges each patient's records into episodes ..."
allows_one_upstream
option :gap_of, type: :integer, default: 0,
       instructions: "Enter a number of days",
       meaning: "The largest gap in days between ..."
returns "One record for each episode. Its start_date is ..."
example "Episodes of diabetes diagnoses",
        ["episode", ["icd9", "250.00"], { gap_of: 90 }]
```

(`meaning:` is a placeholder name. The implementer chooses the name and records it.)

The spec build makes each operator's reference section from the metadata in a fixed order: summary (desc), upstream, arguments, options (each with its meaning), returns, examples with result tables and diagrams. Text about more than one operator, and longer explanations of one operator, stay in markdown after the generated block.

## Why

- One text for each purpose. Today desc, instructions, the README's first paragraph, its option lists and the quick-reference table (Appendix E) all describe the same operators.
- Text beside each `option` call cannot name an option that does not exist.
- A test can validate every example of every operator.

## Prerequisite: the metadata's structural facts are wrong today (first review, finding 1)

- metadatable.rb:158 is `min_upstreams: @max_upstreams || 0`, so min always equals max.
- union, first, last and co_reported report 99/99. occurrence reports 99/99 because occurrence.rb:44 `validate_at_least_one_upstream` overrides occurrence.rb:43 `allows_one_upstream`. The binary temporal operators (before, after, during, ...) report 0/0, because their operands are the `left` and `right` options. trim_date_end and trim_date_start report max 1 and also have left and right.
- JDE never reads min_upstreams or max_upstreams, so nobody noticed.
- A bead must fix this first, with a test that compares the metadata with what validation accepts. The generator renders `left`/`right` as operands and the generic `label` option once, not in every section.

## Rules

- Ruled: two texts per option. `instructions:` is the form hint for typing a value. 8 of today's 11 instructions texts are that hint ('Enter a numeric value and specify "d", "m", or "y" ...'). Only 3 describe a meaning (episode gap_of, occurrence group_by_date, sum group_by_person). The new text says what the option does.
- one_in_two_out.rb:24 and :30 already use an option key `desc:`, a third text that JDE does not read. Fold it into the new text.
- Options are inherited (Metadatable#inherited): the 11 instructions: call sites hold 5 different strings, which appear 21 times over all registered operators (20 times in the published metadata, because sum is hidden). For example, temporal_operator.rb:18 gives `within` to every temporal operator. A subclass needs a way to replace the meaning of one inherited option.
- `desc` is not inherited today. `returns` and `example` must not be inherited either, because an inherited example would show the wrong operator.
- Every published operator has a desc, a returns text, a meaning for each option and argument, and at least one example. Every example validates.
- The 84 vocabulary operators share one section and keep their generated text (standard_description, multiple_vocabularies' desc).
- The set of published operators depends on the database. CPT4_HCPCS needs a lexicon, production lexicons add operators such as cms_place_of_service, and jigsaw_builder sets CONCEPTQL_CUSTOM_VOCABULARIES. The rules apply to the build's database: gdm with no lexicon and no custom vocabularies. gdm and gdm_wide give the same 119 operators. Operators from a lexicon or a custom file fall under the shared vocabulary section.

## JDE effects (tell JDE's session when this ships)

- JDE shows desc as escaped plain text (`{{@model.description}}` in jam-node.hbs). So desc and the option texts are plain text. Backticks would show literally.
- JDE passes instructions for options but not for arguments (operator-registry.js). Argument texts need a JDE change to show.
- JDE's spec/lib/ember_operator_metadata_spec.rb compares a committed copy of 50 operators' metadata with what conceptql serves. Any change to desc or any new key fails JDE's suite until `just ember-operator-metadata` runs.
- JDE embeds the metadata in every page (boot_config_helper.rb). Examples in the metadata go to every page unless JDE filters them (decision 14 in the parent seed leaves that to JDE).
- conceptql's doc/metadata.md documents the metadata shape and needs the new keys.

## Supersedes

Bead conceptql-o29p (derive desc from the README) and the YAML design.

## Ruled 2026-11-03 (conceptql_spec question conceptql-spec-74c)

The operator code is the source of all operator metadata, examples included. An example's title and statement are written in the operator class and appear in ConceptQL.metadata. Results and diagram data are never written in code: the spec build generates them as artifacts (child seed on example results). Whether the editor puts examples into the metadata that every page carries is the editor's choice.

## REVIEW 2026-11-03 (findings that apply here; report docs/reviews/2026-11-03-spec-migration-seeds-review.md)

- Finding 4 (FACT FIX). The rules say the build's database is gdm with no lexicon, but decision 08 runs the examples on the DuckDB fixture, whose database has a lexicon from ohdsi_vocabs (test/db_helper.rb builds CDB with cache_lookups: true). On the fixture, ConceptQL.metadata publishes 431 operators, not 119 (still 36 spec_ids), and 53 of the shared 119 have other short_name and long_name values. Proposed: name two databases. `Database.new(nil, data_model: :gdm)` decides which operators get a section and which metadata is printed. The fixture database runs the examples and draws the trees. The build unsets CONCEPTQL_CUSTOM_VOCABULARIES.
- Finding 4, second part (FACT FIX). "Every published operator has ... at least one example" must apply to each spec_id. Otherwise each of the 84 vocabulary operators needs its own example, because `example` is not inherited.
- Finding 9 (FACT FIX). The prerequisite fix of the upstream counts also fails JDE's suite. JDE's committed metadata copy (frontend/tests/helpers/operator-metadata.json) holds the wrong counts of union, first, last, co_reported, occurrence, before, after, during, trim_date_end and trim_date_start. Add this to the JDE effects, and tell JDE's session when it merges.
- Finding 13 (FACT FIX). The count of instructions texts was corrected above.
- Plausible, not demonstrated: no README example uses equal, filter, match or numeric_filter. Nobody has checked that the fixture gives rows for new examples of them.
- Verified: all 59 README examples validate with no errors or warnings on Database.new(nil), on a mock Postgres database and on the fixture. No README example uses a hidden operator.

UPDATE 2026-11-04: shipped by beads conceptql-jwsv.1 and conceptql-jwsv.6 to conceptql-jwsv.10. The rule "at least one example" applies to each spec_id, as review finding 4 corrected it. On 2026-11-04, all 119 published operators on gdm have a returns text. The 81 operators without their own examples are vocabulary operators, which share the spec_id "vocabulary".
