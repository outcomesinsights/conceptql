---
id: conceptql-0eb
title: 'Spec rewrite findings: six questionable ConceptQL behaviors and an uncommitted spec regenerator'
status: captured
type: question
created_at: 2026-10-30T02:01:24.978057+00:00
updated_at: 2026-10-30T02:36:36.631060+00:00
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

RULED 2026-10-29 (Ryan): "1. fix 2. fix 3. they carry a primary diag, right? what other domain would you give them? 4. what would you do in addition to the warning? 5. ok 6. should union dedup? what's your sense of the overall behavior we should adhere to 7. yes commit and recipe"

- Item 1 (numeric with a column name fails at run time): fix. Bead filed.
- Item 2 (filter accepts an unknown `as` option): fix. Bead filed.
- Item 5 (icd10 removed from Appendix A): accepted as done.
- Item 7 (spec regenerator): commit it with a `just` recipe. Bead filed.
- Items 3, 4 and 6 are open questions back to Ryan, answered in the session on 2026-10-29:
  - Item 3: yes. Utilizable sets criterion_domain to condition_occurrence and carries primary_concept_id, the admission's primary diagnosis. GDM has no visit or admission domain. A new domain would change how union groups streams (Union's Combiner groups by domain) and how the diagram editor colors them. Recommendation: keep condition_occurrence and say so in the spec. Not a defect.
  - Item 4: recommendation: support a trailing `*` as a prefix wildcard (`410*` selects every code in the vocabulary that starts with 410), resolved through the lexicon like any code list, and keep the warning only for a prefix that matches no code.
  - Item 6: today union keeps exact duplicate rows from non-vocabulary inputs (it joins them with UNION ALL), while vocabulary inputs of one domain are merged into one WHERE clause and cpt_or_hcpcs uses a duplicate-removing UNION. Recommendation: every stream is a set, so no operator emits two identical rows; union removes exact duplicates, and skips the removal only where its inputs are provably disjoint (the bead conceptql-5pz rule). This changes the row counts of statements that union overlapping non-vocabulary inputs.

RULED 2026-10-29 (Ryan, answering the questions on items 3, 4 and 6):

- Item 3: "Keep, document it". hospitalization, hospice and snf keep criterion_domain condition_occurrence; the spec gets one sentence that says why.
- Item 4: "Make it an error". No prefix matching. A malformed code fails validation instead of only warning, so a statement cannot silently return 0 rows.
- Item 6: "Every stream is a set". No operator emits two identical rows. union removes exact duplicates and skips the removal only where its inputs provably cannot overlap (the conceptql-5pz rule). Row counts change for statements that union overlapping non-vocabulary inputs.
  Also ruled: conceptql 0.5.0 (released 2026-10-29 while the counting work was still in flight) stays published, and peers may bump to it. The counting work ships in a later release.
