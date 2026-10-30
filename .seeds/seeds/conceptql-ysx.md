---
id: conceptql-ysx
title: 'Adversarial review of the unreleased round: findings that needed rulings'
status: captured
type: decision
created_at: 2026-10-30T12:39:07.024787+00:00
updated_at: 2026-10-30T12:39:07.024787+00:00
---

## Context

Ryan asked for an adversarial review of the unreleased round (2026-10-30). Three review agents attacked v0.5.0..main; a profiler measured annotate. Findings that are plain defects were filed as beads without a ruling. This seed records the findings that needed rulings, and the rulings.

## Rulings (Ryan, 2026-10-30)

- Code formats. The new "improperly formatted code" error rejects real codes: 99 standard LOINC Lab Test codes (pattern `^\w{3,7}-\w$` misses 1-8, 20-8), CPT4/HCPCS modifiers (25, A1), and some Gemscript codes that start with '!' (1,631 in the test vocabulary; 306 not marked invalid, 135 standard). Ryan: "we don't support CPT class codes. are those gemscript codes valid and active concepts? the rest sound like they might be serious and we need to send those on to vocabulary_formats and not maintain our own regexps for finding valid codes". Then: conceptql keeps a pinned copy of vocabulary_formats.tsv in the gem (commit SHA recorded, a just recipe refreshes it). A vocabulary with no vocabulary_formats row gets no format check. Facts handed to vocabulary_formats as seed vfm-9ug.
- trim_date_start / trim_date_end with compare_all: one row per left event, trimmed by the earliest matching right event. The t_shank export engine uses compare_all with join_columns [uuid] for its baseline windows, so check whether a window can have several t0s and tell t_shank before the change.
- sum and the count advice: see the sum group-by-person seed.
- Performance: build the concept-list idea (seed conceptql-ktc).

## Defects filed as beads without a ruling

inner_join / include_rhs_columns return duplicate rows; CHANGELOG errors (numeric unknown column is breaking but listed as a fix; no breaking heading; incomplete fallback list; false claim that metadata shows count deprecated, because ConceptQL.metadata omits operators without a category); MissingVocabularyError names schema "main"; a mixed-case numeric column validates and then fails on Postgres; an interrupted just spec can leave a truncated PNG; two wording errors in the spec's hospitalization paragraph.
