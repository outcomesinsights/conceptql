---
id: conceptql-oji
title: Match codes case-sensitively unless vocabulary_formats declares a vocabulary case-insensitive? ("i16.5" should not pass)
status: captured
type: question
created_at: 2026-10-31T13:36:44.334573+00:00
updated_at: 2026-10-31T13:39:21.550899+00:00
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
