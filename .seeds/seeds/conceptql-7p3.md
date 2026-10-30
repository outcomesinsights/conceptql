---
id: conceptql-7p3
title: How does a ConceptQL statement lock in the meaning of a code that has had more than one meaning?
status: captured
type: question
created_at: 2026-10-30T11:51:55.643472+00:00
updated_at: 2026-10-30T11:51:55.643472+00:00
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
