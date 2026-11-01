---
id: conceptql-d06
title: 'concurrent_within: start "-1d" moves the window start later, not earlier. Intended?'
status: captured
type: question
created_at: 2026-11-01T04:04:12.608241+00:00
updated_at: 2026-11-01T04:04:12.608241+00:00
---

## Question

concurrent_within applies its `start` option in the reverse direction: `start: "-1d"` moves the window start one day later, not earlier. Is that intended?

## Source

Found 2026-10-31 by the agent of bead conceptql-kv2v while rewriting concurrent_within's desc (the new desc describes positive values only). Ryan, 2026-10-31: "Open a seed".

## What is known (to verify)

- The test statement `crit_negative_start.json` (under test/statements, concurrent_within) uses a negative start and its expected results depend on the current direction.
- Bead conceptql-d3v (2026-10-30) changed DateAdjuster so that a bare number means days also after an r/e/s prefix, and made `reverse` apply to bare numbers ("within start side, at_least on before, start on concurrent_within now count back"). So the direction of concurrent_within's start passes through DateAdjuster's reverse flag; check whether the reversal is deliberate there.

## To do before a ruling

- Read the code path (lib/conceptql/operators/concurrent_within.rb, the window/DateAdjuster code) and git history, and say what each sign of `start` and `end` does today, with a small example.
- Read the spec (doc/spec.md.cql) and the conceptql_spec description of concurrent_within, and say what they promise.
- Ask jde for production use of concurrent_within with a `start` or `end` option, and the signs used.
- Then the options: (a) the current direction is intended (document it in the spec and desc), (b) it is a defect (fix it, with a Breaking entry, after counting production use).
