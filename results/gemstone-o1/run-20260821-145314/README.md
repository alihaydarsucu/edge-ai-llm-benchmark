# Run 2026-08-21 — T3 Gemstone O1

> **Status: incomplete / interrupted.** This run is published as preliminary
> evidence and as a reproducibility record. It is **not** the final benchmark
> matrix.

- Run ID: `run-20260821-145314`
- Platform: T3 Gemstone O1 (TI AM67A, 4× Cortex-A53 @ 1.4 GHz, 4 GB LPDDR4)
- Model: Qwen2.5-1.5B-Instruct, Q5_K_M (1,073 MB)
- Backend: CPU only (`-ngl 0`)
- llama.cpp build: `bf0040e` (reported by `llama-bench`)
- Target matrix: 4 quantizations × 1 CPU backend × 4 thread counts × 2 repeats = **32 runs**
- Completed: **4 runs** (12.5%)

## What completed

| Configuration | pp512 (tok/s) | tg128 (tok/s) |
|---|---:|---:|
| q5_k_m, cpu, 4 threads, repeat 1 | 2.51 | 1.79 |
| q5_k_m, cpu, 4 threads, repeat 2 | 2.48 | 1.80 |
| q5_k_m, cpu, 3 threads, repeat 1 | 1.95 | 1.46 |
| q5_k_m, cpu, 3 threads, repeat 2 | 1.94 | 1.46 |

Perplexity was started for Q5_K_M but interrupted after **16 of 30 chunks**.
No final PPL estimate exists. The per-chunk values printed by
`llama-perplexity` are preserved in
[`perplexity/q5_k_m-perplexity.txt`](perplexity/q5_k_m-perplexity.txt).

## What is missing

| Item | Status |
|---|---|
| q4_0, q4_k_m, q8_0 speed runs | Not started |
| Thread counts 1 and 2 | Not started (t2 was launched, then interrupted) |
| Vulkan / GPU runs | Not run |
| Remaining 28 speed configurations | Not run |
| Perplexity for all quantizations | 16/30 chunks, Q5_K_M only |
| Accuracy evaluation | Not run (CSV contains only the header) |
| Thermal log | Not captured (empty `logs/` directory) |
| Peak RAM per run | Not captured (`NA`); the old script had the measurement commented out |

The fifth configuration (`q5_k_m-cpu-t2-r1`) produced an empty raw file
because the run was interrupted right after it started. `results/summary.txt`
ends at `[5/32]`, which matches the four completed CSV rows.

## Directory contents

```
environment.txt is absent for this run (the old harness did not capture it)
results/
  all_results.csv         # 4 parsed rows
  test_boundaries.csv     # start/end timestamps for the 4 completed runs
  summary.txt             # console log, stops at [5/32]
raw/
  *.txt                   # raw llama-bench stdout for each attempt
logs/
  (empty)                 # GNU time / temperature logs were not produced
perplexity/
  perplexity_results.csv  # one interrupted row
  q5_k_m-perplexity.txt   # partial llama-perplexity log
accuracy/
  accuracy_results.csv    # header only
```

The GGUF model file is intentionally **not** committed. See the main README
for download/quantization instructions.

## Why the run stopped

The campaign was interrupted manually before the matrix could finish. The
partial files were kept rather than deleted so that the preliminary numbers
can be traced to raw output. Re-run with the current harness
(`scripts/run-full-matrix.sh`) to produce a complete dataset with an
environment manifest and RAM measurements.
