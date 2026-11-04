---
id: conceptql-24x
title: 'Use the moved diagram renderer in conceptql: spec images without JDE, and a CLI command?'
status: captured
type: question
created_at: 2026-11-04T03:09:26.587861+00:00
updated_at: 2026-11-04T03:09:26.587861+00:00
tags:
  - diagram
  - spec
---

When the renderer is in conceptql (bead conceptql-tf8u, ruled 2026-11-03), conceptql itself can use it. Nothing here is ruled. The move does not depend on any of it.

## What the spec build does today

`just spec` draws the images in docs/spec/images/ only when CONCEPTQL_DIAGRAM_CLI points at JDE's JavaScript CLI (frontend/lib/conceptql-diagram/cli/bin/conceptql-diagram.js). Without it the committed images stay. `just spec-check` (release-check only) cannot redraw images. It compares tree hashes with docs/spec/images/manifest.tsv and names each stale image. So a release with a stale image needs a JDE checkout and node.

## Options

(a) Draw the spec images with ConceptQL::DiagramRenderer.render_static in the spec build. CONCEPTQL_DIAGRAM_CLI goes away. spec-check could redraw and compare the images, not only the tree hashes. Cost: `just spec` and `just spec-check` need resvg 0.33.0 (render_static needs it for every viewBox). The images become the Ruby renderer's output, which the match rule says equals the JS output, so the committed images should not change. Check that before switching.

(b) Add a CLI command (for example `conceptql render_svg <file>` and `render_png`) next to the existing render_json. Users of the gem could draw a statement without JDE. Cost: a resvg requirement on a command line tool, and more surface to keep.

(c) Neither for now. The renderer serves JDE only.

Recommendation: (a) after the move, because it removes the only dependency of conceptql's release on a JDE checkout. (b) only if someone asks for it.
