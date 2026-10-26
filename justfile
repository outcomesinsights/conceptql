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
# run its other two configs.
# Run gdm_wide (default quick test)
test *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ log_dir }}/test
    ts=$(date +%Y%m%d%H%M%S)
    log={{ log_dir }}/test/${ts}.txt

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

# Run all three CI matrix configs in parallel; fail if any fails
test-full:
    #!/usr/bin/env bash
    set -euo pipefail
    ts=$(date +%Y%m%d%H%M%S)
    mkdir -p {{ log_dir }}/gdm_wide {{ log_dir }}/gdm_ohdsi {{ log_dir }}/gdm_vocabs

    echo "Running all 3 CI matrix configs in parallel..."

    SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide \
      docker compose run --rm conceptql 2>&1 | tee {{ log_dir }}/gdm_wide/${ts}.txt &
    pid1=$!

    SEQUELIZER_SEARCH_PATH=slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm \
      docker compose run --rm conceptql 2>&1 | tee {{ log_dir }}/gdm_ohdsi/${ts}.txt &
    pid2=$!

    SEQUELIZER_SEARCH_PATH=slim,gdm_vocabs CONCEPTQL_DATA_MODEL=gdm \
      docker compose run --rm conceptql 2>&1 | tee {{ log_dir }}/gdm_vocabs/${ts}.txt &
    pid3=$!

    failed=0
    for pid in $pid1 $pid2 $pid3; do
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

# Run before every release (CLAUDE.md, Releasing). Fails when a gem is behind
# the newest version conceptql could use:
# - the lock is not current: `bundle lock --update --print` resolves the newest
#   allowed versions without writing, and must match Gemfile.lock;
# - a bound in conceptql.gemspec or the Gemfile excludes the newest release.
# A gem held back only by another gem's constraint is printed and does not fail,
# because conceptql cannot change it. Fix a failure with `just bundle-update`.
# Fail if any gem is behind the newest version conceptql could use
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
    exit $rc

# Local pre-push CI gate. GitHub CI runs the same recipes: its lint job runs
# lint, fmt-check and hygiene, its Postgres job runs `test` and its DuckDB job
# runs `test-duckdb`. Locally `test` runs only the default Postgres gdm_wide
# config (the primary platform). The other 2 Postgres configs and Spark stay in
# remote CI as the last line of defense for cross-env edge cases. test-duckdb
# fails, never skips, when its fixture or libduckdb is unavailable. Run
# `just test-full` for all 3 Postgres configs.
#
# The pre-push hook (.githooks/pre-push, gator's standard) runs this at each pushed
# commit, in a gate worktree under ~/.cache/gator-gate/, then publishes the beads
# with bd-publish. A commit that already passed there is not re-run.
# Lint, then the Postgres and DuckDB suites in parallel, then hygiene
ci: lint fmt-check test-both hygiene

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

# Gator's standard seeds-check: `seeds check --against-git` compares the seed store
# with HEAD, so a seed body rewritten in place fails the commit. It belongs at commit
# (at push it would compare HEAD~1 with HEAD only). It skips where there is no seed
# store or no seeds binary (a clone without the nix tools).
seeds-check:
    #!/usr/bin/env sh
    [ -d .seeds ] || exit 0
    command -v seeds >/dev/null 2>&1 || exit 0
    exec seeds check --against-git

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
