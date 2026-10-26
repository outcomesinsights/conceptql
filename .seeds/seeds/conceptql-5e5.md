---
id: conceptql-5e5
title: 'Over-engineering audit 2026-10-07: cuts to make (all but 1, 2, 7)'
status: resolved
type: decision
created_at: 2026-10-07T17:50:51.199585+00:00
updated_at: 2026-10-26T22:25:03.225972+00:00
resolved_at: 2026-10-26T22:25:03.225963+00:00
resolution: "The three items held back on 2026-10-07 are settled (2026-10-26). #1 JigsawTree: Ryan ruled to keep it; it stays at lib/conceptql/diagram.rb:154. #2 Presto/driftr Rakefile scaffolding: removed with Presto support in 5a37dbde (bead conceptql-wsf); Rakefile:52 is now 'task default: :test'. #7 query optimizer: deleted in 78ca8fc1 (bead conceptql-nte); no 'def optimized', 'unionable?' or Sourcish remains in lib. The three out-of-scope bugs were fixed by conceptql-66w (qualifier, String#glob, metadata) and selection_operators was removed. Efficacy: the audit's findings held; none needed rework."
tags:
  - ponytail-audit
  - cleanup
  - deps
---

A repo-wide audit for over-engineering (ponytail-audit, 2026-10-07). It looked for dead code, unused dependencies, things the standard library or ActiveSupport already provide, and logic that could be shorter. Every `delete:` finding was checked by grepping lib, test, bin, the Rakefile and the two consumers (t_shank, jigsaw-diagram-editor) for static and dynamic references.

Estimated net: about -850 lines and -7 deps (5 runtime: irb, reline, bigdecimal, ostruct, memo_wise; 2 dev: watir, nokogiri).

## Decision (Ryan, 2026-10-07)

Implement every finding **except 1, 2 and 7**. Those three stay open here as deliberation. #21 was withdrawn during the audit (see below).

## Findings

01. **[NOT NOW] delete:** `Diagram::JigsawTree` (~94 lines) and its test block (81 lines). It copies the editor's `ConceptqlAdapter#to_jigsaw_json`, but the editor still uses its own adapter, and nothing calls this one except its test. No seed or bead plans to use it. [lib/conceptql/diagram.rb:150-243, test/lib/conceptql/diagram_test.rb:215+]
02. **[NOT NOW] delete:** The Rakefile's Presto/driftr scaffolding: `namespace :test_script`, `namespace :driftr_script`, `convert`, `prestofy` and the Presto-pinned `cdb`, with hardcoded hosts and schemas. Also `task default: :test_omopv4_plus`, which runs a data model the fixture can't support and writes junk `test/results/omop/*.json` files. Replacement: `task default: :test`.
03. **delete:** `Guardfile`. It's the stock Rails/RSpec template, but the repo uses Minitest and has no guard gem.
04. **delete:** `dockers/base_compose.yml` and `dockers/sqlite/`. Nothing references them except each other; `docker-compose.yml` uses `dockers/standard`.
05. **delete:** `doc/converter.rb`. It instantiates `ConceptQL::Converter`, which no longer exists.
06. **delete:** `LICENSE.txt`. It's an older copy of `LICENSE`, and the gemspec ships only `LICENSE`.
07. **[NOT NOW] delete:** The dead query optimizer: `Query#optimized`, `NullQuery#optimized`, `Operator#optimized`, `Operator#unionable?` and the `Sourcish` module (`unionable?`/`union`). Nothing calls `optimized`, so the union merging never runs.
08. **delete:** `NullQuery`. `Database#query` creates one with `NullQuery.new if …` and throws the result away, so no caller ever receives one. Remove the class and that line.
09. **delete:** Dead files:
    - `ConceptQL.logger` (lib/conceptql/logger.rb): never called, and it would write to `/tmp/cql.log`.
    - `CodeListItem`: never referenced.
    - `Behaviors::Unwindowable`: required but never included; nothing reads `skip_windows?`.
    - `Behaviors::MultipleEvent`: never included.
10. **delete:** Methods with no callers anywhere:
    - TemporalOperator: `at_least_check?`, `inclusive?`, `occurrences_option`
    - Vocabulary: `code_column`, `vocabulary_id_column`, `table_concept_column`, `translate_to_old`
    - Operator: `codes_should_match`, `setup_select`, `same_table?` (Operator and From)
    - DataModel: `convert_table`, `condition_table`, `person_id_column` (Base and Gdm)
    - Read: `mapping_type_to_domain`
    - TrimDate: `within_column`
    - CLI: `filtered`
11. **shrink:** Collapse the five `SqlFormatters` classes, three of which run the same `sql-formatter` binary with different flags, into one formatter that takes a command array. ~150 lines down to ~30.
12. **reuse:** `Utils.blank?`, `Utils.present?`, `Utils.to_sentence` and `Utils.snakecase` copy what ActiveSupport already provides (`Object#blank?`/`present?`, `Array#to_sentence`, `String#underscore`). ActiveSupport is already a runtime dependency.
13. **native:** Drop the runtime dependency `memo_wise`, which is used once (`memo_wise :query`). Replace it with a Hash memo keyed on opts.
14. **native:** Drop the runtime dependency `ostruct`. `Columnizer` should use the plain options Hash. Also delete the `column_names.map {…}` line, whose result is thrown away.
15. **delete:** The runtime dependencies `irb`, `reline` and `bigdecimal`. Nothing in lib requires them; `bigdecimal` already arrives through sequel and activesupport, and `reline` through pry and byebug.
16. **stdlib:** The dev dependencies `watir` and `nokogiri` exist only so the spec-conformance test can launch headless Chrome and scrape anchors from GitHub's rendered README. Fetch the raw README with Net::HTTP and pull the links with a regex.
17. **reuse:** The CLI's `simple_visit` command repeats `Query#extract_metadata`.
18. **delete:** `def_delegators :query, :profile` and `def_delegators :db, :profile_for`. No dataset or db in the stack defines either method.
19. **delete:** `Operator#omopv4?` compares against `:omopv4`, which isn't a data model, so it's always false. Drop it and the dead branch of the ternary in the omopv4_plus POS query modifier.
20. **shrink:** Small leftovers:
    - the stray `nil` statement in `column_family`
    - `db_type` assigned twice in `Database#initialize`
    - `.sort` on one-element arrays in the lab query modifiers
    - `require 'open3'` sits in query.rb, but utils.rb is what uses it
21. **WITHDRAWN** yagni: removing the `omopv4_plus` data model. It is still live downstream. t_shank's DatabaseChecker detects it (app/workers/database_checker.rb:80), and the editor registers six claims databases as `omopv4_plus` (lib/tasks/generate_databases.rake). conceptql's tests never cover it; that is a coverage gap, not a reason to cut.

## Out of scope: bugs noticed in passing (route to a normal review)

- `Columnizer` reads `options.qualifer` (misspelt), so the qualifier option never applies.
- `CLI#cdb` calls `String#glob`, which doesn't exist (the CONCEPTQL_PARQUET_TEST_DIR branch).
- The CLI's `metadata` and `selection_operators` commands call `ConceptQL.metadata` with no arguments, but it requires a database.

## Outcome (2026-10-07)

Implemented via beads, all merged locally to main and closed. Not pushed.

- #3-6 -> conceptql-fsx (also removed their .rubocop_todo.yml excludes)
- #8, #9 -> conceptql-bvj. Deleting logger.rb dropped the gem's only `require 'logger'`; it is now required in database.rb and cli.rb.
- #10, #17-20 -> conceptql-g0i. Every listed method deleted. v5_vocab_to_v4_vocab never existed.
- #11 -> conceptql-kyg. 154 lines down to 47. A fallback-order pin test was added first, and the output of all 5 rdbms was compared with cmp: identical. Presto still formats with `-l postgresql`; the unused trino variant was deleted, not wired in.
- #12 -> conceptql-ztt. Metadata byte-identical; underscore == snakecase for all 127 operator names. one_in_two_out gaps and scope scratch_database keep the old nil-or-empty rule (`x.to_s.empty?`), not ActiveSupport blank?.
- #13-15 -> conceptql-b8l. The lockfile change is removals only; irb's tail (date, erb, psych, rdoc, stringio, tsort) left the lock. bigdecimal and reline stay as transitive deps.
- #16 -> conceptql-8rh. Raw README + regex gives 37 anchors, identical to the rendered page. watir, nokogiri, selenium-webdriver, websocket, rubyzip and rexml left the lock.
- Cascade -> conceptql-p0h. Deleted Vocabulary#table_name, Operator#modify_query, the @codes_regexp plumbing, the unused `deprecated` DSL, and the remaining one-element sorts. KEPT Operator#make_table_name: CastingOperator calls it through `super`, which a name grep cannot see, so the audit's "no callers" was wrong there.

Pre-chain fix: conceptql-m5q. The test_data image's 2026-10-02 FY2027 rebuild split the CPT 80230 text between ohdsi_vocabs and gdm_vocabs. Expected results can now be keyed by lexicon strategy: test/results/<model>/\<ohdsi|gdm>/... wins over the shared file.

Filed, not run: conceptql-pni (dead Chrome libs and the nokogiri build config in dockers/standard/Dockerfile; needs a decision about the published image tag).

Still open here for deliberation: #1 (JigsawTree), #2 (Rakefile Presto/driftr + default task), #7 (dead optimizer). b8l noted that Query#optimized returns a stale cached dataset if called after #query, which is one more reason to delete it under #7.

RULED 2026-10-26 (Ryan), finding 01: keep Diagram::JigsawTree and ship it in 0.4.0 as public API. It was added for the editor to adopt later. Findings 02 and 07 stay open.

RULED 2026-10-26 (Ryan: include the remaining work in 0.4.0): item 02 goes with Presto removal (bead conceptql-wsf). Item 07, the dead query optimizer, is deleted before 0.4.0 (new bead).
