---
id: conceptql-mdo
title: Move the ConceptQL spec, operator documentation and example results into conceptql
status: captured
type: decision
created_at: 2026-11-03T18:14:43.431733+00:00
updated_at: 2026-11-03T18:14:59.740641+00:00
tags:
  - spec
  - migration
  - metadata
  - jde
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
15. Delete conceptql's doc/'ConceptQL Specification (alpha).pdf' and doc/diagram_0.png, both last changed 2014-09-04 (conceptql_spec question conceptql-spec-8fv). Git history keeps them.

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
