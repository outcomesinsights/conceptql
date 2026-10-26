---
id: conceptql-1
title: CPT4_HCPCS merged vocabulary — ConceptQL integration (deferred)
status: resolved
type: decision
created_at: 2026-06-04T17:06:48.933160+00:00
updated_at: 2026-10-26T20:07:50.147020+00:00
resolved_at: 2026-10-26T20:07:50.147000+00:00
resolution: "All four open questions are settled and shipped. (1) Wiring: CPT4_HCPCS is an optional third row of 'CPT or HCPCS' in config/multiple_vocabularies.csv:4 and keeps its own dynamic operator (ruled 2026-10-14). (2) Format regexps: bead conceptql-mxz (7803017c, 796032f3, merged 2026-10-26) set CPT4, HCPCS and CPT4_HCPCS to the vocabulary_formats validator rows (config/vocabularies.csv:9,10,25: ^\\w\\d{3}\\w$, ^[A-Za-z]\\d{4}$, ^\\w\\d{3}\\w$); M0201 is accepted (test/lib/conceptql/operators/code_format_test.rb). cpt_or_hcpcs now warns when every vocabulary rejects a code. (3) Namespace: conceptql-ydh (affe54fa). (4) Standardness: not a conceptql concern (descendants only for provenance and hospitalization). Efficacy: tweaking significant for (2): adopting the official rows exposed a warning-aggregation defect in MultipleVocabularies and a dead select_all? guard, both fixed in mxz; catchable in planning only by running the annotation tests against the new rows first."
tags:
  - cpt
  - hcpcs
  - vocabulary
  - multiple-vocabularies
  - format-regexp
  - deferred
converted_at: 2026-09-09T18:49:50.924417+00:00
---

CONTEXT: A materialized merged vocabulary CPT4_HCPCS is being built upstream in ohdsi_supplemental_vocabs (its seed ohdsi-supplemental-vocabs-1). It unions+dedupes ALL CPT4 + ALL HCPCS into one vocabulary_id so consumers (starting with code_set_catalog) can treat CPT/HCPCS as a single vocabulary. ConceptQL currently solves CPT+HCPCS at READ TIME via the 'CPT or HCPCS' operator (config/multiple_vocabularies.csv). When/if ConceptQL adopts the materialized vocab, the items below must be decided. PUNTED for now - this seed + its bead exist so we catch it before implementing.

DECIDED DIRECTION:

- RETIRE the cpt_or_hcpcs operator from EXPOSURE (stop advertising/offering it for new statements) but KEEP it FUNCTIONAL/SUPPORTED indefinitely - it is the only way to support legacy ConceptQL statements that reference it. Do NOT delete it.

OPEN (decide before implementing):

- Add CPT4_HCPCS to config/multiple_vocabularies.csv, or treat as a plain vocabulary_id lookup (operator becomes redundant for new statements)? Reconcile so we do NOT have BOTH doing the same job.
- format_regexp re-evaluation (config/vocabularies.csv): current CPT4 = four-digits-then-word-char, HCPCS = word-char-then-four-digits. NEITHER matches the 2-char modifiers and may not capture true shapes (Category II/III NNNN-letter, etc.). Need a CPT4_HCPCS regexp unioning all real shapes; CPT4/HCPCS regexps likely need fixing too. Ryan wants a short investigation of actual code shapes - data already partially characterized in vocabulation seed vocabulation-1.1 (CPT4: 11,259 five-digit-numeric + 6,420 four-digit-plus-letter + 390 letter-prefixed; HCPCS: 12,559 letter-prefixed + 27 other).
- Namespace trap: ConceptQL juggles operator name vs OHDSI vocabulary_id vs internal operator symbol (entry.rb remaps the ICD10 vocab to the icd10who operator). Account for this when wiring CPT4_HCPCS.
- Standardness: merged concepts inherit standard_concept from source (can be S), so two standard concepts may exist for one meaning - implications for standard/descendant resolution + whether merged concepts need concept_ancestor / Maps-to rows (also deferred upstream).

RULED 2026-10-14 (Ryan): "CPT4_HCPCS will be part of the cpt_or_hcpcs multi vocab and its own dynamic vocab operator. if you need a guard, add one." This answers the first open question: both. CPT4_HCPCS is a third row of "CPT or HCPCS" in config/multiple_vocabularies.csv, and it keeps the operator cpt4_hcpcs that DynamicVocabularies builds from any lexicon that carries it. The row is marked optional, so a Database whose lexicon lacks CPT4_HCPCS (for example the gdm_vocabs test schema) skips it. A missing required vocabulary still raises. In about a year "CPT or HCPCS" will use CPT4_HCPCS alone (Ryan, 2026-10-14). The format_regexp and standardness questions above stay open.

RULED 2026-10-26 (Ryan): the format regexps come from the vocabulary_formats repo, the official source ('happy for you to submit feedback if you think they can be improved'). Bead conceptql-mxz now holds that work. The namespace question was settled by conceptql-ydh (affe54fa). Standardness does not affect conceptql: it resolves descendants only for provenance and hospitalization concepts, never for CPT or HCPCS codes, so the question is closed for conceptql and stays with the upstream vocabulary build.
