log_dir := "claude_stuff/test-logs"

# Run gdm_wide (default quick test)
test *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{log_dir}}/test
    ts=$(date +%Y%m%d%H%M%S)
    log={{log_dir}}/test/${ts}.txt

    SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide \
      docker compose run --rm conceptql {{ARGS}} 2>&1 | tee "$log"

    ln -sf "test/${ts}.txt" {{log_dir}}/latest.txt
    echo "Log: $log"

# Run all three CI matrix configs in parallel; fail if any fails
test-full:
    #!/usr/bin/env bash
    set -euo pipefail
    ts=$(date +%Y%m%d%H%M%S)
    mkdir -p {{log_dir}}/gdm_wide {{log_dir}}/gdm_ohdsi {{log_dir}}/gdm_vocabs

    echo "Running all 3 CI matrix configs in parallel..."

    SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide \
      docker compose run --rm conceptql 2>&1 | tee {{log_dir}}/gdm_wide/${ts}.txt &
    pid1=$!

    SEQUELIZER_SEARCH_PATH=slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm \
      docker compose run --rm conceptql 2>&1 | tee {{log_dir}}/gdm_ohdsi/${ts}.txt &
    pid2=$!

    SEQUELIZER_SEARCH_PATH=slim,gdm_vocabs CONCEPTQL_DATA_MODEL=gdm \
      docker compose run --rm conceptql 2>&1 | tee {{log_dir}}/gdm_vocabs/${ts}.txt &
    pid3=$!

    failed=0
    for pid in $pid1 $pid2 $pid3; do
      if ! wait $pid; then
        failed=1
      fi
    done

    echo ""
    echo "=== Results ==="
    for log in {{log_dir}}/gdm_*/${ts}.txt; do
      name=$(basename "$(dirname "$log")")
      summary=$(grep -E '^[0-9]+ runs' "$log" || echo "NO SUMMARY FOUND")
      if echo "$summary" | grep -qE '0 failures, 0 errors'; then
        echo "  ✓ ${name}: ${summary}"
      else
        echo "  ✗ ${name}: ${summary}"
      fi
    done

    ln -sf "gdm_wide/${ts}.txt" {{log_dir}}/latest.txt

    if [ $failed -ne 0 ]; then
      echo ""
      echo "FAILED: one or more configs had errors"
      exit 1
    fi
    echo ""
    echo "All configs passed."

bundle-update *ARGS:
    bundle update {{ARGS}}
