---
id: conceptql-vox.2
title: One declared, multi-faceted classification of ConceptQL operators, checked against the spec
status: captured
type: exploration
parent: conceptql-vox
created_at: 2026-11-12T18:31:31.813803+00:00
updated_at: 2026-11-12T23:35:08.427194+00:00
tags:
  - cutting
  - ontology
  - metadata
  - spec
---

CUTTING (2026-11-12). NOT RULED. Set aside so the session could work on the ConceptQL glossary (`conceptql-vox.1`) first.

**What we were discussing:** one declared classification of ConceptQL's ~50 operators, published in `ConceptQL.metadata`. The spec build would check that the spec prose calls each operator only by a class that it has (for example, "selection operator" only for a selection operator).

**Why it came up:** in `conceptql-vox` (OWL ontology for AI-built cohorts), Ryan asked whether an ontology could be built from the class hierarchy. His words, verbatim:

```
doesn't it make sense to have an ontology for things like selection operators pass-throughs, filters, binary operators, things like that that we can discern somewhat from a A following of the class hierarchy. [...] this felt very much like object-oriented programming in its way of thinking. Would that ontology be able to ensure that we are correctly using wording in the spec?
```

**Established (data checked 2026-11-12):**

The code and the spec hold four classifications of operators, and they disagree:

1. Ruby superclasses: the direct subclasses of `PassThru` are co_reported, dedup, episode, count, sum, time_window, union and numeric. These share code, not meaning. So the Ruby hierarchy records code reuse and cannot be the source of a classification.
2. `basic_type`: `:selection`, `:temporal`, `:set`, `:filter`, `:cast`. It has errors: numeric_filter, place_of_service_filter and provenance declare `:temporal`, but none of them compares dates. `PassThru` declares `:set`, so count and time_window inherit `:set`.
3. `category` (the diagram editor's menu groups): "Filter Single Stream", "Select by Property", "Modify Data", "Select by Clinical Codes", "Get Related Data", "Filter by Comparing", "Combine Streams".
4. The section headings of `docs/spec/README.cql.md`: Selection Operators, Set Operators, Time-oriented, Relative Temporal, Temporal Comparison, Time Manipulation, Inline-Filter, Comparison Operators.

Spec term counts (case-insensitive lines): "temporal operator" 11, "selection operator" 8, "filter operator" 2, "set operator" 2, "binary operator" 0, "casting operator" 0, "pass-through" 0.

A single list of classes does not fit. Example: trim_date compares two streams AND changes dates. Claude proposed two independent facets (a facet is one independent property, and each operator has a value for each facet):

- Facet 1, inputs: none, one stream, two streams (left and right), many streams.
- Facet 2, effect on rows (draft):

| Effect                                | Operators                                                                                                            |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Selects rows from the data            | vocabulary, multiple_vocabularies, date_range, gender, race, ethnicity, from, hospice, hospitalization, snf          |
| Removes rows from one stream          | dedup, first, last, occurrence, one_in_two_out, numeric_filter, place_of_service_filter, provenance, provider_filter |
| Removes rows by comparing two streams | filter, except, match, person_filter                                                                                 |
| Removes rows by comparing dates       | before, after, during, contains, any_overlap, equal                                                                  |
| Changes dates or values               | time_window, trim_date, trim_date_start, trim_date_end, episode, numeric                                             |
| Combines streams                      | union, co_reported                                                                                                   |
| Aggregates                            | count, sum                                                                                                           |
| Changes the table (cast)              | person, death, information_periods                                                                                   |

Claude's position: an OWL reasoner cannot check English prose. The check needs one declared classification, a list of spec terms for each class, and a spec-build lint. That is a controlled vocabulary, and it needs no OWL.

Ryan's response, verbatim:

```
I think the two-facet draft Might need to be a multifaceted draft and need to go into a different seed.
```

**Open:**

- Which facets? Ryan expects more than two. Candidates not yet discussed: whether an operator reads from the data at all, whether it passes upstream rows through unchanged, whether it uses dates, and whether its output type differs from its input type.
- Is the facet table correct for each operator? The least certain rows are recall, invalid, information_periods and the casts.
- Do the facet values become glossary terms in `conceptql-vox.1`? That seed defines words such as "selection operator", so the class names should match it.
- Does `category` (an editor menu) stay separate from the classification, or is it derived from it?

## UPDATE 2026-11-12: Ryan's own grouping of operators

Ryan's account, condensed (the raw monologue of 2026-11-12 is in a private transcript archive):

- After a selection operator pulls rows, many kinds of filter follow.
- Inline filters pass upstream results through a filter, and only matching rows go downstream: place_of_service_filter, provenance, provider_filter.
- Occurrence operators (first, last, nth occurrence) compare events in sequence only. They can enforce gaps of time. This is also done inline.
- Binary operators take a left-hand side and a right-hand side and yield one result. Left rows pass if they meet the comparison with the right rows. The name comes from computer science (as for the plus operator). person_filter is one. Many binary operators make temporal comparisons, related to Allen's interval algebra.
- time_window, trim_date_start and trim_date_end change dates. (Ryan first grouped the trim_date operators with time_window. RULED 2026-11-12: that was a mistake. The trim_date operators are binary.)
- union is a set operator that takes many streams. except is a set operator and also a binary operator. co_reported is a kind of its own.
- Ryan doubted that this added much beyond the spec.

### What it shows (Claude, checked 2026-11-12)

- Ryan's groups: selection; inline filter (place_of_service_filter, provenance, provider_filter); sequence (first, last, nth occurrence); binary, left and right (person_filter and the temporal comparisons, related to Allen's interval algebra); date modifiers (time_window, trim_date_start, trim_date_end); set (union is multi-stream, except is binary); co_reported alone.
- This is close to the facet table, with one change: sequence is a group of its own, separate from inline filters.
- Ryan's spoken terms are not in the spec: "binary operator" 0 lines, "pass-through" 0 lines. The spec names "Inline-Filter Operators" (a section) and "inline filter operator" (line 683).
- One disagreement with the code: Ryan grouped trim_date_start and trim_date_end with time_window. In the code they take a left and a right stream (`TrimDate < TemporalOperator < BinaryOperatorOperator`), and their desc says "each left-hand record ... the right-hand record". time_window takes one stream. So they are binary date modifiers.
- except is both a set operator and a binary operator. This is the case that a single list of classes cannot hold, and it supports more than one facet.

## UPDATE 2026-11-12: facets read from the code

Ryan, 2026-11-12: "I think the approach of trying to find one 'kind' for each operator is misleading and taking us in a not-so-useful direction." He asked for a first set of facets from the validations, the superclasses and the metadata of each operator.

Method: a probe script loaded each static operator class (42; the vocabulary operators are built for each database and were not in the list) and dumped its superclass chain, included behavior modules, validations and `to_metadata` fields.

### Facets that the code already declares

1. **Upstream shape** (from the validations): none (`no_upstreams`) for selection operators; exactly one (`one_upstream`); none or one (`at_most_one_upstream`: person, death, numeric); left and right (`required_options(left,right)`, every `BinaryOperatorOperator`); one or more (sum); two or more (union, co_reported).
2. **Reads the data set and takes scope windows** (`Behaviors::Windowable`): cpt_or_hcpcs and the other vocabulary operators, date_range, from, gender, race, information_periods, hospice, hospitalization, snf, person, death. This is Ryan's "selection operator", measured. Not windowable although they take no upstream: recall (reads labeled results, not the data set), invalid, and ethnicity (see below).
3. **Window by person, not by date** (`Behaviors::Timeless`): date_range, from, gender, race, information_periods, person. A window keeps every result of a person who has a window, whatever the dates.
4. **One result per person** (`Behaviors::SingleEvent`): first, last, occurrence, one_in_two_out.
5. **Takes codes as arguments** (`Behaviors::CodeLister`): the vocabulary operators.
6. **Uses provenance** (`Provenanceable`): provenance, one_in_two_out.
7. **Selects utilization records** (`Behaviors::Utilizable`): hospice, hospitalization, snf.
8. **Compares dates of left and right** (superclass `TemporalOperator`, with the options within and at_least): after, before, during, contains, any_overlap, equal, trim_date_start, trim_date_end.

### What the existing labels turn out to be

- `basic_type` is an encoding of upstream shape. `Metadatable#arity` maps it: selection 0, temporal and cast 1, filter 2, set -1 (many). So numeric_filter, place_of_service_filter and provenance say `:temporal` only because each takes one upstream. The names are misleading. The facts are not wrong.
- `category` is the editor's menu grouping. It is not derived from anything.
- The superclasses carry a facet only in some cases: `BinaryOperatorOperator` (left and right), `TemporalOperator` (date comparison), `Occurrence` (first, last). `PassThru` carries none: its subclasses share code only.

### Not declared anywhere

The effect on rows (keeps a subset, changes dates or values, combines streams, aggregates, casts to another table) exists only in the desc texts. If it is a facet, it needs a new declaration.

### Defect found by this listing

gender and race include Timeless and Windowable. ethnicity includes neither, so it probably ignores scope windows. Filed as bead `conceptql-wsib` (not yet verified by a run).

## RULED 2026-11-12 (Ryan)

- "I like the effect on rows facet." Effect on rows becomes a facet. (A ruling on the direction. It does not authorize building the declaration yet.)
- ethnicity should be Timeless, just like gender and race. Recorded on bead `conceptql-wsib`.

### Draft values of the effect facet (Claude, from the desc and returns texts; not confirmed)

An operator can have more than one effect, so the facet holds a set of values.

| Effect        | Meaning                                                        | Operators                                                                                                                                                                                       |
| ------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| select        | makes results from rows of the data set                        | vocabulary operators, date_range, from, gender, race, ethnicity, hospice, hospitalization, snf, information_periods; person and death with no upstream                                          |
| keep          | passes on some upstream results, unchanged                     | place_of_service_filter, provenance, provider_filter, numeric_filter, first, last, occurrence, dedup, filter, except, match, person_filter, before, after, during, contains, any_overlap, equal |
| change        | changes dates or values of results                             | time_window, numeric                                                                                                                                                                            |
| keep + change | removes some results and changes the dates of others           | trim_date_start, trim_date_end, one_in_two_out (an inpatient result gets the admission and discharge dates)                                                                                     |
| combine       | puts the results of several streams into one                   | union; co_reported (combine + keep)                                                                                                                                                             |
| aggregate     | makes new results that each stand for several upstream results | count, sum, episode                                                                                                                                                                             |
| cast          | makes results of another table for the people in the upstream  | person and death with one upstream                                                                                                                                                              |
| refer         | passes on the results of another operator in the statement     | recall                                                                                                                                                                                          |

Uncertain: numeric with no upstream (it allows none or one); whether dedup is keep or aggregate; whether refer is a value or recall is a special case.

## UPDATE 2026-11-12: are the eight facets expressed in the metadata?

Ryan asked: "are all those existing 8 facets well-defined and clearly expressed in the metadata?"

Answer (Claude, checked against `Metadatable#to_metadata` and the probe output): no. Only one facet reaches `ConceptQL.metadata`, and that one only in part.

| Facet              | In the metadata?                                                                                                                                                                                                                                                                                                                                                                    |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Upstream shape  | Partly. `min_upstreams` and `max_upstreams` come from the validations (99 means no limit). Binary operators report 0 and 0, because left and right are options; the two inputs show only as `arity` 2, which comes from `basic_type`. union and co_reported report a minimum of 1 but require 2: there is no `validate_at_least_two_upstreams_to_metadata` (bead `conceptql-wldf`). |
| 2. Windowable      | No. A Ruby module only.                                                                                                                                                                                                                                                                                                                                                             |
| 3. Timeless        | No. A Ruby module only.                                                                                                                                                                                                                                                                                                                                                             |
| 4. SingleEvent     | No. A Ruby module only.                                                                                                                                                                                                                                                                                                                                                             |
| 5. CodeLister      | Indirectly: the argument type is `codelist`.                                                                                                                                                                                                                                                                                                                                        |
| 6. Provenanceable  | Indirectly: the options and argument types.                                                                                                                                                                                                                                                                                                                                         |
| 7. Utilizable      | No. Its category "Select by Property" and its domain are shared with other operators.                                                                                                                                                                                                                                                                                               |
| 8. Date comparison | No. `basic_type` `filter` covers every binary operator, temporal or not.                                                                                                                                                                                                                                                                                                            |

Well-defined? In the code, each behavior module is narrow and exact (for example Timeless only defines `timeless?` true, which the window classes read). But the modules have no documentation, apart from one comment line on Windowable. The metadata, the spec and the editor do not see them.

Consequence: to make the facets usable for the glossary and for a spec check, each one needs an explicit field in the metadata, derived from the module or validation that already defines it. Effect on rows needs a new declaration.

## RULED 2026-11-12 (Ryan), and beads made

Rulings during the conversion to beads:

- The facets go into ONE `facets` hash in each operator's metadata, not top-level keys. Ryan asked why. Claude's reason: the classification is one unit for its readers (spec check, glossary export), and it stays apart from older fields that overlap with it under misleading names (`basic_type`, `arity`, `min_upstreams`). The diagram editor reads those older fields, so they stay unchanged.
- The effect values are built as drafted ("Build with the draft"): select, keep, change, combine, aggregate, cast, refer. dedup is keep, numeric is select and change, recall is refer.
- The spec check is created but blocked until the glossary rules on the term rules ("Create it, blocked").

Beads:

- `conceptql-mc54`: export the eight derived facets as one `facets` hash in `ConceptQL.metadata`.
- `conceptql-x9qv`: declare each operator's effects and export them as `facets[:effects]` (depends on mc54).
- `conceptql-tc0q`: spec-build check of operator class terms against the facets. BLOCKED on the glossary ruling of the term rules (depends on mc54 and x9qv).
- Defects found on the way: `conceptql-wsib` (ethnicity ignores scope windows; Ryan: it should be Timeless like gender and race) and `conceptql-wldf` (metadata min_upstreams is 1 for union and co_reported, which require 2).
