# Roadmap

## Guiding principle

The project should produce more than a table of `llama-bench` numbers. The
target is a **reproducible, citable artifact** that answers deployment
questions:

1. Which quantization gives the best quality/speed trade-off at a given memory
   budget?
2. How does throughput change under sustained load and thermal throttling?
3. How many tokens per joule does each board deliver?
4. What fits in 2 GB of RAM, and what happens when it does not?
5. How do two four-core Cortex-A53 boards compare under an identical protocol?
6. Does quantization damage Turkish quality more than English quality?

A result is considered a real contribution only if it is **reproducible**,
**comparable across boards**, and **actionable** for someone deploying a small
LLM on an edge device.

## Status snapshot

| Workstream | Status |
|---|---|
| Preliminary Gemstone O1 run | 4/32 speed runs, interrupted |
| Perplexity | 16/30 chunks for Q5_K_M, no final PPL |
| Accuracy | Not run |
| Thermal / RAM | Not captured |
| Arduino UNO Q | Not started |
| Publication | Repository public; DOI pending |

The immediate priority is to replace the preliminary dataset with a complete,
well-controlled baseline.

## Phase 1 — Complete the baseline on the T3 Gemstone O1 (P0)

### 1.1 Full CPU speed matrix

- [ ] 4 quantizations: Q4_0, Q4_K_M, Q5_K_M, Q8_0.
- [ ] 4 thread counts: 1, 2, 3, 4.
- [ ] 2 independent repeats per configuration.
- [ ] 32 runs total, CPU only (`-ngl 0`), `llama-bench -p 512 -n 128`.
- [ ] Verify that every run has raw output, a parsed CSV row, and an
      environment manifest entry.
- [ ] Record peak RSS for every run (install the `time` package).

Measured run time in the preliminary campaign was **26–34 minutes per run**,
so the full matrix is roughly **14–18 hours** of continuous execution. Run it
in `tmux`/`screen`, preferably overnight.

**Acceptance criteria:** 32/32 rows, zero parse failures, all raw files
non-empty, `analysis/summarize.py --check` passes.

### 1.2 Thermal and frequency logging

- [ ] Start `scripts/temp-logger.sh` before the matrix.
- [ ] Extend the logger to record CPU frequency (`/sys/devices/system/cpu/.../cpufreq/scaling_cur_freq`)
      and, where available, GPU frequency.
- [ ] Record the CPU governor and cooling setup (passive/fan) in the run
      metadata.
- [ ] Join thermal readings to `test_boundaries.csv` and report the
      temperature range per configuration.

**Why it matters:** without this, a slow run cannot be distinguished from a
throttled run. This is also the foundation for Phase 3.

### 1.3 Quality baseline

- [ ] Run perplexity for all four quantizations (30 chunks each).
- [ ] Run the 10-prompt accuracy set for all four quantizations.
- [ ] Record final PPL, chunks completed, and accuracy per quantization.

Perplexity took roughly **2 hours per quantization** in the preliminary run,
so this phase is about **8 hours** of execution.

### 1.4 Vulkan backend

- [ ] Verify that `llama-bench` reports `ggml_vulkan: Found ...` and actually
      offloads the model.
- [ ] Run the full matrix on the best two quantizations first (16 runs).
- [ ] Expand to all four quantizations if the results are stable.
- [ ] Report CPU and Vulkan results separately; never mix a silent CPU fallback
      into GPU results.

## Phase 2 — Arduino UNO Q and the 2 GB memory wall (P0/P1)

### 2.1 Baseline matrix

- [ ] Confirm the RAM variant (2 GB or 4 GB) and record it.
- [ ] Build llama.cpp for the QRB2210 (CPU first, Vulkan second).
- [ ] Run the same 32-run CPU matrix with the same model files (verify SHA-256).
- [ ] Capture thermal, frequency, and RAM data.

### 2.2 Memory-wall experiments on the 2 GB variant

- [ ] Q8_0: does it load and generate at all?
- [ ] Context lengths 512, 1024, 2048, 4096: where does it fail?
- [ ] `mmap` vs `--no-mmap`.
- [ ] Swap disabled vs zram vs disk swap; record throughput collapse and OOM
      behaviour.
- [ ] Report the largest working (model, quantization, context) combination.

**Why it matters:** “does it fit?” is the first question an edge developer
asks, and it is rarely answered with measured data.

## Phase 3 — Differentiating experiments (P1)

### 3.1 Sustained load and thermal throttling

- [ ] Run 60 minutes of continuous generation for 4 representative
      configurations per board.
- [ ] Log tok/s per minute, temperature, and CPU frequency.
- [ ] Report steady-state throughput, time-to-throttle, and the throughput drop
      relative to the first minute.
- [ ] Repeat with and without active cooling if a fan is available.

**Deliverable:** a “sustained vs burst” table and a tok/s-vs-time plot. This is
more useful for real deployments than a 30-second benchmark.

### 3.2 Energy efficiency

- [ ] Measure board power with an INA219/INA260 or a calibrated USB-C power
      meter.
- [ ] Record idle power and load power for each configuration.
- [ ] Compute tokens/joule and tokens/watt.
- [ ] Compare CPU and Vulkan efficiency.

**Deliverable:** an energy-efficiency Pareto plot. On battery-powered or
thermally constrained devices, perf/W matters more than peak tok/s.

### 3.3 Real application latency with `llama-server`

- [ ] Add a load-test script for the OpenAI-compatible `llama-server` endpoint.
- [ ] Measure time-to-first-token (TTFT) and inter-token latency (ITL) at
      p50/p95.
- [ ] Test concurrency 1, 2, and 4.
- [ ] Measure cold start (model load + first token) on eMMC and, if available,
      microSD/NVMe.

**Deliverable:** latency-aware results that map to user experience, not just
batch throughput.

### 3.4 Turkish quality under quantization

- [ ] Build a 50–100 prompt Turkish set covering instruction following,
      grammar, math, code, and factual questions.
- [ ] Optionally add a TurkishMMLU subset.
- [ ] Evaluate Q4_0, Q4_K_M, Q5_K_M, and Q8_0; use Q8_0 as the reference.
- [ ] Compare the degradation with the English accuracy set.

**Hypothesis:** low-bit quantization damages Turkish more than English. If
confirmed, this is a genuinely novel and locally relevant contribution.

### 3.5 Roofline and memory-bandwidth analysis

- [ ] Measure memory bandwidth with STREAM or `mbw`.
- [ ] Estimate arithmetic intensity of prompt processing vs token generation.
- [ ] Correlate achieved tok/s with bandwidth and clock speed.
- [ ] Explain why Vulkan helps (or does not help) each phase.

**Hypothesis:** token generation is memory-bandwidth-bound and prompt
processing is compute-bound, so GPU offload improves `pp512` more than `tg128`.

### 3.6 Build-flag sensitivity

- [ ] Compare `-DGGML_NATIVE=ON` with a generic build.
- [ ] Test LTO and `-O3` where supported.
- [ ] Test thread affinity (`taskset`) on the four A53 cores.
- [ ] Measure the best-performing build recipe and document it.

**Deliverable:** a reproducible build recipe with measured gains, not folklore.

## Phase 4 — Analysis and publication (P1)

- [ ] Freeze the dataset and tag `v1.0.0`.
- [ ] Generate the final tables and figures with `analysis/`.
- [ ] Write the technical report:
  - motivation and related work,
  - hardware and protocol,
  - throughput, scaling, memory, thermal, energy, quality,
  - Turkish results,
  - threats to validity,
  - deployment recommendations.
- [ ] Publish the dataset on Hugging Face Datasets (optional but useful).
- [ ] Add a GitHub Pages dashboard with the main plots.
- [ ] Archive on Zenodo and add the DOI to `README.md`, `CITATION.cff`, and
      `.zenodo.json`.
- [ ] Submit the report to arXiv (cs.PF / cs.LG) or an edge-AI/TinyML workshop.

## Minimum publishable unit

A defensible first release needs:

| Item | Quantity |
|---|---|
| CPU speed runs | 2 boards × 32 = 64 |
| Vulkan speed runs | 1 board × 16 (subset) |
| Perplexity runs | 2 boards × 4 = 8 |
| Accuracy runs | 2 boards × 4 = 8 |
| Thermal logs | Every campaign |
| Sustained-load runs | 2 boards × 4 = 8 |
| Energy measurements | Same as sustained-load runs |
| Turkish evaluation | 2 boards × 4 quantizations |

Estimated machine time: **60–80 hours**, plus analysis and writing. This is
realistic over 2–4 weeks, not a weekend.

## Hypotheses to test

| ID | Hypothesis | Experiment |
|---|---|---|
| H1 | `pp512` scales nearly linearly to 4 threads; `tg128` saturates earlier | Phase 1.1 |
| H2 | Vulkan improves prompt processing more than token generation | Phase 1.4 + 3.5 |
| H3 | Q4_K_M is the best quality/speed point for a 2 GB device | Phase 1.3 + 2.2 |
| H4 | Sustained throughput drops more than 15% after 10 minutes without active cooling | Phase 3.1 |
| H5 | Q8_0 does not fit comfortably in 2 GB with a 2K context | Phase 2.2 |
| H6 | Turkish quality degrades faster than English at Q4_0 | Phase 3.4 |

## Prioritized backlog

| Priority | Experiment | Effort | Main output |
|---|---|---|---|
| P0 | Complete Gemstone CPU matrix | 14–18 h runtime | Core dataset |
| P0 | Thermal + RAM logging | Low | Valid interpretation |
| P0 | Perplexity + accuracy | ~8 h runtime | Quality baseline |
| P0 | UNO Q CPU matrix | 14–18 h runtime | Cross-board comparison |
| P1 | 2 GB memory wall | 4–6 h | Deployment limits |
| P1 | Sustained load + throttling | 8–12 h | Steady-state numbers |
| P1 | Vulkan subset | 8–12 h | Backend comparison |
| P1 | Turkish evaluation | 1–2 days analysis | Novel quality result |
| P1 | `llama-server` TTFT/ITL | 1–2 days engineering | Real-world latency |
| P2 | Energy measurement | Hardware + 1 week | tokens/joule |
| P2 | Roofline / bandwidth | 2–3 days | Explanatory analysis |
| P2 | Build-flag tuning | 1 week | Faster build recipe |
| P2 | Raspberry Pi 4B/5 | If hardware appears | Optional comparison |

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Thermal throttling confounds results | Log temperature/frequency; use cooling; report both burst and sustained numbers |
| 2 GB UNO Q cannot run Q8_0 | Treat the failure as a result; document the memory wall |
| Vulkan silently falls back to CPU | Harness aborts unless `ALLOW_CPU_FALLBACK=1`; verify the `ggml_vulkan` line |
| Hardware unavailability (RPi) | Keep it optional; never report unmeasured numbers |
| Long run times | Use `tmux`, run overnight, checkpoint CSV rows after every run |
| Measurement noise | Two independent repeats; report sample standard deviation; avoid running other services |
| Subjective Turkish evaluation | Use a fixed rubric and, where possible, multiple-choice tasks |

## Out of scope

- NVIDIA Jetson Orin NX.
- NPU/DSP offload (C7x, Adreno, etc.).
- Models that cannot fit in 4 GB of RAM.
- Training or fine-tuning.
- Cloud/server GPU comparisons.

## Definition of done for v1.0.0

- [ ] Complete CPU matrix on at least two boards.
- [ ] Verified Vulkan subset.
- [ ] Perplexity and accuracy for every quantization.
- [ ] Thermal, frequency, and RAM data for every speed run.
- [ ] Sustained-load and energy results.
- [ ] Turkish evaluation.
- [ ] Reproducible scripts and environment manifests.
- [ ] Technical report and Zenodo DOI.
- [ ] All claims traceable to a raw log and a CSV row.
