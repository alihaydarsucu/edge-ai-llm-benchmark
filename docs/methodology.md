# Methodology

## 1. Research questions

1. How fast do small instruction-tuned LLMs run on low-power ARM single-board
   computers when only the CPU is used?
2. How much does quantization reduce throughput and quality on these boards?
3. How does throughput scale with thread count on a four-core Cortex-A53?
4. Does the Vulkan GPU backend improve prompt processing or token generation
   compared with the CPU backend?
5. How do two four-core Cortex-A53 boards (T3 Gemstone O1 at 1.4 GHz and
   Arduino UNO Q at 2.0 GHz) compare under an identical workload?

## 2. Workload

| Parameter | Value |
|---|---|
| Model | Qwen2.5-1.5B-Instruct (1.54 B parameters) |
| Quantizations | Q4_0, Q4_K_M, Q5_K_M, Q8_0 |
| Prompt processing | `pp512` (512-token prompt) |
| Token generation | `tg128` (128 generated tokens) |
| Backends | CPU (`-ngl 0`), Vulkan (`-ngl 999`) where available |
| Thread counts | 1, 2, 3, 4 |
| Repeats | 2 independent `llama-bench` invocations per configuration |
| Context | llama.cpp default for `llama-bench` |

`llama-bench` reports prompt-processing and token-generation throughput in
tokens per second. Each invocation performs its own warm-up and its internal
repetitions (llama.cpp default: 5) and reports a mean with a standard
deviation. The outer repeat in this project is a second, independent process
invocation, which captures run-to-run variation rather than only
within-process variation.

The model was chosen because:

- 1.5 B parameters fit in 2 GB of RAM at Q4/Q5, making a 2 GB Arduino UNO Q a
  meaningful comparison point.
- It is instruction-tuned and supports a documented ChatML prompt format.
- It is small enough that a 30-chunk WikiText-2 perplexity run finishes in
  hours rather than days on a Cortex-A53.

## 3. Fixed and varied factors

**Varied:** quantization, backend, thread count.

**Fixed:** model family, prompt/generation lengths, llama.cpp build, tokenizer,
context size for perplexity, evaluation corpus, accuracy prompt set, and
greedy decoding for accuracy.

**Recorded but not controlled:** CPU governor, background services, ambient
temperature, storage type, RAM variant, and kernel version. The harness writes
an `environment.txt` manifest with kernel, CPU model, memory, llama.cpp
version, model sizes, and SHA-256 hashes. Future campaigns should also record
the governor and the board's power mode.

## 4. Measurement procedure

For each configuration, `scripts/run-full-matrix.sh`:

1. Creates a timestamped run directory under
   `results/<platform>/run-YYYYMMDD-HHMMSS/`.
2. Captures the environment manifest.
3. Runs `llama-bench -m <model> -p 512 -n 128 -t <threads> -ngl <ngl>`.
4. Stores raw stdout in `raw/<tag>.txt`.
5. Measures peak resident memory with GNU `time -v` when available.
6. Appends a row to `results/all_results.csv`.
7. Records start/end timestamps in `results/test_boundaries.csv` so that an
   external thermal log can be aligned with each run.
8. Sleeps for a short cooldown (default 3 s) before the next configuration.

A thermal logger (`scripts/temp-logger.sh`) is run in a second session and
writes every readable thermal zone to `logs/temperature.csv` every 5 seconds.

## 5. Quality evaluation

### 5.1 Perplexity

`scripts/run-perplexity.sh` runs `llama-perplexity` on the WikiText-2 raw test
set with:

- `--chunks 30`
- context `-c 512`
- batch `-b 2048`
- fixed seed

The final estimate is extracted from the log. Perplexity is measured once per
quantization because it is a property of the weights, not of the thread count
or backend.

### 5.2 Accuracy

`scripts/run-accuracy-eval.sh` asks ten short factual/arithmetic questions
using the Qwen2.5 ChatML format:

```text
<|im_start|>system
Answer concisely with a single word or number only.<|im_end|>
<|im_start|>user
<question><|im_end|>
<|im_start|>assistant
```

Generation is greedy (`--temp 0`, fixed seed, 32 tokens). An answer is counted
as correct when it contains the expected fixed string (case-insensitive).
This is intentionally simple: it detects gross quantization damage, not subtle
reasoning differences. A larger benchmark (for example MMLU or ARC) is out of
scope for v1.

## 6. Analysis

`analysis/summarize.py` validates the CSV schema, aggregates repeats
(mean and sample standard deviation), and reports coverage against the
expected matrix.

`analysis/plot_results.py` produces grouped bar charts of prompt-processing
and token-generation throughput by quantization and thread count.

## 7. Threats to validity

- **Thermal throttling.** The AM67A has no active cooling by default. The
  preliminary run did not capture temperature, so throttling cannot be ruled
  out. The harness now supports a thermal log, and future runs must use it.
- **Memory bandwidth.** All four Cortex-A53 cores share the LPDDR4/LPDDR4X
  bus. Thread scaling is therefore expected to flatten earlier than on a
  desktop CPU. The two boards have different memory types and widths.
- **NPU/DSP are not used.** The AM67A's C7x DSP/MMA accelerators (4 TOPS) are
  not exercised by standard llama.cpp CPU or Vulkan backends. The benchmark
  measures the CPU and, optionally, the GPU only.
- **Model/residual differences.** Different quantization file sizes change
  memory pressure. Peak RSS is recorded so that throughput can be interpreted
  together with memory use.
- **Small sample size.** Two repeats per configuration are enough to detect
  large effects, not to estimate confidence intervals precisely. The
  preliminary run has only two thread counts for one quantization.
- **Storage and OS differences.** eMMC, microSD, and NVMe affect model load
  time, not steady-state throughput, but they matter for end-to-end latency.
  Load time is not part of `pp512`/`tg128`.
- **Compiler flags.** Throughput depends on the llama.cpp build
  (`-DGGML_NATIVE=ON` and architecture-specific flags). The build identifier
  is recorded; the exact CMake command is documented in
  [build-llama-cpp.md](build-llama-cpp.md).

## 8. Harness changes relative to the preliminary run

The original scripts that produced `run-20260821-145314` had three issues:

1. The accuracy script piped the question through stdin instead of passing the
   constructed ChatML prompt to `llama-cli -p`, so the model did not receive
   the system instruction.
2. Peak RAM measurement was commented out, so `ram_mb` is `NA`.
3. No environment manifest was captured, and the matrix script hard-coded a
   single platform.

The scripts in `scripts/` fix these points, add deterministic decoding for the
accuracy check, make the backend/thread/quantization lists configurable, and
write an environment manifest. Historical data is left unchanged.
