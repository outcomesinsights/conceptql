---
id: conceptql-7p3
title: How does a ConceptQL statement lock in the meaning of a code that has had more than one meaning?
status: captured
type: question
created_at: 2026-10-30T11:51:55.643472+00:00
updated_at: 2026-10-30T12:00:36.764119+00:00
---

## Question

How does a ConceptQL statement lock in the meaning of a code, so that its result does not depend on which dataset it runs against?

## What Ryan said (2026-10-30, verbatim)

Asked which form the reused-code warning should take (seed conceptql-lp3), with the recommendation "warn only when the data's date range covers more than one meaning":

> this feels like a weird approach -- if I have an algorithm with renumbered codes, its behavior changes based on datast its applied to? this feels bad. conceptql statements are supposed to be definitive, explicit, and consistent and we're not doing this here. We need to not only concsider the warning, but how conceptql locks in the correct codes

## The problem

A code such as DRG 107 has had more than one meaning. 529 of 895 DRG codes have more than one name in the vocabulary, and 530 of 531 changes fall on the 2007-10-01 MS-DRG renumbering. A statement like ["drg", "107"] names the code string only, so on data that spans 2007 it selects events of both meanings. The statement does not say which meaning the author intended.

Earlier in this session (2026-10-29) Ryan asked "how, in conceptql do we indicate which version of the code to use in the statement?". The answer was: there is no way today. The only idiom is to combine the code with a date range (during + date_range). Directions offered then, not ruled:

- (a) The date idiom plus documentation.
- (b) A `meaning_on` option that resolves the code to the meaning valid on a date.
- (c) Trust the concept that the data stores.

## Directions to evaluate (not ruled)

- The statement must name one meaning when a code has more than one, and validation fails when it does not ("definitive, explicit").
- The meaning is named by a date (meaning_on), by a concept ID that the editor resolves when the author picks the code, or by a separate vocabulary for each code system (for example MS-DRG apart from CMS-DRG, as ICD-9 and ICD-10 are separate).
- Whatever is chosen, the reused-code warning becomes either unnecessary or a validation error.

## Facts needed before ruling

How the vocabularies (OHDSI and GDM) store a code with more than one meaning (concept rows, IDs, validity dates); how data rows reference a code (concept ID or code string, and whether the ETL picks the meaning by date); and how the drg operator and other vocabulary operators resolve a code to rows.

FACTS 2026-10-30 (read-only research agent; logs claude_stuff/code-meaning-probe-20261030-0453\*.log .. -045649.log in the primary checkout):

- OHDSI vocabulary: each meaning of a code is its own concept row with its own concept_id, valid_start_date, valid_end_date and concept_class_id ('DRG' for the pre-2007 CMS system, 604 rows, all invalid_reason D; 'MS-DRG', 848 rows). One vocabulary_id 'DRG' covers both systems. GDM vocabulary (gdm_vocabs.concepts) has the same IDs but no dates and no class, and lacks 90 OHDSI DRG rows.
- Affected vocabularies that conceptql selects on: DRG (529 of 895 codes have more than one row) and HCPCS (1 code, AC). ICD9CM, ICD10CM, ICD9Proc, ICD10PCS, CPT4, NDC, LOINC, RxNorm, SNOMED and Revenue Code have none.
- Validity windows do not give one meaning per date: 28 DRG codes have overlapping windows (DRG 107: two old-DRG meanings 1998-2005); on 2010-01-01, 142 codes have no valid row and 22 have two or more. DRG 519/520 MS-DRG rows start 2014-10-01, leaving a 2007-10..2014-09 gap.
- Data rows (slim.clinical_codes, wide.observations) store clinical_code_concept_id, clinical_code_source_value and clinical_code_vocabulary_id. The ETL maps each source code to ONE concept ID regardless of the event date: 95 of 153 DRG rows (all 2008-2010) hold an old-DRG concept that had ended 2007-09-30 (example: code 010 on 2008-08-01 holds "Nervous System Neoplasms" instead of MS-DRG "Pancreas transplant"). 97 of 113 reused-code rows hold the lowest ID. NDC 4032, HCPCS 189, CPT4 147 and ICD9CM 118 rows also hold a concept not valid on the event date.
- conceptql selects by vocabulary + every concept ID whose code matches (lib/conceptql/lexicon/lexicon_strategy.rb:20-34, 57-60; operators/vocabulary.rb:111-124). No date, class or invalid_reason filter; clinical_code_source_value is never used for selection.

Consequence: the stored concept ID does not say which meaning applied, so pinning a concept ID in the statement cannot select the right events with today's ETL. What does say the meaning is the code plus the event date (which coding system was in force).

RULED 2026-10-30 (Ryan), answering three questions:

- How a statement names a DRG meaning: "One operator per DRG system". New operators ms_drg (events from 2007-10-01) and cms_drg (events before 2007-10-01). Each selects the DRG code AND the event dates of its system, so ["ms_drg","010"] always means the MS-DRG meaning. Rejected: pinning a concept ID per code (needs OHDSI dates, which have gaps and overlaps), and fixing the ETL first.
- Today's drg operator: "Deprecate drg entirely". drg warns now (like count) and becomes an error in a later release; authors move to ms_drg or cms_drg.
- The ETL finding (one concept ID per source code regardless of event date): tell the ETL repo's session; conceptql does not depend on the fix.
  The reused-code warning becomes unnecessary for DRG once drg is deprecated; HCPCS AC is the only other reused code.
