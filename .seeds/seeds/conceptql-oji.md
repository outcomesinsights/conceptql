---
id: conceptql-oji
title: Match codes case-sensitively unless vocabulary_formats declares a vocabulary case-insensitive? ("i16.5" should not pass)
status: captured
type: question
created_at: 2026-10-31T13:36:44.334573+00:00
updated_at: 2026-10-31T13:46:45.111275+00:00
---

## Question

Should ConceptQL match codes and keywords case-sensitively, with case-insensitivity only where the vocabulary_formats row declares it?

## Ryan, 2026-10-31 (verbatim)

"sxqe: if a code should be case insensitive, the vocabulary_format regexp should explicitly list case insensitivity. call me a stickler, but I think ICD-10-CM code i16.5 just doesn't look right and shouldn't be repected"

## What is true today (checked 2026-10-31)

- The lookup ignores case. Since commit aaaa06bc (2019-02-25, "Lexicon#concepts: make concept_code search case insensitive"), `LexiconStrategy#concepts` (lib/conceptql/lexicon/lexicon_strategy.rb:31) and `lexicon_ohdsi.rb:71` compare `lower(concept_code)` with the code in lower case. So `["icd10cm", "i16.5"]` selects the I16.5 concept.
- The pinned format table accepts lower case for several vocabularies: ICD10CM `(?:QA[0-9]|[A-Za-z][0-9][0-9ABab])(\.[0-9A-Za-z]{1,4})?`, ICD10CM.DOTLESS, HCPCS `[A-Za-z]\d{4}`, ICD10PCS `[0-9A-HJ-NP-Za-hj-np-z]{1,7}`, and CPT4 `\w\d{3}\w`. No row uses an inline `(?i)` flag, and the table has no case column. So `i16.5` passes the format check today.
- Bead conceptql-sxqe (merged a89a7a4c, 2026-10-31) made provenance keyword validation ignore case, so that it agrees with the lookup. Under Ryan's rule above, that direction is wrong: provenance keywords have no vocabulary_formats row, so they would be matched exactly.
- conceptql must not keep its own format patterns (CLAUDE.md): a pattern change is made in vocabulary_formats and the pinned copy is refreshed.

## Directions (not ruled)

- (a) Case-exact everywhere: the lookup compares `concept_code` exactly; a code in the wrong case selects nothing and gets the format warning (once vocabulary_formats rows are upper case only). Provenance keywords become exact too (undo the sxqe direction).
- (b) Case-exact by default, case-insensitive per vocabulary when vocabulary_formats declares it (an inline `(?i)` in the regexp, or a new column). conceptql would read that flag for both the format check and the lookup.
- In both, vocabulary_formats needs its rows changed to upper case only where the vocabulary is upper case (ICD10CM, HCPCS, ICD10PCS, CPT4); that repo also serves code_collector and others, so its own seed rules on it.

## Facts needed before ruling

- Production use: how many codes in current production algorithms differ in case from the vocabulary's concept_code (per vocabulary), and how many provenance keywords are not lower case. Asked jde on 2026-10-31. (jde's 2026-10-31 provenance survey: every production provenance keyword is already lower case.)
- Which vocabularies store mixed or lower case concept_codes (the lookup's case-insensitivity may exist for one of them).

RULED 2026-10-31 (Ryan): "b". Codes match case-exactly by default. A vocabulary is case-insensitive only when its vocabulary_formats row declares it; conceptql honors that declaration in both the format check and the lookup. Provenance keywords have no vocabulary_formats row, so they match exactly (this reverses the direction of bead conceptql-sxqe). Rejected: (a) case-exact everywhere with no declaration.

FACT 2026-10-31 (synpuf test vocabulary, ohdsi_vocabs): the claims vocabularies store upper-case codes. Exceptions: NDC 3 codes with a lower-case letter (e.g. 1549912340a), ICD9CM 1 defect row (sd), LOINC 2 survey codes. JS_CODE_PROV_TYPE and JS_FILE_PROV_TYPE codes are all lower case, and every production provenance keyword is lower case (jde survey 2026-10-31).

Before beads: (1) vocabulary_formats chooses how a row declares case-insensitivity (an inline (?i) in the regexp, or a column) and makes the upper-case vocabularies' patterns upper case only; handed to that repo 2026-10-31. (2) jde's production survey of codes that match only when case is ignored (asked 2026-10-31): those statements stop matching when the lookup becomes exact, so they need counting and a plan first.

UPDATE 2026-10-31: handed to vocabulary_formats as seed vfm-8k1 ("Declare case-insensitivity explicitly...", commit b9fceee there). Facts it found: more rows admit lower case than listed above (ICD10, CPT4_HCPCS and variants, the \*\_MODIFIER rows, ATC, NDC.ALPHANUM, ICDO3 and others); some rows are already upper case only (ICD9CM, ICD10PCS.BILLABLE, RxNorm Extension); the ICD10PCS row's notes and seed vfm-yop chose permissive case on purpose (a caller who lowercases codes would get a silent 100% false-negative rate), which this ruling reverses; codesistant compiles every row with re.IGNORECASE, so a declaration has no effect there until it changes; a scoped (?i:...) works in Python, Ruby, PCRE and RE2, while a global (?i) must start the pattern in Python 3.11+. conceptql waits for vfm-8k1's ruling before filing beads.

FACTS 2026-10-31 (jde production survey; 1,259 current algorithms; ohdsi20260829 concept table incl. invalid concepts; 215,971 code arguments, 112,119 distinct (vocabulary, code) pairs in 1,181 algorithms; positive control c9422/HCPCS classified case-only; JDE log claude_stuff/case-survey-20261031-064244.log):

- Codes that match a concept_code only when case is ignored: 0, in every vocabulary. Case-exact matching changes no production algorithm.
- Exact matches: 209,074 occurrences (97,519 distinct codes, 1,179 algorithms). No match in either case: 6,897 occurrences in 32 algorithms (NDC 6,815 in 6), including one NDC argument "6.9025e+10" (a code that became a float).
- Lower-case codes in algorithms: 150, all exact matches, all SEER staging (SEER_COMBINED_T cX/pX/c1A, SEER_COMBINED_M, SEER_EOD_2018_STGGRP 0a/0is, SEER_EOD_2018_M M1a). There the c/p prefix means clinical or pathological, so case carries meaning.
- No vocabulary used by the algorithms has two concept_codes that differ only in case, so today's case-insensitive selection selects no extra concepts.
- conceptql's unknown-code warning (known_codes) already compares case exactly; only selection ignores case.
- Limits: usrds_first_transplant arguments and algorithm-reference operators were not checked.
