---
id: conceptql-k9w
title: "Which form should the reused-code warning take: (a) as built, every reused code with all names; (b) codes only; (c) only when the data's dates cover more than one meaning; plus (d) dates on the OHDSI source?"
status: resolved
type: question
created_at: 2026-10-29T21:08:26.826214+00:00
updated_at: 2026-10-31T03:19:52.911959+00:00
resolved_at: 2026-10-31T03:19:52.911949+00:00
resolution: 'Ruled 2026-10-30: keep the warning as built; ms_drg and cms_drg settle the DRG case.'
relationships:
  - target_id: conceptql-lp3
    rel_type: questions
    created_at: 2026-10-29T21:08:26.828806+00:00
---

RULED 2026-10-30 (Ryan): "Keep it as built". The reused-code warning stays as it is for drg and the other vocabularies; ms_drg and cms_drg (bead conceptql-alw, seed conceptql-7p3) need none, because each fixes the DRG meaning by event date. Fact found the same day: ohdsi_supplemental_vocabs bead ohdsi_supplemental_vocabs-yyg (open) says HCPCS "AC", the one other reused code in the test vocabulary, is a supplemental row that collides with an Athena code, not a code HCPCS reused.
