log_dir := "claude_stuff/test-logs"

# The DuckDB C library that test-duckdb builds the duckdb gem against. The gem's
# own version does not decide it: ruby-duckdb 2.x builds against libduckdb 1.4 or
# newer. Local runs and the pre-push gate use the 1.5.x line, because 2.x showed
# speed regressions. GitHub CI tests 1.5.x and 2.x (LIBDUCKDB_VERSION in the
# DuckDB job's matrix), so the cut-over to 2.x is already tested when it comes.
# 1.5.x reaches end of life in March 2027. Set LIBDUCKDB_VERSION to test another
# release. Bundler does not rebuild an installed duckdb gem when it changes, so
# run `gem pristine duckdb` after a switch.
libduckdb_version := env("LIBDUCKDB_VERSION", "1.5.6")

# docker-compose.yml runs the conceptql container as this user (its `user:`), so
# the files a docker run writes into the checkout are not owned by root.
export CONCEPTQL_UID := `id -u`
export CONCEPTQL_GID := `id -g`

# CI's Postgres matrix sets SEQUELIZER_SEARCH_PATH and CONCEPTQL_DATA_MODEL to
# run its other config.
# Run gdm_wide (default quick test)
test *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ log_dir }}/test
    ts=$(date +%Y%m%d%H%M%S)
    log={{ log_dir }}/test/${ts}.txt

    trap '{{ just_executable() }} --justfile {{ justfile() }} test-db-down' EXIT

    rc=0
    SEQUELIZER_SEARCH_PATH="${SEQUELIZER_SEARCH_PATH:-wide,slim,ohdsi_vocabs}" \
      CONCEPTQL_DATA_MODEL="${CONCEPTQL_DATA_MODEL:-gdm_wide}" \
      docker compose run --rm conceptql {{ ARGS }} 2>&1 | tee "$log" || rc=$?

    ln -sf "test/${ts}.txt" {{ log_dir }}/latest.txt
    echo "Log: $log"
    exit $rc

# Mirrors CI's Run-DuckDB-Tests job (.github/workflows/run_tests.yml) on host Ruby.
# Tests write temp tables into the database file and the default source is a
# PUBLISHED Dropbox share, so the source is never opened: each run copies it to a
# scratch dir, verifies the copy against the committed checksum, tests the copy,
# and deletes it. libduckdb (libduckdb_version) is cached per version under
# ~/.cache/conceptql/libduckdb.
# Part of `ci` (the pre-push gate). Override the source with DUCKDB_TEST_DATA_SOURCE.
# Run the suite against DuckDB, as CI does (args: test files; default all)
test-duckdb *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ log_dir }}/duckdb
    log={{ log_dir }}/duckdb/$(date +%Y%m%d%H%M%S).txt
    exec 3>&1 > >(tee "$log") 2>&1
    tee_pid=$!
    work=""
    finish() {
      rc=$?
      if [ -n "$work" ]; then rm -rf "$work"; fi
      exec >&- 2>&-
      wait "$tee_pid" || true
      echo "Log: $log" >&3
      exit $rc
    }
    trap finish EXIT

    [ "$(uname -s)-$(uname -m)" = Linux-x86_64 ] || { echo "linux-amd64 only, as in CI"; exit 1; }

    # DuckDB renamed the release file in 2.0: 1.x ships libduckdb-linux-amd64.zip,
    # 2.x ships duckdb-shared-libs-linux-amd64.tar.gz. Both hold libduckdb.so and
    # the headers at the top level.
    version={{ libduckdb_version }}
    libdir="${XDG_CACHE_HOME:-$HOME/.cache}/conceptql/libduckdb/v${version}"
    if [ ! -f "$libdir/libduckdb.so" ]; then
      if [ "${version%%.*}" -ge 2 ]; then asset=duckdb-shared-libs-linux-amd64.tar.gz; else asset=libduckdb-linux-amd64.zip; fi
      echo "Downloading libduckdb v${version} ($asset) to $libdir"
      rm -rf "$libdir.tmp"
      mkdir -p "$libdir.tmp"
      curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v${version}/${asset}" -o "$libdir.tmp/$asset"
      case "$asset" in
        *.zip) unzip -q "$libdir.tmp/$asset" -d "$libdir.tmp" ;;
        *.tar.gz) tar -xzf "$libdir.tmp/$asset" -C "$libdir.tmp" ;;
      esac
      rm "$libdir.tmp/$asset"
      mv "$libdir.tmp" "$libdir"
    fi

    export SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide BUNDLE_WITH=duckdb
    export BUNDLE_BUILD__DUCKDB="--with-duckdb-include=$libdir --with-duckdb-lib=$libdir"
    export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    bundle check >/dev/null || bundle install

    src="${DUCKDB_TEST_DATA_SOURCE:-$HOME/Dropbox/Publicized/synpuf_test_data.duckdb}"
    [ -f "$src" ] || { echo "No DuckDB fixture at $src (set DUCKDB_TEST_DATA_SOURCE)"; exit 1; }
    mkdir -p "${TMPDIR:-/tmp}/conceptql-duckdb"
    work=$(mktemp -d "${TMPDIR:-/tmp}/conceptql-duckdb/run.XXXXXX")
    data="$work/synpuf_test_data.duckdb"
    echo "Copying $src -> $data"
    cp "$src" "$data"

    magic=$(dd if="$data" bs=1 skip=8 count=4 2>/dev/null)
    [ "$magic" = DUCK ] || { echo "Not a DuckDB file: magic at offset 8 is '$magic', expected 'DUCK' ($src)"; exit 1; }
    if ! (cd "$work" && sha256sum -c "{{ justfile_directory() }}/.github/synpuf_test_data.sha256"); then
      echo "Checksum mismatch: $src is not the fixture pinned in .github/synpuf_test_data.sha256"
      echo "  pinned: $(cut -d' ' -f1 .github/synpuf_test_data.sha256)"
      echo "  actual: $(sha256sum "$data" | cut -d' ' -f1)"
      exit 1
    fi

    export SEQUELIZER_URL="duckdb://$data"
    # `just ci` runs `test` at the same time, and it writes coverage/; keep this run's report apart.
    export CONCEPTQL_COVERAGE_DIR="{{ justfile_directory() }}/{{ log_dir }}/duckdb/coverage"
    args=({{ ARGS }})
    if [ ${#args[@]} -eq 0 ]; then
      bundle exec ruby test/all.rb
    else
      bundle exec ruby -e 'files = ARGV.dup; ARGV.clear; files.each { |f| require File.expand_path(f) }' "${args[@]}"
    fi

# The diagram renderer's tests (test/diagram_renderer/) need no database and
# need resvg at exactly ConceptQL::DiagramRenderer::Resvg::VERSION (mise.toml
# pins it; `just setup` installs it). The Postgres docker image and the DuckDB
# runs have no resvg, so test/all.rb leaves these tests out and this recipe
# runs them on the host. It fails, never skips, when resvg is missing or is
# another version. Part of `ci` (the pre-push gate).
# Run the diagram renderer tests on the host (args: test files; default all)
test-diagram *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ log_dir }}/diagram
    log={{ log_dir }}/diagram/$(date +%Y%m%d%H%M%S).txt
    exec 3>&1 > >(tee "$log") 2>&1
    tee_pid=$!
    finish() {
      rc=$?
      exec >&- 2>&-
      wait "$tee_pid" || true
      echo "Log: $log" >&3
      exit $rc
    }
    trap finish EXIT

    {{ just_executable() }} --justfile {{ justfile() }} resvg-check

    export CONCEPTQL_COVERAGE_DIR="{{ justfile_directory() }}/{{ log_dir }}/diagram/coverage"
    args=({{ ARGS }})
    if [ ${#args[@]} -eq 0 ]; then
      bundle exec ruby test/diagram_renderer/all.rb
    else
      bundle exec ruby -e 'files = ARGV.dup; ARGV.clear; files.each { |f| require File.expand_path(f) }' "${args[@]}"
    fi

# The diagram renderer (ConceptQL::DiagramRenderer) runs resvg, and its output
# is right only with resvg at exactly ConceptQL::DiagramRenderer::Resvg::VERSION.
# test-diagram and spec (so also spec-check) run this first. It fails, never
# skips, when resvg is missing or is another version.
# Fail unless resvg is on PATH at the version the diagram renderer needs
resvg-check:
    #!/usr/bin/env bash
    set -euo pipefail
    want=$(ruby -Ilib -rconceptql/diagram_renderer -e 'print ConceptQL::DiagramRenderer::Resvg::VERSION')
    if ! command -v resvg >/dev/null; then
      echo "resvg is not on PATH. The diagram renderer needs resvg ${want}: run \`just setup\` (mise.toml pins it)."
      exit 1
    fi
    have=$(resvg --version)
    if [ "$have" != "$want" ]; then
      echo "resvg ${have} is on PATH ($(command -v resvg)). The diagram renderer needs resvg ${want}: run \`just setup\` (mise.toml pins it)."
      exit 1
    fi
    echo "resvg ${have} ($(command -v resvg))"

# Rebuilds docs/spec/README.md from docs/spec/README.cql.md. docs/spec/build/run.rb
# runs every ConceptQL block on the DuckDB fixture (through test-duckdb, so it
# needs what test-duckdb needs) and writes each example: the statement, its
# diagram and the first 10 rows of its result. It draws every
# docs/spec/images/<sha>.svg with ConceptQL::DiagramRenderer, so it needs resvg
# (resvg-check), removes the SVG files that no example uses, and writes
# docs/spec/images/manifest.tsv. It also writes
# docs/spec/examples/<spec_id>.json (ConceptQL.spec_examples_path): the result
# rows and the diagram tree of each example of each published spec_id.
# Edit docs/spec/README.cql.md, never docs/spec/README.md.
# Like fmt-check, it rewrites first and THEN fails: commit what it changed.
# When the build fails (spec-check's images, an invalid example), it still
# names the files that changed, and then fails with the build's exit status.
# Rebuild docs/spec/README.md, its images and its example files; fail if they changed
spec:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p claude_stuff
    log=claude_stuff/spec-$(date +%Y%m%d-%H%M%S).log
    exec 3>&1 > >(tee "$log") 2>&1
    tee_pid=$!
    finish() {
      rc=$?
      exec >&- 2>&-
      wait "$tee_pid" || true
      echo "Log: $log" >&3
      exit $rc
    }
    trap finish EXIT

    {{ just_executable() }} --justfile {{ justfile() }} resvg-check
    # find fails on a path that does not exist yet (the first build writes it).
    snapshot() { { find docs/spec/README.md docs/spec/images docs/spec/examples -type f 2>/dev/null || true; } | sort | xargs -r sha256sum; }
    before=$(snapshot)
    build_rc=0
    {{ just_executable() }} test-duckdb docs/spec/build/run.rb || build_rc=$?
    treefmt --no-cache docs/spec/README.md docs/spec/examples
    changed=0
    after=$(snapshot)
    if [ "$after" != "$before" ]; then
      # Not `git status`: a rebuild that restores the committed file is a change too.
      echo "just spec changed these files; review and commit them:"
      { diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true; } | sed -n 's/^[<>] [0-9a-f]*  /  /p' | sort -u
      changed=1
    fi
    [ "$build_rc" -eq 0 ] || { echo "docs/spec/build/run.rb failed (exit $build_rc)"; exit "$build_rc"; }
    [ "$changed" -eq 0 ] || exit 1
    echo "docs/spec/README.md, docs/spec/images and docs/spec/examples are up to date"

# A step of release-check, and only of release-check: between releases, main
# may hold a stale spec and stale images (seed conceptql-mdo, decision 09), so
# ci, the pre-push hook and the workflows do not run it. It runs `just spec`
# with CONCEPTQL_SPEC_CHECK=1, so it needs what test-duckdb needs (the DuckDB
# fixture, linux amd64) and resvg (resvg-check). The build prints the Ruby and
# libduckdb versions that it used. It draws every image into a temporary
# directory and leaves docs/spec/images alone. It fails and names each image
# that differs from its new drawing, is missing, or is not used by an example.
# It also compares the sha256 of each diagram tree's canonical JSON with
# docs/spec/images/manifest.tsv, and names each image whose hash differs. Like `spec`, it
# rewrites docs/spec/README.md and docs/spec/examples first and THEN fails, also
# when an example file changed.
# Fail if docs/spec/README.md, a diagram image or an example file does not match the code
spec-check:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p claude_stuff
    log=claude_stuff/spec-check-$(date +%Y%m%d-%H%M%S).log
    exec 3>&1 > >(tee "$log") 2>&1
    tee_pid=$!
    finish() {
      rc=$?
      exec >&- 2>&-
      wait "$tee_pid" || true
      echo "Log: $log" >&3
      exit $rc
    }
    trap finish EXIT

    CONCEPTQL_SPEC_CHECK=1 {{ just_executable() }} --justfile {{ justfile() }} spec

# test and test-full run this when they exit. Each checkout (the primary, every
# worktree, the pre-push gate copy) has its own compose project, so without this
# every finished worktree left its test_data database running (59 were found on
# titan on 2026-11-02). It does nothing while another test run of this checkout
# still uses the database, and nothing when KEEP_TEST_DB is set.
# --volumes removes the anonymous volume that the test_data image declares
# (/var/lib/postgresql). The database lives in PGDATA=/data inside the image, so
# the volume is always empty. Without --volumes, every run left one dangling
# volume (153 were traced to conceptql runs on titan by 2026-11-12).
# Stop this checkout's test database unless a test run still uses it
test-db-down:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -z "${KEEP_TEST_DB:-}" ] || exit 0
    running=$(docker ps -q --filter "label=com.docker.compose.project.working_dir=${PWD}" --filter "label=com.docker.compose.oneoff=True")
    [ -z "$running" ] || { echo "test-db-down: another test run uses this checkout's database; leaving it up"; exit 0; }
    docker compose down --remove-orphans --volumes

# Run both Postgres CI matrix configs in parallel; fail if either fails
test-full:
    #!/usr/bin/env bash
    set -euo pipefail
    ts=$(date +%Y%m%d%H%M%S)
    mkdir -p {{ log_dir }}/gdm_wide {{ log_dir }}/gdm_ohdsi

    # Create or recreate test_data once, before the parallel runs. When its image
    # or config has changed, each `docker compose run` would try to recreate it,
    # and the losers fail with "container name ... is already in use".
    trap '{{ just_executable() }} --justfile {{ justfile() }} test-db-down' EXIT
    docker compose up -d test_data

    echo "Running both Postgres CI matrix configs in parallel..."

    SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide \
      docker compose run --rm conceptql 2>&1 | tee {{ log_dir }}/gdm_wide/${ts}.txt &
    pid1=$!

    SEQUELIZER_SEARCH_PATH=slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm \
      docker compose run --rm conceptql 2>&1 | tee {{ log_dir }}/gdm_ohdsi/${ts}.txt &
    pid2=$!

    failed=0
    for pid in $pid1 $pid2; do
      if ! wait $pid; then
        failed=1
      fi
    done

    echo ""
    echo "=== Results ==="
    for log in {{ log_dir }}/gdm_*/${ts}.txt; do
      name=$(basename "$(dirname "$log")")
      summary=$(grep -E '^[0-9]+ runs' "$log" || echo "NO SUMMARY FOUND")
      if echo "$summary" | grep -qE '0 failures, 0 errors'; then
        echo "  ✓ ${name}: ${summary}"
      else
        echo "  ✗ ${name}: ${summary}"
      fi
    done

    ln -sf "gdm_wide/${ts}.txt" {{ log_dir }}/latest.txt

    if [ $failed -ne 0 ]; then
      echo ""
      echo "FAILED: one or more configs had errors"
      exit 1
    fi
    echo ""
    echo "All configs passed."

bundle-update *ARGS:
    bundle update {{ ARGS }}

# config/vocabulary_formats.tsv is a copy of the published table of the public
# repository outcomesinsights/vocabulary_formats, and the code-format check
# reads it (bead conceptql-bns). config/vocabulary_formats.sha records the
# commit it came from. The recipe resolves the ref to a commit SHA first and
# downloads that commit, so the copy and the SHA always agree. Review the diff
# of the TSV and run `just ci` before you commit a refresh.
# Refresh config/vocabulary_formats.tsv from GitHub (arg: a branch or commit SHA)
vocabulary-formats $ref="main":
    #!/usr/bin/env bash
    set -euo pipefail
    repo=outcomesinsights/vocabulary_formats
    sha=$(curl -fsSL -H 'Accept: application/vnd.github.sha' "https://api.github.com/repos/${repo}/commits/${ref}") \
      || { echo "GitHub did not resolve '${ref}' to a commit of ${repo}"; exit 1; }
    [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "GitHub answered '${sha}' for '${ref}', not a commit SHA"; exit 1; }
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    curl -fsSL "https://raw.githubusercontent.com/${repo}/${sha}/vocabulary_formats.tsv" -o "$tmp"
    head -1 "$tmp" | tr '\t' '\n' | grep -qx vocabulary_id || { echo "${repo}@${sha}: vocabulary_formats.tsv has no vocabulary_id column"; exit 1; }
    head -1 "$tmp" | tr '\t' '\n' | grep -qx regexp || { echo "${repo}@${sha}: vocabulary_formats.tsv has no regexp column"; exit 1; }
    cat "$tmp" > config/vocabulary_formats.tsv
    echo "$sha" > config/vocabulary_formats.sha
    echo "config/vocabulary_formats.tsv is now ${repo}@${sha}"

# Run before every release (CLAUDE.md, Releasing). Fails when a gem is behind
# the newest version conceptql could use:
# - the lock is not current: `bundle lock --update --print` resolves the newest
#   allowed versions without writing, and must match Gemfile.lock;
# - a bound in conceptql.gemspec or the Gemfile excludes the newest release.
# A gem held back only by another gem's constraint is printed and does not fail,
# because conceptql cannot change it. Fix a failure with `just bundle-update`.
# Then it runs spec-check, which fails when docs/spec/README.md, a diagram
# image or an example file does not match the code.
# Fail if a gem is behind the newest version conceptql could use, or the spec is stale
release-check:
    #!/usr/bin/env bash
    set -euo pipefail
    rc=0
    fresh=$(bundle lock --update --print 2>/dev/null)
    if ! diff -u Gemfile.lock <(printf '%s\n' "$fresh") >/dev/null; then
      echo "FAIL Gemfile.lock is not current. \`bundle lock --update\` would change:"
      diff -u Gemfile.lock <(printf '%s\n' "$fresh") | grep -E '^[-+]    [a-z]' | sed 's/^/  /' || true
      rc=1
    fi
    outdated=$(bundle outdated --parseable 2>/dev/null || true)
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      verdict=$(printf '%s\n' "$line" | FRESH="$fresh" ruby -e '
        line = $stdin.read
        name = line[/\A(\S+)/, 1]
        newest = line[/newest ([^\s,]+)/, 1]
        requested = line[/requested ([^)]+)/, 1]
        if requested && !Gem::Requirement.new(requested.split(", ")).satisfied_by?(Gem::Version.new(newest))
          puts "FAIL #{name} #{newest} is excluded by our own bound \"#{requested}\""
        elsif ENV.fetch("FRESH").include?("\n    #{name} (#{newest}")
          puts "behind #{name}: #{newest} is allowed but not locked"
        else
          puts "info #{name} #{newest} is held back by another gem"
        end')
      echo "$verdict"
      case "$verdict" in FAIL*) rc=1 ;; esac
    done <<<"$outdated"
    [ $rc -eq 0 ] && echo "ok   every gem is at the newest version conceptql allows"
    {{ just_executable() }} --justfile {{ justfile() }} spec-check || { echo "FAIL just spec-check"; rc=1; }
    exit $rc

# Local pre-push CI gate. GitHub CI runs the same recipes: its lint job runs
# lint, fmt-check and hygiene, its Postgres job runs `test` and its DuckDB job
# runs `test-duckdb`. Locally `test` runs only the default Postgres gdm_wide
# config (the primary platform). The other Postgres config and Spark stay in
# remote CI as the last line of defense for cross-env edge cases. test-duckdb
# fails, never skips, when its fixture or libduckdb is unavailable. Then
# test-diagram runs the diagram renderer tests, which fail when resvg is not
# the pinned version. Run `just test-full` for both Postgres configs.
#
# The pre-push hook (.githooks/pre-push, gator's standard) runs this at each pushed
# commit, in a gate worktree under ~/.cache/gator-gate/, then publishes the beads
# with bd-publish. A commit that already passed there is not re-run.
# Lint, then the Postgres and DuckDB suites in parallel, then the diagram renderer tests and hygiene
ci: lint fmt-check test-both test-diagram hygiene

# The two suites share no state: test uses the docker test_data database and
# writes coverage/; test-duckdb tests a per-run copy of its fixture and writes its
# coverage under claude_stuff/test-logs/duckdb/. Their output interleaves on the
# terminal, and each one also writes its own log under claude_stuff/test-logs/.
# Run the Postgres gdm_wide suite and the DuckDB suite at the same time
[parallel]
test-both: test test-duckdb

# Formats every tracked file in every language here (treefmt.toml), including
# RuboCop's safe autocorrections. The suite writes new expected-results files in
# prettier's layout (test/prettier_json.rb), so they need no extra pass.
# Rewrite files to canonical format. Run deliberately; never from a hook.
fmt:
    treefmt

# Fails if `fmt` would change anything. It formats the tree first and THEN fails
# (fix-and-fail): re-stage what it changed. It never rewrites and succeeds.
fmt-check:
    treefmt --fail-on-change

# What actually runs before a push. Defaults to the complete `ci`; point it at
# something smaller ONLY where running complete CI locally is impractical.
pre-push: ci

# Reports and never rewrites: rubocop's safe autocorrections run in `fmt`, never
# here. Tools come from mise.toml; a missing one fails the recipe. cog checks the
# commit subjects since the last v* tag, or the last 20 commits before the first
# tag (a shallow clone fails here, loudly).
# Every non-rewriting check: rubocop, shellcheck, actionlint, zizmor, hadolint, cog
lint:
    bundle exec rubocop
    shellcheck $(git ls-files '*.sh' '*.bash')
    actionlint
    zizmor --offline .
    git ls-files '*Dockerfile' '*.Dockerfile' | xargs -r hadolint
    tag="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)" && cog check --ignore-merge-commits "${tag:-HEAD~20}..HEAD"

# Installs the pinned tools (mise.toml) and the bundle. A clone needs git and mise.
setup:
    mise install
    bundle install
    @if [ -d .beads ] && [ ! -d .beads/embeddeddolt ] && command -v bd >/dev/null 2>&1; then bd bootstrap; fi
    @if [ -d .githooks ]; then git config core.hooksPath .githooks; fi

# Runs on every commit, so it must stay FAST — a sub-minute budget. Tests belong
# here when they fit; lint alone when they do not. fmt-check never rewrites.
pre-commit: lint fmt-check hygiene seeds-check

# Gator's standard seeds-check: `seeds check --gate` compares the seed store with
# HEAD, so a seed body rewritten in place fails the commit (SEEDS_GATE_CONFIRM=1 allows
# an intended rewrite). It belongs at commit
# (at push it would compare HEAD~1 with HEAD only). It skips where there is no seed
# store or no seeds binary (a clone without the nix tools).
seeds-check:
    #!/usr/bin/env sh
    [ -d .seeds ] || exit 0
    command -v seeds >/dev/null 2>&1 || exit 0
    exec seeds check --gate

# Content checks inherited from overcommit when it was removed (2026-09-12):
# MergeConflicts, YamlSyntax, JsonSyntax. RuboCop and the test target were already
# covered by fmt-check/lint/test; HardTabs and TrailingWhitespace were dropped because
# they fight shfmt, .tsv, and generated files.
hygiene:
    #!/usr/bin/env bash
    set -uo pipefail
    rc=0
    bad=$(git ls-files | xargs -r grep -IlE '^(<{7}|={7}|>{7})( |$)' 2>/dev/null || true)
    [ -n "$bad" ] && { echo "merge conflict markers:"; printf '%s\n' "$bad" | sed 's/^/  /'; rc=1; }
    for f in $(git ls-files '*.yml' '*.yaml'); do
      python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "$f" 2>/dev/null \
        || { echo "invalid YAML: $f"; rc=1; }
    done
    for f in $(git ls-files '*.json'); do
      jq empty "$f" 2>/dev/null || { echo "invalid JSON: $f"; rc=1; }
    done
    exit $rc
