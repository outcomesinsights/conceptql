---
id: conceptql-mhm
title: One ConceptQL specification, built inside conceptql
status: resolved
type: decision
created_at: 2026-11-03T16:32:51.956574+00:00
updated_at: 2026-11-03T18:15:07.753876+00:00
resolved_at: 2026-11-03T18:15:07.753866+00:00
resolution: "Superseded on 2026-11-03 by conceptql-mdo (move the spec, operator documentation and example results into conceptql) and its children conceptql-mdo.1 to .4. They carry the adversarial review and Ryan's 15 rulings from conceptql_spec seed conceptql-spec-6sm. Changed since this seed: no history import, DuckDB gdm_wide results, new docs/spec/ directory, renderer split off."
---

Captured 2026-11-03 from a conceptql_spec session with Ryan. This seed records the decisions and the chain of reasoning that led to them, so that a later session can see why each step was taken. Ryan's confirmation of these decisions is recorded here. It is NOT permission to build. Beads come after an adversarial review of this seed.

## Decisions

1. RULED: there is one ConceptQL specification. On 2026-11-03 two copies existed: conceptql_spec's README (rewritten for 0.6.0 on 2026-11-03) and conceptql's doc/spec.md.cql -> doc/spec.md (forked from that README in 2016, edited for 0.6.0 on 2026-10-29..31). Each copy had content that the other lacked.
2. RULED: the conceptql_spec README text is the specification. conceptql's authored copy is eliminated.
3. RULED: operators get an explicit `hidden` flag (default false). invalid, from, numeric, dedup, sum and count are hidden. Every operator gets a category. Bead conceptql-voth.
4. RULED: numeric and sum are not public. Ryan: "we do not yet support numeric or sum in any meaningful way." The spec does not document numeric, sum, count or dedup.
5. PROPOSED, Ryan agreed in discussion: move the conceptql_spec repository into conceptql (for example `docs/spec/`, with its git history), so that one commit and one release carry an operator's code, its specification text, its examples and their results.
6. PROPOSED, Ryan agreed in discussion: store each operator's reference documentation in its operator class (child seed conceptql-mhm.1: operator documentation as code). Build the operator reference sections of the spec from `ConceptQL.metadata`.
7. PROPOSED, Ryan agreed in discussion: the spec build produces example results and line counts as data that the gem ships, so that the Jigsaw diagram editor (JDE) can show examples with result tables and diagrams in its operator help (child seed conceptql-mhm.2: example results and diagrams for JDE).

## How we got here (each step and why)

1. Two copies of the spec had diverged. Ryan ruled that the README is the spec.
2. conceptql cannot delete doc/spec.md. `ConceptQL.spec_path` returns it (commit ccf966b2). The gemspec allowlist, spec_path_test.rb and the release workflow require it. JDE serves it to agents over MCP, one resource per `## ` section (JDE seed jde-c0y.8, JDE docs/mcp.md). So the first plan was that conceptql ships a pinned copy of the README (bead conceptql-gmpe), as it does for vocabulary_formats.
3. Pre-slicing the spec into one file per section was rejected. JDE's slicer (McpServer::ConceptqlSpec) already splits the file, ignores `## ` inside code blocks, takes names from headings, and tests that each section is under 40,000 bytes. One file keeps the `](#anchor)` links between sections working, and conceptql's operator test scans one file.
4. Each operator's metadata `desc` repeated the README's one-sentence description: two texts for one purpose. JDE seed jde-c0y.5 records agents who found that descriptions did not match behavior. First plan: conceptql derives `desc` from the first paragraph of each operator section (bead conceptql-o29p).
5. Parsing markdown by convention is fragile. A formal structure (upstream, arguments, options, returns) was wanted. Next plan: a YAML file of operator prose in conceptql_spec, with a template that builds the reference sections, and conceptql reads the YAML instead of parsing markdown.
6. Examples help users understand operators, so examples went into the YAML too. Then result tables and diagrams were wanted in JDE's help.
7. At that point the cost of two repositories was clear: a copy step, a pinned commit, a conceptql test that downloads the README from GitHub, and three dependencies between beads in different repos that bd cannot record and someone must check by hand. 0.6.0 itself needed a separate synchronization of the spec after the release. So: move the spec into conceptql.
8. Inside one repository, the YAML file has no remaining advantage over the operator code. `desc` and option `instructions:` are already written in the operator classes. Putting the text beside the `option` call removes the need for a check that matches names between two files. JDE already loads the metadata.

## Alternatives rejected

- Delete doc/spec.md: breaks ConceptQL.spec_path and JDE's MCP resources.
- Ship the spec pre-sliced: breaks links between sections and creates a second format.
- Derive `desc` by parsing the first paragraph of each markdown section: depends on writers following a convention.
- A YAML file of operator prose: useful only while the spec and the code are in separate repositories.
- Store result tables in the YAML or in code: they would differ from what conceptql returns. Results are generated by the build.
- Publish numeric and sum so that the spec can document them: ruled out (decision 4).

## Facts measured on 2026-11-03

- Pinned conceptql f24667f0, data model gdm, ConceptQL::Database.new(nil): 125 operators registered, 119 published. The 119 use 36 spec_ids. vocabulary-operator covers 84 vocabulary operators. Each of the other 35 spec_ids belongs to exactly one operator. The README's operator links and the metadata's spec_ids match (36 = 36).
- Today an operator is published when it has a category (lib/conceptql/nodifier.rb:48). `desc` plays no part.
- 42 operator files set `desc` explicitly (a different grep found 43). 11 option `instructions:` texts exist in 6 files. JDE shows them as form help.
- The README's operator sections use labeled lists unevenly: 13 Upstream, 9 Arguments, 13 Options, 10 Returns across 35 sections.
- Both GitHub repositories are public. conceptql_spec has 117 commits since 2016-02-01.
- JDE links to github.com/outcomesinsights/conceptql_spec in 3 places (frontend/app/models/tree-node.js:388, routes/algorithms/new/diagram.js:52, routes/algorithms/algorithm/diagram.js:35).
- conceptql_spec builds its README with Postgres test data in Docker (`just readme`, lib/knitter.rb). conceptql's `just spec` runs spec examples on its DuckDB fixture. Two spec builds exist.
- conceptql_spec draws diagrams with JDE's renderer CLI (CONCEPTQL_DIAGRAM_CLI, frontend/lib/conceptql-diagram in JDE).

## Open questions

- Which test data produces the spec's results: DuckDB (no Docker) or Postgres. Some results may change and must be read.
- How conceptql's build gets JDE's diagram renderer without a path to a sibling checkout.
- How to merge conceptql_spec's history (subtree merge into docs/spec/ or similar), and what the old repository keeps (a README with a link, then archive).
- What happens to the 3 JDE links and to conceptql's spec test.
- Whether the gem ships the rendered spec as doc/spec.md (spec_path) from the new location, and whether the SVG diagrams ship.
- Whether `desc` and `instructions:` are plain text or markdown. JDE shows them as tooltips and form help.
- Unruled: delete conceptql's doc/"ConceptQL Specification (alpha).pdf" and doc/diagram_0.png (both last changed 2014-09-04). The recommendation is to delete both.

## Beads that this changes

- conceptql_spec-vvf and its children vvf.1 to vvf.5 (port content, heading levels, operator check, conceptql bump, old files): reshape after the move. The content port (vvf.1) still matters, because doc/spec.md.cql has content that the README lacks. Its notes record the numeric/sum ruling.
- conceptql-gmpe (ship a pinned copy of the README): replaced by the move.
- conceptql-o29p (derive desc from the spec): replaced by operator documentation as code.
- conceptql-voth (hidden flag): unchanged.
- conceptql_spec-vj2, -oa9, -201 (knitter cache, --clean, mdl pin in CI): may disappear with the conceptql_spec build.
