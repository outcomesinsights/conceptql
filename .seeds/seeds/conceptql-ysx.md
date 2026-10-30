---
id: conceptql-ysx
title: 'Adversarial review of the unreleased round: findings that needed rulings'
status: captured
type: decision
created_at: 2026-10-30T12:39:07.024787+00:00
updated_at: 2026-10-30T14:17:38.838345+00:00
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

RULED 2026-10-30 (Ryan), after bead conceptql-bns:

- NDC: "strict 11". conceptql keeps vocabulary_formats' default NDC row (\\d{11}), so 9-digit product codes, codes that lost leading zeros, hyphenated codes and HCPCS codes in an ndc operator are validation errors. jde's count (survey of 1,259 current production algorithms, 2026-10-29 copy): 10 algorithms have non-11-digit NDC codes: 7 Drafts, 1 Finalized (entrectinib: HCPCS J9170-J9172 in an ndc operator), 2 Retired; 8,001 codes. None of them can match the 11-digit codes claims rows store.
- No vocabulary lexicon on a real database: "option A". Today Lexicon#determine_strategy silently falls back to LexiconNoDB when neither the data db nor LEXICON_URL has the vocabulary tables; every code becomes 1 = 0 and the unknown-code checks turn off, so ["icd9","412"] returns 0 rows instead of 48 with no error. Ruled: ConceptQL::Database raises a clear error when it has a real data database (not nil, not mock) and finds no vocabulary. Rejected: (B) per-operator validation errors, (C) provenance only, (D) documentation only.

RULED 2026-10-30 (Ryan), reversing item 4 of 2026-10-29 ("Make it an error"): a code that does not match its vocabulary format is a WARNING again, and the statement stays valid. In the JDE session: "we should warn on non-11 digit NDC, but the algorithm is still valid. The point of a vocabulary format check in ConceptQL is to _warn_ about possible issues, not reject the statement as invalid. I misunderstood the question. I thought format check was a warning only and I think that's how it used to behave, yes?" Confirmed in the conceptql session: "yes, bad code format is a warning". Fact: through 0.5.0 it was a warning (v0.4.1 operator.rb:599 add_warning "improperly formatted code"); commit 1bc89d65 (unreleased) made it an error. The NDC ruling ("strict 11") still holds, but a non-11-digit NDC now gives a warning, not an error.
