---
id: conceptql-mdo.5
title: The spec check runs only in just release-check, and a committed manifest of diagram-tree hashes detects stale images
status: captured
type: decision
parent: conceptql-mdo
created_at: 2026-11-03T18:54:27.423077+00:00
updated_at: 2026-11-03T18:54:27.423077+00:00
tags:
  - spec
  - release
  - diagram
---

Child of conceptql-mdo (move the spec into conceptql). Captured 2026-11-03. Ryan accepted this proposal. It is a decision, not permission to build.

## Ruled: the spec check runs in `just release-check`, and the pre-push hook does not change

- Ryan wants a difference between the spec and the code caught locally, only while a release is prepared, not on every push (question conceptql-5hn).
- `just release-check` is step 1 of conceptql's release procedure (CLAUDE.md, "Releasing"). It runs only by hand. No hook, recipe or workflow calls it.
- The pre-push hook is gator's standard hook, the same in every repo (.githooks/pre-push, never edited here). It runs `just ci` at each pushed commit. A pushed tag runs the same recipe, and a commit that already passed is not re-run. The hook has no tag-only step.
- So a tag-only check would need a change to gator's fleet hook, and adding the check to `ci` would run it on every push. Neither is wanted.
- Decision: the spec rebuild with no cache, and the comparison, are steps of `just release-check`. The pre-push hook does not change.

## Ruled: a committed manifest detects stale diagram images

The problem (review finding 5, docs/reviews/2026-11-03-spec-migration-seeds-review.md):

- Each diagram image shows record counts on its lines. Its file name comes from the statement only.
- When a change alters an example's counts, the release check sees the new text and result tables. Without a renderer the build keeps the old image (question conceptql-q8n), and the old image still shows the old counts. No check sees it.

Decision:

- The build already makes each example's diagram tree with its counts (the shipped artifact of conceptql-mdo.3). That tree is what the renderer draws.
- When the build draws images, it also writes a committed manifest beside them: one line for each image, with the image name and the sha256 of the diagram tree it was drawn from.
- `just release-check` rebuilds the trees, which needs no renderer, and compares their hashes with the manifest. A mismatch fails and names each stale image, with the instruction to redraw with CONCEPTQL_DIAGRAM_CLI set.
- Between releases, images can be stale, as the results can (decision 09).
- The hash is of the tree's canonical JSON, the same rule as the artifact names (review finding 6), so it does not depend on the Ruby version.
