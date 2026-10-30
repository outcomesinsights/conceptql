---
id: conceptql-0eb
title: 'Spec rewrite findings: six questionable ConceptQL behaviors and an uncommitted spec regenerator'
status: captured
type: question
created_at: 2026-10-30T02:01:24.978057+00:00
updated_at: 2026-10-30T02:01:24.978057+00:00
---

Found 2026-10-29 by the agent that rewrote doc/spec.md for GDM (bead conceptql-p3i). It ran every spec example against the DuckDB test fixture (gdm_wide, OHDSI lexicon). None of these is fixed. Each needs a ruling: defect (file a bead) or intended (document it).

## Behaviors that look wrong

1. `["numeric", "quantity", stream]` passes validation, then fails at run time with a DuckDB "column not found" error.
2. `filter` accepts an unknown `as` option with no warning or error.
3. `hospitalization` results have criterion_domain `condition_occurrence` and criterion_table `collections`. The domain looks wrong for an inpatient stay.
4. `["icd9", "410*"]` only warns "improperly formatted code" and returns 0 rows. Only a bare `"*"` works as a wildcard. The old spec used `410*` in its showcase.
5. The `icd10` (WHO) operator is an "invalid operator" against the fixture's lexicon, so the agent removed it from Appendix A.
6. `union` keeps duplicates from upstreams that are not vocabulary operators: `union(first(412), 412)` gives 85 rows, not 48. This matters to bead conceptql-5pz (UNION ALL where inputs cannot overlap): today's `union` already behaves as UNION ALL in this case, so the duplicate-removal rules are not uniform.

## Stale spec text that is not about OMOP (left as it was)

- "For 11 of the 13 temporal operators" overstates what is implemented.
- The `day` operator is still listed as not implemented.

## The spec regenerator is not committed

The agent rebuilt the 2017 diagram renderer (layout, colors, graphviz `dot`) and a harness that runs every ConceptQL block in doc/spec.md.cql. Diagram file names are the SHA256 of the statement's Ruby 2 `inspect` with symbol keys. The scripts are only in an ignored scratch directory of the primary checkout (`claude_stuff/spec-tools/`: knit.rb, spec_harness.rb, spec_blocks.rb, ops.rb, old_inspect.rb). The next spec edit needs them. Options: (a) commit them as a `just spec` recipe with a test, (b) leave them out and regenerate by hand next time. Recommendation: (a).
