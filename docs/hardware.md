# Hardware

## T3 Gemstone O1 — primary platform

| Item | Specification |
|---|---|
| SoC | Texas Instruments AM67A (J722S family) |
| CPU | 4× Arm Cortex-A53 @ 1.4 GHz (64-bit) |
| Real-time cores | 2× Arm Cortex-R5F @ 800 MHz |
| GPU | 50 GFLOPS class GPU, OpenGL ES 3.2 / OpenCL 1.2 EP / Vulkan 1.2 |
| AI accelerators | 2× C7x DSP with MMA, 4 TOPS total |
| RAM | 4 GB LPDDR4 |
| Storage | 32 GB eMMC, microSD, M.2 2280 NVMe |
| OS used | Gemstone Linux (Debian-based) |
| Cooling | Board fan header; active cooling not assumed in the preliminary run |

The C7x DSP/MMA accelerators are not used by llama.cpp's CPU or Vulkan
backends. The measured numbers therefore reflect the four Cortex-A53 cores
(and, in future GPU runs, the Vulkan GPU path).

Sources:

- <https://docs.t3gemstone.org/en/boards/o1/introduction>
- <https://docs.t3gemstone.org/en/boards/o1/tiam67>
- <https://github.com/t3gemstone/hardware>

## Arduino UNO Q — comparison platform (planned)

| Item | Specification |
|---|---|
| MPU | Qualcomm Dragonwing QRB2210 |
| CPU | 4× Arm Cortex-A53 @ 2.0 GHz (64-bit) |
| GPU | Adreno 702 @ 845 MHz |
| MCU | STM32U585 (Cortex-M33 @ 160 MHz, 2 MB flash, 786 kB SRAM) |
| RAM | 2 GB or 4 GB LPDDR4X |
| Storage | 16 GB or 32 GB eMMC |
| OS | Debian Linux (upstream support) |

The STM32U585 handles real-time I/O and is not involved in LLM inference.
Only the QRB2210 runs llama.cpp.

The 2 GB variant is the interesting low-memory case but has limited headroom:
Q8_0 weights are roughly 1.6 GB, which leaves little room for the OS and KV
cache. The 4 GB variant is preferable for the full quantization matrix. The
exact variant must be recorded with the results.

Sources:

- <https://docs.arduino.cc/hardware/uno-q/>
- <https://docs.arduino.cc/resources/datasheets/ABX00162-datasheet.pdf>
- <https://store.arduino.cc/products/uno-q>

## Raspberry Pi 4B / 5 — optional

Included only if hardware becomes available.

| Board | CPU | GPU | RAM options |
|---|---|---|---|
| Raspberry Pi 4B | 4× Cortex-A72 @ 1.5 GHz | VideoCore VI | 2/4/8 GB LPDDR4 |
| Raspberry Pi 5 | 4× Cortex-A76 @ 2.4 GHz | VideoCore VII | 4/8 GB LPDDR4X |

The Pi 4B is the closest generation to the Cortex-A53 boards; the Pi 5 is a
faster, newer comparison point. Results will be added only for boards that
are actually measured.

## Out of scope

- **NVIDIA Jetson Orin NX** — removed from the comparison plan. No measurements
  will be reported for it.
- **NPU/DSP offload** — not supported by the llama.cpp backends used here.

## Cross-platform controls

To keep comparisons meaningful:

- Use the same GGUF files (verify SHA-256 in `environment.txt`).
- Use the same llama.cpp commit and build flags where possible.
- Use the same `pp512` / `tg128` workload and thread counts.
- Record the RAM variant, storage type, OS image, kernel, and cooling setup.
- Run the thermal logger for every campaign.
- Report the board's power mode and CPU governor if it exposes one.
