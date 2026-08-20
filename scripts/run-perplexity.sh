#!/usr/bin/env bash
#
# run-perplexity.sh — quality check on WikiText-2 raw test data.
#
# Perplexity is a property of the model and quantization, not of the thread
# count, so it is measured once per quantization outside the speed matrix.
#
# Download the corpus first:
#   wget https://huggingface.co/datasets/ggml-org/ci/resolve/main/wikitext-2-raw-v1.zip
#   unzip wikitext-2-raw-v1.zip -d ~/models
#
# Usage:
#   ./scripts/run-perplexity.sh results/gemstone-o1/run-20260821-145314
#
# Environment overrides:
#   LLAMA_BIN, MODELS_DIR, WIKITEXT, MODEL_PREFIX, QUANTS, CHUNKS
#
set -uo pipefail

RUN_DIR="${1:-}"
if [[ -z "$RUN_DIR" ]]; then
    echo "Usage: $0 <run-directory>" >&2
    exit 1
fi
[[ -d "$RUN_DIR" ]] || { echo "ERROR: no such directory: $RUN_DIR" >&2; exit 1; }

LLAMA_BIN="${LLAMA_BIN:-$HOME/llama.cpp/build/bin}"
MODELS_DIR="${MODELS_DIR:-$HOME/models}"
MODEL_PREFIX="${MODEL_PREFIX:-qwen2.5-1.5b-instruct}"
QUANTS="${QUANTS:-q4_0 q4_k_m q5_k_m q8_0}"
WIKITEXT="${WIKITEXT:-$MODELS_DIR/wikitext-2-raw/wiki.test.raw}"
CHUNKS="${CHUNKS:-30}"

if [[ ! -f "$WIKITEXT" ]]; then
    echo "ERROR: $WIKITEXT not found. Download wikitext-2-raw-v1.zip first." >&2
    exit 1
fi

if [[ -x "$LLAMA_BIN/llama-perplexity" ]]; then
    PPL_CMD=("$LLAMA_BIN/llama-perplexity")
elif [[ -x "$LLAMA_BIN/llama-cli" ]]; then
    echo "WARNING: llama-perplexity not found; falling back to llama-cli --perplexity." >&2
    PPL_CMD=("$LLAMA_BIN/llama-cli" "--perplexity")
else
    echo "ERROR: neither llama-perplexity nor llama-cli found in $LLAMA_BIN." >&2
    exit 1
fi

OUT_DIR="$RUN_DIR/perplexity"
mkdir -p "$OUT_DIR"
CSV="$OUT_DIR/perplexity_results.csv"
echo "quant,final_ppl,chunks_done,status,timestamp" > "$CSV"

for quant in $QUANTS; do
    model_path="$MODELS_DIR/${MODEL_PREFIX}-${quant}.gguf"
    if [[ ! -f "$model_path" ]]; then
        echo "Skipping $quant: $model_path not found."
        continue
    fi

    echo "=== Perplexity: $quant (this can take hours on a Cortex-A53) ==="
    out_file="$OUT_DIR/${quant}-perplexity.txt"

    "${PPL_CMD[@]}" -m "$model_path" \
        -f "$WIKITEXT" \
        -c 512 \
        -b 2048 \
        --chunks "$CHUNKS" \
        --seed 42 \
        > "$out_file" 2>&1

    exit_code=$?
    final_ppl=$(grep -oP 'Final estimate: PPL = \K[0-9.]+' "$out_file" | tail -1)
    chunks_done=$(grep -oP '\[[0-9]+\]' "$out_file" | tail -1 | tr -d '[]')

    if [[ -n "$final_ppl" ]]; then
        status="completed"
    elif [[ -n "$chunks_done" ]]; then
        status="interrupted"
    else
        status="failed"
    fi

    timestamp=$(date +%Y-%m-%dT%H:%M:%S)
    echo "${quant},${final_ppl:-NA},${chunks_done:-0},${status},${timestamp}" >> "$CSV"
    echo "-> $quant: PPL=${final_ppl:-NA}, chunks=${chunks_done:-0}/$CHUNKS, status=$status (exit $exit_code)"
done

echo
echo "Wrote $CSV"
