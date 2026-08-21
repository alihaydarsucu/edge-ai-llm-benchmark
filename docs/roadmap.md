# Roadmap

## Phase 0 — Harness and preliminary run (done)

- [x] CPU/Vulkan llama.cpp build for the T3 Gemstone O1.
- [x] Speed, perplexity, accuracy, and thermal scripts.
- [x] First matrix run (`run-20260821-145314`) — interrupted after 4/32
      configurations.
- [x] Preserve raw output and document what is missing.

## Phase 1 — Complete the T3 Gemstone O1 matrix (next)

- [ ] Re-run the full 32-configuration CPU matrix (`q4_0`, `q4_k_m`, `q5_k_m`,
      `q8_0` × threads 1–4 × 2 repeats).
- [ ] Run the Vulkan backend (`-ngl 999`) for the same matrix, after verifying
      that the model is actually offloaded.
- [ ] Capture peak RAM for every run.
- [ ] Capture a thermal log for every campaign.
- [ ] Record the CPU governor and cooling setup.
- [ ] Complete perplexity for all four quantizations (30 chunks each).
- [ ] Run the 10-prompt accuracy check for all four quantizations.

## Phase 2 — Arduino UNO Q comparison

- [ ] Confirm the RAM variant (2 GB or 4 GB) and record it.
- [ ] Build llama.cpp on the QRB2210 (CPU, then attempt Vulkan).
- [ ] Run the same quantization × thread matrix.
- [ ] On the 2 GB variant, test whether Q8_0 can run at all and document
      memory pressure/swap behaviour.
- [ ] Run perplexity and accuracy.
- [ ] Capture thermal and power data if the board exposes it.

## Phase 3 — Analysis and comparison

- [ ] Aggregate both platforms with `analysis/summarize.py`.
- [ ] Produce throughput, scaling, memory, and quality plots.
- [ ] Compare normalized performance (tok/s per GHz and tok/s per watt if
      power data is available).
- [ ] Document thermal throttling and any failed configurations.

## Phase 4 — Optional Raspberry Pi

- [ ] Run the matrix on a Raspberry Pi 4B or Pi 5 **if hardware becomes
      available**. No results will be reported without measurements.

## Phase 5 — Publication

- [ ] Freeze a release tag (`v1.0.0`).
- [ ] Archive on Zenodo and add the DOI to `README.md` and `CITATION.cff`.
- [ ] Publish the technical report (methodology, results, threats to validity).
- [ ] Link the report and the archived dataset from the repository.

## Explicitly out of scope

- NVIDIA Jetson Orin NX.
- NPU/DSP offload (C7x, Adreno, etc.).
- Models larger than what fits in 4 GB of RAM.
