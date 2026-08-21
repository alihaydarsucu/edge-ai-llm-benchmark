# Building llama.cpp

The benchmark harness calls `llama-bench`, `llama-cli`, and
`llama-perplexity` from a single build directory. The preliminary run used
build `bf0040e`.

## 1. Dependencies

On a Debian-based image:

```bash
sudo apt update
sudo apt install -y build-essential cmake git libcurl4-openssl-dev
```

For the Vulkan backend, also install the Vulkan loader and shader compiler:

```bash
sudo apt install -y libvulkan-dev vulkan-tools glslc
```

## 2. CPU-only build

```bash
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
git checkout bf0040e

cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j2
```

Use `-j2` on a four-core board. Higher parallelism can trigger the OOM killer
on a 4 GB system. On a 2 GB Arduino UNO Q, use `-j1` and enable swap or zram.

## 3. Vulkan build

```bash
cmake -B build-vulkan \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_VULKAN=ON
cmake --build build-vulkan -j2
```

If your distribution provides a system shaderc/glslc, prefer it. If CMake
fetches and compiles shaderc from source, the build is memory-hungry.

### If the build runs out of memory

Symptoms: `cc1plus` or `glslc` is killed, the SSH session drops, or `dmesg`
shows an OOM kill.

Mitigations, in order:

1. Reduce parallelism: `cmake --build build-vulkan -j1`.
2. Add swap (temporary file or zram) for the duration of the build.
3. Build on a host with more RAM and copy the resulting `build-vulkan/bin/`
   directory to the board. Keep the same architecture (aarch64) and, if
   possible, the same OS libraries.
4. Build only the targets you need:
   `cmake --build build-vulkan -j2 --target llama-bench llama-cli llama-perplexity`.

## 4. Verify the backend

CPU build:

```bash
./build/bin/llama-bench --version
```

Vulkan build:

```bash
vulkaninfo --summary
./build-vulkan/bin/llama-bench -m /path/to/model.gguf -p 16 -n 16 -ngl 999
```

The run must print a `ggml_vulkan: Found ...` line and the model must be
offloaded. If it silently uses the CPU, do not record the run as a GPU result.
The harness checks for a Vulkan trace in the binary and refuses to run GPU
configurations unless `ALLOW_CPU_FALLBACK=1` is set.

## 5. Recommended directory layout

```text
~/llama.cpp/build/bin/            # CPU build used by default
~/models/*.gguf                   # quantized models
~/models/wikitext-2-raw/wiki.test.raw
```

The scripts read `LLAMA_BIN` and `MODELS_DIR`, so a different layout is fine.
