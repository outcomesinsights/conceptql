---
id: conceptql-mhm.2
title: Example results and diagrams as shipped data for the Jigsaw diagram editor's operator help
status: resolved
type: idea
parent: conceptql-mhm
created_at: 2026-11-03T16:32:58.450037+00:00
updated_at: 2026-11-03T18:15:07.304883+00:00
resolved_at: 2026-11-03T18:15:07.304874+00:00
resolution: Superseded on 2026-11-03 by conceptql-mdo.3 (example results and diagram trees as build artifacts), which carries the reviewed deliberation and Ryan's rulings from conceptql_spec seed conceptql-spec-6sm.3.
---

Child of the seed "One ConceptQL specification, built inside conceptql". Captured 2026-11-03. Ryan agreed in discussion. Not yet permission to build.

## Proposal

Ryan expects that some part of the spec will be the documentation that the Jigsaw diagram editor (JDE) shows for each operator. Examples help users most, and the result tables and diagrams help explain them.

- The spec build runs each operator example (from the operator's `example` items) on the test data. It saves each example's result rows and the record and person counts on each diagram line as data (for example JSON) that the gem ships.
- JDE draws the diagram with its own renderer (frontend/lib/conceptql-diagram) from the statement and the counts. The gem does not need to ship images for JDE.
- JDE shows the result table from the shipped data. JDE must never run help examples on its own database, which holds real data.
- JDE selects an operator's help by `spec_id` or operator name. Today JDE only opens github.com/outcomesinsights/conceptql_spec#\<spec_id> (frontend/app/models/tree-node.js:388).
- Help from the installed gem describes the conceptql version that runs. The GitHub link shows main, which can differ.

## Why generated, not stored by hand

Result tables written by hand or stored in a source file would differ from what conceptql returns after a change. The build regenerates them, and a release ships the regenerated data with the code.

## Open points

- Which test data (DuckDB fixture or Postgres) produces the shipped results.
- Size of the shipped data, and whether to limit rows per example.
- A link inside help text to another operator should open that operator's help in JDE, not a GitHub page.
- JDE work belongs to JDE's own seeds and beads. Tell the JDE session when conceptql ships the data.
