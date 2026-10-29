---
id: conceptql-lp3
title: How noisy may the reused-code warning be? 60% of DRG codes in use have more than one meaning
status: captured
type: question
created_at: 2026-10-29T21:08:16.452855+00:00
updated_at: 2026-10-29T21:08:26.830696+00:00
tags:
  - conceptql-ttk
  - validation
  - warnings
relationships:
  - target_id: conceptql-k9w
    rel_type: questioned-by
    created_at: 2026-10-29T21:08:26.828806+00:00
---

## Context

Bead conceptql-ttk added the annotate warning "code(s) with more than one meaning" (commit on branch conceptql-ttk/reused-code-warning, 2026-10-29). Ryan ruled that analyze warns about codes that had a different meaning in another period, and left the rule and the wording to the implementer. Rule built: a selected code warns when the vocabulary has more than one distinct name for it, ignoring case and spacing. Each item lists the code and all its names, without dates:

```
["code(s) with more than one meaning",
 "410: Biliary tract proc except only cholecyst w or w/o c.d.e. w/o CC/MCC | Chemotherapy without Acute Leukemia As Secondary Diagnosis"]
```

## Measurements (2026-10-29, DuckDB test fixture vocabulary, JDE survey statement list)

- 529 of 895 DRG codes have more than one name, and so does 1 HCPCS code (AC: a placeholder name, then a real one). ICD, CPT and NDC codes have one name each.
- Every DRG name change is a change of meaning. The highest word overlap (Jaccard) between an old and a new name is 0.33 (DRG 519 and 520: cervical spinal fusion, then back procedures except spinal fusion). 530 of 531 changes fall on the 2007-10-01 MS-DRG renumbering.
- DRG 104 to 107 have two different names in overlapping periods. For example, 107 means "Coronary Bypass without Cardiac Catheter" and "Coronary Bypass with Cardiac Catheter" between 1998 and 2005. A rule limited to separate periods would miss them.
- The GDM vocabulary source keeps the names (464 DRG codes with more than one) but has no dates.
- Production impact: 29 of the 1,259 current algorithms use the drg operator. 10 of them would get the warning. 294 of their 490 DRG codes (60%) have more than one name. All 10 are Drafts.

```
chronic_pulmonary_disease_elixhause (Draft): 5 of 5 DRG codes
congestive_heart_failure_elixhauser (Draft): 78 of 78 DRG codes
inpatient_chemotherapy (Draft): 2 of 2 DRG codes
solid_tumor_from_elixhauser (Draft): 17 of 56 DRG codes
metastatic_cancer_from_elixhauser (Draft): 17 of 56 DRG codes
liver_disease_from_elixhauser (Draft): 15 of 15 DRG codes
rheumatoid_arthritis_elixhauser (Draft): 3 of 3 DRG codes
neurological_disorders_elixhauser (Draft): 75 of 75 DRG codes
valvular_disease_from_elixhauser (Draft): 78 of 78 DRG codes
stem_cell_bone_marrow_transplant (Draft): 4 of 4 DRG codes
```

The Elixhauser algorithms use MS-DRG codes (the post-2007 meanings). On data from after 2007 their warning is noise. On SEER-Medicare data, which starts before 2007, it is correct: those codes then also select the old meanings.

## Why no dates

Dates exist only in the OHDSI vocabulary source. The statement tests share one expected file for the OHDSI and GDM sources (test/results/gdm), and place_of_service_filter/anno_3 selects DRG 001. A warning with dates would differ between the two sources, so that test would need per-source expected files or a different code.

## Options (not ruled)

- (a) Keep the warning as built: every reused code with all its names. Correct, but an Elixhauser algorithm gets one warning with 75-78 long items.
- (b) Short form, like "unknown code(s)": list only the codes. Short, but the user must look up the meanings.
- (c) Warn only when the data's date range covers more than one meaning of the code. The quietest and most exact option. It needs each meaning's dates (the OHDSI source only) and a date-range query on the data during analyze.
- (d) Add the dates of each meaning on the OHDSI source, with any of the above.

Recommendation: (c) with (d), because 60% of the DRG codes in use would otherwise warn, and most of those warnings are noise on post-2007 data. Until Ryan rules, (a) stays as built.
