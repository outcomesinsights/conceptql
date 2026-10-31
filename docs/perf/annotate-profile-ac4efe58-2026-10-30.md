# Profile of annotate on algorithm ac4efe58, 2026-10-30 (seed conceptql-643)

**Answer:** On the code of 2026-10-30, annotate with counts on `ac4efe58` took
about 2.8 s, not the 62 s that the survey measured on conceptql 0.4.1. The new
one-query counting removed the per-operator repetition. Of the remaining time,
DuckDB query planning was 70-75%. The forced per-operator path still took 78-83
s, and `Scope#sort_extracted_ctes` was 29.4 s of that.

**The logs of this profile are lost.** They were in the worktree
`.claude/worktrees/profile-643/claude_stuff/`, and they were deleted when that
worktree was removed. The seeds `conceptql-643` (section PROFILE) and
`conceptql-ktc` are the only record. This report repeats their numbers.

## Question

The survey (`algorithm-survey-2026-10-29.md`) found that annotate on
`ac4efe58` spent about 50 s in Ruby. It suspected `Scope#sort_extracted_ctes`
but did not show it. Ryan ruled on 2026-10-30: profile annotate on
`ac4efe58` first, and change no code before the profile.

## Setup

- **Host:** titan (2 x Xeon E5-2690 v2, 40 logical CPUs).
- **Code measured:** main at `8a1aaa85` (2026-10-30 04:51). It includes
  one-query counting (`741f84b4`), which is not in any release.
- **Statement:** production algorithm `ac4efe58` (Draft, 111 operators in the
  survey's count, 143 countable operators in the one-query statement, 23,415
  bytes of JSON).
- **Data set:** native_sample_5000, the SEER-Medicare sample (DuckDB,
  gdm_wide, 5,000 patients, 7.8M observation rows).
- **Software:** DuckDB 1.5.6. Ruby 3.4.8 (inferred: the profile used
  stackprof, and the bead conceptql-ahg5 bench loads stackprof from the Ruby
  3.4.8 install). sequel 5.109.0, duckdb gem 2.0.0.1, sequel-duckdb 0.4.2.
- **titan-lock:** held. The lock log shows 10 `perf` iterations named
  `profile-643` from 05:02 to 05:14, all with rc=0. None was disturbed by a
  test suite.
- **Other load (`below`):** machine CPU use inside those iterations had a
  median of 65%, a 90th percentile of 73% and a maximum of 80%. The profile
  itself used at most 8 DuckDB threads (20%). So about 17 other logical CPUs were busy
  (other Ruby processes, Java and Postgres). **The absolute times are noisy
  and probably inflated.** The seed `conceptql-ktc` says the same.

## Method

The script `p643.rb` is gone. The lock log shows that it ran in four modes:
`wall`, `instr`, `stackprof` and `explain`. From the seed, these timed
annotate, split its time by instrumenting conceptql methods, sampled CPU with
stackprof, and profiled the plain query and the count statement in DuckDB. It
ran annotate on the normal one-query path, and on the per-operator path with
one-query counting forced off.

## Results

One-query path (the normal path on DuckDB and Postgres):

| measure                     | value                                             |
| --------------------------- | ------------------------------------------------- |
| annotate with counts, wall  | 2.84 s, 3.39 s, 2.76 s                            |
| count statement             | one statement, 268 KB, 265 CTEs, 100 IN lists     |
| DuckDB execution            | 1.8-1.95 s (count statement 1.56-1.74 s)          |
| `with_ctes` (2 root builds) | 1.1 s, of which `sort_extracted_ctes` 0.61-0.64 s |
| literalize                  | 0.2 s                                             |
| `Dataset#sql` calls         | 851 top-level, 33 MB of SQL                       |

DuckDB profile of the plain query and the count statement:

| statement       | planning    | total latency | size                                            |
| --------------- | ----------- | ------------- | ----------------------------------------------- |
| plain query     | 1.05-1.44 s | 1.41-1.85 s   | 236 KB, 264 CTEs, 99 IN lists, 1,306 plan nodes |
| count statement | 1.78-2.00 s | 2.55-2.84 s   | 268 KB, 265 CTEs                                |

Per-operator path (forced; Spark, temp tables and uncountable statements still
use it):

| measure                    | value                             |
| -------------------------- | --------------------------------- |
| annotate with counts, wall | 78-83 s                           |
| `sort_extracted_ctes`      | 29.4 s                            |
| `Dataset#sql` calls        | 53,209 top-level, 2,976 MB of SQL |

Hot spots in the per-operator stackprof samples:

- `scope.rb:357`, `filter_map` with `other != name`: CTE names were
  `Sequel.identifier` objects, so each comparison ran Sequel's
  `Expression#==`. 46.6% of samples.
- `scope.rb:363`, `Array#-` on the same objects: 12-14%.
- `Operator#evaluate` is not memoized, so `OneQueryCounts#build_dataset`
  evaluates the tree twice (`one_query_counts.rb:68` and `:73`).
- `gdm.rb:119` `source_vocabulary_ids` recomputed its value on every call.

## Conclusion and decisions

- On DuckDB and Postgres the 62 s is gone, because of one-query counting.
  The CTE sort matters only where counting falls back to one query per
  operator, mainly Spark.
- DuckDB planning is the largest remaining cost. Ryan ruled "Do the
  concept-list idea" (seed `conceptql-ktc`), which became bead `conceptql-6cz`
  (`concept-lists-merged-ctes-2026-10-30.md`).
- Ryan ruled "Fix the hot spot" for the CTE sort. That became bead
  `conceptql-ahg5` (`per-operator-annotate-2026-10-30.md`).

## Later shown stale

The `sort_extracted_ctes` hot lines above were correct for `8a1aaa85`. Bead
`conceptql-6cz` (`c7a5eeb4`) rewrote the sort to compare quoted names as
strings a few hours after this profile. So when bead `conceptql-ahg5` started,
the two hot lines were already gone. The per-operator time on later code is in
`per-operator-annotate-2026-10-30.md` (about 36 s before that bead, 30 s
after).

## Sources

- Seed `conceptql-643`, sections PROFILE, RULED and RESULT.
- Seed `conceptql-ktc`, section PROFILE.
- The lock log on titan (`~/.local/state/titan-lock/activity.log`, entries
  named `profile-643`) and `below` system data for 2026-10-30 05:02-05:15.
- The logs that the seed names
  (`.claude/worktrees/profile-643/claude_stuff/profile-643-*.log`) no longer
  exist.
