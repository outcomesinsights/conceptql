---
id: conceptql-sn2
title: MultipleVocabularies also defines the ICD10 operator (ICD10CM + ICD10WHO), not only 'CPT or HCPCS'. When MultipleVocabularies is deprecated, what does 'ICD10' become?
status: resolved
type: question
created_at: 2026-10-14T19:22:28.938163+00:00
updated_at: 2026-10-14T20:41:13.389371+00:00
resolved_at: 2026-10-14T20:41:13.389361+00:00
relationships:
  - target_id: conceptql-8u6
    rel_type: questions
    created_at: 2026-10-14T19:22:28.940357+00:00
---

RULED (Ryan, 2026-10-14): "icd10 is an incorrect multiple vocabulary operator and I thought we had already said it needed to be purged immediately." The ICD10 row (ICD10CM + ICD10WHO) is removed from config/multiple_vocabularies.csv, so ["icd10", ...] is now an invalid operator. No earlier record of the purge ruling was found in conceptql beads, seeds or session history. The entry.rb remap of the WHO vocabulary ICD10 to the operator name icd10who stays, so "icd10" does not silently come back as a WHO-only operator.
