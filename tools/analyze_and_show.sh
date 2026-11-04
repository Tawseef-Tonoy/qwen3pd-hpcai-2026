#!/bin/bash
set -euo pipefail

EXP="${1:?Usage: tools/analyze_and_show.sh <experiment-dir> [exploratory|official] [concurrency]}"

MODE="${2:-exploratory}"
CONCURRENCY="${3:-}"

echo
echo "Running analysis..."
echo

if [[ -n "${CONCURRENCY}" ]]; then
    python3 tools/analyze_aiperf.py \
        "${EXP}" \
        --mode "${MODE}" \
        --concurrency "${CONCURRENCY}"
else
    python3 tools/analyze_aiperf.py \
        "${EXP}" \
        --mode "${MODE}"
fi

echo
echo "Displaying decision dashboard..."
echo

python3 tools/show_analysis.py \
    "${EXP}" \
    --no-report
