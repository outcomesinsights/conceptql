---
id: conceptql-mdo.3
title: Example results and diagram trees as build artifacts at predictable paths, for the diagram editor's operator help
status: captured
type: decision
parent: conceptql-mdo
created_at: 2026-11-03T18:14:51.179198+00:00
updated_at: 2026-11-03T18:14:51.179198+00:00
tags:
  - spec
  - examples
  - jde
---

Child of the seed on moving the spec, operator documentation and example results into conceptql. Carried from conceptql_spec seed conceptql-spec-6sm.3 on 2026-11-03. Ryan ruled on the test data and on when staleness is checked.

## Proposal

Ryan expects some part of the spec to be the help that JDE shows for each operator. Examples help users most, and result tables and diagrams explain them.

- The spec build runs each operator's examples on the test data and saves, for each example, the result rows and the diagram tree with counts. conceptql already builds that tree: `ConceptQL::Diagram.render([statement], cdb:, counts: true)`, format conceptql-diagram/v1 (used today by conceptql_spec's lib/diagram_renderer.rb).
- The spec build writes this data as artifacts at predictable paths under docs/spec/ (for example one file per operator or per example). The gem ships them with a ConceptQL method that returns their location (see the child seed on the move for the gem checks). The API, MCP and the editor read them from there (ruled 2026-11-03, conceptql_spec question conceptql-spec-74c).
- JDE draws the diagram from the shipped tree and shows the shipped result table. JDE never runs a help example on its own database, which holds real data. Shipping the tree, not the statement, also keeps JDE from annotating against its production lexicon, which can give other warnings than the build did (first review, finding 9).
- JDE finds an operator's help by operator name or spec_id. Today JDE only opens github.com/outcomesinsights/conceptql_spec#\<spec_id>.

## Rulings

- Ruled: results come from conceptql's DuckDB fixture on gdm_wide, as JDE seed jde-c0y.8 already ruled. conceptql_spec's README today uses Postgres in Docker with the mutable tag outcomesinsights/misc:test_data.ignitor, which was moved to a new image at 14:23 UTC on 2026-11-03, after the README was generated. So today's README results cannot be reproduced, and some results will change in the move. Read every changed table. The vocabulary schema of the fixture must be named too.
- Ruled: staleness is checked at release. The release workflow rebuilds the results with no cache and fails on any difference. Between releases, main can hold stale results.

## Rules

- A missing count fails the build of shipped data. Today conceptql_spec's DiagramRenderer#tree catches every error, draws the diagram without counts and prints only a warning.
- An example used as help must return at least one row, or be marked as not for help. Today the SNF, hospice and place-of-service examples of conceptql_spec's README return no records.
- No new data exposure: the result tables show codes from synthetic SynPUF data, and the same tables are already public in the README. Keep the same columns.

## Open

- Size of the shipped data: default to the README's current limit of 10 result rows per example (conceptql_spec lib/knitter.rb), unless the implementer finds a reason to change it and records it.
- A link inside help text to another operator should open that operator's help in JDE.
- How JDE draws the diagram depends on the renderer decision (conceptql_spec seed conceptql-spec-dcn, a separate pursuit).
