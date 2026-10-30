---
id: conceptql-6c3
title: sum needs a group-by-person option so a statement can count events per person
status: captured
type: decision
created_at: 2026-10-30T12:39:06.582737+00:00
updated_at: 2026-10-30T12:39:06.582737+00:00
---

## Question

sum needs an option to group by person, so a statement can count (or total) events per person.

## Why (found 2026-10-30 by the adversarial review of the unreleased round)

The count deprecation warning and the spec told users to count events per person with `["sum", ["numeric", 1, stream]]`. That is wrong. `Sum#query` (lib/conceptql/operators/sum.rb) groups by every dynamic column except start_date, end_date, criterion_id and value_as_number, so source_value, criterion_table and criterion_domain are group keys. `sum(numeric 1, icd9 412/414.01/250.00)` returned 306 rows for 168 persons; person 14 got 7 and 6 on two rows instead of 13.

## RULED 2026-10-30 (Ryan)

"open a seed that sum needs a group by person option, fix advice, make beads, implement beads, update spec".

Design chosen for the bead (the agent may refine names; record any change here): sum gets a boolean option `group_by_person`. With it, sum returns one row per person: person_id, criterion_domain 'person', criterion_table 'person', criterion_id 0... (as the person cast produces), start_date the minimum, end_date the maximum, value_as_number the sum. The count deprecation warning and the spec recommend `["sum", ["numeric", 1, stream], {"group_by_person": true}]`.
