---
id: conceptql-1n4
title: provider_filter without roles crashes the plain query with nil.split instead of a validation error
status: captured
type: question
created_at: 2026-10-29T20:43:41.234113+00:00
updated_at: 2026-10-29T20:43:41.234113+00:00
tags:
  - algorithm-survey
  - bug
  - validation
---

## What fails

2 Draft algorithms use `provider_filter` with `specialties: "*"` and no `roles` option:

- a7ef139e providers_from_procedures: `["provider_filter", ["cpt_or_hcpcs", "*"], {specialties: "*"}]`
- d19f0502 physician_specialty_from_office_visits: `provider_filter` over a `cpt_or_hcpcs` code list, `{specialties: "*"}`

`annotate` handles them correctly. It reports the validation error `[["required option not present", "roles"]]` and raises nothing. The plain query crashes instead:

```
NoMethodError: undefined method 'split' for nil
lib/conceptql/operators/provider_filter.rb:30:in 'ConceptQL::Operators::ProviderFilter#query'
```

## Cause (checked in the code 2026-10-29)

The survey said the crash came from `specialties: "*"`. That is wrong. Line 29 splits `options[:specialties]`, which is present. Line 30 splits `options[:roles]`, which is nil. The operator declares `validate_required_options :specialties, :roles`, but the plain query path builds SQL without checking validation first, so the missing option reaches `nil.split`.

## Questions (not ruled)

- Should `roles` default to `"*"` when it is absent, as the user probably meant? Or should the statement stay invalid?
- Should the plain query path (`Query#sql`, `Query#query`) raise a clear validation error for every invalid statement, instead of whatever error the operator code happens to hit? That would cover this seed and the unknown-operator seed together.

## Source

Source: the Jigsaw diagram editor's survey of all current production algorithms, run 2026-10-29 (JDE seed jde-c0y.1 plans per-operator counts and asked for this seed). The survey ran today's `annotate` with counts and the plain query on each of the 1,259 current algorithms (`child_id IS NULL AND deleted_at IS NULL`). Data: the SEER-Medicare sample native_sample_5000 (DuckDB, gdm_wide, 5,000 patients, 7.8M observation rows). Software: DuckDB 1.5.6, conceptql 0.4.1, threads=8, on titan. Ryan ruled on 2026-10-29: "yes, file them as seeds and we'll investigate the best way to proceed".

Survey totals:

```
statements: 1259; plain ok 1253; annotate ok 1256
annotate_s: median 0.058  p90 0.234  p99 1.005  max 57.934  sum 200.7
plain_s:    median 0.037  p90 0.123  p99 0.520  max 2.293  sum 84.4
```
