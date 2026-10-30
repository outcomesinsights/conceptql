---
id: conceptql-e8n
title: What should the count operator do now that every stream is a set?
status: captured
type: question
created_at: 2026-10-30T05:17:08.048015+00:00
updated_at: 2026-10-30T05:17:08.048015+00:00
---

## Question

Seed conceptql-0eb item 6 was ruled "Every stream is a set" (2026-10-29). Bead conceptql-jib made union remove exact duplicate rows (merged f4bf64b0). Beads conceptql-i3n (occurrence at_least) and conceptql-1jy (trim_date\_\* compare_all) will remove the other duplicates the conceptql-jib agent found.

The `count` operator (lib/conceptql/operators/count.rb) exists to count duplicates. Its desc: "Counts the number of records that exactly match across all columns." It groups by every column except value_as_number and writes count(1) into value_as_number. When its upstream is a set, the count is 1 for every row. It can exceed 1 only when upstream rows differ in value_as_number alone, because that column is left out of the grouping.

## What changed already

- The spec's Counting example "count rows seen twice in a union" now shows 1 on every row. The conceptql-jib agent kept the example and rewrote its text.
- With more than one upstream, count already joined them with UNION (distinct), so it never counted across upstreams.
- An algorithm that used count after a union to find codes seen in both branches now gets 1 everywhere. Nothing reports an error.

## Options

- (a) Deprecate count: a statement that uses it gets a warning now and a validation error in a later release.
- (b) Remove count now, as part of the same behavior change (0.5.1 or 0.6.0).
- (c) Redefine count to count the upstream rows per person, or per something else that still has meaning. That is a new operator under an old name.
- (d) Keep count unchanged and document that it counts only rows that differ in value_as_number.

Recommendation: (a). It tells existing algorithm users that the meaning changed, and it does not break their saved statements at once.

## Data to gather before ruling

How many saved production algorithms use count. JDE can count them.
