---
id: conceptql-d9w
title: "annotate against a dataset: check each code against both the full lexicon and the dataset's trimmed vocabulary"
status: captured
type: question
created_at: 2026-11-10T16:19:07.430294+00:00
updated_at: 2026-11-11T04:29:20.733669+00:00
---

## The question

When annotate runs against a dataset, can it check each code against both the full lexicon and the dataset's own trimmed vocabulary tables? With both, a code gets one of three answers: known everywhere, not in the lexicon (an unknown code), or in the lexicon but not in this dataset's data.

Handed off from the JDE seeds session, JDE seed jde-22q (item 7 of Mark's MCP report), 2026-11-10.

Ryan, verbatim (2026-11-10, relayed by the JDE session): "If we are not editing against a data set, certainly we're working against lexicon. We are creating an algorithm in general. If we are working against a specific data set, then it's actually helpful feedback to say we didn't find this code. ... my vision is the workflow is something like we will work against lexicon to generate the original diagram and check for unknown codes. Then you can switch to a specific data set and it will actually call out the codes that aren't present in the concept table, which would suggest that those codes aren't present in the data set. ... I just want to think about the warning message. Ideally, when running annotate against a data set, we would check not only for the presence of each code in the data set, but then also against lexicon, which is, I don't think the wiring for ConceptQL supports that right now, and I'm not sure how difficult it would be to support it, but that would really narrow it down if a concept is present in lexicon, but it's not present in the data sets slimmed down tables, then what you definitely have is a concept that is just not present in the data. ... I guess the question becomes how How hard is it to get Conceptual to when it's calling annotate to look at both lexicon And the database-specific vocabularies to give you that comprehensive picture."

## Facts (verified by the JDE session, 2026-11-10)

- Dataset seer_medicare_all_cancer_2024_enriched_20261027 (DuckDB). Its concept table keeps 71,927 of OHDSI's 100,273 ICD10CM codes (ohdsi20260829, FY2027): exactly the 51,780 codes in clinical_codes plus 20,147 parent codes. The \_20261103 build is the same.
- M84.58XP, W56.22, W56.22XA, W56.22XD and W56.22XS are valid in OHDSI and absent from the data. count_statement calls them "unknown code(s)", which is wrong: they are real codes that this dataset does not contain.
- The trim comes from t_shank's perf report docs/perf/vocabulary-trim-2026-10-18.md (16-52% shorter SQL phase). Ryan keeps it.

JDE's three paths today:

1. Editing with no dataset (StatementDraft#annotations): `ConceptQL::Database.new(nil)`, no data and no lexicon. Only the format check runs.
2. Algorithm save (AnalyzeQueries, Algorithm#cdb): `ConceptQL::Database.new(Rails.application.lexicon_db)`, the full lexicon (LEXICON_URL, Postgres) but no data database. No unknown-code check runs.
3. count_statement and the editor's count view (CountStatements): `ConceptQL::Database.new(db, lexicon: ConceptQL::Lexicon.for_dataset(db))`. The only lexicon is the dataset's trimmed tables.

## What the conceptql code shows (main 850fa4b6, read 2026-11-10)

- `Operator#add_warnings?` is `@errors.empty? && !no_db?(db, opts)`. `no_db?` is true for a nil or mock data database. So every warning that needs a lookup, including the unknown-code check, is off without a data database, even when a full lexicon is present. This is why paths 1 and 2 give no unknown-code warning.
- `Vocabulary#additional_validation` asks `dm.known_codes(db, vocabulary_id, args, check_case: false)`. That goes to the one Lexicon that the Database holds (`Database#lexicon`, or the `lexicon:` option).
- `Lexicon#known_codes(data_db, vocabulary_id, codes)` is a self-contained call on a Lexicon object. `LexiconStrategy#known_codes` returns every code as known when the data database is a mock, or when the vocabulary is empty.
- `Vocabulary#where_clause` turns codes into concept ids through the same lexicon. The export does the same, so counts and SQL must keep using the dataset's tables.

## Assessment: how hard

Moderate. The lexicon is already an object with a `known_codes` call, so a second one fits the design. Three pieces:

1. **A second lexicon on Database.** An option such as `reference_lexicon:` holds the full lexicon beside the dataset's lexicon. Code-to-concept translation keeps using the dataset's lexicon. Only the unknown-code check reads the second one. Small.
2. **The split in `Vocabulary#additional_validation`.** Codes that the dataset's lexicon does not know are asked again of the reference lexicon. Those it knows get the new "not in this dataset" warning. The rest keep "unknown code". Small.
3. **The warning gate.** Path 1 and path 2 need the lexicon check without a data database. `add_warnings?` ties all lookups to a data database, and `LexiconStrategy#known_codes` reads the data database too. Separating "checks that need a lexicon" from "checks that need data" is needed. Only two operators use `add_warnings?` (vocabulary and information_periods); see the risk exploration below.

Tests need two lexicons that differ. The DuckDB fixture has one set of vocabulary tables. A test could build a trimmed copy in a temporary schema, or the fixture could gain one (vocabulation owns the fixture).

## Overlap with other seeds

- conceptql-zhn (bead conceptql-d1bd): when etl_vocabulary_ids says a whole vocabulary is absent, a warning for each of its codes says the same thing again. The two warnings should not both fire for one operator.
- conceptql-3z1 (beads conceptql-k7vg, conceptql-si8t): the new warning goes into annotate like every other warning. Nothing new is needed for it to reach JDE.

## Open questions

- The wording of the new warning. Ryan: "I just want to think about the warning message."
- Is the reference lexicon an explicit option (JDE passes LEXICON_URL's lexicon), or does a Database that has a dataset lexicon find the full one by itself (`Database.lexicon_db` from LEXICON_URL)?
- Does path 1 (no data database, no lexicon) gain a lexicon? That is a JDE change: StatementDraft#annotations would pass the full lexicon.

## UPDATE 2026-11-10: risk exploration of part 3 (the warning gate)

Ryan: "let's explore d9w and see how much "risk" there really is".

Findings from the code (main 850fa4b6):

- Only two operators use `add_warnings?`: Vocabulary#additional_validation and InformationPeriods#additional_validation. Provenance and PlaceOfServiceFilter already gate their lexicon lookups on `dm.lexicon.strategy == :no_db`, a lexicon gate. So the pattern exists.
- Lexicon lookups (`known_codes`, `code_meanings`, `concepts_table`) query the lexicon strategy's own database. They ignore the data database. So they work with no data database.
- Of the checks behind the gate, only the CPT4/HCPCS merged-vocabulary check reads data (`db[criterion_table]`). The unknown-code check and the reused-code check need only the lexicon.
- `ConceptQL::Database.new(nil)` already gets the full lexicon when LEXICON_URL is set (Lexicon#determine_strategy falls back to the LEXICON_URL database). JDE's .env sets LEXICON_URL. So JDE's editing path 1 already has the full lexicon, and only the gate stops the check. The JDE handoff's "no lexicon" for path 1 holds only where LEXICON_URL is unset.

Experiment, a throwaway worktree, not committed (diff: claude_stuff/exp-lexicon-gate-20261110.diff in the primary checkout):

- A new gate `lexicon_checks?` = `@errors.empty? && dm.lexicon.strategy != :no_db`. The merged-vocabulary check stays behind `add_warnings?`. The unknown-code and reused-code checks in Vocabulary, and InformationPeriods, move to the new gate. 8 lines added, 4 removed, in 3 files.
- `just test-both`: Postgres gdm_wide 1401 runs, 0 failures; DuckDB 1401 runs, 0 failures. No expected-results file changed. Log: claude_stuff/worktrees/exp-lexicon-gate/exp-lexicon-gate-test-both-20261110-083259.log.
- Probe of JDE's editing path (no data database, the fixture as the LEXICON_URL lexicon), `["union", ["icd9","412","999.99","4100"], ["cpt","99214","00000"], ["drg","410"]]`:

```
main:       icd9 warnings=[["improperly formatted code","4100"]]
            cpt  warnings=null
            drg  warnings=[["deprecated operator", ...]]
experiment: icd9 warnings=[["improperly formatted code","4100"],["unknown code(s)","999.99"]]
            cpt  warnings=[["unknown code(s)","00000"]]
            drg  warnings=[["deprecated operator", ...],["code(s) with more than one meaning","410: Biliary tract proc ... | Chemotherapy ..."]]
```

Logs: claude_stuff/lexicon-gate-probe-main-20261110-083348.log and claude_stuff/lexicon-gate-probe-exp-20261110-083559.log.

Assessment: part 3 is small and low risk, not medium. What remains is unmeasured:

- JDE starts to show unknown-code and reused-code warnings while editing and on save. The stored warnings of an algorithm change at its next save. That change is the goal. How many current algorithms gain a warning is not measured; JDE can count it.
- Each annotate without a data database now runs 2 lexicon lookups for each vocabulary operator against LEXICON_URL (Postgres). `cache_lookups: true` on the Database caches them. Latency is not measured.
- No test covers "no data database, real lexicon". The bead needs one.
  Parts 1 and 2 (the second lexicon, and the split into two warnings) were not tried.

## RULED 2026-11-10: a warning, never an error; the wording

Ryan: "when JDE is going to ask if an algorithm is valid, it will be valid. Unless there's an error, right? And in this case, we are going to be issuing a warning if a database, a data set doesn't contain a particular code in the algorithm when we are doing a count statements ... I don't want to mark an algorithm as having an error just because one particular data set doesn't contain all of the concepts that it represents. That's not an actual error. And that is not an invalid algorithm. Okay, so the wording. The wording should be Code not present in this dataset."

- A code that the lexicon knows and the dataset does not gets a warning, never an error. Valid means no operator has an error (bead conceptql-k7vg). An algorithm's validity never depends on a dataset.
- The warning fires only when annotate runs against a dataset (JDE's count_statement and the editor's count view).
- Wording: "code not present in this dataset". The existing messages are lower case with "(s)" ("unknown code(s)"), so the message may become "code(s) not present in this dataset" to match.

## UPDATE 2026-11-10: measured impact of the gate change (part 3)

Corpus: conceptql's 341 statement tests (test/statements/\*\*/\*.json, 872 operators). Setup: JDE's editing path, no data database, LEXICON_URL = titan ohdsi_vocabs, schema ohdsi20260829 (it includes the OI vocabularies CPT4_HCPCS and GDM_INFORMATION_TYPE). The gate change was applied as a monkeypatch of the experiment diff. Script: claude_stuff/lexicon-gate-measure.rb. Logs: claude_stuff/lexicon-gate-measure-main-20261110-084927.log and claude_stuff/lexicon-gate-measure-exp-20261110-085032.log.

```
                         main        gate change
annotated                341         341 (0 raised)
annotate ms, median      57.0        60.0
annotate ms, p90         100.6       93.5
annotate ms, total       22468       22966
lexicon queries, total   365         1828
lexicon queries, max     9           43 (a 20-operator statement)
unknown code(s)          0           17
more than one meaning    0           3
statements gaining one   0           18
```

- The extra queries add about 3 ms per statement (median), run on titan against titan's Postgres. Lookup caching (`cache_lookups: true`) was off, as in JDE today.
- With the data database present (main code, DuckDB fixture), the same warnings already fire for except/crit_412_inpatient (condition_type "inpatient_header"), co_reported/crit_somehow_bad_columns (cpt_or_hcpcs codes) and complex/count_required_columns (ndc "00000000000"). Log: claude_stuff/lexicon-gate-datadb-check-\*.log. The gate change adds no new kind of warning. It shows the existing warnings where no data database is attached.
- revenue_code "100" is unknown in ohdsi20260829, which stores Revenue Code as "0100".

Not measured:

- Production algorithms: this session was denied reads of titan's jigsaw_production copy (auto-mode classifier, "Production Reads").
- Parts 1 and 2 on a trimmed dataset (SEER-Medicare): its file is under /mnt/samba/confidential_data, and it was not read.

## UPDATE 2026-11-10: measured on production algorithms and on SEER-Medicare

Ryan authorized the investigation ("Do what you need to in order to complete this investigation"), including read-only production reads. Corpus: the 1,256 current kept algorithms of titan's jigsaw_production (read-only export, claude_stuff/prod-current-algorithms-20261110-085558.jsonl, not committed). Full lexicon: titan ohdsi_vocabs, schema ohdsi20260829.

### The gate change (part 3), JDE's editing and save paths

Script claude_stuff/lexicon-gate-measure.rb. Logs claude_stuff/lexicon-gate-measure-prod-main-20261110-085615.log and claude_stuff/lexicon-gate-measure-prod-exp-20261110-085741.log.

```
                              main      gate change
algorithms annotated          1256      1256 (0 raised)
annotate ms, median           61.5      89.8
annotate ms, p90              88.2      149.5
annotate ms, max              208.4     1340.6
lexicon queries, total        6387      17317
unknown code(s) warnings      0         31
more than one meaning         0         10
algorithms gaining a warning  0         39
```

- Added time per algorithm: median 29 ms, p90 90 ms, p99 227 ms.
- The cost grows with the length of the code list. The worst: antihypertensive_therapy (1 ndc operator, 33,747 codes) 185 -> 1341 ms; statin_therapy (13,073 ndc codes) 110 -> 1210 ms.
- Examples of the new warnings: icd03_morphology 9666/3 (9 algorithms), cpt_or_hcpcs 85047 (4), drg codes with two meanings (10 Elixhauser-style algorithms), ndc package codes, revenue code 0453-0458, icd9cm 043 and 044, icd10cm I79.2.

### Parts 1 and 2: the split on a trimmed dataset

Dataset seer_medicare_all_cancer_2024_enriched_20261103 (DuckDB, opened read-only; only concept, vocabulary and etl_vocabulary_ids were read; the merged-vocabulary check, which scans clinical_codes, was skipped). Vocabulary#additional_validation was monkeypatched to ask the full lexicon about each code the dataset did not know. Script claude_stuff/two-lexicon-measure.rb. Log claude_stuff/two-lexicon-measure-20261110-090153.log.

- 2,940 vocabulary operators in the 1,256 algorithms.
- In vocabularies that the dataset has: 174,452 codes. 106,335 are "not present in this dataset" (539 algorithms). 218 are unknown to the full lexicon too (25 algorithms).
- By vocabulary, not present / unknown: NDC 101,234 / 144; CPT4_HCPCS 3,313 / 34 (these come from the CPT4_HCPCS operator inside cpt_or_hcpcs; MultipleVocabularies' aggregation would drop such a warning today, see the review below); ICD10CM 1,032 / 1; ICD10PCS 324 / 0; ICD03_Morphology 75 / 29; Revenue Code 6 / 10; many SEER\_\* vocabularies with up to 90 each.
- Length of the not-present list per operator: 739 operators have one; median 3 codes, p90 94, max 24,502; 71 operators over 100, 16 over 1,000. The longest: antihypertensive_therapy 24,502 of 27,203 codes; statin_therapy 11,350 of 13,073.
- Each operator's annotated statement already holds all its codes as arguments, so a full not-present list is at most the size of the operator itself.

Open, with these counts: does the warning list every not-present code (up to 24,502), or a count with a sample? Recommended: the full list in the annotation, and JDE shortens it for display.

## Proposed plan, 2026-11-10 (for adversarial review before beads)

Ruled so far: a dataset-specific "not present" result is a warning, never an error; wording "code not present in this dataset" (proposed form "code(s) not present in this dataset" to match "unknown code(s)"; not confirmed).

Proposed beads (not created yet):

1. Lexicon gate: a new `lexicon_checks?` (`@errors.empty? && dm.lexicon.strategy != :no_db`). The unknown-code and reused-code checks in Vocabulary, and the check in InformationPeriods, move to it. The CPT4/HCPCS merged-vocabulary check stays behind `add_warnings?`, because it reads data. Tested by the throwaway experiment (diff claude_stuff/exp-lexicon-gate-20261110.diff).
2. Reference lexicon: a Database option for the full lexicon beside the dataset's lexicon. Vocabulary#additional_validation asks the reference lexicon about each code the dataset's lexicon does not know. Known there: warning "code(s) not present in this dataset". Unknown there: "unknown code(s)". Code-to-concept translation and counts keep using the dataset's lexicon. When conceptql-d1bd's warning fires for the operator (the whole vocabulary is absent), the per-code warning does not also fire.

Open, not ruled: the plural form of the wording; whether the not-present list holds every code (recommended) or a count with a sample; whether the reference lexicon is an explicit option (JDE passes it) or found from LEXICON_URL.

## UPDATE 2026-11-10: Adversarial review 2026-11-10 (claude_stuff/adversarial-review-annotate-plan-20261110-093509.md, probes in claude_stuff/review-annotate-plan/)

Findings for the two proposed beads (not yet created):

- The proposed reference-lexicon bead depends on conceptql-d1bd (the suppression rule) and needs a test fixture with two lexicons that differ. Neither was stated.
- MultipleVocabularies (cpt_or_hcpcs, 452 in production) warns about codes only when every inner vocabulary rejects them (code_warnings, multiple_vocabularies.rb:140-151), and aggregate_messages keeps only codes that every vocabulary shares. The not-present warning needs a rule there, or cpt_or_hcpcs never shows it.
- The proposed lexicon gate ignores the skip_db option, which add_warnings? honors.
- PLAUSIBLE: against a dataset, an operator whose vocabulary the dataset lacks can be an "invalid operator" error, because each Database builds vocabulary operators from its own lexicon.
- Confirmed correct: each Lexicon has its own cache, so a second lexicon shares no entries; the lexicon-gate diff matches its description.

## UPDATE 2026-11-10: Ryan's questions on read, cpt_or_hcpcs and long lists

Ryan, transcribed: "shouldn't read be based on vocabulary then? ... We need to handle the no records so that it's properly reporting. And then I would like to understand why not present in this database would never trigger either. Why are we accepting every code under CPT4 and or HCPCS? ... it sounds like we just need to re-architect this one. Use the message form that matches unknown codes. I don't know how to handle long lists. How have we done that in the past? Have we ever done a count plus a sample? Or is this new class of error larger than anything we've ever seen before."

RULED: the message is "code(s) not present in this dataset", matching "unknown code(s)".

Findings:

- read: `Read < Operator` wraps one `ReadGDM < Vocabulary`. The wrapper existed because the omopv4_plus data model split Read over four tables (ReadCondition, ReadProcedure, ReadDrug, ReadObservation). The omopv4_plus removal (af3b2803, 2026-10-29) left a wrapper of one operator. Read has no row in config/vocabularies.csv. Direction (Ryan): read becomes a plain vocabulary operator, so every vocabulary check covers it.
- Why CPT4 and HCPCS accept every code: `LexiconStrategy#known_codes` returns every code as known when the lexicon has no concept of the vocabulary (`vocabulary_is_empty?`, lib/conceptql/lexicon/lexicon_strategy.rb:125-132). The rule came from e32221cd (2020-09-14, "Ignore unknown codes if vocabulary has no concepts", refs #185; its test is drug_text_string/anno_1). SEER-Medicare's concept table has CPT4_HCPCS (15,876 rows) and no CPT4, HCPCS, ICD9CM or Read rows. So on that dataset the inner CPT4 and HCPCS operators of cpt_or_hcpcs accept every code, and `MultipleVocabularies#code_warnings` warns only about a code that every inner vocabulary rejects. The same rule makes icd9cm and read accept every code there.
- Direction (Ryan): re-architect cpt_or_hcpcs. Proposed: it checks its codes as one set. A code is known when any of its vocabularies has it in the dataset. Otherwise, a code that the reference lexicon knows is "not present in this dataset", and the rest are unknown. The no-records warning fires when none of its vocabularies is in etl_vocabulary_ids. Its warnings no longer pass through aggregate_messages.
- Proposed for the 2020 rule: where a reference lexicon or etl_vocabulary_ids exists, an empty vocabulary in the dataset's lexicon no longer hides codes; the no-records and not-present warnings replace it. Where neither exists, the rule stays, because a lexicon that lacks a vocabulary would otherwise call every code unknown.
- Long lists: conceptql has never shortened a warning. "unknown code(s)" lists every code, and no operator code truncates or samples. On SEER-Medicare today, JDE's count path already reports each not-present code as "unknown code(s)", so the longest list (24,502 codes, antihypertensive_therapy) already appears today. The new warning relabels those codes; it does not make the list longer.

## RULED 2026-11-10 (Ryan, on the read, cpt_or_hcpcs and long-list findings)

Ryan: "I agree with the challenge to the 2020 rule / full code lists please".

1. cpt_or_hcpcs is re-architected as proposed above. It checks its codes as one set. A code is known when any of its vocabularies has it in the dataset. Otherwise a code that the reference lexicon knows is "code(s) not present in this dataset", and the rest are "unknown code(s)". The no-records warning fires when none of its vocabularies is in etl_vocabulary_ids. Its code warnings no longer pass through aggregate_messages.
2. The 2020 empty-vocabulary rule (LexiconStrategy#known_codes, e32221cd) changes as proposed. Where etl_vocabulary_ids or a reference lexicon exists, an empty vocabulary in the dataset's lexicon no longer makes every code known. Where neither exists, the rule stays.
3. Warnings keep the full code list. conceptql does not shorten or sample. JDE shortens the list for display if it needs to.
4. read becomes a plain vocabulary operator (the direction Ryan gave earlier), so every vocabulary check covers it.

## UPDATE 2026-11-10: beads created

- conceptql-qdn9: make read a plain vocabulary operator. conceptql-d1bd depends on it.
- conceptql-0ubo: run the lexicon-only code checks when a lexicon exists without a data database (part 3; honors skip_db).
- conceptql-8oim: reference lexicon, "code(s) not present in this dataset", and the limit on the 2020 rule. Depends on conceptql-d1bd and conceptql-0ubo.
- conceptql-0h2n: re-architect cpt_or_hcpcs code checks. Depends on conceptql-8oim and conceptql-d1bd.

Still open: whether the reference lexicon is an explicit Database option that JDE passes (proposed) or found from LEXICON_URL. conceptql-8oim waits for that answer.

## RULED 2026-11-10: how a Database gets the reference lexicon

Ryan: "explicit option with a fall back to LEXICON_URL". The reference lexicon is an explicit Database option (reference_lexicon:). When it is not given and LEXICON_URL is set, the Database uses the LEXICON_URL lexicon. Recorded in bead conceptql-8oim.

## RULED 2026-11-10: the 2020 rule, provenance and place_of_service_filter

Ryan: "provenance and place_of_service should check reference lexcicon and provide warnings" and "202 rule it applies when dataset and reference lexcicon are missing the vocab, yes?" (answered yes).

1. The 2020 empty-vocabulary rule applies only when both the dataset's lexicon and the reference lexicon have no concepts of the vocabulary. Without a reference lexicon, it applies when the dataset's lexicon has none. etl_vocabulary_ids no longer affects the rule. This replaces ruling 2 above, which conceptql-8oim shipped: today a filled etl_vocabulary_ids or any reference lexicon turns the rule off, so a vocabulary that neither lexicon has gets every code reported as unknown.
2. provenance and place_of_service_filter check their codes against the reference lexicon too, and report "code(s) not present in this dataset" or "unknown code(s)" as warnings. Today an unknown code is an error there, checked against the dataset's lexicon only, so validity depended on the dataset.

Beads: conceptql-dufi (the 2020 rule, one shared method; also information_periods), conceptql-amuu (provenance and place_of_service_filter; depends on conceptql-dufi).

Still open: when the data has no records of a vocabulary, the vocabulary operator skips the unknown-code, not-present and reused-code checks of its own codes (conceptql-8oim). Proposed: skip only the not-present check. Downstream operators such as provenance are not affected: they check their own codes in every case.
