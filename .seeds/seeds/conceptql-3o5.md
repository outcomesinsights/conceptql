---
id: conceptql-3o5
title: 'Diagram rendering converts annotated statements into a separate node tree: could the renderer walk the annotated statement directly?'
status: captured
type: question
created_at: 2026-11-10T15:48:19.900845+00:00
updated_at: 2026-11-10T15:48:19.900845+00:00
---

## The question

Why does diagram rendering convert a ConceptQL statement into a separate node tree before it draws? Could the renderer walk the annotated statement directly?

Ryan, transcribed speech, 2026-11-10 (in the conceptql-3z1 discussion): "the diagram renderer seems to take a conceptual statement and restructure it in a way that it finds more acceptable for rendering the SVG. And that's bothered me all along ... we're building a tree and ConceptQL statements, particularly even when annotated, are coming out as a tree. So I'm not sure why it's not possible to just walk the tree and render it directly."

## What happens today (checked 2026-11-10, conceptql main 976a1195)

In conceptql:

- `ConceptQL::Diagram.render` (lib/conceptql/diagram.rb, 243 lines) calls `Query#annotate`, then converts each operator into a node: `{name, base, humanName, vocabularyId, outputTypes, values, parameters, children, errors, warnings, counts}`. This is the `conceptql-diagram/v1` format. It does not use scope_annotate.
- `ConceptQL::DiagramRenderer` draws that node tree. It is a Ruby port of the JDE JavaScript renderer (js/lib/conceptql-diagram). Its tests require the Ruby output to match the JavaScript output for 70 reference fixtures.

In JDE (the diagram page):

- The editor keeps its own tree (StatementDraft). PageDiagram turns it into ConceptQL statements with each operator's id set to its node path ("0.1"), runs scope_annotate, and copies the errors, warnings and counts back onto the editor's nodes by path. Then it calls DiagramRenderer.render_app.

## Why the node tree exists (as far as the code shows)

1. The renderer was written in JavaScript for the Ember editor's own tree, not for ConceptQL statements. The Ruby port kept its input format so that it matches the JavaScript output exactly.
2. A ConceptQL operator is a positional array that mixes values, upstreams and an options hash. Binary operators keep their two inputs in the `left` and `right` options. The renderer needs named children in drawing order, and values separate from parameters.

## Directions (not ruled)

1. The renderer reads the annotated statement directly. The conversion code moves into the renderer; it does not disappear. The JavaScript references then no longer apply as they are.
2. Keep the node tree, but make it the only intermediate: JDE builds its diagram from `annotate` output instead of its own tree plus scope_annotate.
3. Leave it.

Related: conceptql-3z1 (scope_annotate loses data when two operators share a name).
