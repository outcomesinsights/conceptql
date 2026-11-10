---
id: conceptql-xri
title: co_reported with one input is valid and gives no warning
status: captured
type: question
created_at: 2026-11-10T14:59:40.710484+00:00
updated_at: 2026-11-10T15:09:07.874828+00:00
---

## The gap

`["co_reported",["icd10cm","C78.00"]]` is valid and counts the same as its input. co_reported with one input has no meaning: "reported in the same context as a record of every other upstream" is true of every record when there is no other upstream. conceptql gives no error and no warning.

Source: Mark's Claude, MCP test report 2026-11-09 (item 15), handed off from JDE seed jde-ed7. Code check, 2026-11-10 (main at 976a1195): `lib/conceptql/operators/co_reported.rb` uses `validate_at_least_one_upstream`, which errors only on zero upstreams.

## Production data

Read-only query by the JDE session, 2026-11-10. Only 4 algorithm versions were ever saved with a one-input co_reported, and none is a current kept version. Three are Mark's deleted tests zz_api_test_a, and one is a deleted 2019 algorithm. So an error would make no current algorithm invalid.

```
co_reported by input count, all versions:
1 input     4
2 inputs  179
3 inputs   25
4 inputs   20
5 or more  21
```

## Directions (not ruled)

1. A warning when co_reported has fewer than two inputs.
2. A validation error when co_reported has fewer than two inputs. The production count above shows that no current algorithm breaks.

## Related

`union` is the only other operator with `allows_many_upstreams` and `validate_at_least_one_upstream`. A one-input union is harmless (it passes its input through), so it is not part of this question.

## UPDATE 2026-11-10: Ryan's direction

Ryan (transcribed speech, 2026-11-10): "For XRI, yes, a single input is valid, but should be a warning, right? Same with like a union or anything else that is expecting that really only works well if there's two or more operators. If we can make that like a validation statement or something like that that we put in those classes, that'd be great."

So the direction is a warning, not an error, declared in the operator class like the existing `validate_*` statements (for example a class-level `warn_with_fewer_than_two_upstreams`).

Scope check, main at 976a1195: only two operators declare `allows_many_upstreams`, `union` and `co_reported`. Both use `validate_at_least_one_upstream`. There is no intersect operator. Binary operators (before, after and others) take `left` and `right` and are not affected.

This reverses the earlier note that a one-input union is out of scope: Ryan includes union.
