#!/usr/bin/env bash
#
# temp-logger.sh — record SoC thermal zones while a benchmark runs.
#
# Run this in a second SSH/tmux session before starting the speed matrix:
#   ./scripts/temp-logger.sh results/gemstone-o1/run-20260821-145314
#
# Output: <run-dir>/logs/temperature.csv
#
set -uo pipefail

RUN_DIR="${1:-}"
if [[ -z "$RUN_DIR" ]]; then
    echo "Usage: $0 <run-directory>" >&2
    exit 1
fi

OUT_DIR="$RUN_DIR/logs"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/temperature.csv"

if [[ ! -f "$OUT_FILE" ]]; then
    echo "timestamp,zone,temp_c" > "$OUT_FILE"
fi

echo "Logging thermal zones to $OUT_FILE (Ctrl+C to stop)."
echo "interval_seconds=${INTERVAL_SECONDS:-5}"

INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"

while true; do
    ts=$(date +%Y-%m-%dT%H:%M:%S)
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [[ -r "$zone" ]] || continue
        zone_id=$(basename "$(dirname "$zone")")
        raw_temp=$(cat "$zone")
        temp_c=$(awk -v raw="$raw_temp" 'BEGIN {printf "%.1f", raw / 1000}')
        echo "${ts},${zone_id},${temp_c}" >> "$OUT_FILE"
    done
    sleep "$INTERVAL_SECONDS"
done
