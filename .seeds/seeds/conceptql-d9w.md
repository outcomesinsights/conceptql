---
id: conceptql-d9w
title: "annotate against a dataset: check each code against both the full lexicon and the dataset's trimmed vocabulary"
status: captured
type: question
created_at: 2026-11-10T16:19:07.430294+00:00
updated_at: 2026-11-10T16:19:07.430294+00:00
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
3. **The warning gate.** Path 1 and path 2 need the lexicon check without a data database. `add_warnings?` ties all lookups to a data database, and `LexiconStrategy#known_codes` reads the data database too. Separating "checks that need a lexicon" from "checks that need data" touches every warning that uses `add_warnings?`. Medium, and the riskiest part.

Tests need two lexicons that differ. The DuckDB fixture has one set of vocabulary tables. A test could build a trimmed copy in a temporary schema, or the fixture could gain one (vocabulation owns the fixture).

## Overlap with other seeds

- conceptql-zhn (bead conceptql-d1bd): when etl_vocabulary_ids says a whole vocabulary is absent, a warning for each of its codes says the same thing again. The two warnings should not both fire for one operator.
- conceptql-3z1 (beads conceptql-k7vg, conceptql-si8t): the new warning goes into annotate like every other warning. Nothing new is needed for it to reach JDE.

## Open questions

- The wording of the new warning. Ryan: "I just want to think about the warning message."
- Is the reference lexicon an explicit option (JDE passes LEXICON_URL's lexicon), or does a Database that has a dataset lexicon find the full one by itself (`Database.lexicon_db` from LEXICON_URL)?
- Does path 1 (no data database, no lexicon) gain a lexicon? That is a JDE change: StatementDraft#annotations would pass the full lexicon.
