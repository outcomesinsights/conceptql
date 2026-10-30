---
id: conceptql-96g
title: Drop the omopv4_plus (OMOP CDM) data model from conceptql?
status: captured
type: question
created_at: 2026-10-30T00:05:17.586094+00:00
updated_at: 2026-10-30T00:05:24.652912+00:00
relationships:
  - target_id: conceptql-chr
    rel_type: questioned-by
    created_at: 2026-10-30T00:05:24.651386+00:00
---

Ryan, 2026-10-29: "I'm thinking we can probably drop OMOP support". Not ruled yet.

## Scope: what "OMOP support" means here

"OMOP support" is the `omopv4_plus` data model: queries against OMOP CDM v4 data tables (`condition_occurrence`, `visit_occurrence`, `person`, and so on). It is NOT the OHDSI vocabularies. Production runs `gdm_wide` with the OHDSI lexicon (`ohdsi_vocabs`, `concept` table), and that must stay. The column name `omopv5_vocabulary_id` is an OHDSI vocabulary ID, so it also stays (a rename is a separate question).

## Evidence (survey 2026-10-29)

- No test fixture has OMOP tables. CI never runs `omopv4_plus`. `rake test_omopv4_plus` is red against the only fixture (bead conceptql-ok0).
- The model is already partly broken. Bead conceptql-myp found that provenance raised NoMethodError on `omopv4_plus`. The fix removed five operators (provenance, one_in_two_out, hospitalization, hospice, snf) from that model instead of implementing them.
- The OMOP-only code in conceptql:
  - `lib/conceptql/data_model/omopv4_plus.rb` (12 lines).
  - `lib/conceptql/query_modifiers/omopv4_plus/` (5 files, 243 lines).
  - `schemas/omopv4_plus.yml` (729 lines) and `schemas/omopv4_plus_more_ignorables.tsv`.
  - The OMOP branch of the `read` operator (`ReadOmopBase` and four subclasses) and `Vocabularies::Behaviors::Omopish`.
  - `VocabularyClassFactory#get_omopv4_plus_klass`, `Entry#belongs_in_omopv4_plus?`, and the `omopv4_vocabulary_id` column of `config/vocabularies.csv`.
  - The `test_omopv4_plus` rake task, the CLI help text, and about 10 tests that build an `omopv4_plus` database on `Sequel.mock`.
- The largest part is hidden. `DataModel::Base` (463 lines, 58 methods) holds the OMOP defaults, and `Gdm` (25 methods) overrides some of them. Removal means moving the methods that GDM still inherits into `Gdm` and deleting the rest. That is the step that needs care.

## Downstream (read only, outside this repo)

- jigsaw-diagram-editor: `lib/tasks/generate_databases.rake` creates six development `Database` rows with `data_model: "omopv4_plus"` (seer_medicare, medicare, pharmetrics, marketscan, optum, japan_claims). `docker/.env` lists `omopv4_plus` as a valid option.
- t_shank has its own `TShank::DataModel::Omopv4Plus` and detects it from the data store.
- The survey could not see production. The open fact is whether any production Jigsaw `Database` row still has `data_model = 'omopv4_plus'`.

## Options

- (a) Remove `omopv4_plus` from conceptql in the next minor release (0.5.0, a breaking change). Move the inherited methods from `Base` into `Gdm`. File handoffs for t_shank and jigsaw-diagram-editor to remove their OMOP paths on their own schedules.
- (b) Deprecate first. In 0.4.x, `ConceptQL::Database.new(data_model: :omopv4_plus)` prints a deprecation warning. Remove it in 0.5.0 as in (a).
- (c) Keep it as it is. It costs nothing at run time, but every change to `Base` must keep an untested model working.

## Recommendation

(a), after one check: confirm that no production Jigsaw database uses `omopv4_plus`. If one does, use (b). The model has no fixture and no CI, and it is already partly broken, so a deprecation period protects no tested user.
