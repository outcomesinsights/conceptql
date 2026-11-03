---
id: conceptql-mdo
title: Move the ConceptQL spec, operator documentation and example results into conceptql
status: captured
type: decision
created_at: 2026-11-03T18:14:43.431733+00:00
updated_at: 2026-11-03T19:04:56.563322+00:00
tags:
  - spec
  - migration
  - metadata
  - jde
relationships:
  - target_id: conceptql-5hn
    rel_type: questioned-by
    created_at: 2026-11-03T18:36:56.885228+00:00
  - target_id: conceptql-q8n
    rel_type: questioned-by
    created_at: 2026-11-03T18:36:57.384769+00:00
  - target_id: conceptql-3i7
    rel_type: questioned-by
    created_at: 2026-11-03T18:36:57.864536+00:00
  - target_id: conceptql-59n
    rel_type: questioned-by
    created_at: 2026-11-03T18:36:58.356063+00:00
  - target_id: conceptql-ivi
    rel_type: questioned-by
    created_at: 2026-11-03T18:36:58.899738+00:00
---

Captured 2026-11-03 in conceptql from a handoff by the conceptql_spec session. That session deliberated with Ryan on 2026-11-03 and recorded the result in conceptql_spec seeds conceptql-spec-6sm (with children 6sm.1, 6sm.2, 6sm.3, 6sm.5 and the answered questions conceptql-spec-74c and conceptql-spec-8fv), merged to conceptql_spec main at commit 40fcafc. This seed and its four children carry that deliberation into conceptql, so that conceptql has one current record. They supersede conceptql seeds conceptql-mhm, conceptql-mhm.1 and conceptql-mhm.2, which predate the review and the rulings.

Ryan's rulings recorded here are decisions. They are NOT permission to build. Beads come after Ryan discusses the adversarial review of these seeds.

## Goal

One source for everything that describes ConceptQL, released with the code that it describes: the specification text, each operator's reference documentation and examples, the example results, and the diagrams. The Jigsaw diagram editor (JDE) shows operator help from the installed gem, so the help matches the conceptql version that runs.

## Decisions (ruled by Ryan on 2026-11-03)

01. There is one ConceptQL specification. The text of conceptql_spec's README is the specification. conceptql's own authored copy (doc/spec.md.cql) is eliminated.
02. numeric and sum are not public. Ryan: "We do not yet support numeric or sum in any meaningful way." The spec does not document numeric, sum, count or dedup.
03. Operators get an explicit `hidden` flag that defaults to false. invalid, from, numeric, dedup, sum and count are hidden. Every operator gets a category. (Bead conceptql-voth. Child seed on the hidden flag.)
04. The unused `hidden` column of config/vocabularies.csv is deleted, so the word has one meaning.
05. The spec moves into the conceptql repository WITHOUT its git history. The conceptql_spec repository is archived and keeps its history readable.
06. Each operator's reference documentation lives in its operator class (child seed on operator documentation as code).
07. Each option has two texts: `instructions:` stays the form hint for typing a value, and a new text says what the option does.
08. The spec's example results come from conceptql's DuckDB fixture on gdm_wide. This agrees with the earlier JDE ruling in JDE seed jde-c0y.8.
09. Shipped example results are checked for staleness at release, not at every push. Between releases, main can hold stale results. Ryan accepted that.
10. A fix to help text reaches JDE only after a conceptql release. Accepted.
11. The diagram renderer and the move of the spec are separate pursuits. The move does not wait for the renderer decision. The renderer deliberation is conceptql_spec seed conceptql-spec-dcn (child dcn.1, Ryan's idea of one Ruby renderer, and questions conceptql-spec-3pr and conceptql-spec-9je). Ryan suggested that the JDE session (repository jigsaw-diagram-editor, which holds the current renderer) may lead it. It is not part of this deliberation.
12. The spec lives in a NEW docs/spec/ directory of conceptql, with its own build. conceptql's current spec build is removed: doc/spec.md.cql, doc/spec.md, doc/spec/\*.png, script/spec/ and the `just spec` recipe. The new build may reuse code from script/spec/, such as its DuckDB harness. ConceptQL.spec_path then returns the generated spec under docs/spec/. The gemspec allowlist, test/lib/conceptql/spec_path_test.rb and release.yml's installed-gem check change with it. JDE's MCP slicer reads whatever spec_path returns.
13. Until the renderer is decided, the build draws diagram images with JDE's renderer from a local checkout when CONCEPTQL_DIAGRAM_CLI is set, as conceptql_spec does today. The images are committed. CI checks only the text and the data. Nothing becomes worse than today.
14. The operator code is the source of all operator metadata, examples included (conceptql_spec question conceptql-spec-74c). An example's title and statement are written in the operator class and appear in ConceptQL.metadata. Results and diagram data are never written in code: the spec build generates them as artifacts at predictable paths, which the API, MCP and the editor read. Whether the editor puts examples into the metadata that every page carries is the editor's choice.
15. Delete conceptql's doc/'ConceptQL Specification (alpha).pdf' and doc/diagram_0.png. The PDF last changed on 2014-09-04 (befeb7de), and diagram_0.png on 2014-07-11 (f53c6060, the initial commit) (conceptql_spec question conceptql-spec-8fv). Git history keeps them.

## How the deliberation went (each step and why)

1. Two copies of the spec had diverged. conceptql's copy (doc/spec.md.cql) dates from conceptql's first commit (2014-07-11). conceptql_spec was created from it on 2016-02-01. Agents updated both for 0.6.0, separately: conceptql's copy on 2026-10-29..31, the README on 2026-11-03. Ryan ruled that the README text is the spec.
2. conceptql could not simply delete doc/spec.md. ConceptQL.spec_path returns it, the gemspec and the release workflow require it, and JDE serves it to agents over MCP, one resource per `## ` section. The first plan was to ship a pinned copy of the README (bead conceptql-gmpe).
3. Pre-sliced spec files were rejected. JDE's slicer already splits one file, and one file keeps the links between sections working.
4. Operator `desc` repeated the README's descriptions. The plan became to derive desc from the README (bead conceptql-o29p).
5. Parsing markdown by convention is fragile, so a YAML file of operator text was proposed. Examples went into it, and then result tables and diagrams were wanted in JDE's help.
6. Two repositories needed a copy step, a pinned commit, and three dependencies between beads in different repositories that bd cannot record. So the spec moves into conceptql.
7. In one repository, a YAML file has no advantage over text in the operator classes, where desc and instructions already live.
8. An adversarial review (conceptql_spec docs/reviews/2026-11-03-spec-migration-seed-review.md, 14 findings) reviewed the first version of this deliberation (conceptql-mhm and its children). It found that the metadata's upstream counts are wrong, that the renderer is in a private repository, that the test data was not pinned, that importing the history breaks conceptql's lint, and more. Ryan ruled on the points listed above. Each child seed records the findings that apply to it.
9. Diagram rendering: JDE's session recommended moving the JavaScript renderer into conceptql. Ryan proposed that a Ruby renderer draw every diagram on the server, and that the browser animate from the old drawing to the new one. Ryan then split the renderer off as a separate pursuit (decision 11).

## Alternatives rejected

- Delete doc/spec.md: breaks spec_path and JDE's MCP resources.
- Ship the spec pre-sliced: breaks links between sections.
- Derive desc by parsing markdown: depends on a convention.
- A YAML file of operator text: useful only while the spec and the code are in separate repositories.
- Store result tables by hand: they would differ from what conceptql returns.
- Import the spec's history: 86 of conceptql_spec's 117 commits are not conventional commits, so conceptql's `cog check` fails until the next tag.
- Publish numeric and sum: ruled out.
- A Ruby renderer in addition to the JavaScript renderer: two renderers of one picture (JDE seed jde-uo9 chose one renderer).
- Keep the renderer only in JDE: the public spec's images could not be rebuilt from public code.

## Bead order (proposed during tending, Ryan did not object)

1. Fix ConceptQL.metadata's upstream counts, with a test against validation (child seed on operator documentation as code).
2. The hidden flag and the deletion of the vocabularies.csv hidden column (bead conceptql-voth, child seed on the hidden flag).
3. Create docs/spec/ with the spec text of conceptql_spec's README.cql.md, its build on the DuckDB fixture, and the interim images. Add the content that only conceptql's doc/spec.md.cql has (the list in conceptql_spec bead conceptql_spec-vvf.1, minus the Values section that decision 2 drops). Remove conceptql's old spec build and the 2014 files. Move spec_path. conceptql's operator test reads the local spec.
4. Operator documentation in the operator classes, and generated reference sections (child seed on operator documentation as code).
5. Example results and diagram trees as artifacts at predictable paths, with a ConceptQL method, the gem allowlist and the release check (child seed on example results).
6. JDE changes its links (JDE's session).
7. The banner on conceptql_spec's README, then archive conceptql_spec (child seed on the move).

## Beads this changes (leave them unchanged until Ryan approves beads)

- conceptql-gmpe (ship a pinned README copy) and conceptql-o29p (derive desc from the README): superseded by the move and by documentation as code.
- conceptql-voth (hidden flag): add decision 4 (delete the CSV column). Its acceptance (the same 119 names and 36 spec_ids) stays.
- conceptql_spec beads conceptql_spec-vvf and its children vvf.1 to vvf.5 close as superseded when the conceptql beads exist. vvf.1's list of content to port goes into the conceptql bead for step 3.
- conceptql_spec beads conceptql_spec-vj2, -oa9 and -201 (knitter cache, --clean, mdl pin) disappear with conceptql_spec's build. Move any that still apply.

## Review of these seeds

An adversarial review of this seed and its children against conceptql's code follows. Its report is docs/reviews/2026-11-03-spec-migration-seeds-review.md. Its findings are recorded in the seeds below this line.

## Children

- conceptql-mdo.1: copy the spec into docs/spec/ without history, the switch order, archive conceptql_spec.
- conceptql-mdo.2: operator documentation as code, and the prerequisite fix of the upstream counts.
- conceptql-mdo.3: example results and diagram trees as build artifacts.
- conceptql-mdo.4: the hidden flag and the deletion of the vocabularies.csv hidden column.

## REVIEW 2026-11-03 (adversarial review of these seeds)

Report: docs/reviews/2026-11-03-spec-migration-seeds-review.md (16 findings, checked against conceptql HEAD 44be502d and the pinned DuckDB fixture with libduckdb 1.5.6). The main session spot-checked findings 1, 2, 3, 8, 10 and 13 and confirmed them. False facts were corrected in place in each seed. Each child seed records the findings that apply to it.

Not ruled. These findings need Ryan's decision (each is also a question attached to the seed it concerns):

- Finding 1 (decision 09, where the release staleness check runs). release.yml:15-17 records a 2026-10-02 ruling that keeps the 2 GB fixture and the test suite out of release.yml. Its jobs install no bundle, no libduckdb and no treefmt. A failure there also comes after the public tag exists. Options: (a) a new release.yml job, as decision 09 says; (b) a step in `just release-check`, which runs locally before the version bump; (c) a run_tests.yml job that rebuilds and compares, and fails only on a commit that changes lib/conceptql/version.rb. The reviewer recommends (b) plus (c).
- Finding 5 (decision 13, interim images). Today the renderer raises when CONCEPTQL_DIAGRAM_CLI is not set, and conceptql_spec's knitter deletes every image at the start of a build. The images show counts but are named by the statement only, so stale counts are not visible. Two choices: what the build does without the CLI, and how stale images are detected.
- Finding 7 (decisions 05 and 11, step 7). The renderer seeds conceptql-spec-dcn, dcn.1, 3pr and 9je stay open in conceptql_spec, and an archived repository is read-only. conceptql_spec main is also 6 commits ahead of origin, including the seeds and the review that this seed cites.
- Finding 14 (decision 12). After step 3, doc/ holds only metadata.md and implementation_notes.md, and docs/ holds perf/ and spec/.
- Finding 16 (low). Public conceptql seeds and the review report name files in the private JDE repository. Seeds already on origin/main do the same. No secrets were found.

Proposed changes to the bead order (fact fixes, not ruled):

- Step 1 also breaks JDE's ember_operator_metadata_spec: JDE's committed metadata copy holds the wrong upstream counts of 10 operators. Tell JDE's session when step 1 merges (finding 9).
- Step 3 also: removes test/lib/conceptql/spec_diagram_draw_test.rb and spec_diagram_name_test.rb, which require script/spec/ and run in `just ci`; updates CLAUDE.md:9 and the justfile comments at lines 118-125; drops the knitter cache and its `.gitignore:27` rule; carries conceptql_spec bead conceptql_spec-vvf.2 (heading levels), which no step owned; writes an empty result as plain text, not a fence; adds a conceptql test that splits the spec with JDE's rule and checks balanced fences and the 40,000-byte limit; rewrites Appendix D (it sends public readers to the private JDE); and updates README.md:9 (findings 3, 8, 12, 15). Removing `just spec` drops no gate check, because `ci` does not run it (justfile:304).
- A new step between 5 and 6: release conceptql. JDE pins `~> 0.6.0` (JDE Gemfile:40), and decision 10 makes a release the only route for help to reach JDE. The release waits until the round is done (finding 11).
- Each step that changes the public surface writes a CHANGELOG entry under \[Unreleased\]: spec_path moves, upstream counts change, new metadata keys, a new path method, Entry#hidden? and Entry#visible? removed (finding 11).
- Step 7 also: push conceptql_spec main before the archive, and change the 4 outcomesinsights.github.io links (findings 7 and 15).

## Rulings on the review (Ryan, 2026-11-03)

16. Staleness check (question conceptql-5hn, refines decision 09): "I would like to catch desync between spec and conceptql locally before a release is pushed." The check is a step in `just release-check`. It rebuilds the spec and its example artifacts with no cache and fails on any difference. release.yml is not changed. Not ruled: whether the pre-push hook also runs the check when a v\* tag is pushed.
17. Interim images (question conceptql-q8n, refines decision 13): "in the absence of a renderer, keeping existing images is preferred." Without CONCEPTQL_DIAGRAM_CLI, the build keeps the committed images. It neither deletes them nor fails. Not ruled: how stale counts in kept images are detected.
18. Renderer seeds and the archive (question conceptql-3i7): "Those are going to be taken care of. Keep your eyes on your own repo." The renderer seeds, the push of conceptql_spec main and the archive itself belong to conceptql_spec. The proposed change to step 7 ("push conceptql_spec main before the archive") is withdrawn from conceptql's plan.
19. Directory name (question conceptql-59n): use the convention, which is docs/. 23 of the 24 outins repos with a documentation directory use docs/, and YARD writes generated output to doc/ by default. Step 3 moves doc/metadata.md and doc/implementation_notes.md into docs/ and removes doc/.
20. Private JDE names in public seeds (question conceptql-ivi): accepted.

## RULED 2026-11-03 (Ryan): the open points of rulings 16 and 17

- conceptql-mdo.5 records both. The spec check runs only in `just release-check`, and the pre-push hook does not change (this closes the open point of ruling 16). A committed manifest of diagram-tree hashes, checked by `just release-check`, detects stale images (this closes the open point of ruling 17).
- Children list: add conceptql-mdo.5.

## RULED 2026-11-03 (Ryan, while converting to beads)

21. Spec file names: source docs/spec/README.cql.md, output docs/spec/README.md, built by `just spec`. GitHub shows the spec when someone opens docs/spec/.
22. Appendix E (the quick-reference table) is generated from desc, one row per published spec_id.
23. Example artifacts: one JSON file per spec_id, docs/spec/examples/\<spec_id>.json. ConceptQL.spec_examples_path returns the directory.

## Beads (created 2026-11-03)

Epic conceptql-jwsv holds the conceptql work: conceptql-jwsv.1 (upstream counts), conceptql-voth (hidden flag and the CSV column), conceptql-jwsv.2 (docs/spec/ build and the switch), conceptql-jwsv.3 (doc/ into docs/), conceptql-jwsv.4 (content port), conceptql-jwsv.5 (spec-check in release-check), conceptql-jwsv.6 (DSL), conceptql-jwsv.7 to .9 (operator texts in three batches), conceptql-jwsv.10 (generated sections and Appendix E), conceptql-jwsv.11 (example JSON files). conceptql-gmpe and conceptql-o29p are closed as superseded. No bead makes a release: Ryan releases when the round is complete. JDE's link changes and the archive of conceptql_spec are not conceptql beads.
