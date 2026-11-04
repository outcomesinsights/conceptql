# Pre-release review of conceptql v0.6.0..main (2026-11-04)

Three adversarial reviewers examined the 88 commits between v0.6.0 and main (af194d67). Each one
covered one area: behavior changes that reach consumers, the diagram renderer with the packaging
and CI, and the operator metadata with the spec. Each finding has measured numbers and a verdict.
A concern whose numbers did not hold up is recorded with verdict DOES NOT HOLD UP, and it needs no
decision.

`just ci` and `just release-check` passed on main before the review. The reviewers ran no Docker
suites, did not test Spark, and did not run GitHub CI.

Production identifiers (study and algorithm version IDs) and paths into other repositories are
removed from this public copy. The counts remain.

## Result

No finding blocks the release. The next version is 0.7.0 under cliff.toml's 0.x rules, because
the round has breaking changes.

| ID  | Finding                                                                                                                  | Severity   | Verdict          |
| --- | ------------------------------------------------------------------------------------------------------------------------ | ---------- | ---------------- |
| B1  | The CHANGELOG marks 1 of 4 breaking changes as Breaking. 0 of 1,259 current production algorithms are affected.          | should-fix | CONFIRMED        |
| P1  | The gem never checks the resvg version at run time. `Resvg#version` has 0 callers.                                       | should-fix | CONFIRMED        |
| M2  | The `equal` help example matches the fixture's only HbA1c record with itself.                                            | should-fix | CONFIRMED        |
| P3  | The CHANGELOG says "the same output as in the editor", but 280 of 280 SVGs differ in `<style>`. 70 of 70 PNGs are equal. | note       | CONFIRMED        |
| P7  | The gemspec license says MIT only, and the gem ships fonts under the SIL Open Font License 1.1.                          | note       | CONFIRMED        |
| B3  | `known_codes` and `code_meanings` raise `Sequel::DatabaseError` without a concept table. 0.6.0 returned empty results.   | note       | CONFIRMED        |
| M1  | JDE's page metadata grows from 255,471 to 653,999 bytes (21,625 to 33,485 compressed). JDE reads 0 of the new keys.      | note       | CONFIRMED (size) |
| P2  | On titan, the resvg mise shim fails outside the conceptql directory: 60 of 60 examples failed from `/tmp`.               | note       | CONFIRMED        |
| B2  | One replaced production algorithm version is now invalid. A Draft study still references it. A JDE bead fixes the data.  | note       | CONFIRMED        |
| M3  | The `trim_date_end` example's note about patients born after 1980 applies to 0 of 249 patients.                          | note       | CONFIRMED        |
| M4  | A saved statement with a removed option fails validation. The editor shows no field to clear it.                         | note       | CONFIRMED        |
| M6  | JDE's help links still point at the conceptql_spec repository. All 36 spec_ids resolve in both specs.                    | note       | CONFIRMED        |
| B7  | The rule "a `(?i:...)` vocabulary never raises" applies to 0 of 38 vocabularies.                                         | note       | CONFIRMED        |
| B8  | The CHANGELOG's blank-domain count (40 of 41) differs from the DuckDB fixture (55 of 56). 0 production results change.   | note       | CONFIRMED        |
| P4  | A local `gem build` ships untracked files. A tag release builds from a clean checkout.                                   | note       | CONFIRMED        |
| P5  | A local build on titan has 170 of 185 files at mode 0660. v0.6.0 had the same problem. CI releases are not affected.     | note       | CONFIRMED        |
| P6  | `render_app` raises `NoMethodError`, not an input error, for the raw tree of `Diagram.render`.                           | note       | CONFIRMED        |
| P9  | The shipped spec has 74 links to images that the gem does not ship. This is the ruled behavior.                          | note       | CONFIRMED        |
| P10 | JDE's old `~> 0.6.0` pin would exclude 0.7.0. JDE now takes conceptql from git.                                          | note       | CONFIRMED        |
| B4  | `information_periods` with a space in an ID now selects 0 periods. 0 production statements are affected.                 | none       | DOES NOT HOLD UP |
| B5  | The race fix changes more than the CHANGELOG says. 0 of 171 studies use a race filter.                                   | none       | DOES NOT HOLD UP |
| B6  | No consumer call raises CodeCaseMismatchError (t_shank 3 calls, JDE 1 call).                                             | none       | DOES NOT HOLD UP |
| M5  | No metadata change breaks JDE: 0 operators added or removed, 0 keys removed.                                             | none       | DOES NOT HOLD UP |
| P8  | CI does not run the renderer on Ruby 3.3, but 740 of 740 tests pass locally on 3.3.10 and 3.4.8.                         | none       | DOES NOT HOLD UP |

The three reports follow without changes, except for the removed identifiers.

## Review: behavior changes that reach consumers (conceptql v0.6.0..main)

Reviewer: adversarial-reviewer, 2026-11-04. main = af194d67, v0.6.0 = f24667f0.
Measurement log: `claude_stuff/review-behavior-20261104-071716.log`.

Method: I ran v0.6.0 (from `git archive` in `/tmp/rvb/v060`, with its own Gemfile) and main side by
side. I validated all 1,652 production algorithm rows (1,259 current) from
a JDE log (export of 2026-11-01)
under both versions with `Database.new(nil, data_model: :gdm)` and compared the error sets. I ran
queries on a copy of the DuckDB fixture in three setups (wide+ohdsi, slim+gdm_vocabs,
slim+ohdsi). I compared `ConceptQL.metadata` of both versions in the same three setups.

The case-exact matching commit da1917db is an ancestor of v0.6.0. It is not in this release, so I
did not review it again.

### Findings, most severe first

#### B1. The CHANGELOG marks only one of four breaking changes as Breaking

- Claim: three statement-level changes make a statement that validated on 0.6.0 fail on main, but
  the CHANGELOG lists them under Changed without **Breaking**, and their commits have no `!`.
- Evidence:
  - The unmarked changes are: a positional upstream on 13 operators (f4e3b6c9). Two or more upstreams on
    `occurrence`, `first` and `last` (1148eff7). The options `equal` `within` and `first`/`last`
    `group_by_date` set to a real value (c6113f7d).
  - Reproduced on main: `["first", up, ["icd9","250.00"]]` raises `has multiple upstreams`.
    `["equal", {left:, right:, within: "30d"}]` raises `unsupported option`. Both ran on v0.6.0
    (191 and 0 rows).
  - `git cliff --unreleased` writes a "Breaking changes" section with 1 entry (b424a516). Only
    b424a516 of the 88 commits is typed `!`.
  - Public Ruby API changes also lack a Breaking mark. `DataModel::Gdm#information_period_where_clause(arguments)`
    became `(db, arguments)`. `Vocabularies::Entry#vocabulary_long_name` was removed, and the
    CHANGELOG does not list that removal at all. Consumer call sites of both: 0 in JDE and
    t_shank.
  - Real impact: 0 of 1,259 current production algorithms change validity. 1 of 1,652 rows does
    change (see B2). JDE's own count agrees
    (a JDE log).
- Severity: should-fix-before-release. This is a documentation defect. It does not change the
  version, because b424a516 already makes it v0.7.0.
- Verdict: CONFIRMED.
- Decision for Ryan: add **Breaking:** to the three Changed entries and list the two Ruby API
  changes, or leave them unmarked because no current production statement is affected. I
  recommend that you mark them, because a consumer reads the CHANGELOG to decide whether to
  upgrade.

#### B2. A live Draft study still points at an algorithm version that main rejects

- Claim: algorithm row (ID removed) (`multiple_glp_1_on_same_day`) has `group_by_date: true` on 6
  `first` nodes. It is a replaced version, but non-deleted Draft study (ID removed) still references
  it in `study_criteria`.
- Evidence: under main, the corpus diff shows 1 new error, `["unsupported option", "group_by_date", true]`
  on this row only. `study-criteria.csv` lists study (ID removed), status Draft, deleted f. JDE's
  count log shows the same row as "live_algorithms 1, current 0".
- Severity: note. JDE bead p8wn is to fix this data.
- Verdict: CONFIRMED.
- Unverified: whether an export of study (ID removed) reads this version or the current one.

#### B3. `known_codes` and `code_meanings` now raise Sequel::DatabaseError when the concept table is missing

- Claim: with the default `check_case: true`, the new check queries the concept table without the
  guard that the strategy lookups have. A lexicon without a concept table now raises where 0.6.0
  returned an empty answer.
- Evidence: `Lexicon.new(nil, db, strategy: LexiconOhdsi.new(db))` on an empty in-memory DuckDB
  (the construction that JDE `code_search.rb:56` uses):
  - v0.6.0: `known_codes` → `[]`, `code_meanings` → `{}`.
  - main: both raise `Sequel::DatabaseError: Table with name concept does not exist!`.
    `concepts_to_codes` → `[["412", nil]]` on both.
  - With `check_case: false`, `known_codes` → `[]` on main.
  - Cause: `LexiconStrategy#case_variants` (`lib/conceptql/lexicon/lexicon_strategy.rb:68`) does
    not rescue, but `known_codes` (line 125) rescues `Sequel::DatabaseError`.
- Consumer impact: 0 call sites. JDE calls `concepts` with no codes, and t_shank calls only
  `concept_ids`.
- Severity: note. The CHANGELOG does not mention it.
- Verdict: CONFIRMED.

#### B4. An `information_periods` ID with spaces is now treated as a code

- Claim: on 0.6.0 every argument went through `to_i`, so `" 100000078"` selected 217 periods. On
  main it is not `/\A\d+\z/`, so it becomes an unknown code: it selects 0 periods and gets a
  warning.
- Evidence:
  - DuckDB fixture: v0.6.0 gives 217 rows and main gives 0. `"PARTD"` gives 0 → 217, which is the
    intended fix.
  - Production: 1 `information_periods` node, which has no argument.
  - t_shank passes `Option#label`, which `Database#set_options` fills from the integer IDs. 1 of
    134 export fixtures has a label, `"100000081"`, which is digits only.
- Severity: note.
- Verdict: DOES NOT HOLD UP as a release risk (0 affected statements).

#### B5. The race fix changes more than the CHANGELOG says, but no export uses it

- Claim: on 0.6.0, any `race` list that contained Unknown selected no patients at all, not only no
  Unknown patients. t_shank builds `[:race, *races]` with "Unknown" (`exporter.rb:429-446`).
- Evidence: `["race","White","Unknown"]` gave 0 rows on v0.6.0 and 204 on main. `["race","White"]`
  gives 204 on both.
  - Production studies (rehearsal dump of 2026-11-02): all 171 select every race, so 0 studies
    use the race filter.
  - Production algorithms with `race`: 0. t_shank fixtures with a race filter: 0 of 134.
  - The fixture has 0 patients with no race, so `["race","Unknown"]` is 0 on both versions.
- Severity: note. The CHANGELOG text "an Unknown argument selected no patients" understates the
  0.6.0 defect.
- Verdict: DOES NOT HOLD UP as consumer breakage.

#### B6. CodeCaseMismatchError at consumer call sites

- Claim tested: a consumer call that returned a value on 0.6.0 now raises.
- Evidence:
  - t_shank has 3 call sites (`exporter.rb:1957, 1958, 1986`). `"LINE"` → 100000065, `"CLAIM"`
    → 100000064 and `"carrier_claim"` → 100012425 on both vocabulary setups, with no raise.
  - JDE has 1 call site (`code_search.rb:40`), which passes no codes, so the check returns early.
  - The t_shank worktree `dedup-test` still asks for `"line"`, but it pins conceptql 0.5.0.
- Verdict: DOES NOT HOLD UP (0 raising call sites).

#### B7. "A (?i:...) vocabulary never raises" applies to no vocabulary

- Claim: the CHANGELOG exception covers 0 of the 38 vocabularies in the pinned
  `config/vocabulary_formats.tsv`. `Formats.case_insensitive?` is false for all of them. The text
  `(?i:` occurs only in the notes column.
- Severity: note. The statement is true, but no real data runs that code path.
- Verdict: CONFIRMED (as stated: 0 vocabularies).

#### B8. The blank-domain count in the CHANGELOG does not match the DuckDB fixture

- Claim: the CHANGELOG says `gdm_vocabs.vocabularies` gives "40 of its 41" vocabularies the
  domain `''`. The DuckDB fixture has 56 rows: 55 are `''` and 1 is NULL.
- Evidence:
  - The predominant domain changes from `['']` to `['condition_occurrence']` for 41 operators in
    the gdm_vocabs metadata, plus `read` from another commit. It changes for 0 operators with the
    OHDSI vocabularies.
  - Production uses `LexiconOhdsi` (a JDE log).
    So 0 production results change, although 116 current algorithms use these operators.
  - I did not check the Postgres image, which may be the source of "41".
- Severity: note.
- Verdict: CONFIRMED for the DuckDB fixture. The production impact does not hold up (0).

### Semver

`git cliff --bumped-version` gives v0.7.0. cliff.toml has `breaking_always_bump_major = false`
and `features_always_bump_minor = false`, so the breaking commit b424a516 bumps the minor
version. The next version must be 0.7.0, not 0.6.1. t_shank pins `~> 0.6.0`, so it does not take
0.7.0 until its Gemfile changes. JDE now takes conceptql from the local repo (b82a803d4, lock at
bcf278af), as the coordinator said. I checked the Gemfile and Gemfile.lock.

### Checked and found clean

- Statements do not raise CodeCaseMismatchError. I ran 8 wrong-case statements (icd10cm `i10`,
  hcpcs `j9100`, provenance `INPATIENT` and `Inpatient:Primary`, information_periods `partd`,
  place_of_service_filter, ms_drg, read). Each went through annotate, count and code_list, on 2
  setups. That gave 0 raises: only warnings or validation errors.
- Internal lookups with the check on: only Utilizable's constants (`inpatient`, `hospice`, `snf`,
  `primary`). All 4 resolve on 3 setups, and `hospitalization` counts 153 rows.
- Metadata: the operator sets are identical: 119/119 with no DB, 431/431 OHDSI, 154/154 GDM.
  - `min_upstreams` changes on exactly 9 operators and `max_upstreams` on exactly 5, as the
    CHANGELOG lists.
  - Options change only on equal, first and last.
  - `short_name` changes on 0 operators, and `Entry#short_name` changes on 0 of 399 entries.
  - Categories do not change.
- `group_by_date` had no effect on 0.6.0, as the CHANGELOG says. first and last gave identical
  193 rows with and without it, on data with 725 same-date ties.
- JDE does not read `min_upstreams` or `max_upstreams` (0 hits in app, lib or frontend/app).
- t_shank has no `rescue ArgumentError` that could hide the new error.
- The gemspec ships `code_case_mismatch_error.rb`, `docs/spec/README.md` and 36 example files.
- The production corpus produced 0 exceptions under both versions. The number of invalid rows
  went from 135 to 136 (B2).

### Not tested

- The Postgres configs (docker is not allowed) and Spark.
- An export of study (ID removed).
- The JDE frontend with the new metadata.
- Production data newer than 2026-11-02.

## Adversarial review: diagram renderer move, packaging, CI and release workflow

Release range `v0.6.0..main` (88 commits, HEAD af194d67). Reviewer area: the renderer, the gem package, `run_tests.yml`, `release.yml`, `.github/install-resvg.sh`.
Log: `claude_stuff/review-packaging-20261104-071707.log`. No tracked file was changed. The temporary worktrees were removed.

No blocker was found. Every finding below is a note or a should-fix item.

### Findings

#### P1. The gem never checks the resvg version at run time, so a host with another resvg gets wrong diagrams without an error.

- Evidence: in `lib/`, `Resvg#version` is defined (`lib/conceptql/diagram_renderer/resvg.rb:51`) and is called 0 times. Only `just resvg-check` and `install-resvg.sh` check the version, and neither runs in a host application.
- `docs/diagram_renderer.md:29-30` and `mise.toml` say that resvg 0.34 gives a viewBox that matches none of the 70 fixtures. I could not repeat that measurement: the download of resvg 0.34.0 was refused by the permission system. So the size of the drift is the author's number, **unverified** by me.
- resvg 0.33.0 has binaries only for linux-x86_64, macos-x86_64 and win64 (GitHub release assets, 10 files). A host on linux arm64 or Apple Silicon must build it or run another version.
- Severity: should-fix-before-release (the gem is now public API).
- Verdict: CONFIRMED (0 version checks in lib). The drift size is unverified.
- Decision for Ryan: should `render_static` and `png` refuse to run (or warn) when `resvg --version` is not 0.33.0? Options: (a) raise `Resvg::Error` once on the first call, at the cost of one extra process start; (b) only document it in the README and CHANGELOG. I recommend (a).

#### P2. On titan, `resvg` on PATH is a mise shim that fails outside the conceptql directory.

- Evidence: a run from `/tmp` against the installed gem gave `mise ERROR No version is set for shim: resvg`. Result: 3 of 8 API checks failed (render_static, render_static with options, png), and 60 of 60 spec examples failed. With the real 0.33.0 binary first on PATH, the result was 8 of 8 and 60 of 60.
- This is 1 host-only dependency. It affects host processes on titan only. CI is not affected, and the JDE container is not affected, because both install the binary itself.
- Severity: note.
- Verdict: CONFIRMED.
- Decision for Ryan: should titan get a global mise pin for resvg 0.33.0 (`mise use -g github:linebender/resvg@0.33.0`)? Without it, the renderer works on the host only from inside this repository.

#### P3. The CHANGELOG says the renderer has "the same output as in the editor". The `<style>` text differs in every SVG.

- Evidence: I rendered the 70 fixtures with the gem and with JDE's old renderer (JDE commit fe5b1fa77, with JDE's own asset paths). Five variants were compared.
  - static: 70 of 70 differ only in `<style>`.
  - static with counts and options: 70 of 70 differ only in `<style>`.
  - app: 70 of 70 differ only in `<style>`.
  - app, locked and summary: 70 of 70 differ only in `<style>`.
  - PNG: 70 of 70 are byte-identical.
- Cause: the gem's `diagram.css` is 8,396 bytes and JDE's was 24,671 bytes (commit f5f58b35). The fonts are identical (5 of 5 sha256 match). The sprite is identical (15,183 bytes).
- This confirms the JDE session's numbers exactly.
- Severity: note. The sub-bullet of the CHANGELOG already describes the trimmed CSS.
- Verdict: CONFIRMED.
- Suggested wording: "the same drawing as in the editor. The SVG `<style>` holds only the diagram rules."

#### P4. A local `gem build` ships untracked files from `config/`, `assets/diagram/` and `docs/spec/examples/`.

- Evidence: the gemspec uses `Dir[...]` globs (`conceptql.gemspec:28-30`). In a temporary worktree I added `config/vocabularies.custom.csv` and `assets/diagram/notes.txt`. Both files (2 of 2) were in the built gem.
- `vocabularies.custom.csv` is the default path of `ConceptQL.custom_vocabularies_file_path`, so a host-local file of that name is a realistic case.
- `release.yml` builds from a clean checkout, so a tag release is not affected. `rake release` builds locally and is affected.
- The `config/*` part existed in 0.6.0. The `assets/` and `examples/` parts are new.
- Severity: note.
- Verdict: CONFIRMED.

#### P5. A local build has 170 of 185 files at mode 0660.

- Evidence: the umask on titan is 007. `gem build` printed "not world-readable" warnings, and the tar entries kept mode 0660 (v0.6.0 had 125 such files).
- CI checkouts use umask 022, so a release from `release.yml` is not affected.
- Severity: note. This existed before this release.
- Verdict: CONFIRMED.

#### P6. `render_app` raises `NoMethodError` for the tree that `ConceptQL::Diagram.render` returns.

- Evidence: `render_app(ConceptQL::Diagram.render([["icd9","412"]]))` raises `NoMethodError: undefined method 'length' for nil` (1 failing call). The same tree passed through `DiagramData.from` first renders 28,153 bytes.
- The contract is documented (`docs/diagram_renderer.md:77`). However, `render_static` accepts the raw tree and `render_app` does not, and the error is not an `InputError`.
- Severity: note.
- Verdict: CONFIRMED.

#### P7. The gemspec license says only MIT. The gem now ships fonts under the SIL Open Font License 1.1.

- Evidence: `spec.license = 'MIT'`. Five Roboto files are shipped. Their name tables give "Copyright 2011 The Roboto Project Authors" and https://openfontlicense.org. `assets/diagram/fonts/OFL.txt` (93 lines) is shipped with the fonts, and it has the copyright line and the full licence.
- OFL compliance looks correct: the licence text is shipped, and Roboto has no Reserved Font Name.
- The metadata is incomplete. `spec.licenses = ["MIT", "OFL-1.1"]` would be accurate.
- `operators.svg` (33 symbols) has no licence or copyright text. Its provenance is the editor's own sprite, and I could not trace it further (**unverified**).
- Severity: note.
- Verdict: CONFIRMED (the metadata gap).

#### P8. The installed-gem smoke test and the renderer tests in CI do not cover the Ruby 3.3 floor.

- Evidence: the `release.yml` publish job runs only on Ruby 4.0. `Run-Diagram-Renderer-Tests` runs only on Ruby 3.4.
- I ran both locally on 3.3.10 and 3.4.8, and both pass.
  - Renderer tests: 740 runs, 21,615 assertions, 0 failures on each Ruby.
  - Empty-`GEM_HOME` install and exercise: 8 of 8 checks and 60 of 60 examples on each Ruby. The output sizes are identical on 3.3, 3.4 and 4.0 (135,216 bytes static, 7,422 bytes PNG).
- Severity: note.
- Verdict: DOES NOT HOLD UP as a defect today. It remains a coverage gap. The `Pathname` bug that `paths.rb` describes is the class of bug that this gap would miss.

#### P9. The shipped spec has dangling image links.

- Evidence: `docs/spec/README.md` in the gem has 74 links to `images/<sha>.svg`, and 0 images are shipped. v0.6.0's `doc/spec.md` had 55 such references.
- This is ruled behaviour (CLAUDE.md: "ships ... no images"). An application can draw the diagrams from the `tree` in `docs/spec/examples/*.json`.
- Severity: note.
- Verdict: CONFIRMED, by design.

#### P10. The next version is 0.7.0. JDE's old pin `~> 0.6.0` would exclude it.

- Evidence: `git cliff --bumped-version` prints `v0.7.0`.
- JDE now takes conceptql from git (pinned at bcf278af), so nothing breaks today. When JDE returns to rubygems, its Gemfile needs `~> 0.7.0`.
- Severity: note.
- Verdict: CONFIRMED.

### Checked and found clean

- **Package size**: 404,992 bytes and 185 files, against 157,696 bytes and 127 files for v0.6.0.
  - Unpacked: 1,292,435 bytes against 624,833.
  - The largest additions: fonts 230,486 bytes, `docs/spec/README.md` 215,552 bytes, 36 example JSON files 194,234 bytes.
  - 59 files were added and 1 was removed (`doc/spec.md`). No caller of the old path remains: 0 hits in `lib/` and `bin/`, and JDE's MCP server uses `ConceptQL.spec_path`.
- **Unwanted files**: 0 in the gem (test references, `docs/spec/images`, `claude_stuff`, `.seeds`, `.beads`, directory entries).
- **Tracked files missing from the gem**: only `bin/beautify_json.sh`, which existed before and is not a runtime file.
- **Empty `GEM_HOME` install** (Ruby 4.0.9, 3.4.8, 3.3.10): 8 of 8 checks pass on each.
  - The checks: `spec_path`, `spec_examples_path` (36 files), `metadata(cdb)` (119 operators), `Diagram.render`, `render_static`, `render_static` with options, `png`, `render_app`.
  - 60 of 60 spec example trees render.
  - `conceptql help` runs.
- **Autoload**: `require "conceptql"` loads 0 renderer files on all three Rubies. After first use, 13 are loaded, all from the gem directory.
- **Ruby 3.3 compatibility**: 740 of 740 tests pass on 3.3.10 and on 3.4.8.
- **Same output on rerun**: 0 of 70 fixtures differ between two runs (static SVG and PNG).
- **`install-resvg.sh`**:
  - It ran to completion into `/tmp`, and the checksum matched.
  - The tar member is `resvg`.
  - The binary is identical to the mise 0.33.0 install.
  - The pin is the same as the SHA-256 in JDE's Dockerfile.
  - shellcheck reports 0 findings.
- **Workflows**:
  - actionlint: 0 findings.
  - zizmor 1.31.1 offline: 0 findings (1 ignored, 12 suppressed).
  - Every action is pinned to a SHA, and the pins are the same as the green v0.6.0 run.
- **Host-only dependencies in the new CI path**: 0. There are no `/home/ryan`, Dropbox, titan or mise-shim references in `install-resvg.sh`, the diagram job, `test-diagram`, `resvg-check`, the renderer, or its tests.
- **The asset check in `release.yml`**: it uses `git ls-files assets/diagram`, which lists 8 files. The render step's string check (`>412</tspan>`) matches real output: a 135,216-byte SVG.
- **Lockfile**: nokogiri 1.19.7 has a native gem for x86_64-linux-gnu. `bundle install` and the tests work on Ruby 3.3 and 3.4.
- **Assets**: `operators.svg` is identical to JDE's sprite (15,183 bytes). The 5 font files match JDE by sha256. Roboto-700.ttf has `usWeightClass` 700.

### Not tested

- The real first GitHub run of `run_tests.yml` and `release.yml`. That needs a push. The trusted-publisher exchange and the `release` environment can only be tested by a tag push.
- Output drift with resvg 0.34 or later. The binary download was refused. The test needs a resvg 0.34.0 binary in `/tmp`.
- `mise install` of resvg on an Apple Silicon Mac (boost), where 0.33.0 has no arm64 build.

## Adversarial review: operator metadata, spec and example files (v0.6.0..main)

Date: 2026-11-04. Reviewer area: metadata, spec, example files as consumers read them.
Log: `claude_stuff/review-metadata-20261104-071807.log`.
JDE was measured at its current main, 773af2737. It takes conceptql from the local repo at
bcf278af. `git diff bcf278af main -- lib docs config conceptql.gemspec` is empty, so JDE runs
the release candidate's metadata and spec.

No blocker was found.

### Findings

#### M1. Each load of the JDE app shell now carries 399 KB more metadata, and JDE reads none of it

- Claim: the three new keys are 61% of the served metadata, and JDE's frontend reads none of them.
- Evidence (fixture lexicon, gdm_wide, `cache_lookups: true`, 431 operators, the JDE production path):
  v0.6.0 = 255,471 bytes. main = 653,999 bytes (deflate 21,625 -> 33,485).
  `meaning` 263,613 B (40.3%), `returns` 118,833 B (18.2%), `examples` 16,225 B (2.5%).
- With no database (119 operators): 71,958 -> 187,423 bytes. New keys = 114,751 B (61.2%).
- Most of it is repetition. Across the 119 operators, 260 `meaning` strings have only 46 distinct
  values (69,185 B in total, 11,340 B distinct). The `codes` meaning (377 B) repeats 82 times.
  The `label` meaning (211 B) repeats 119 times. One `returns` text (269 B) repeats 84 times.
- JDE `boot_config_helper.rb:12` embeds `ConceptQL.metadata(cdb)[:operators]` with no key filter.
  `operator-registry.js` reads 12 keys (`op_metadata['...']`). None of them is returns, examples or meaning.
- Effect: none shown. The payload is in the SPA shell (`launch.html.erb:36`), so it is sent once
  per full load, not per route. No test or limit fails.
- Severity: note. Verdict: CONFIRMED as a size fact. DOES NOT HOLD UP as a defect.
- Decision for Ryan: JDE can slice the 12 keys it reads before it embeds the metadata, or keep
  the keys for the planned operator help. That is a JDE choice, and conceptql needs no change.

#### M2. The `equal` help example compares a record with itself, so it shows nothing about matching

- Claim: the only HbA1c record in the fixture matches itself, so the example gives a misleading result.
- Evidence: the fixture has 1 record of LOINC 4548-4 (1 patient, value 5.1, duckdb query, log).
  `docs/spec/examples/equal-operator.json` has `help: true` and 1 row: that record.
  The statement is `equal(left: loinc 4548-4, right: loinc 4548-4)`, the same stream on both sides.
  `equal` joins on person and value only (`equal.rb` where_clause), so every record with a value matches itself.
- A reader is led to think that the patient has two equal results.
- Severity: should-fix-before-release (it is the only example that JDE help will show for equal).
  Verdict: CONFIRMED.
- Decision for Ryan: change the example to two different streams that share values in the
  fixture, or mark it `help: false`.

#### M3. The trim_date_end example names a case that the result never shows

- Claim: "(patients born after 1980 are dropped)" describes 0 patients in the fixture.
- Evidence: the fixture has 249 patients, with births from 1911-01-01 to 1976-12-01. 0 were born
  after 1980-01-01. The example's root count is person 249/249, so nothing is dropped.
  The matching trim_date_start claim is true: 77 patients reached 50 before 1980, and 249 - 172 = 77.
- Severity: note. Verdict: CONFIRMED.

#### M4. Statements saved with an option that was removed now fail validation, and the editor shows no field to clear it

- Claim: `equal.within` and `first`/`last`.`group_by_date` were removed from the metadata.
  A stored statement that sets them now gets `unsupported option`.
- Evidence: the metadata diff shows 3 options REMOVED (log). `operator.rb:601` validates them.
  CHANGELOG.md:83-85 documents it. JDE builds the option fields only from the metadata
  (`operator-registry.js` `opts:`), so the editor has no field that clears the stored value.
- Not tested: the number of saved JDE algorithms that set these options. That needs a query
  of JDE's production database.
- Severity: note (documented, intended). Verdict: CONFIRMED for the mechanism. The count is **unverified**.

#### M5. Metadata changes between v0.6.0 and main that JDE reads

- 0 operators added, removed or renamed (119 published; 431 with the fixture lexicon). The categories are identical.
- No key was removed. 2 keys were added (returns and examples, on all 119 operators).
  The only type change is long_name null -> String on 69 operators.
- Values that changed: `desc` on 33 operators, `long_name` on 79, options on 14
  (11 instruction texts, 3 options removed, 2 option `desc` keys removed on one_in_two_out),
  min_upstreams on 9, max_upstreams on 5, information_periods arguments on 1
  ([] -> a `codelist` argument), and read.predominant_domains on 1 ([] -> condition_occurrence).
- JDE effect: JDE shows `desc` (33 visible text changes, intended). JDE does not display
  operator long_name, and it does not read min/max_upstreams or an option `desc` (grep: 0 call sites).
  `argument:codelist` exists (`frontend/app/arguments/codelist.js`), so information_periods does not throw.
  read now gets outputTypes [condition_occurrence] instead of [].
- JDE's refreshed copy (fc445f8d4, 50 operators, 112,124 bytes) has returns and examples on all 50.
  It differs from the fixture-lexicon metadata in 2 values (gemscript long_name, rxnorm short_name).
  Those come from vocabulary differences between JDE's test database and the fixture, not from the code.
- Severity: note. Verdict: DOES NOT HOLD UP as a break. 0 changes break JDE.

#### M6. JDE help links still point at the conceptql_spec repository, which the plan archives

- Claim: `tree-node.js:388` builds `https://github.com/outcomesinsights/conceptql_spec#<spec_id>`.
- Evidence: all 36 spec_ids are anchors in conceptql_spec's README today (0 misses), and in the new spec (0 misses).
  Seed conceptql-mdo.1 assigns the link switch to JDE.
- Severity: note (not a conceptql release defect). Verdict: CONFIRMED. The links work until the
  conceptql_spec README changes.

### Checked and found clean

- MCP slicer (JDE's `ConceptqlSpec.split` reproduced, with ActiveSupport `parameterize`): 22 sections,
  0 duplicate slugs, largest 25,955 B ("Inline-Filter Operators"), 0 over 40,000 B. Index 4,075 B,
  which is not larger than the largest section. Fence lines: 154, balanced. 0 single-line triple-backtick
  lines, 0 indented fences, and 0 `~~~` fences that the rule would misread.
- Internal links in docs/spec/README.md: 63 links (45 distinct), 0 unresolved.
- Old conceptql_spec README: 69 heading anchors. 0 have no counterpart in the new spec. Its 121 internal links all resolve.
- spec_id: 119 operators, 0 blank, 36 distinct, 0 that are not an anchor in the new spec.
- Image references: 74 (72 distinct), 0 missing files.
- Example files: 36 files, 60 examples, 56 with help:true. 4 return 0 rows (hospice, snf,
  place_of_service_filter, cms_drg 205), and all 4 are help:false. 0 help examples are empty.
  0 metadata examples are absent from their spec_id's file.
- Every one of the 119 operators has a `returns` text. 81 operators have no example of their own.
  They are vocabulary operators that share the vocabulary spec_id, by design (seed conceptql-mdo.2).
  hospice, snf and place_of_service_filter have no help example, because the fixture has no such data
  (the fixture has 0 records with a place of service).
- Text against code (sampled): first and occurrence tie-break on criterion_id; the filter and except
  comparison columns; the trim_date_end/start direction and the within sign; match's columns;
  equal's NULL rule. Each agrees with the code. provider_filter concepts 38003868 (NUCC Endocrinology)
  and 100000067 (Attending physician) are what the title says. trim_date_start's 77 dropped patients are correct.
- gdm and gdm_wide metadata are byte-identical (no database).

### Not tested

- The real production JDE database may publish more operators than the fixture's 431. The size scales with that count.
- The number of saved algorithms that use the removed options (M4).
