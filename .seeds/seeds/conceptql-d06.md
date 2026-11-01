---
id: conceptql-d06
title: 'concurrent_within: start "-1d" moves the window start later, not earlier. Intended?'
status: captured
type: question
created_at: 2026-11-01T04:04:12.608241+00:00
updated_at: 2026-11-01T04:06:42.082770+00:00
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

FACTS 2026-10-31:

- Code: lib/conceptql/operators/concurrent_within.rb:43 builds the window start with DateAdjuster.new(self, options[:start]).adjust(l.start_date, true): reverse = true. So start "1d" means one day BEFORE start_date and "-1d" one day AFTER; end "1d" means one day after end_date (no reverse). The reverse flag has been there since at least 3ba2a6ec (2017-07-11), so the direction is old and deliberate: start is a distance before the record.
- The new desc (bead conceptql-kv2v) already says: 'The start option sets how far before the start_date that date range begins, and the end option sets how far after the end_date it ends.'
- doc/spec.md.cql has no concurrent_within section. time_window, by contrast, is signed: "start": "-30d" means 30 days earlier (spec lines 748-822). So the two operators read the same text in opposite directions for start.
- Production (jde survey 2026-10-31, log JDE claude_stuff/concurrent-within-survey-20261031-210536.log): 0 concurrent_within operators in the 1,259 current algorithms, and 0 rows containing 'concurrent' in all 1,652 algorithm rows including old and deleted versions. A change affects no production algorithm and no study.
- In the suite, only test/statements/concurrent_within/crit_negative_start.json ({start: "-1d", end: "0d"}) uses a negative start.
