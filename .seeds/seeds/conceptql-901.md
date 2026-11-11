---
id: conceptql-901
title: 'A LEXICON_URL without vocabulary tables raises in 0.8.0: keep raising?'
status: resolved
type: question
created_at: 2026-11-11T06:48:08.330842+00:00
updated_at: 2026-11-11T12:22:47.092106+00:00
resolved_at: 2026-11-11T12:22:47.092097+00:00
resolution: 'Keep raising: a LEXICON_URL database without vocabulary tables raises NoVocabularyError (Ryan, 2026-11-11). No code change.'
---

## The question

In conceptql 0.8.0, a set `LEXICON_URL` whose database shows no OHDSI vocabulary tables raises `Lexicon::NoVocabularyError` at the first query, even when the data database has its own vocabulary. Should it raise, or should the Database run with no reference lexicon (and maybe warn)?

## What happened (2026-11-10)

- Bead conceptql-8oim (Ryan: "explicit option with a fall back to LEXICON_URL") made `Database#reference_lexicon` fall back to a Lexicon of the `LEXICON_URL` database. `Database#lexicon_url_lexicon` raises when that database has no vocabulary tables. `Database#operators` builds the reference lexicon, so every query touches it. In 0.7.0, `LEXICON_URL` was read only when the data database had no vocabulary tables.
- conceptql-jh58 removed the GDM lexicon, so a `LEXICON_URL` database with only GDM vocabulary tables also raises now.
- t_shank found it the same night: 7 exporter_spec examples failed in its local-gems mode with "the LEXICON_URL database has no vocabulary tables". Its `docker/.env` sets `LEXICON_URL=postgres://ryan:r@test_data/test_data` with no search path, so the connection sees only `public`, and the vocabulary is in `ohdsi_vocabs`. 0.7.0 passed because the data database had the vocabulary. conceptql told t_shank the cause and two fixes on its side (a search path in the URL, or unsetting `LEXICON_URL` for the postgres engine, as its spark and duckdb engines already do). t_shank bead t_shank-njva moves t_shank to 0.8.0.

## Directions (not ruled)

(a) Keep raising. A misconfigured `LEXICON_URL` is then loud, and every consumer must point it at a database that shows the vocabulary.
(b) No reference lexicon, with a log warning. The Database then behaves as 0.7.0 did for that configuration, and the not-present warning silently disappears.
(c) Raise only when the data database also lacks the vocabulary (the 0.7.0 failure case), otherwise (b).

Production (measured by t_shank, read-only, 2026-11-10): the production `LEXICON_URL` is titan.jsaw.io/ohdsi_vocabs?search_path=ohdsi20260829. That schema has concept, concept_ancestor, concept_relationship and vocabulary (11,393,905 concepts), so production does not raise on 0.8.0. Only t_shank's test config hit it. t_shank's pick: add ?search_path=ohdsi_vocabs to docker/.env's `LEXICON_URL`.

RULED 2026-11-11 (Ryan): keep raising (direction a). ConceptQL::Database.new keeps raising Lexicon::NoVocabularyError when LEXICON_URL is set and its database has no vocabulary tables, even when the data database has its own vocabulary. No code change.

How the ruling was reached. Ryan first said: "it's odd to me to make conceptql completely dependent on LEXICON_URL", and then: "I don't want conceptql to require a set of vocabulary tables, be they a dataset's or LEXICON_URL". The session explained that a vocabulary operator filters `clinical_code_concept_id IN (...)` with concept IDs it looks up in the concept table (lib/conceptql/operators/vocabulary.rb, where_clause). With no vocabulary, no row matches, which is why seed conceptql-ysx (option A, commit af39b5b5) made a missing vocabulary raise instead of returning 0 rows.

The session offered one way to need no vocabulary tables: filter on clinical_code_vocabulary_id and clinical_code_source_value when no vocabulary exists. Measured on the DuckDB fixture (claude_stuff/source-value-vs-concept-code-20261111-042144.log): CPT4, NDC, DRG and LOINC source values equal the concept codes (37,785 rows). ICD9CM source values have no dots, "3488" against "348.8" (50,783 of 52,316 rows), and ICD9Proc is the same (109 of 215 rows). So it would need a rule for each vocabulary. Descendants, concept names and the unknown-code check cannot work without a vocabulary.

Ryan then ruled: "oh, nevermind. let's keep raising". Not pursued: source-value matching, a reference lexicon that only logs a warning, and a raise only when the data database also lacks the vocabulary. t_shank's fix (?search_path=ohdsi_vocabs in docker/.env's LEXICON_URL, bead t_shank-njva) stays as planned.
