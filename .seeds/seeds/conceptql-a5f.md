---
id: conceptql-a5f
title: Lexicon re-issues identical vocabulary queries per Database/export; remove the round trips, possibly with a cache that lives one Database
status: captured
type: question
created_at: 2026-09-29T03:04:20.735970+00:00
updated_at: 2026-10-14T19:21:39.973882+00:00
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

## 2026-10-14: Ryan reopens the cache question, scoped to one Database

Ryan, verbatim, in the conceptql session that re-evaluated SQL optimization (seed conceptql-8u6):

> I think we had actually talked about this caching before, and you might want to consult with TShank to see if it has any notes on it. What I'm envisioning is that we might have a Cache object that we can pass into A conceptual database object My fear is having long-lived cache objects that end up becoming misleading. I guess first, does SQL have any sort of, and I'm saying SQL the gem have any sort of idea about this kind of caching? Before we do anything else on our own, if SQL does not, is there some sort of library or Ruby idiom or something that would provide us this kind of caching. And again, my major concern, which I think should be captured in A5F, is is I don't want long lived caching that ends up giving us weird problems and it becomes hard to track.

("conceptual database object" is ConceptQL::Database. "SQL the gem" is Sequel.)

**Ryan's concern, as the constraint for this seed:** no long-lived cache. A cache must not outlive the work it serves, and its behaviour must be easy to trace. This replaces the earlier framing "remove the round trips without a cache" only to the extent Ryan rules on the sketch below.

## What t_shank recorded (relayed by the t_shank session, 2026-10-14)

- t-shank-58t (2026-09-29) ruled out every cache that only speeds up tests: "he does not want test-only code paths". It named three variants: a process-lifetime Lexicon, a result cache in conceptql or t_shank, and Ryan's Sequelizer sketch (a cache object keyed on connection + SQL). The reason recorded: "Production does not run ~100 exports against one database in quick succession, so the cache would exist for CI alone."
- The same seed recorded the hazard of a connection-level cache: "the same connection creates and drops temp tables all through an export, so it would have to know which tables are immutable, and getting that wrong returns stale answers silently."
- 2026-09-30, Ryan on a Spark CACHE TABLE of the vocabulary tables: first "Vocabulary cache makes sense to me and I'd like to see that become part of production", then the final ruling "Let's do no cache table and see how the all-in-RAM version works without it. Seems like production won't get a speedup because we don't run many exports in rapid succession." t_shank bead t_shank-bfz is closed as won't do.
- t-shank-ucq (2026-10-14, agent wording, Ryan did not comment): a memo for one export is one code path in production too, so it does not conflict with the test-only ruling.
- No design exists in t_shank for an export-scoped cache.

Facts about lifetime in t_shank:

- t_shank builds one ConceptQL::Database per export. Exporter#cdb (t_shank lib/t_shank/exporter.rb:130-131) memoizes it, and Exporter#setup_db (line 125) discards it when the connection is set. Each export log has exactly one "NEW CDB" line.
- The statistics workers (statistical.rb:12, statistician.rb:32) build their own ConceptQL::Database.
- Lexicon#determine_strategy tries the data database first, so in production every vocabulary lookup goes to Spark.

## Newer measurement (t_shank, 2026-10-14)

Export f4f10fdf (marketscan_mdcd_2026_20260318). Count of SELECTs against concept, concept_ancestor, concept_relationship or vocabulary. This method differs from the one behind "618 lookups, 183 distinct", so compare these two rows only with each other.

```
March production run:          970 lookups, 198 distinct, 6.04 min total, 5.00 min on repeats
2026-10-14 bench re-run:       929 lookups, 195 distinct, 2.58 min total, 2.04 min on repeats
                               (8.3% of the bench run's 24.6 min SQL phase)
```

The per-run spread is not known yet.

## Does Sequel have this kind of cache? No.

Checked against the installed sequel 5.109.0 source.

- `caching` plugin: caches Sequel::Model rows looked up by primary key, in an external store with the memcache API and a time-to-live. conceptql uses datasets, not models, and lexicon lookups are not primary-key lookups.
- `static_cache` plugin: loads every row of a Model's table once and freezes them. It is for small tables that never change. `concept` has about 11M rows.
- `schema_caching` and `index_caching` extensions: they store table metadata (column and index information) in a file. They do not store query results.
- Dataset#cached_dataset and the SQL-string cache: they speed up building SQL. They never store results.
- `table_exists?` has no cache. Each call sends a probe query.

So Sequel has no cache for dataset results. Anything here is ours.

## Ruby idioms and libraries

- **Instance memoization** (`@x ||= ...`, or a Hash keyed on the arguments). The cache lives exactly as long as the object that holds it, and the lifetime is visible in the code. This is the idiom that fits Ryan's concern.
- **memo_wise** gem: the same lifetime as instance memoization. conceptql used it until d65f965c removed it (conceptql-b8l, runtime dependency cleanup). Adding it back is not needed for a single Hash.
- **ActiveSupport::Cache::MemoryStore** (activesupport is already a dependency): it has a time-to-live and a size limit. A time-to-live limits age by the clock, not by the work. The cache could expire in the middle of an export, or survive after the export if something holds it. So it does not answer the concern.
- **Process-wide caches** (class-level Hashes, constants, LRU gems): these are the long-lived kind. Excluded.

## Sketch for deliberation (not ruled)

A lookup cache that the ConceptQL::Database owns.

- **Where the cache sits:** at the Lexicon method boundary. Lexicon (lib/conceptql/lexicon.rb) already delegates every lookup to its strategy through `def_delegators`. The methods that return values (for example concept_ids, descendants_of, related_concept_ids, vocabularies, known_codes) would be memoized on the method name plus its arguments. The methods that return datasets (concepts_table, concepts_ds, vocabularies_query) send no query and need no cache. The table_exists? probes (db_has_all_vocabulary_tables?, table_is_missing?) would be answered once per Database.
- **Why at the Lexicon and not at the connection (Ryan's 2026-09-29 Sequelizer sketch):** the Lexicon reads only vocabulary tables, and those do not change during an export. A cache at the connection sees every query, including the temp tables that an export creates and drops. It would need to know which tables never change, and a mistake returns stale results with no error. Keying on Lexicon methods removes that question.
- **Lifetime:** conceptql already builds one Lexicon per ConceptQL::Database (Database#lexicon, database.rb:102-104). In t_shank that is one export. The statistics workers get their own. Note: Database#initialize already accepts a ready-made Lexicon through `opts[:lexicon]` (database.rb:34). A memo inside the Lexicon would therefore follow any Lexicon that a caller passes to several Databases.
- **Fit with the 2026-09-29 rule:** production runs the same code path, and production gains. The bench re-run above spent 2.04 of 2.58 minutes of lookup time on repeats. So it is not a test-only path. t_shank's CI also gains only within each export, because every export gets a new Database.
- **Traceability:** the cache holds no global state and has no time-to-live. It can count hits and misses and log them when the export ends, and a reader such as `ConceptQL::Database#lookup_cache` can expose it to tests and to t_shank.

## Open questions for Ryan

1. **Who creates the cache?** (a) ConceptQL::Database always creates its own and accepts none from outside. A long-lived cache is then impossible by construction, and t_shank needs no change. (b) The caller passes one in, as Ryan sketched. That makes the lifetime explicit at the call site, but a caller could pass one cache to many Databases, which brings back the long-lived case. Recommendation: (a).
2. **Cache or SQL push-down for the Gender lookup?** Candidate (a) from 2026-09-28, which emits the is_a lookup as a subquery in the generated SQL, still removes that round trip without any cache. The two can coexist. Which lookups dominate the 195 distinct ones in f4f10fdf has not been broken down by Lexicon method yet. That breakdown should come before choosing.
