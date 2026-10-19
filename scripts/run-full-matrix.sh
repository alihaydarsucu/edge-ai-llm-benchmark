#!/usr/bin/env bash
#
# run-full-matrix.sh — speed matrix for llama.cpp on edge SBCs.
#
# Measures prompt processing (pp512) and token generation (tg128) for every
# combination of quantization, backend, thread count, and repeat. Results are
# written to results/<platform>/<run-id>/ together with the raw llama-bench
# output, an environment manifest, and test start/end timestamps.
#
# Usage:
#   ./scripts/run-full-matrix.sh
#   PLATFORM=arduino-uno-q BACKENDS="cpu:0" ./scripts/run-full-matrix.sh
#
# Environment overrides:
#   PLATFORM            Platform slug (default: gemstone-o1)
#   LLAMA_BIN           Directory containing llama-bench (default: ~/llama.cpp/build/bin)
#   MODELS_DIR          Directory containing GGUF files (default: ~/models)
#   MODEL_PREFIX        GGUF filename prefix (default: qwen2.5-1.5b-instruct)
#   QUANTS              Space-separated quantization tags (default: q4_0 q4_k_m q5_k_m q8_0)
#   BACKENDS            name:ngl pairs (default: "cpu:0"; add "gpu:999" for Vulkan)
#   THREADS             Space-separated thread counts (default: "1 2 3 4")
#   REPEATS             Repetitions per configuration (default: 2)
#   COOLDOWN_SECONDS    Pause between runs (default: 3)
#   ALLOW_CPU_FALLBACK  Set to 1 to run "gpu" configs even if Vulkan is missing
#
# Output layout:
#   results/<platform>/<run-id>/
#     environment.txt
#     results/all_results.csv
#     results/test_boundaries.csv
#     results/summary.txt
#     raw/<tag>.txt
#     logs/<tag>-time.txt
#
set -uo pipefail

PLATFORM="${PLATFORM:-gemstone-o1}"
LLAMA_BIN="${LLAMA_BIN:-$HOME/llama.cpp/build/bin}"
MODELS_DIR="${MODELS_DIR:-$HOME/models}"
MODEL_PREFIX="${MODEL_PREFIX:-qwen2.5-1.5b-instruct}"
QUANTS="${QUANTS:-q4_0 q4_k_m q5_k_m q8_0}"
BACKENDS="${BACKENDS:-cpu:0}"
THREADS="${THREADS:-1 2 3 4}"
REPEATS="${REPEATS:-2}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-3}"
ALLOW_CPU_FALLBACK="${ALLOW_CPU_FALLBACK:-0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ID="run-$(date +%Y%m%d-%H%M%S)"
BASE_DIR="$ROOT_DIR/results/$PLATFORM/$RUN_ID"
RESULTS_DIR="$BASE_DIR/results"
LOGS_DIR="$BASE_DIR/logs"
RAW_DIR="$BASE_DIR/raw"

BENCH_BIN="$LLAMA_BIN/llama-bench"
SUMMARY="$RESULTS_DIR/summary.txt"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -x "$BENCH_BIN" ]] || die "llama-bench not found at $BENCH_BIN"

mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$RAW_DIR"
: > "$SUMMARY"

# ---------------------------------------------------------------------------
# Environment manifest
# ---------------------------------------------------------------------------
ENV_FILE="$BASE_DIR/environment.txt"
{
    echo "# Benchmark environment"
    echo "platform: $PLATFORM"
    echo "run_id: $RUN_ID"
    echo "started: $(date -Is)"
    echo "hostname: $(hostname 2>/dev/null || echo unknown)"
    echo "kernel: $(uname -srmo)"
    echo
    echo "## Hardware"
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | grep -E '^(Architecture|Model name|CPU\(s\)|Thread|Core|Socket|CPU max|CPU min)' || true
    fi
    if [[ -r /proc/meminfo ]]; then
        grep -E '^(MemTotal|MemAvailable|SwapTotal)' /proc/meminfo || true
    fi
    echo
    echo "## Software"
    echo "llama_bin: $LLAMA_BIN"
    echo "models_dir: $MODELS_DIR"
    echo "quantizations: $QUANTS"
    echo "backends: $BACKENDS"
    echo "threads: $THREADS"
    echo "repeats: $REPEATS"
    echo
    "$BENCH_BIN" --version 2>&1 || true
    echo
    for model in "$MODELS_DIR"/"$MODEL_PREFIX"-*.gguf; do
        [[ -f "$model" ]] || continue
        echo "model: $(basename "$model")"
        echo "size_bytes: $(stat -c %s "$model")"
        if command -v sha256sum >/dev/null 2>&1; then
            echo "sha256: $(sha256sum "$model" | cut -d' ' -f1)"
        fi
    done
} > "$ENV_FILE" 2>&1

# ---------------------------------------------------------------------------
# Backend safety check
# ---------------------------------------------------------------------------
if printf '%s\n' $BACKENDS | grep -q '^gpu:'; then
    if ! { strings "$BENCH_BIN" 2>/dev/null || cat "$BENCH_BIN"; } | grep -aqi 'vulkan'; then
        if [[ "$ALLOW_CPU_FALLBACK" == "1" ]]; then
            echo "WARNING: no Vulkan trace in llama-bench; GPU configs may fall back to CPU." | tee -a "$SUMMARY"
        else
            die "llama-bench does not look Vulkan-enabled, but a gpu backend was requested. Rebuild with -DGGML_VULKAN=ON or set ALLOW_CPU_FALLBACK=1."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Resolve available quantizations
# ---------------------------------------------------------------------------
AVAILABLE_QUANTS=()
for quant in $QUANTS; do
    model_path="$MODELS_DIR/${MODEL_PREFIX}-${quant}.gguf"
    if [[ -f "$model_path" ]]; then
        AVAILABLE_QUANTS+=("$quant")
    else
        echo "WARNING: $model_path not found; skipping '$quant'." | tee -a "$SUMMARY"
    fi
done

[[ ${#AVAILABLE_QUANTS[@]} -gt 0 ]] || die "No GGUF files found in $MODELS_DIR for prefix '$MODEL_PREFIX'."

read -r -a BACKEND_LIST <<< "$BACKENDS"
read -r -a THREAD_LIST <<< "$THREADS"
TOTAL_CONFIGS=$(( ${#AVAILABLE_QUANTS[@]} * ${#BACKEND_LIST[@]} * ${#THREAD_LIST[@]} * REPEATS ))

MASTER_CSV="$RESULTS_DIR/all_results.csv"
echo "quant,backend,ngl,threads,repeat,pp_tps,tg_tps,ram_mb,model_size_mb,timestamp" > "$MASTER_CSV"

BOUNDARIES_CSV="$RESULTS_DIR/test_boundaries.csv"
echo "tag,start_ts,end_ts" > "$BOUNDARIES_CSV"

{
    echo "=== $PLATFORM FULL MATRIX BENCHMARK ==="
    echo "Run ID: $RUN_ID"
    echo "Started: $(date -Is)"
    echo "Configurations: $TOTAL_CONFIGS (${#AVAILABLE_QUANTS[@]} quant x ${#BACKEND_LIST[@]} backend x ${#THREAD_LIST[@]} threads x $REPEATS repeats)"
    echo
} | tee -a "$SUMMARY"

# GNU time is optional; RAM stays NA when it is unavailable.
TIME_BIN=""
if [[ -x /usr/bin/time ]] && /usr/bin/time -v true >/dev/null 2>&1; then
    TIME_BIN="/usr/bin/time"
else
    echo "WARNING: GNU time not found; ram_mb will be NA. Install the 'time' package." | tee -a "$SUMMARY"
fi

parse_tps() {
    local file="$1" test_name="$2"
    awk -F'|' -v t="$test_name" '
        index($0, t) {
            value = $(NF - 1)
            gsub(/ /, "", value)
            sub(/±.*/, "", value)
            print value
            exit
        }
    ' "$file"
}

CURRENT=0
FAILED=0
INTERRUPTED=0

on_interrupt() {
    INTERRUPTED=1
    {
        echo
        echo "=== INTERRUPTED at $(date -Is) ==="
        echo "Completed $CURRENT/$TOTAL_CONFIGS configurations before interruption."
    } | tee -a "$SUMMARY"
    exit 130
}
trap on_interrupt INT TERM

for quant in "${AVAILABLE_QUANTS[@]}"; do
    model_path="$MODELS_DIR/${MODEL_PREFIX}-${quant}.gguf"
    model_size_mb=$(du -m "$model_path" | cut -f1)

    for backend_pair in "${BACKEND_LIST[@]}"; do
        backend_name="${backend_pair%%:*}"
        ngl="${backend_pair##*:}"

        for threads in "${THREAD_LIST[@]}"; do
            for repeat in $(seq 1 "$REPEATS"); do
                CURRENT=$((CURRENT + 1))
                tag="${quant}-${backend_name}-t${threads}-r${repeat}"
                raw_file="$RAW_DIR/${tag}.txt"
                time_file="$LOGS_DIR/${tag}-time.txt"

                echo "[$CURRENT/$TOTAL_CONFIGS] $tag" | tee -a "$SUMMARY"
                start_ts=$(date +%Y-%m-%dT%H:%M:%S)

                bench_args=(
                    -m "$model_path"
                    -p 512
                    -n 128
                    -t "$threads"
                    -ngl "$ngl"
                )

                if [[ -n "$TIME_BIN" ]]; then
                    "$TIME_BIN" -v -o "$time_file" "$BENCH_BIN" "${bench_args[@]}" \
                        > "$raw_file" 2>&1
                else
                    "$BENCH_BIN" "${bench_args[@]}" > "$raw_file" 2>&1
                fi

                end_ts=$(date +%Y-%m-%dT%H:%M:%S)
                echo "${tag},${start_ts},${end_ts}" >> "$BOUNDARIES_CSV"

                pp_tps=$(parse_tps "$raw_file" "pp512")
                tg_tps=$(parse_tps "$raw_file" "tg128")

                ram_mb="NA"
                if [[ -f "$time_file" ]]; then
                    rss_kb=$(awk -F': ' '/Maximum resident set size/ {print $2}' "$time_file")
                    if [[ -n "${rss_kb:-}" ]]; then
                        ram_mb=$(awk -v kb="$rss_kb" 'BEGIN {printf "%.0f", kb / 1024}')
                    fi
                fi

                if [[ -z "$pp_tps" || -z "$tg_tps" ]]; then
                    FAILED=$((FAILED + 1))
                    echo "  -> WARNING: could not parse llama-bench output (see $raw_file)" | tee -a "$SUMMARY"
                fi

                echo "${quant},${backend_name},${ngl},${threads},${repeat},${pp_tps:-NA},${tg_tps:-NA},${ram_mb},${model_size_mb},${end_ts}" >> "$MASTER_CSV"

                sleep "$COOLDOWN_SECONDS"
            done
        done
    done
done

trap - INT TERM

{
    echo
    echo "=== COMPLETED at $(date -Is) ==="
    echo "Configurations run: $CURRENT/$TOTAL_CONFIGS"
    echo "Parse failures: $FAILED"
    echo "Results: $MASTER_CSV"
    echo "Raw output: $RAW_DIR"
} | tee -a "$SUMMARY"
