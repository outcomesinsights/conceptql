# Adversarial review of the spec-migration seeds (2026-11-03)

Reviewed: the seeds conceptql-mdo (decision) and its children conceptql-mdo.1 to conceptql-mdo.4, on branch `seeds/spec-migration` at 99b1ab45 (conceptql main 44be502d).
This is a read-only review. I changed no seed, bead or code. The scratch scripts and logs are in `claude_stuff/review-20261103/` of the worktree.
The DuckDB checks ran on a copy of the pinned fixture (sha256 d90fc4c9…, the value in `.github/synpuf_test_data.sha256`) with libduckdb 1.5.6.
The earlier review (conceptql_spec `docs/reviews/2026-11-03-spec-migration-seed-review.md`) is not repeated here, except where a new seed answers it wrongly or incompletely.

## Summary

The most severe problem is decision 09: a release check that rebuilds the example results and "fails on any difference" cannot run in release.yml as the workflow is today. Also, it gives false failures if the new build reuses conceptql_spec's knitter.
release.yml has no fixture, no bundle, no libduckdb and no treefmt, and a ruling of 2026-10-02 keeps the 2 GB fixture out of it.
A failure there also comes after the tag is pushed.
conceptql_spec's knitter takes `LIMIT 10` with no `ORDER BY`. On the same database, 15 of the 59 README examples returned different rows in 3 runs.
The second problem is a misdiagnosis. The 44,083-byte MCP section has a different cause than the seeds assume. The knitter writes "`No Results found.`" for an empty result, and JDE's slicer reads that line as a code fence. When I correct that one line, the largest section is 12,119 bytes.
Other defects: the seeds name two different databases for the build, the interim images can become stale with no check, the archive of conceptql_spec conflicts with the renderer deliberation that lives there, and the removal list for step 3 misses two tests.

## Verified defects, ranked by damage

### 1. Decision 09: the release workflow cannot rebuild the results as written, and the failure comes after the tag (conceptql-mdo, conceptql-mdo.3). NEEDS RULING

- Claim (mdo.3, Rulings): "The release workflow rebuilds the results with no cache and fails on any difference."
- Evidence:
  - release.yml:15-17 says "No test suite runs here. The suite needs Postgres, Spark and a 2 GB DuckDB fixture, so it stays in run_tests.yml … (ruled 2026-10-02)".
  - release.yml:97-99: the publish job "installs no bundle and runs no development dependency". The verify job installs nothing either.
  - A rebuild needs `BUNDLE_WITH=duckdb`, libduckdb (justfile:70-84), the fixture from the `DUCKDB_TEST_DATA_URL` variable (run_tests.yml:173-209), and treefmt with mdformat (uvx) and prettier (mise.toml). The build loads `test/db_helper`, which loads simplecov and minitest (development dependencies).
  - Order of events in CLAUDE.md "Releasing": the commit lands on main, CI passes, and then the tag is pushed. A difference found in release.yml then needs a new commit on main, a new CI run, and a deleted and re-pushed public tag.
- Change. Rule on where the check runs. The options:
  - (a) A new job in release.yml, as the decision says. It needs all the tools above, and a failure needs a re-tag.
  - (b) A step in `just release-check` (step 1 of Releasing), before the version bump. It is cheap and uses the local fixture, but nothing enforces it.
  - (c) A job in run_tests.yml that rebuilds and compares on each push to main. It always runs, so it never shows as "skipped" (run_tests.yml:234 makes a skipped job fail `ci`). release.yml already requires a green run_tests.yml on the tagged commit, so this blocks a release before the tag. This conflicts with "main can hold stale results", unless the job only reports on commits that do not change `lib/conceptql/version.rb`.
  - Recommendation: (b) plus (c), with (c) failing only on a commit that changes `version.rb`. Name the Ruby version and the libduckdb version of the rebuild (the justfile's 1.5.6), because CI tests 1.5.6 and 2.0.0.

### 2. conceptql_spec's knitter gives different result rows from run to run, so "fail on any difference" fails at random (conceptql-mdo.1, conceptql-mdo.3). FACT FIX

- Claim (mdo.1): "Keep one build". The seeds do not say which knitter survives. mdo.3 (Open) defaults to "the README's current limit of 10 result rows per example (conceptql_spec lib/knitter.rb)".
- Evidence:
  - conceptql_spec lib/knitter.rb:141 is `knitter.cdb.query(statement).query.limit(10).all`, with no ORDER BY.
  - I ran each of the 59 README.cql.md examples 3 times in one process on the DuckDB fixture (`claude_stuff/review-20261103/determinism-20261103-102115.log`). 15 examples gave different first-10 rows between runs. Examples: "First Office Visit Per Patient" (line 89), "Episodes of diabetes diagnoses" (line 1040), and the `first`, `last` and `occurrence` examples.
  - conceptql's own script/spec/harness.rb orders by `person_id, criterion_domain, start_date, criterion_id` before its LIMIT 10. With that order, no example had a tie at the tenth row or inside the first ten.
- Change. Write a rule into mdo.3: the build orders every result by a total order before the limit. Use the harness order plus `criterion_table`, because a criterion_id is unique only within its table. Say that the new build takes its result code from script/spec/harness.rb, not from lib/knitter.rb.

### 3. The 44,083-byte section comes from one "`No Results found.`" line, not from section length (conceptql-mdo.1, and conceptql_spec-vvf.2). FACT FIX

- Claim (mdo.1): "Today's README already has one 44,083-byte section by that rule. The generated spec must keep every `## ` section under the limit."
- Evidence:
  - lib/knitter.rb:151 writes "`No Results found.`" for an example with no rows. README.md has 3 such lines (619, 639, 1668), and README.md has 127 fence lines (an odd number).
  - JDE's slicer (app/mcp/mcp_server.rb, `split`) toggles its fence state on any line that starts with three backticks. Lines 619 and 639 cancel each other. Line 1668, in the Place of Service Filter section, inverts the state for the rest of the file. So every later `## ` heading counts as inside a fence, and the sections after it join into one 44,083-byte resource.
  - With that one line replaced by plain text, the largest section is 12,119 bytes ("Time Manipulation Operators"). conceptql's script/spec/knit.rb:51 already writes the empty result with single backticks.
  - JDE's test for the 40,000-byte limit runs only in JDE, against the installed gem (spec/requests/mcp_conceptql_spec_spec.rb). JDE takes conceptql's local main during tandem development. So if step 3 points spec_path at the README text as it is, JDE's suite fails at once. Nothing in conceptql would fail first.
- Change:
  - Correct the cause in mdo.1.
  - Put into step 3: the empty-result text without a fence, the heading demotion of conceptql_spec-vvf.2 (one `# `, everything else one level lower), and a conceptql test. That test splits the generated spec with JDE's rule, then checks that the fences balance and that every section is under 40,000 bytes.
  - vvf.2's heading work is not in any step today. The bead order carries only vvf.1 into step 3.

### 4. The seeds name two different databases for the build (conceptql-mdo.2 against decision 08 and conceptql-mdo.3). FACT FIX

- Claim (mdo.2): "The rules apply to the build's database: gdm with no lexicon and no custom vocabularies. gdm and gdm_wide give the same 119 operators."
- Claim (decision 08, mdo.3): the results come from the DuckDB fixture on gdm_wide.
- Evidence:
  - The current spec build reaches the fixture through test/db_helper.rb. That file builds `CDB` with `cache_lookups: true`, so it builds a lexicon from `ohdsi_vocabs`.
  - On the fixture with that lexicon, `ConceptQL.metadata(CDB)` publishes 431 operators, not 119. It is 312 more vocabulary operators (for example `cpt4_hcpcs`, `cms_place_of_service`, `cprd_*`, `seer_*`). Still 36 spec_ids (`claude_stuff/review-20261103/duck-20261103-102000.log`).
  - 53 of the 119 shared operators have a different `short_name` and `long_name` with the lexicon (for example `currency`: nil without a lexicon, "International Currency Symbol (ISO 4217)" with it). The render tree's `humanName` comes from the same place, for example "ICD-9 CM".
- Change:
  - Say in mdo.2 that the build uses two databases. `Database.new(nil, data_model: :gdm)` decides which operators get a section and which metadata is printed. The fixture database runs the examples and draws the trees.
  - Say that the build unsets `CONCEPTQL_CUSTOM_VOCABULARIES`.
  - Say that the rule "every published operator has … at least one example" applies to each spec_id, not to each operator. Without that, the 84 vocabulary operators each need an example, because `example` is not inherited.

### 5. Decision 13: when CONCEPTQL_DIAGRAM_CLI is not set, the behavior is undefined, and stale images cannot be found (conceptql-mdo, conceptql-mdo.1). NEEDS RULING

- Claim: "the build draws diagram images … when CONCEPTQL_DIAGRAM_CLI is set … CI checks only the text and the data. Nothing becomes worse than today."
- Evidence:
  - Today the variable is required, not optional. DiagramRenderer#initialize (lib/diagram_renderer.rb:26) calls `cli`, and `cli` raises when the variable is empty (line 60). prep_readme.sh stops too.
  - lib/knitter.rb:35 deletes the whole image directory at the start of each build (`d.rmtree if d.exist?`). If an implementer adds a "skip when not set" path and keeps that line, a build without the CLI deletes all 58 committed SVGs.
  - Each SVG is drawn with `--show-counts`, so it shows row counts from the data. Its file name is a hash of the statement only (lib/knitter.rb:43). When results change, the image keeps its name and its old counts. No text or data check sees it.
  - conceptql's rule for its gate is "fails, never skips" (justfile:296-297, CLAUDE.md). A build that skips the images when a variable is missing is a skip.
- Change. Rule on two things:
  - Without the CLI, the build should (a) fail, (b) skip only with an explicit flag such as `--no-images` that CI passes, and keep the committed images, or (c) skip silently. I recommend (b).
  - To detect stale images, the options are (a) write the sha256 of each render tree (with its counts) to a committed manifest beside the images, and let the CI check compare the manifest with the rebuilt trees, which needs no renderer, (b) draw the images without counts, or (c) accept stale images. I recommend (a).

### 6. Image names depend on the Ruby version (conceptql-mdo.1, conceptql-mdo.3). FACT FIX

- Evidence:
  - lib/knitter.rb:43 names each SVG `SHA256("#{stmt}")`, which is Ruby's `inspect`. Ruby 3.4 changed `Hash#inspect` from `{:gap_of=>"90"}` to `{gap_of: "90"}`.
  - The episode example `[ "episode", ["icd9", "250.00"], { "gap_of": "90" } ]` has `README/0fba3266….svg`, which is the 3.4+ form. The 3.3 form gives `4841db72….svg`, which does not exist.
  - CI's DuckDB job runs Ruby 3.3 and 3.4 (run_tests.yml:166), and 3.3 is the gemspec floor. A rebuild on 3.3 changes the image link of every example that has an options hash, so the text comparison of decision 09 fails.
  - conceptql's script/spec/old_inspect.rb uses the Ruby 2.x form, so reusing conceptql's naming renames all of conceptql_spec's SVGs.
- Change. Name each image and each artifact by the sha256 of the statement's canonical JSON. Accept one rename of the images in the move.

### 7. Archiving conceptql_spec conflicts with the renderer deliberation and with unpushed work (decisions 05 and 11, step 7). NEEDS RULING

- Evidence:
  - Decision 11 keeps the renderer deliberation in conceptql_spec seeds conceptql-spec-dcn, dcn.1, 3pr and 9je. All four are `captured` (open).
  - An archived GitHub repository is read-only. After the archive, nobody can push those seeds when they change or resolve.
  - conceptql_spec's local main is 6 commits ahead of origin (`git rev-list --count origin/main..main`). Those commits include the earlier review and the 6sm seeds that conceptql-mdo cites as its source.
- Change:
  - Add to step 7: push conceptql_spec main before the archive.
  - Rule where the renderer seeds go before the archive: (a) carry them into conceptql, as the 6sm seeds were, (b) carry them into JDE, whose session may lead the renderer work, or (c) delay the archive until the renderer is decided. I recommend (b) if JDE leads, else (a).

### 8. Step 3's removal list misses two tests, CLAUDE.md and an ignore rule (conceptql-mdo decision 12, conceptql-mdo.1). FACT FIX

- Claim (decision 12): the removal is "doc/spec.md.cql, doc/spec.md, doc/spec/\*.png, script/spec/ and the `just spec` recipe".
- Evidence:
  - test/lib/conceptql/spec_diagram_draw_test.rb:5 requires `script/spec/grapher`, and spec_diagram_name_test.rb:4 requires `script/spec/old_inspect`. Both run in `test/all.rb`, so `just ci` fails when script/spec/ goes.
  - Superseded bead conceptql-gmpe listed both tests and the CLAUDE.md "Spec:" line. The new seeds drop that list.
  - CLAUDE.md:9 (the "Spec:" line) and the justfile comment block at lines 118-125 describe the old build.
  - `.gitignore:27` ignores `doc/.?????????*`, the knitter's cache directories. If the new build reuses the knitter's cache under docs/spec/, nothing ignores `docs/spec/.<hash>/`. The cache key includes `SEQUELIZER_URL` (lib/knitter.rb:218). `just test-duckdb` points that at a new `mktemp -d` directory on each run (justfile:94), so every run makes a new cache directory.
  - `just spec` is not in `ci` (justfile:304), so removing the recipe drops no check from the gate or from CI. This is correct, but the seeds should say it.
- Change. Add the two tests, CLAUDE.md:9, the justfile comments and the ignore rule to step 3. Drop the knitter cache. Decision 09 requires a build with no cache in any case.

### 9. Step 1 breaks JDE's suite, and the seed does not say so (conceptql-mdo.2). FACT FIX

- Claim (mdo.2): "JDE never reads min_upstreams or max_upstreams, so nobody noticed." The JDE effects list names only desc changes and new keys.
- Evidence: JDE's committed copy `frontend/tests/helpers/operator-metadata.json` holds the wrong values today: union, first, last, co_reported and occurrence are 99/99, before, after and during are 0/0, and trim_date_end and trim_date_start are 1/1. `spec/lib/ember_operator_metadata_spec.rb` compares that copy with the served metadata, so step 1 fails JDE's suite until `just ember-operator-metadata` runs.
- Change. Add step 1 to the JDE effects list, and tell JDE's session when step 1 merges.

### 10. Entry#visible? is called, so deleting the column changes a test (conceptql-mdo.4, bead conceptql-voth). FACT FIX

- Claim (mdo.4): "Entry#hidden? and Entry#visible? (entry.rb:111-125) are never called."
- Evidence: test/lib/conceptql/vocabularies/removed_vocabulary_rows_test.rb:35 and :59 assert `must_be :visible?`. No code in lib/ calls either method.
- Change. Write "never called outside one test". Name that test in voth, so that the implementer knows that the change to it is intended. The jigsaw rule "Never change tests to make them pass" otherwise makes the implementer stop.

### 11. No step makes a conceptql release, and no step writes the CHANGELOG (conceptql-mdo, bead order). FACT FIX

- Evidence:
  - JDE's Gemfile:40 is `gem "conceptql", "~> 0.6.0"`.
  - Decision 10 says help reaches JDE only through a release, and step 6 (JDE links and help) needs the shipped artifacts.
  - conceptql's CHANGELOG.md is written by hand under `[Unreleased]`. Changes the seeds make to the public surface need an entry: spec_path moves, the upstream counts change, new metadata keys, a new path method, and `Entry#hidden?` and `Entry#visible?` go away. Superseded bead conceptql-o29p required a CHANGELOG entry. The new seeds do not.
- Change. Add "release conceptql" between steps 5 and 6, under the rule that a release waits until the round is complete. Add a CHANGELOG line to each step that changes the public surface.

### 12. The copy list is a deny list, and it misses files (conceptql-mdo.1). FACT FIX

- Evidence:
  - README.cql.md:650 links `additional_images/any_overlap.png`. The seeds do not move `additional_images/`.
  - The deny list misses tracked files that must not come: docker-compose.yml (the mutable `test_data.ignitor` tag), .env.example, .mdlrc, justfile, prep_readme.sh, AGENTS.md, exe/annotate.rb, lib/annotater.rb and lib/fake_annotater.rb.
  - README.cql.md:1555 (Appendix D) tells public readers to use a checkout of the private JDE, and it describes the Postgres build that goes away.
- Change. Replace the deny list with an allow list: README.cql.md, the images it links, and, if any, the Ruby code that survives. Add the rewrite of Appendix D to step 3.

### 13. Small factual errors (conceptql-mdo decision 15, conceptql-mdo.2). FACT FIX

- doc/diagram_0.png last changed on 2014-07-11 (f53c6060, the initial commit), not 2014-09-04. The PDF date (2014-09-04, befeb7de) is correct.
- "11 texts appear 21 times": the 11 `instructions:` call sites hold 5 different strings. They appear 21 times over all registered operators and 20 times in the published metadata, because `sum` is hidden.

### 14. doc/ and docs/ both remain, and docs/ already has broken references (decision 12). NEEDS RULING (minor)

- After step 3, doc/ holds only metadata.md and implementation_notes.md. docs/ holds perf/ and the new spec/.
- AGENTS.md:99 cites `docs/QUICKSTART.md` and cog.toml:2 cites `docs/lint-and-format.md`. Neither file exists.
- Options: (a) move doc/metadata.md and doc/implementation_notes.md into docs/ in step 3 and remove doc/, or (b) keep both directories. I recommend (a). Fix the two broken references in either case.

### 15. Two link sites have no step (conceptql-mdo.1). FACT FIX

- conceptql README.md:9 and the four links in outcomesinsights.github.io (crash-course post lines 14 and 71, algorithm-library post lines 72 and 114) are listed. No step in the bead order changes them.
- Change. Put README.md:9 into step 3. Put the blog links into step 7.

### 16. Names from the private JDE repository in the public seeds (all five seeds). NEEDS RULING (low)

- conceptql is PUBLIC and jigsaw-diagram-editor is PRIVATE (`gh repo view`). The seeds name JDE files (jam-node.hbs, operator-registry.js, boot_config_helper.rb, ember_operator_metadata_spec.rb), JDE seed IDs, and jigsaw_builder's use of `CONCEPTQL_CUSTOM_VOCABULARIES`.
- Seeds already on origin/main do the same (for example conceptql-alj names `app/models/algorithm.rb:258`). I found no secret, host credential or data.
- This report is also repo content in the public repository, and it names JDE files.
- Options: (a) accept, because it is consistent with what is already public, or (b) a rule for the whole `.seeds/` store, which these seeds cannot fix alone. I recommend (a).

## Plausible concerns that I did not demonstrate

- **libduckdb 2.0 against 1.5.6.** I tested only 1.5.6, because the cached 2.0.0 is incomplete (`v2.0.0.tmp`). If 2.0 gives other results, the release check must name its version.
- **Operators with no example.** No README example uses `equal`, `filter`, `match` or `numeric_filter`. I did not test whether the fixture can give rows for new examples of them. The `snf`, `hospice` and `place_of_service_filter` examples return 0 rows on the fixture (verified). Under mdo.3's rule they are "not for help", so JDE shows no example for 3 operators until the fixture has that data.
- **Repository growth.** The 58 SVGs are 8.8 MB, and each one embeds the Roboto woff2 font. conceptql's pack is 19.75 MiB today. Each redraw adds a full copy of each changed SVG to the history.
- **Linux only.** `just test-duckdb` downloads only the linux-amd64 libduckdb. A spec build that uses it cannot run on macOS hosts. conceptql_spec's Postgres build in Docker was not limited in this way.
- **mdformat is not pinned.** The treefmt block runs it through uvx with no version. A new release of mdformat can change the generated text. fmt-check would see that first.
- **Icons.** Seed conceptql-spec-9je asks whether the operator icons may be public. The interim SVGs embed them in public conceptql. They are already public in conceptql_spec, so this is not worse than today.
- **Cache access from a tag.** I did not check whether a tag-triggered run can restore the fixture cache that runs on main created.

## Facts in the seeds that I verified as correct at HEAD

- metadatable.rb:158 is `min_upstreams: @max_upstreams || 0`. metadatable.rb:231-233 sets 1/99 for `validate_at_least_one_upstream`.
- occurrence.rb:43 `allows_one_upstream` and :44 `validate_at_least_one_upstream`. one_in_two_out.rb:24 and :30 use the option key `desc:`. temporal_operator.rb:17-18 declares `within` (the call starts on line 17).
- nodifier.rb:48 drops operators with empty categories. entry.rb:111 `hidden?` and :123 `visible?`. The line numbers did not move after the change to entry.rb since f24667f0.
- 125 operators are registered, 119 are published, and there are 36 spec_ids, on gdm and on gdm_wide with `Database.new(nil)`. The metadata JSON of the two data models is identical. The 6 unpublished operators are count, dedup, from, invalid, numeric and sum. vocabulary-operator covers 84 operators.
- The upstream counts in mdo.2: union, first, last, co_reported and occurrence are 99/99, before, after and during are 0/0, and trim_date_end and trim_date_start are 1/1.
- 21 rows in vocabularies.csv have `hidden`. 18 of them are published operators, so a connection to the new flag gives 101.
- spec_path_test.rb:17 and release.yml:132 are as the seed says.
- The DuckDB fixture matches its pin.
- All 59 README examples validate with no errors and no warnings on three databases: `Database.new(nil)` on gdm, a mock Postgres database on gdm, and the DuckDB fixture with its lexicon. So "every example validates" does not depend on the database.
- `ConceptQL::Diagram.render(..., counts: true)` gives the same JSON on repeated runs.
- No README example uses a hidden operator.
- The 4 JDE code links, the JDE test (diagram-test.js:255), AGENTS.md:54, jam-node.hbs:26 `{{@model.description}}`, boot_config_helper.rb:12, the 50 operators in JDE's committed metadata copy, and mcp_server.rb:127 (`ConceptQL.spec_path`).
- conceptql_spec_test.rb downloads README.md from GitHub main, unless `CONCEPTQL_SPEC_README` is set. It checks both directions between the published spec_ids and the README's `](#…-operator)` links. All 36 links resolve to headings today. Step 3 keeps this check. Recommendation: after step 4 it should also check the headings, because a generated table of contents makes the link check weaker.
- conceptql_spec's lib/ and exe/ have 25 rubocop offenses in 6 files, all safe to autocorrect. README/ holds 8.8 MB in 58 SVGs.
- The 2014-07-11 origin of doc/spec.md.cql (renamed from doc/spec.md in 2016), and the PDF date.
- The built gem is 160 KB today.

## What I did not test

- I did not run the full test suites, JDE's suites, Docker, GitHub CI or release.yml. A test of the release check needs a test tag on a fork or a staging repository.
- I did not draw any SVG, because the JDE renderer CLI was not run.
- I did not test libduckdb 2.0.0, Ruby 3.3, or Spark.
- I did not test production lexicons, which need read access to a production database.
- I did not test the size of the generated sections after step 4, because that generator does not exist yet.
