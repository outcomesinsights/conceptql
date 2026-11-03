---
id: conceptql-q8n
title: 'Interim diagram images: without CONCEPTQL_DIAGRAM_CLI, should the spec build fail, skip only with an explicit --no-images flag and keep the committed images (recommended), or skip silently; and should stale counts in images be caught by a committed manifest of render-tree hashes (recommended), by drawing images without counts, or not at all?'
status: resolved
type: question
created_at: 2026-11-03T18:36:57.382258+00:00
updated_at: 2026-11-03T18:41:33.052978+00:00
resolved_at: 2026-11-03T18:41:33.052971+00:00
relationships:
  - target_id: conceptql-mdo
    rel_type: questions
    created_at: 2026-11-03T18:36:57.384769+00:00
---

RULED 2026-11-03 (Ryan): 'in the absence of a renderer, keeping existing images is preferred.' Without CONCEPTQL_DIAGRAM_CLI, the spec build keeps the committed images. It neither deletes them nor fails. Ryan did not rule on how stale counts in kept images are detected (a committed manifest of render-tree hashes was recommended).
