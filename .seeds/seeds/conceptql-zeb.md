---
id: conceptql-zeb
title: Let cpt and hcpcs also find their codes stored as CPT4_HCPCS, through a mapping
status: deferred
type: idea
created_at: 2026-11-05T14:05:18.588711+00:00
updated_at: 2026-11-05T14:05:29.920034+00:00
tags:
  - cpt
  - hcpcs
  - cpt4_hcpcs
  - vocabulary
  - mapping
  - deferred
---

IDEA (Ryan, 2026-11-05, relayed by the roobetl session roobetl-cd). NOT RULED FOR BUILD: Ryan deferred it.

Ryan's words, verbatim:

```
if we're worried that conceptql doesn't find cpt or hcpcs codes when they are stored in cpt4_hcpcs vocabs, we could create a mapping between those vocabs and the vocab operators for cpt and hcpcs could search and include the mapping, but I don't care to do that right this moment.
```

CONTEXT: bead conceptql-rpy3 (open bug, the known-issue record) says that the cpt and hcpcs operators return no rows on production data, because that data stores CPT-4 and HCPCS codes only as CPT4_HCPCS. Bead conceptql-k5ho (closed, merge cd61dad3) added a warning that names cpt_or_hcpcs. This idea would fix the result itself, not only warn.

THE IDEA: create a mapping from CPT4 and HCPCS concepts to their CPT4_HCPCS copies. Then cpt and hcpcs search their own vocabulary and also follow the mapping, so they find the CPT4_HCPCS rows too.

FACTS (from roobetl, 2026-11-05):

- CPT4_HCPCS has one row per code. Each row copies one CPT4 or HCPCS concept, with a new concept_id.
- 381 codes are in both CPT4 and HCPCS. Their CPT4_HCPCS row comes from the HCPCS row.
- CPT4_HCPCS has no concept_relationship rows, so no mapping exists today. ohdsi_supplemental_vocabs seed ohdsi-supplemental-vocabs-jd3 accepted that.
- Every current CPT4 and HCPCS code is in CPT4_HCPCS, except 152 OI-added HCPCS ambulance codes.

QUESTIONS TO SETTLE BEFORE ANY BUILD:

- Where does the mapping live: concept_relationship rows built upstream in ohdsi_supplemental_vocabs, or a join on concept_code inside conceptql? The codes are identical, so a code join may need no mapping table.
- The 381 shared codes have one CPT4_HCPCS row, copied from HCPCS. Should cpt find that row for a code that is also a CPT4 code?
- Today a vocabulary operator does not follow mappings to other vocabularies (the spec says so). This idea is an exception to that rule.
- Seed conceptql-1 records that in about a year cpt_or_hcpcs will use CPT4_HCPCS alone. Does that plan make this idea unnecessary?
