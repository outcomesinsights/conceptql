log_dir := "claude_stuff/test-logs"

# Run all three CI matrix configs in parallel; fail if any fails
test:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{log_dir}}
    ts=$(date +%Y%m%d-%H%M%S)

    echo "Running all 3 CI matrix configs in parallel..."

    SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide \
      docker compose run --rm conceptql 2>&1 | tee {{log_dir}}/gdm_wide-${ts}.log &
    pid1=$!

    SEQUELIZER_SEARCH_PATH=slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm \
      docker compose run --rm conceptql 2>&1 | tee {{log_dir}}/gdm_ohdsi-${ts}.log &
    pid2=$!

    SEQUELIZER_SEARCH_PATH=slim,gdm_vocabs CONCEPTQL_DATA_MODEL=gdm \
      docker compose run --rm conceptql 2>&1 | tee {{log_dir}}/gdm_vocabs-${ts}.log &
    pid3=$!

    failed=0
    for pid in $pid1 $pid2 $pid3; do
      if ! wait $pid; then
        failed=1
      fi
    done

    echo ""
    echo "=== Results ==="
    for log in {{log_dir}}/*-${ts}.log; do
      name=$(basename "$log" -${ts}.log)
      summary=$(grep -E '^\d+ runs' "$log" || echo "NO SUMMARY FOUND")
      if echo "$summary" | grep -qE '0 failures, 0 errors'; then
        echo "  ✓ ${name}: ${summary}"
      else
        echo "  ✗ ${name}: ${summary}"
      fi
    done

    if [ $failed -ne 0 ]; then
      echo ""
      echo "FAILED: one or more configs had errors"
      exit 1
    fi
    echo ""
    echo "All configs passed."

# Run a single config (gdm_wide by default)
test-quick:
    SEQUELIZER_SEARCH_PATH=wide,slim,ohdsi_vocabs CONCEPTQL_DATA_MODEL=gdm_wide \
      docker compose run --rm conceptql
