---
id: conceptql-80o
title: 'provenance with no keywords: keep, make it an error, or require an explicit "*"?'
status: captured
type: question
created_at: 2026-10-31T12:50:58.109889+00:00
updated_at: 2026-10-31T12:52:08.484707+00:00
---

## Question

`provenance` with no keyword arguments keeps every record that has any file or code provenance. Should that stay, become a validation error, or be spelled explicitly with a `"*"` keyword?

## What is true today (2026-10-31)

- Nothing in conceptql requires at least one provenance keyword. With none, `Provenanceable#build_where_from_codes` builds the plain condition over all provenance concepts, so the operator keeps records whose file_provenance_type or code_provenance_type is any provenance concept. Bead conceptql-8mrc kept this behavior on purpose and did not rule on it.
- `"*"` is not a provenance keyword today; it would be reported as "unrecognized keywords".

## Ryan, 2026-10-31

"first, see what's in production and if this form is used anywhere. I'd aruge we could take a "\*" wildcard as an argument to make this situation explicit -- sometimes we just want provenance attached to conceptql rows"

## Directions (not ruled)

- (a) Keep the empty form as it is. Document it.
- (b) Make the empty form a validation error, and add `"*"` as the explicit way to ask for any provenance (Ryan's lean). Production statements with the empty form would become invalid, so they need counting first and a migration path (a deprecation warning first, as for count and drg).
- (c) Add `"*"`, and keep the empty form as a deprecated synonym that warns.

## Facts needed before ruling

- Production use: asked jde on 2026-10-31 for counts and algorithm IDs of provenance with no keywords, with `"*"`, and with the `<file>:<code>` form, over the same production set as its 2026-10-29 survey.
- Whether "keeps every record with any provenance" is what "provenance attached to conceptql rows" means: provenance is a filter, so records with NULL in both columns are dropped. If the intent is to attach provenance columns without filtering, that is a different feature.

FACTS 2026-10-31 (jde survey of current production algorithms, child_id IS NULL AND deleted_at IS NULL, 1,259 algorithms, read-only, no data rows; JDE log claude_stuff/provenance-survey-20261031-055137.log): 99 provenance operators in 61 algorithms.

- No keyword arguments: 0 operators.
- "\*" as a keyword: 0 operators.
- <file>:<code> form: 1 operator (b298a95f, a Draft, inpatient:primary_or_first).
- Keywords by operator count: inpatient 71, outpatient 21, carrier_claim 14, primary_or_first 5, 100012292 1 (3b7deef8, a Draft), inpatient:primary_or_first 1.
  So making the empty form an error breaks no production statement, and no deprecation period is needed for it.
