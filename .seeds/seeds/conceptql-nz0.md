---
id: conceptql-nz0
title: LexiconStrategy#concepts wildcard branch is unreachable — delete or raise?
status: captured
type: question
created_at: 2026-09-18T16:51:39.478325+00:00
updated_at: 2026-09-18T17:23:16.952959+00:00
---

`lib/conceptql/lexicon/lexicon_strategy.rb:14`

```
ds = ds.where(vocabulary_id: vocabulary_id) unless vocabulary_id == '*'
```

The `unless` bypass is unreachable. Raised by t_shank-main, which had reported it
to the vocabulation team as a live exposure after the 2026-09-17 vocabulation
refresh added ~91k ICD10CM_ALPHA_INDEX/EINDEX concepts sharing 43 concept_codes
with other vocabularies (Bladder, BMI, TBI, Capsule, DNR, Palliative care...).
Ryan pushed back that we never do a wildcard lookup; he was right. The wrong
report is the real cost -- a reader finds the branch and reasons forward from its
existence. Captured on their side as seed t-shank-rhl.

## Verified independently in conceptql (2026-09-18)

- The bypass exists in exactly ONE method. `concepts_ds`, `vocabulary_is_empty?`
  and `concepts_by_name` filter unconditionally, so `'*'` matches NOTHING there.
  If `'*'` were supported they would need the same branch.
- 8 call sites in conceptql; none passes `'*'`. No literal `'*'` is passed as a
  vocabulary argument anywhere in lib/.
- `'*'` reaches `arguments`, never `vocabulary_id`. `Vocabulary#select_all?` is
  `arguments.include?('*')` and guards the lexicon call at vocabulary.rb:115
  (`unless select_all?`), so the wildcard case makes FEWER lexicon calls, not
  broader ones. `provider_filter.rb` uses the same shape.
- `vocabulary_id` is derived from the operator: `vocab_entry.omopv5_vocabulary_id || op_name`, or hardcoded (`17`, `'Read'`). Nothing registers under `'*'`.

## The constraint that decides the fix -- NOT in the original report

`vocabulary_id` is POLYMORPHIC. It is not always a String:

- Array -- utilizable.rb:43,45 and provenanceable.rb:12,23 pass
  `%w[JIGSAW_FILE_PROVENANCE_TYPE JS_FILE_PROV_TYPE]` and
  `%w[JIGSAW_CODE_PROVENANCE_TYPE JS_CODE_PROV_TYPE]` (4 call sites)
- Integer -- read.rb:87 `ReadOmop#vocabulary_id` returns `17`
- String -- 'Read', 'Place of Service', operator names

Sequel turns the Array into an IN clause, which is why it works today. So the
answer to t_shank's open question ("can any caller legitimately pass nil?") is:
no caller passes nil, but four pass Arrays and one passes an Integer.

This rules out the obvious guard. `raise unless vocabulary_id.is_a?(String)`
breaks 5 call sites immediately. A guard must reject only nil/blank/`'*'` while
leaving Array and Integer alone -- e.g.
`raise ArgumentError, ... if vocabulary_id.blank? || vocabulary_id == '*'`
(a non-empty Array is not blank).

## Options

(a) Delete the `unless` clause. Smallest. `'*'` then matches no vocabulary and
anything relying on it returns empty -- silently.
(b) Raise ArgumentError on nil/blank/`'*'` (Ryan's suggestion, relayed via
t_shank-main -- NOT confirmed directly). Names the mistake instead of
returning an empty set. Must tolerate Array and Integer.
(c) Leave it and comment. Weakest: the next reader re-derives the same false
alarm, which is exactly what just happened.

## Open question for Ryan

Was `'*'` ever a real cross-vocabulary feature that might be wanted back? If so
that is worth a comment saying so, which would itself have prevented the wrong
report. Nobody currently knows; the git archaeology has not been done.

Recommendation: (b) with (a) folded in, guarded as above, plus a test asserting
the raise. Not implemented -- a relayed suggestion is not authorization, and this
session has already seen two relayed rulings turn out not to be Ryan's.

## The 43 colliding concept_codes (snapshot, from t_shank-main 2026-09-18)

Recorded here because conceptql owns lexicon resolution, not because they bear on
the branch -- they do not; it is unreachable either way. Kept with the question so
a future reader sees the evidence that produced the false alarm.

These are concept_codes shared between ICD10CM_ALPHA_INDEX/ICD10CM_EINDEX and at
least one other vocabulary. All word-shaped, which is what an alphabetic index
contains -- and why they collide with vocabularies that use words as codes
(MARCLA_UNIT_NM, CPRD_FORMULATION, NAACCR).

```
BMI              MARCLA_OBS_TYPE        Milk             CPRD_FORMULATION
Bladder          NAACCR                 Mountain         MARCLA_DIVISION
Brain            NAACCR                 Mutation         MARCLA_UNIT_NM
Breast           NAACCR                 Occult           Cancer Modifier
Bulky            Cancer Modifier        Palliative care  MARCLA_ENC_INT_TYPE
Capsule          CPRD_FORMULATION       Pathology        MARCLA_PROV_SPEC
Colon            NAACCR                 Poor             MARCLA_UNIT_NM
Counseling       MARCLA_PROV_SPEC       Positive         MARCLA_UNIT_NM
DES              OncoTree               Potter's         Gemscript
DNR              MARCLA_UNIT_NM         Pouch            CPRD_FORMULATION
Dermal           Gemscript              Presence         MARCLA_UNIT_NM
Device           CPRD_FORMULATION       Retinopathy      MARCLA_UNIT_NM
Diaphragm        CPRD_FORMULATION       Ring             CPRD_FORMULATION
Esophagus        NAACCR                 Risk             MARCLA_UNIT_NM
Extensive        Cancer Modifier        Skin             NAACCR
Feet             MARCLA_UNIT_NM         Status           MARCLA_UNIT_NM
Finger           CPRD_FORMULATION       Stomach          NAACCR
Funnel           CPRD_FORMULATION       Suture           CPRD_FORMULATION
Gas              CPRD_FORMULATION       TBI              MARCLA_LAB_UNIT
Lung             NAACCR                 Tissue           CPRD_FORMULATION
                                        Vaccination      CPRD_FORMULATION
                                        Water            CPRD_FORMULATION
                                        Yellow           MARCLA_UNIT_NM
```

Source: ohdsi_vocabs.concept in the published
~/Dropbox/Publicized/synpuf_test_data.duckdb as refreshed 2026-09-17 21:55.
A SNAPSHOT, not a constant -- the set grows as the index grows. Do not hardcode it;
re-derive if it ever matters.

Why it is inert today: a lookup is always scoped to one vocabulary (or an explicit
Array of them), so a code colliding across vocabularies is never ambiguous in
practice. It would only bite if a genuine cross-vocabulary lookup were introduced
-- which is the same decision the open question above is really about.

## ANSWERED by archaeology (2026-09-18) — it was never a feature

The open question above ("was `'*'` ever a real cross-vocabulary feature?") is
settled. It was not. Ryan pushed back on it being asked at all: the code and the
history were both already in hand.

Traced with `git log --all -S` across every path, following the two renames and
one quote-style change:

```
  70a1643c  2023-09-01  "Finish up work on OHDSI Vocabs"
            INTRODUCED. Written fresh into data_model/gdm.rb#concepts with the
            bypass already in it, as `unless vocabulary_id == "*"`.
            `git grep` at 70a1643c^ finds the construct NOWHERE in the tree, so
            nothing was being preserved or ported. It did not come from Lexicon,
            despite that commit moving other methods out of Lexicon.
  27a48995  2024-12-09  "Monolithic commit ... Presto support"
            Quote style only: "*" -> '*'.
  0b8f77da  2024-12-19  "Get initial version of driftr_script working"
            MOVED data_model/gdm.rb -> lexicon/lexicon_strategy.rb. Not an
            introduction; the same line is removed and re-added in one diff.
            (driftr_script itself is gone from the tracked tree.)
```

No caller has EVER passed `'*'` as a vocabulary_id. `-S"concepts(db, '*'"` and
`-S"concept_ids(db, '*'"` return zero commits across all history, on every branch.

## What it was conflated with

The REAL asterisk feature is seven years older and operates on a DIFFERENT
parameter:

```
  5b2fb0a8  2017-07-28  "All vocabulary operators should now accept asterisk"
            Added `Vocabulary#select_all?` == `arguments.include?('*')`, plus
            `[['*', 'ALL CODES']]` describe-codes output and anno_select_all
            fixtures for icd9/hcpcs.
```

`select_all?` reads asterisk out of `arguments` and GUARDS the lexicon call
(`unless select_all?` at vocabulary.rb:115), so the genuine wildcard makes fewer
lexicon calls. The 2023 bypass reads asterisk out of `vocabulary_id` and WIDENS
the query. Same character, opposite direction, unrelated parameters.

So the bypass is accreted defensive code, most likely written by someone who knew
`'*'` was meaningful in this operator family and guarded the wrong parameter.

## Consequence for the decision

Delete-vs-raise is no longer a question about preserving a feature; there is no
feature. Nothing is lost by removing the `unless` clause outright. A raise is
worth adding only on its own merits -- turning a silently-empty result into a
named error -- and if added must tolerate Array and Integer per the polymorphism
section above.

## DECISION (Ryan, 2026-09-18): option (b) with (a) folded in

Delete the bypass AND raise. Implement now.

Final shape:

```
raise ArgumentError, "..." if vocabulary_id.blank? || Array(vocabulary_id).include?('*')
ds = ds.where(vocabulary_id: vocabulary_id)     # unconditional
```

Three things the guard has to get right, all established above:

1. `blank?` not a type check. `17.blank?` is false, `%w[A B].blank?` is false,
   so ReadOmop's Integer and the four provenance Arrays pass through untouched.
   `nil` and `''` raise, and an EMPTY Array raises too -- which is correct, since
   `where(vocabulary_id: [])` silently matches nothing.
2. `Array(vocabulary_id).include?('*')` rather than `== '*'`, so `['*']` is caught
   as well as the bare string. `Array(nil)` is `[]`, but `blank?` has already
   raised by then.
3. The raise goes FIRST, before `concepts_table`, so the error names the mistake
   before any query is built.

Not touched: `concepts_ds`, `vocabulary_is_empty?`, `concepts_by_name`. They
already filter unconditionally and were never part of the defect.

Also unchanged: `Vocabulary#select_all?` and everything reading `'*'` out of
`arguments`. That is the real 2017 feature and it stays exactly as it is. The
whole point of this change is that the two asterisks are unrelated.

Tracked as bead conceptql-7dr.
