#!/usr/bin/env bash
#
# run-accuracy-eval.sh — deterministic small-prompt accuracy check.
#
# Runs a fixed set of ten factual/arithmetic prompts through llama-cli for each
# quantization. Accuracy depends on the model and quantization, not on the
# thread count or backend, so one run per quantization is enough.
#
# ChatML is applied explicitly because Qwen2.5-Instruct expects it. Generation
# is greedy (temperature 0) to make the check reproducible.
#
# Usage:
#   ./scripts/run-accuracy-eval.sh results/gemstone-o1/run-20260821-145314
#
# Environment overrides:
#   LLAMA_BIN   Directory containing llama-cli (default: ~/llama.cpp/build/bin)
#   MODELS_DIR  Directory containing GGUF files (default: ~/models)
#   MODEL_PREFIX, QUANTS, THREADS, NGL
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
THREADS="${THREADS:-4}"
NGL="${NGL:-0}"

CLI_BIN="$LLAMA_BIN/llama-cli"
[[ -x "$CLI_BIN" ]] || { echo "ERROR: llama-cli not found at $CLI_BIN" >&2; exit 1; }

OUT_DIR="$RUN_DIR/accuracy"
mkdir -p "$OUT_DIR"
CSV="$OUT_DIR/accuracy_results.csv"
echo "quant,question_id,question,expected,answer_snippet,correct,timestamp" > "$CSV"

# question|expected substring (case-insensitive, fixed-string match)
QUESTIONS=(
    "What is 12 plus 7?|19"
    "What is the capital of France?|Paris"
    "What is the chemical symbol for water?|H2O"
    "How many days are there in a week?|7"
    "What planet is known as the Red Planet?|Mars"
    "What is 9 times 6?|54"
    "Who wrote Romeo and Juliet?|Shakespeare"
    "What is the freezing point of water in Celsius?|0"
    "What is the largest ocean on Earth?|Pacific"
    "What is 100 divided by 4?|25"
)

for quant in $QUANTS; do
    model_path="$MODELS_DIR/${MODEL_PREFIX}-${quant}.gguf"
    if [[ ! -f "$model_path" ]]; then
        echo "Skipping $quant: $model_path not found."
        continue
    fi

    echo "=== Accuracy: $quant ==="
    correct_count=0
    total=0
    question_id=0

    for qa in "${QUESTIONS[@]}"; do
        question_id=$((question_id + 1))
        question="${qa%%|*}"
        expected="${qa##*|}"

        prompt=$'<|im_start|>system\nAnswer concisely with a single word or number only.<|im_end|>\n<|im_start|>user\n'"${question}"$'<|im_end|>\n<|im_start|>assistant\n'

        answer=$("$CLI_BIN" -m "$model_path" \
            -p "$prompt" \
            -n 32 \
            --temp 0 \
            --seed 42 \
            --no-display-prompt \
            -no-cnv \
            -t "$THREADS" \
            -ngl "$NGL" \
            2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g' | tr -d '\r' | tr '\n' ' ')

        answer=$(echo "$answer" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        total=$((total + 1))

        if echo "$answer" | grep -Fqi -- "$expected"; then
            correct=1
            correct_count=$((correct_count + 1))
        else
            correct=0
        fi

        timestamp=$(date +%Y-%m-%dT%H:%M:%S)
        snippet=$(echo "$answer" | cut -c1-120 | sed 's/"/'"'"'/g')
        echo "${quant},${question_id},\"${question}\",\"${expected}\",\"${snippet}\",${correct},${timestamp}" >> "$CSV"
    done

    if [[ "$total" -gt 0 ]]; then
        accuracy=$(awk -v c="$correct_count" -v t="$total" 'BEGIN {printf "%.1f", (c / t) * 100}')
        echo "-> $quant: $correct_count/$total correct (${accuracy}%)"
    fi
done

echo
echo "Wrote $CSV"
