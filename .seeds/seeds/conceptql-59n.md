---
id: conceptql-59n
title: 'After step 3, doc/ holds only metadata.md and implementation_notes.md and docs/ holds perf/ and spec/: move both files into docs/ and remove doc/ (recommended), or keep both directories?'
status: resolved
type: question
created_at: 2026-11-03T18:36:58.341471+00:00
updated_at: 2026-11-03T18:41:33.786947+00:00
resolved_at: 2026-11-03T18:41:33.786940+00:00
relationships:
  - target_id: conceptql-mdo
    rel_type: questions
    created_at: 2026-11-03T18:36:58.356063+00:00
---

RULED 2026-11-03 (Ryan): use the conventional name. The convention is docs/: 23 of the 24 outins repos with a documentation directory use docs/, conceptql is the only one with doc/, and YARD writes its generated output to doc/ by default. So step 3 moves doc/metadata.md and doc/implementation_notes.md into docs/ and removes doc/. It also fixes AGENTS.md:99 and cog.toml:2, which cite docs/ files that do not exist.
