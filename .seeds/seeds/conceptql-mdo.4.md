---
id: conceptql-mdo.4
title: Explicit hidden flag; numeric, sum, count and dedup stay hidden; delete the unused hidden column of vocabularies.csv
status: captured
type: decision
parent: conceptql-mdo
created_at: 2026-11-03T18:14:51.589865+00:00
updated_at: 2026-11-03T18:36:47.007020+00:00
tags:
  - operators
  - metadata
---

Child of the seed on moving the spec, operator documentation and example results into conceptql. Carried from conceptql_spec seed conceptql-spec-6sm.5 on 2026-11-03. Ruled by Ryan.

## Rulings

- Operators get an explicit `hidden` flag that defaults to false (bead conceptql-voth). Today an operator is published only when it has a category (lib/conceptql/nodifier.rb:48). The flag makes that rule explicit, and every operator gets a category.
- invalid, from, numeric, dedup, sum and count are hidden. numeric and sum are not public: "we do not yet support numeric or sum in any meaningful way." The spec does not document numeric, sum, count or dedup.
- The unused `hidden` column of config/vocabularies.csv is deleted (first review, finding 8). An agent added it on 2017-06-21 (commit 7800d44e). Entry#hidden? and Entry#visible? (entry.rb:111-125) are never called in lib/. Only test/lib/conceptql/vocabularies/removed_vocabulary_rows_test.rb:35 and :59 call visible?, so deleting the column changes that test on purpose. It marks 21 vocabularies: Concept Class, Condition Type, Currency, Death Type, Device Type, Domain, Drug Type, Ethnicity, Gender, Meas Type, Note Type, NUCC, Observation Type, Obs Period Type, Procedure Type, Race, Relationship, UCUM, Visit, Visit Type, Vocabulary. 18 of them are published operators today. Connecting the column to the new flag would drop the published set from 119 to 101.

## Facts (pinned conceptql f24667f0, gdm, Database.new(nil))

- 125 operators registered, 119 published, 36 spec_ids. vocabulary-operator covers 84 vocabulary operators. Each of the other 35 spec_ids belongs to one operator.
- JDE builds its operators from the published metadata. An existing algorithm that uses a hidden operator may not open in JDE. That is a reason to check production algorithms before any vocabulary operator is hidden later.

## Handoff

Add the CSV deletion to bead conceptql-voth. Its acceptance (the same 119 names and 36 spec_ids) stays. Leave voth unchanged until Ryan approves beads.

## REVIEW 2026-11-03 (finding 10; report docs/reviews/2026-11-03-spec-migration-seeds-review.md)

Entry#visible? is called by test/lib/conceptql/vocabularies/removed_vocabulary_rows_test.rb:35 and :59 (corrected above). Name that test in bead conceptql-voth, so that the implementer knows the change to it is intended. The jigsaw rule "never change tests to make them pass" otherwise stops the implementer. Verified: 21 hidden rows, 18 of them published operators, 101 if connected to the new flag.
