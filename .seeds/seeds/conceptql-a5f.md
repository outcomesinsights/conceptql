---
id: conceptql-a5f
title: Lexicon re-issues identical vocabulary queries per Database/export; remove the round trips without a cache
status: captured
type: question
created_at: 2026-09-29T03:04:20.735970+00:00
updated_at: 2026-09-30T13:08:50.199158+00:00
tags:
  - lexicon
  - performance
  - spark
  - t_shank
  - ci-cost
---

Lexicon lookups re-issue identical vocabulary queries against the data database on every export. Eliminate the redundant round trips, without adding a cache.

Requested by the t_shank session (2026-09-28); feeds t_shank bead t_shank-4wv (cut t_shank CI to \<=120 billable minutes per run, from 248).

## Measured (t_shank, 2026-09-28)

One CI-shaped Spark shard: 17 fixtures, 36 exports, Spark 3.3.2 ThriftServer on 2 CPUs, 1,158 s of statement time. Log: /home/ryan/projects/outins/jigsaw/main/t_shank/claude_stuff/spark-tuning-20260928-124526.export.log (t_shank's claude_stuff, gitignored, this host only).

- Vocabulary SELECTs (FROM concept / concept_relationship / concept_ancestor / vocabulary): 232 statements, only 11 DISTINCT. They took 332 s, 29% of statement time, and 316 s of that repeated a query already issued earlier in the same process.
- The two worst are LexiconOhdsi#is_a_relationships-shaped (`SELECT concept_1_id FROM (SELECT concept_id_1 AS concept_1_id ... FROM concept_relationship WHERE ... 'is a' ...)`), 72 times each at ~1.5 s, ~108 s each in total. In conceptql they come from LexiconStrategy#related_concept_ids -> is_a_relationships (lexicon_strategy.rb:66), which the Gender operator calls for 8507/8532 (gender.rb:42,46).
- 468 `table_exists?` probes, all against vocabulary tables (concept_relationship 234, concept 198, vocabulary 18, concept_ancestor 18): 52 s. Sources in conceptql: LexiconOhdsi/LexiconGDM.db_has_all_vocabulary_tables? (lexicon_ohdsi.rb:9, lexicon_gdm.rb:9), run by Lexicon#determine_strategy for every new Lexicon, and table_is_missing? (lexicon_ohdsi.rb:56), reached from Vocabulary (vocabulary.rb:168) and LexiconStrategy (lexicon_strategy.rb:82).

## Why it repeats

- conceptql builds one Lexicon per ConceptQL::Database instance (database.rb:108 `@lexicon ||= Lexicon.new(...)`, and Database#initialize reaches it at database.rb:43).
- t_shank builds a new ConceptQL::Database per export (t_shank lib/t_shank/exporter.rb:132).
- LEXICON_URL is unset in these runs, so every lookup goes to the Spark data db at ~1.5 s per round trip. Production Spark exports pay the same.

## Option B (seed conceptql-alj) makes this worse. Not yet measured, because t_shank pins conceptql ffb6d133 (2026-09-12), from before option B

Before option B, the vocabulary list (`lexicon.vocabularies`, a SELECT on `vocabulary`) was read ONCE per process, at require. Since d6d7b1f7, `Database#operators` (database.rb:121) reads it once per Database, so once per t_shank export: about 36 more ~1.5 s round trips per shard on Spark. Any fix here must cover this new per-Database query too, or option B lands in t_shank as a regression.

## Constraint (Ryan, relayed by t_shank 2026-09-28)

"caching is a nightmare". Frame the fix around removing the round trips, NOT around caching their results.

## Candidates to evaluate (not a diagnosis)

(a) **Push the lookup into the generated SQL.** Emit the vocabulary lookup (e.g. the is_a / related-concept expansion) as a subquery or join inside the export's query, so no separate fetch to Ruby happens. Removes the round trip entirely and is not a cache. Check the effect on SQL shape per adapter (Postgres, Spark, DuckDB, Presto) and on the CTE / temp-table machinery.
(b) **Resolve vocabulary from a fast LEXICON_URL database.** Caveat: Lexicon#determine_strategy tries the DATA db first (lexicon.rb:31-39), so setting LEXICON_URL alone may change nothing. And a different vocabulary copy could change outputs, which t_shank's fixtures forbid.
(c) **A process-lifetime Lexicon shared across Database instances.** That is caching, which Ryan objects to; listed only for completeness, with that objection attached.

Also in scope: the table_exists? probes. determine_strategy probes 4 tables per new Lexicon, and table_is_missing? probes again per call site. Whether those can be answered once per query build, or folded into (a), is part of the evaluation.

## Hazards

- t_shank's 133 export fixtures compare against committed expected CSVs that must NEVER be regenerated. Any change must keep lexicon results, and therefore export output, identical.
- Before/after measurement without spending CI minutes: t_shank's untracked harness /home/ryan/projects/outins/jigsaw/main/t_shank/claude_stuff/spark-tuning-harness/ reproduces a CI shard locally. Measure with it, from t_shank, against a conceptql branch.
- The count that matters is round trips per export on Spark, not Ruby time. Report statement counts (total vs DISTINCT) before and after.

## Open question

Which of (a) / (b), or something else, removes the round trips without a cache and without changing any lexicon result? This is deliberation, not yet a task (Ryan, 2026-09-28: "not a bead, probably a seed").

## Ruling relayed from t_shank: candidate (c) is RULED OUT (Ryan, 2026-09-29)

Relayed by the t_shank session on 2026-09-30 and recorded in its seed t-shank-58t. Not heard directly in this repo. Attributed as relayed.

**No test-only code paths.** The export fixtures exist to prove production behaviour. A mechanism that only makes tests faster, and that production never exercises, masks production behaviour and is not acceptable. Ryan applied this to every caching variant:

- a process-lifetime shared Lexicon (candidate c above): ruled out;
- a result cache in conceptql or t_shank: ruled out;
- a Sequelizer extension handed a cache object keyed on connection + SQL (Ryan's own sketch): set aside for the same reason.

What survives: changes that remove the redundancy for PRODUCTION too, through one code path. Candidate (a), emitting the Gender operator's concept_relationship lookup (gender.rb:42,46 -> related_concept_ids -> is_a_relationships) as a subquery in the generated SQL instead of fetching IDs into Ruby, fits. Unmeasured: it may only move the scan into every query that filters on gender.

Related measured fact from t_shank (not a conceptql change): a Spark-side CACHE TABLE on the four vocabulary tables, done in t_shank's TEST SETUP only, cut a CI-shaped shard's wall time by 29% and lexicon lookups from 1.43 s to 0.18 s. Whether that setup-level variant is acceptable is pending Ryan's ruling. It bears on how much (a) would buy on Spark.
