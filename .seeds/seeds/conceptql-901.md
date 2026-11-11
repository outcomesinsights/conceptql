---
id: conceptql-901
title: 'A LEXICON_URL without vocabulary tables raises in 0.8.0: keep raising?'
status: captured
type: question
created_at: 2026-11-11T06:48:08.330842+00:00
updated_at: 2026-11-11T06:48:37.403473+00:00
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
