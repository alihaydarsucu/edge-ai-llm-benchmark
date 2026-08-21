# Edge AI LLM Inference Benchmarking

**llama.cpp on the T3 Gemstone O1 and Arduino UNO Q**

[![Validate results](https://github.com/alihaydarsucu/t3-gemstone-benchmark/actions/workflows/validate-results.yml/badge.svg)](https://github.com/alihaydarsucu/t3-gemstone-benchmark/actions/workflows/validate-results.yml)
[![Code: MIT](https://img.shields.io/badge/code-MIT-blue.svg)](LICENSE)
[![Data: CC BY 4.0](https://img.shields.io/badge/data-CC%20BY%204.0-lightgrey.svg)](DATA-LICENSE.md)
[![Status: work in progress](https://img.shields.io/badge/status-work%20in%20progress-orange.svg)](#project-status)

> **Preliminary and incomplete dataset — last updated 2026-10-19.**
> The only benchmark campaign so far (`run-20260821-145314`) was interrupted
> after **4 of 32** speed configurations. Perplexity stopped at **16 of 30
> chunks**, the accuracy suite was **never run**, and no thermal log was
> captured. The numbers in this README are therefore early indicators, not
> final results. Every gap is listed in [Project status](#project-status).

## Overview

This project measures how well small instruction-tuned language models run on
low-power ARM single-board computers. The goal is a reproducible dataset and a
technical report that answer a practical question:

> *What throughput and quality can you expect from a 1.5 B-parameter LLM on a
> four-core Cortex-A53 edge board, and how does it change with quantization,
> thread count, and GPU offload?*

The benchmark uses [llama.cpp](https://github.com/ggml-org/llama.cpp) with the
CPU and Vulkan backends, the Qwen2.5-1.5B-Instruct model, and a fixed matrix of
quantizations and thread counts. It records:

- prompt-processing and token-generation throughput (`pp512`, `tg128`),
- peak resident memory,
- perplexity on WikiText-2,
- accuracy on a fixed short-prompt set,
- thermal zone readings around each run.

The first platform is the **T3 Gemstone O1** (TI AM67A). The primary
comparison platform is the **Arduino UNO Q** (Qualcomm QRB2210). A Raspberry Pi
4B/5 will be added only if hardware becomes available. A planned NVIDIA
Jetson Orin NX comparison has been **dropped**.

The end goal is a public GitHub repository, a Zenodo-archived release with a
DOI, and a technical report.

## Project status

**The current dataset is incomplete.** The campaign reached the fifth
configuration, then stopped; the partial files were kept for traceability.

| Workstream | Target | Current |
|---|---|---|
| Speed matrix, T3 Gemstone O1, CPU | 32 runs (4 quantizations × 4 thread counts × 2 repeats) | **4 runs** (Q5_K_M, threads 3–4) |
| Quantizations | Q4_0, Q4_K_M, Q5_K_M, Q8_0 | Q5_K_M only |
| Thread counts | 1, 2, 3, 4 | 3, 4 only |
| Vulkan / GPU backend | Same matrix with `-ngl 999` | Not run |
| Perplexity | 4 quantizations × 30 chunks | Q5_K_M, **16/30 chunks**, no final PPL |
| Accuracy | 10 prompts × 4 quantizations | Not run (CSV header only) |
| Thermal log | Continuous during the matrix | Not captured |
| Peak RAM | Every run | `NA` (old harness had it disabled) |
| Arduino UNO Q | Full matrix | Not started |
| Raspberry Pi 4B/5 | Optional | Not started |

What exists today:

- Four completed `llama-bench` runs with raw output.
- A partial `llama-perplexity` log for Q5_K_M.
- Empty accuracy output and an empty thermal log directory.
- The full harness needed to repeat and extend the campaign.

What does **not** exist yet: a complete throughput matrix, any GPU numbers, a
final perplexity value, any accuracy score, thermal data, or any Arduino UNO Q
measurement.

See [`run-20260821-145314/README.md`](results/gemstone-o1/run-20260821-145314/README.md)
for the exact state of the preliminary run.

## Preliminary results

All rows below are **CPU-only** (`-ngl 0`), **Q5_K_M**, **two independent
repeats**, on the T3 Gemstone O1. No other quantization or thread count
completed.

| Threads | pp512 (tok/s) | tg128 (tok/s) | Relative pp | Relative tg | Runs |
|---:|---:|---:|---:|---:|---:|
| 3 | 1.95 ± 0.01 | 1.46 ± 0.00 | 1.00× | 1.00× | 2 |
| 4 | 2.50 ± 0.02 | 1.80 ± 0.01 | 1.28× | 1.23× | 2 |

Uncertainties are sample standard deviations across the two independent
invocations. Relative values are against 3 threads **within this partial
dataset** — not against a full scaling curve.

Raw data: [`results/all_results.csv`](results/gemstone-o1/run-20260821-145314/results/all_results.csv) ·
Raw logs: [`raw/`](results/gemstone-o1/run-20260821-145314/raw)

### What the early numbers suggest

- Going from 3 to 4 threads improved prompt processing by about **28%** and
  token generation by about **23%** on this 4-core board. That is close to
  linear for prompt processing and slightly sub-linear for generation, but the
  1- and 2-thread points are missing, so the shape of the scaling curve is
  unknown.
- Run-to-run variation was below 1% between the two repeats, which suggests
  the measurement is stable at this load.
- Absolute throughput is low: about **2.5 tok/s** prompt processing and
  **1.8 tok/s** generation for a 1.5 B model. This is expected from four
  Cortex-A53 cores at 1.4 GHz with no NPU/DSP offload.

### What these numbers do **not** show

- **No quantization comparison.** Only Q5_K_M is present, so no statement
  about Q4_0/Q4_K_M/Q8_0 speed or quality is possible.
- **No GPU result.** The AM67A GPU (Vulkan 1.2) was not exercised in this run.
- **No quality result.** The perplexity run is partial and there is no final
  PPL; the accuracy suite never ran.
- **No thermal analysis.** Throttling during these four runs cannot be ruled
  out.
- **No board comparison.** The Arduino UNO Q has not been measured yet.

## Hardware

### T3 Gemstone O1 — measured

| Item | Specification |
|---|---|
| SoC | Texas Instruments AM67A |
| CPU | 4× Arm Cortex-A53 @ 1.4 GHz |
| Real-time cores | 2× Arm Cortex-R5F @ 800 MHz |
| GPU | 50 GFLOPS class, Vulkan 1.2 |
| AI accelerators | 2× C7x DSP + MMA, 4 TOPS total |
| RAM | 4 GB LPDDR4 |
| Storage | 32 GB eMMC (microSD / NVMe expandable) |
| OS | Gemstone Linux (Debian-based) |

The C7x DSP/MMA accelerators are not used by llama.cpp's CPU or Vulkan
backends, so the 4 TOPS figure does not apply to these measurements.

### Arduino UNO Q — planned comparison

| Item | Specification |
|---|---|
| MPU | Qualcomm Dragonwing QRB2210 |
| CPU | 4× Arm Cortex-A53 @ 2.0 GHz |
| GPU | Adreno 702 @ 845 MHz |
| MCU | STM32U585 (Cortex-M33, real-time I/O only) |
| RAM | 2 GB or 4 GB LPDDR4X |
| Storage | 16 GB or 32 GB eMMC |
| OS | Debian Linux |

Both boards are four-core Cortex-A53 designs, which makes the comparison
architecturally clean: **1.4 GHz vs 2.0 GHz**, LPDDR4 vs LPDDR4X, and different
GPU generations. The UNO Q's 2 GB variant is the constrained case; Q8_0
weights are roughly 1.6 GB, so that configuration may not fit comfortably. The
RAM variant will be recorded with the results.

Full specifications and sources: [`docs/hardware.md`](docs/hardware.md).

## Comparison plan

| Platform | Role | Status |
|---|---|---|
| T3 Gemstone O1 | Primary platform | Partial data |
| Arduino UNO Q | Primary comparison target | Planned |
| Raspberry Pi 4B / 5 | Opportunistic, only if hardware is available | Not planned as a dependency |
| NVIDIA Jetson Orin NX | Removed from scope | Not measured |

The comparison will use identical GGUF files (verified by SHA-256), the same
llama.cpp commit, the same `pp512`/`tg128` workload, and the same thread
counts. If the UNO Q gets a working Vulkan path, both the CPU and GPU results
will be reported separately. NPU/DSP offload is out of scope.

## Methodology

For every configuration:

```bash
llama-bench -m qwen2.5-1.5b-instruct-<quant>.gguf -p 512 -n 128 -t <threads> -ngl <ngl>
```

- **Model:** Qwen2.5-1.5B-Instruct, quantized to Q4_0, Q4_K_M, Q5_K_M, Q8_0.
- **Backends:** CPU (`-ngl 0`) and Vulkan (`-ngl 999`) where verified.
- **Threads:** 1, 2, 3, 4.
- **Repeats:** two independent process invocations per configuration, in
  addition to `llama-bench`'s internal repetitions.
- **Memory:** peak RSS via GNU `time -v`.
- **Quality:** perplexity on WikiText-2 raw (30 chunks, context 512, batch
  2048) and a deterministic 10-prompt accuracy check using the Qwen2.5 ChatML
  template and greedy decoding.
- **Thermals:** all readable `/sys/class/thermal/thermal_zone*/temp` zones
  every 5 seconds, aligned to run boundaries.

The harness writes an environment manifest with kernel, CPU model, memory,
llama.cpp version, model sizes, and SHA-256 hashes.

Read the full protocol, including threats to validity, in
[`docs/methodology.md`](docs/methodology.md).

## Reproduce

### 1. Clone and build llama.cpp

```bash
git clone https://github.com/alihaydarsucu/t3-gemstone-benchmark.git
cd t3-gemstone-benchmark

git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
git checkout bf0040e                 # build used for the preliminary run
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j2
cd ..
```

For the Vulkan build and the shaderc/OOM workaround, see
[`docs/build-llama-cpp.md`](docs/build-llama-cpp.md).

### 2. Download the models

```bash
mkdir -p ~/models
for q in q4_0 q4_k_m q5_k_m q8_0; do
  huggingface-cli download Qwen/Qwen2.5-1.5B-Instruct-GGUF \
    "qwen2.5-1.5b-instruct-${q}.gguf" --local-dir ~/models
done
```

Alternatively, convert and quantize the HF model yourself with
`convert_hf_to_gguf.py` and `llama-quantize`.

Download the WikiText-2 corpus for perplexity:

```bash
cd ~/models
wget https://huggingface.co/datasets/ggml-org/ci/resolve/main/wikitext-2-raw-v1.zip
unzip wikitext-2-raw-v1.zip
```

### 3. Run a campaign

```bash
source config/gemstone-o1.env
./scripts/run-full-matrix.sh
```

Start the thermal logger in a second terminal at the same time:

```bash
./scripts/temp-logger.sh results/gemstone-o1/<run-id>
```

Then quality checks (these are slow on a Cortex-A53):

```bash
./scripts/run-perplexity.sh results/gemstone-o1/<run-id>
./scripts/run-accuracy-eval.sh results/gemstone-o1/<run-id>
```

All scripts accept environment overrides (`LLAMA_BIN`, `MODELS_DIR`,
`QUANTS`, `THREADS`, `BACKENDS`, `REPEATS`). For the UNO Q:

```bash
source config/arduino-uno-q.env
./scripts/run-full-matrix.sh
```

### 4. Validate and summarize

```bash
python3 analysis/summarize.py --check   # schema + raw-file validation
python3 analysis/summarize.py           # Markdown table
python3 -m pip install -r analysis/requirements.txt
python3 analysis/plot_results.py --platform gemstone-o1
```

## Repository layout

```text
.
├── README.md
├── LICENSE                  # MIT (code)
├── DATA-LICENSE.md          # CC BY 4.0 (data and docs)
├── CITATION.cff
├── .zenodo.json
├── config/
│   ├── gemstone-o1.env
│   └── arduino-uno-q.env
├── scripts/
│   ├── run-full-matrix.sh
│   ├── run-perplexity.sh
│   ├── run-accuracy-eval.sh
│   └── temp-logger.sh
├── results/
│   └── gemstone-o1/
│       └── run-20260821-145314/
│           ├── README.md
│           ├── results/all_results.csv
│           ├── results/test_boundaries.csv
│           ├── raw/*.txt
│           ├── perplexity/
│           ├── accuracy/
│           └── logs/
├── analysis/
│   ├── summarize.py
│   ├── plot_results.py
│   └── requirements.txt
├── docs/
│   ├── methodology.md
│   ├── hardware.md
│   ├── build-llama-cpp.md
│   ├── data-schema.md
│   └── roadmap.md
└── .github/workflows/validate-results.yml
```

## Results data

`results/<platform>/<run-id>/results/all_results.csv` is the main dataset:

| Column | Description |
|---|---|
| `quant` | Quantization tag (`q4_0`, `q4_k_m`, `q5_k_m`, `q8_0`) |
| `backend` | `cpu` or `gpu` |
| `ngl` | GPU layers offloaded (0 for CPU, 999 for all) |
| `threads` | Thread count |
| `repeat` | Outer repetition index |
| `pp_tps` | Prompt-processing throughput (tok/s) |
| `tg_tps` | Token-generation throughput (tok/s) |
| `ram_mb` | Peak RSS in MiB (`NA` if not measured) |
| `model_size_mb` | GGUF size in MiB |
| `timestamp` | End of the run (ISO 8601, local time) |

Full schemas for boundaries, perplexity, accuracy, and environment manifests
are in [`docs/data-schema.md`](docs/data-schema.md). Model weights are not
committed; raw llama.cpp output is.

## Roadmap

- [x] Harness, preliminary run, and raw-data preservation.
- [ ] Complete the 32-run CPU matrix on the T3 Gemstone O1.
- [ ] Add verified Vulkan runs.
- [ ] Complete perplexity (all quantizations) and accuracy.
- [ ] Capture thermal and peak-memory data for every run.
- [ ] Run the same matrix on the Arduino UNO Q.
- [ ] Analyze, plot, and publish the comparison.
- [ ] Optional: Raspberry Pi 4B/5 if hardware is available.
- [ ] Freeze a release, archive on Zenodo, add the DOI, publish the report.

The detailed plan is in [`docs/roadmap.md`](docs/roadmap.md).

## Publication and citation

A Zenodo-archived release with a DOI is planned once the matrix is complete.
Until then, cite the repository:

```bibtex
@software{sucu_2026_edge_llm_benchmark,
  author  = {Sucu, Ali Haydar},
  title   = {Edge AI LLM Inference Benchmarking on T3 Gemstone O1 and Arduino UNO Q},
  year    = {2026},
  url     = {https://github.com/alihaydarsucu/t3-gemstone-benchmark},
  note    = {Work in progress; preliminary and incomplete dataset}
}
```

Machine-readable metadata is in [`CITATION.cff`](CITATION.cff). The DOI will
be added here and in the citation file after the first archived release.

## License

- **Code** (`scripts/`, `analysis/`): [MIT](LICENSE).
- **Data, figures, and documentation**: [CC BY 4.0](DATA-LICENSE.md).

## Acknowledgements

- [llama.cpp / ggml](https://github.com/ggml-org/llama.cpp) for the inference
  engine and benchmarking tools.
- [T3 Gemstone](https://t3gemstone.org/) for the O1 board and documentation.
- [Arduino](https://www.arduino.cc/) for the UNO Q platform documentation.
- [Qwen](https://github.com/QwenLM/Qwen2.5) for the Qwen2.5 model family.
- The WikiText-2 dataset maintained by the
  [ggml-org CI dataset mirror](https://huggingface.co/datasets/ggml-org/ci).
