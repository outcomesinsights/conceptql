---
id: conceptql-mdo.1
title: Copy the spec into a new docs/spec/ without history, switch links in a safe order, and archive conceptql_spec
status: captured
type: decision
parent: conceptql-mdo
created_at: 2026-11-03T18:14:50.066549+00:00
updated_at: 2026-11-03T18:14:50.066549+00:00
tags:
  - spec
  - migration
---

Child of the seed on moving the spec, operator documentation and example results into conceptql. Carried from conceptql_spec seed conceptql-spec-6sm.1 on 2026-11-03. Ryan ruled: move WITHOUT history, archive the old repository.

## What moves, and how

- Copy the spec text of conceptql_spec's README.cql.md into a NEW docs/spec/ directory of conceptql with its own build (ruled 2026-11-03), with no git history. Name the source commit of conceptql_spec in the commit body.
- conceptql's current spec build (doc/spec.md.cql, doc/spec.md, doc/spec/\*.png, script/spec/, `just spec`) is removed. The new build may reuse its code.
- Do NOT bring: conceptql_spec's Gemfile and Gemfile.lock (they pin conceptql from GitHub, so a build with them would test the pinned gem, not the working tree), .beads/, .github/, dependabot.yml, mise.toml, .ruby-version, README.html, possibilities\*, prep_possibilities.sh, monitor_readme.sh.
- The spec build runs from conceptql's own bundle with the working-tree lib.
- The generated markdown goes through treefmt (mdformat) as the last step, as `just spec` does today. Without that, mdformat rewrites about 1,433 lines of today's README and fmt-check fails.
- Imported Ruby must pass conceptql's rubocop (25 offenses in the 6 files of conceptql_spec's lib/ and exe/, all autocorrectable), or be replaced by conceptql's own spec scripts.
- Keep one build. conceptql's knitter (script/spec/knit.rb) and conceptql_spec's knitter (lib/knitter.rb) do the same job.
- Move the still-relevant open beads of conceptql_spec into conceptql's tracker before the archive.

## Order of the switch (each step must finish before the next)

1. conceptql's test test/lib/conceptql/operators/conceptql_spec_test.rb reads the local spec instead of downloading raw.githubusercontent.com/outcomesinsights/conceptql_spec/main/README.md. Otherwise any change to the old README breaks conceptql CI.
2. JDE ships new links. JDE links to the old repository in 4 code sites (tree-node.js, and the diagram routes for algorithm, algorithm/edit and new), in one JDE test and in JDE's AGENTS.md. JDE work goes to JDE's session.
3. The old README stays complete and gets a banner that names the new location. The existing `#<spec_id>` anchors then keep working for deployed JDE and other readers. Then archive the repository.

Other links: conceptql README.md:9, and 4 links in outcomesinsights.github.io (two posts from 2023: the ConceptQL crash course and the algorithm library).

## What the gem ships

- ConceptQL.spec_path moves to the generated spec under docs/spec/ (ruled 2026-11-03). JDE's MCP slicer reads whatever spec_path returns. The gemspec allowlist, spec_path_test.rb and release.yml's installed-gem check move with it.
- JDE's slicer starts a resource at each `## ` heading, and its test requires each resource to be under 40,000 bytes (about 10,000 tokens, JDE seed jde-c0y.8). Today's README already has one 44,083-byte section by that rule. The generated spec must keep every `## ` section under the limit.
- The example data (child seed on example results) needs its own path and a ConceptQL method that returns it. spec_path_test.rb:17 allows only doc/spec.md under doc/ today, and release.yml:132 checks only config/, schemas/ and doc/spec.md. Both must cover the new files.
- Default: the gem does not ship the SVG images. conceptql_spec's README/ directory holds about 8.8 MB of SVGs. MCP readers do not need them, and the editor draws diagrams from the shipped diagram trees. The SVG files stay in the repository for GitHub readers.

## Interim diagram images (ruled 2026-11-03)

Until the renderer is decided (separate pursuit, conceptql_spec seed conceptql-spec-dcn), the docs/spec/ build draws diagram images with JDE's renderer from a local checkout when CONCEPTQL_DIAGRAM_CLI is set, as conceptql_spec does today. The images are committed. CI checks only the text and the data.

## Review findings from the first review that apply here (conceptql_spec docs/reviews/2026-11-03-spec-migration-seed-review.md)

- Finding 4 (history breaks lint): answered by the no-history ruling.
- Finding 5 (no place in the gem for results): above.
- Finding 6 (switch order and link count): above.
- Finding 10 (section size): above.
