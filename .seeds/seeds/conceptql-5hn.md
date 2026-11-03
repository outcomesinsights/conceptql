---
id: conceptql-5hn
title: 'Where does the release staleness check of the example results run, given that release.yml cannot get the DuckDB fixture (ruled 2026-10-02) and fails only after the tag: a release.yml job, a step in just release-check, a run_tests.yml job that fails only on a version bump, or both of the last two (recommended)?'
status: resolved
type: question
created_at: 2026-11-03T18:36:56.883339+00:00
updated_at: 2026-11-03T18:41:32.677480+00:00
resolved_at: 2026-11-03T18:41:32.677473+00:00
relationships:
  - target_id: conceptql-mdo
    rel_type: questions
    created_at: 2026-11-03T18:36:56.885228+00:00
---

RULED 2026-11-03 (Ryan): 'I would like to catch desync between spec and conceptql locally before a release is pushed.' The check runs locally, before the release is pushed: a step in just release-check that rebuilds the spec and its example artifacts with no cache and fails on any difference. release.yml is not changed, and no run_tests.yml job is added. Not ruled: whether the pre-push hook also runs the check when a v\* tag is pushed, which would enforce it.
