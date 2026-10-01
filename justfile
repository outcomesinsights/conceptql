log_dir := "claude_stuff/test-logs"

# Run gdm_wide (default quick test)
test *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ log_dir }}/test
    ts=$(date +%Y%m%d%H%M%S)
    log={{ log_dir }}/test/${ts}.txt

    SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide \
      docker compose run --rm conceptql {{ ARGS }} 2>&1 | tee "$log"

    ln -sf "test/${ts}.txt" {{ log_dir }}/latest.txt
    echo "Log: $log"

# Mirrors CI's Run-DuckDB-Tests job (.github/workflows/run_tests.yml) on host Ruby.
# Tests write temp tables into the database file and the default source is a
# PUBLISHED Dropbox share, so the source is never opened: each run copies it to a
# scratch dir, verifies the copy against the committed checksum, tests the copy,
# and deletes it. libduckdb is cached per version under ~/.cache/conceptql/libduckdb.
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

    # libduckdb version from the duckdb gem in Gemfile.lock, as CI's "Derive DuckDB Version"
    version=$(sed -nE '/^GEM$/,/^$/ s/^    duckdb \(([0-9]+\.[0-9]+\.[0-9]+)[^)]*\)$/\1/p' Gemfile.lock)
    [ -n "$version" ] || { echo "No duckdb gem in Gemfile.lock's GEM section"; exit 1; }
    libdir="${XDG_CACHE_HOME:-$HOME/.cache}/conceptql/libduckdb/v${version}"
    if [ ! -f "$libdir/libduckdb.so" ]; then
      echo "Downloading libduckdb v${version} to $libdir"
      rm -rf "$libdir.tmp"
      mkdir -p "$libdir.tmp"
      curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v${version}/libduckdb-linux-amd64.zip" \
        -o "$libdir.tmp/libduckdb.zip"
      unzip -q "$libdir.tmp/libduckdb.zip" -d "$libdir.tmp"
      rm "$libdir.tmp/libduckdb.zip"
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
    # `just test` (docker) leaves a root-owned coverage/; keep this run's report out of it.
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

# `bundle update --source`, not `bundle lock --update`: the latter once bumped
# sequel-duckdb's version to 0.2.1 but left its revision at the 0.1.0 commit, an
# uninstallable lock (conceptql-stt). check-oi-pins then fails if any revision
# still differs from its remote branch. A bundler local.<gem> override pins the
# local checkout's HEAD instead, so the check also catches an unpushed one.
# Re-pin this gem's OI git deps to their current main HEAD (review the diff)
bump-oi: && check-oi-pins
    bundle update --source sequelizer sequel-duckdb sequel-hexspace
    @git --no-pager diff --stat -- Gemfile.lock

# Fail unless every OI GIT block in the lock is pinned to its remote branch HEAD
check-oi-pins lock="Gemfile.lock":
    #!/usr/bin/env bash
    set -euo pipefail
    pins=$(awk '/^[A-Z]/ { git = ($0 == "GIT"); remote = rev = ""; branch = "main" }
      git && /^  remote: / { remote = $2 }
      git && /^  revision: / { rev = $2 }
      git && /^  branch: / { branch = $2 }
      git && /^  specs:$/ && remote ~ /github\.com\/outcomesinsights\// { print remote, rev, branch }' "{{ lock }}")
    [ -n "$pins" ] || { echo "No OI GIT blocks found in {{ lock }}"; exit 1; }
    rc=0
    while read -r remote rev branch; do
      head=$(git ls-remote "$remote" "refs/heads/$branch" </dev/null | cut -f1)
      if [ -z "$head" ]; then
        echo "FAIL $remote: no refs/heads/$branch on the remote"; rc=1
      elif [ "$rev" != "$head" ]; then
        echo "FAIL $remote: locked at $rev but $branch is $head"; rc=1
      else
        echo "ok   $remote $rev"
      fi
    done <<<"$pins"
    [ $rc -eq 0 ] || echo "{{ lock }} is not pinned to OI main: run 'bundle update --source <gem>' and re-check"
    exit $rc

# Local pre-push CI gate — runs the default Postgres gdm_wide config (the
# primary platform) and the DuckDB suite before allowing a push. The other 2
# Postgres configs and Spark stay in remote CI as the last line of defense for
# cross-env edge cases. test-duckdb fails, never skips, when its fixture or
# libduckdb is unavailable. Wired into the pre-push git hook; bypass with:
#   git push --no-verify   (or SKIP_CI_GATE=1 git push)
# Run `just test-full` to exercise all 3 Postgres configs manually.
ci: fmt-check test test-duckdb hygiene

# Rewrite files to canonical format. Run deliberately; never from a hook.
fmt:
    git ls-files "*.sh" | xargs -r shfmt -w
    just --fmt --unstable
    git ls-files "*.md" | xargs -r mdformat

# Report format drift without changing anything. This is what the hooks run —
# a formatter that rewrites files mid-commit changes what you already reviewed.
fmt-check:
    git ls-files "*.sh" | xargs -r shfmt -d
    just --fmt --check --unstable
    git ls-files "*.md" | xargs -r mdformat --check

# What actually runs before a push. Defaults to the complete `ci`; point it at
# something smaller ONLY where running complete CI locally is impractical.
pre-push: ci

# Runs on every commit, so it must stay FAST — a sub-minute budget. Tests belong
# here when they fit; lint alone when they do not. fmt-check never rewrites.
pre-commit: fmt-check hygiene

# Content checks inherited from overcommit when it was removed (2026-09-12):
# MergeConflicts, YamlSyntax, JsonSyntax. RuboCop and the test target were already
# covered by fmt-check/lint/test; HardTabs and TrailingWhitespace were dropped because
# they fight shfmt, .tsv, and generated files. See habituate/standards.md.
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
