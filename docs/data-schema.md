# Data schema

## Directory layout

```text
results/
└── <platform>/
    └── run-YYYYMMDD-HHMMSS/
        ├── environment.txt
        ├── README.md
        ├── results/
        │   ├── all_results.csv
        │   ├── test_boundaries.csv
        │   └── summary.txt
        ├── raw/
        │   └── <quant>-<backend>-t<threads>-r<repeat>.txt
        ├── logs/
        │   ├── <tag>-time.txt
        │   └── temperature.csv
        ├── perplexity/
        │   ├── perplexity_results.csv
        │   └── <quant>-perplexity.txt
        └── accuracy/
            └── accuracy_results.csv
```

Platform slugs: `gemstone-o1`, `arduino-uno-q`, and optionally
`raspberry-pi-4b` / `raspberry-pi-5`.

## `results/all_results.csv`

| Column | Type | Meaning |
|---|---|---|
| `quant` | string | Quantization tag: `q4_0`, `q4_k_m`, `q5_k_m`, `q8_0` |
| `backend` | string | `cpu` or `gpu` |
| `ngl` | integer | Number of GPU layers offloaded (0 for CPU, 999 for all) |
| `threads` | integer | Thread count passed to `llama-bench -t` |
| `repeat` | integer | Outer repetition index (1-based) |
| `pp_tps` | float or `NA` | Prompt-processing throughput, tokens/s (`pp512`) |
| `tg_tps` | float or `NA` | Token-generation throughput, tokens/s (`tg128`) |
| `ram_mb` | integer or `NA` | Peak resident set size in MiB (GNU time) |
| `model_size_mb` | integer | GGUF file size in MiB |
| `timestamp` | ISO 8601 | End of the run, local time |

Historical rows may contain `NA` in `ram_mb` because the preliminary harness
did not measure it.

## `results/test_boundaries.csv`

| Column | Meaning |
|---|---|
| `tag` | Configuration tag, e.g. `q5_k_m-cpu-t4-r1` |
| `start_ts` | Start of the `llama-bench` invocation |
| `end_ts` | End of the invocation |

Join this file with `logs/temperature.csv` on timestamps to attribute thermal
readings to a configuration.

## `perplexity/perplexity_results.csv`

| Column | Meaning |
|---|---|
| `quant` | Quantization tag |
| `final_ppl` | Final perplexity, or `NA` if the run did not finish |
| `chunks_done` | Number of completed chunks |
| `status` | `completed`, `interrupted`, or `failed` |
| `timestamp` | End of the attempt |

The preliminary run records the interrupted attempt explicitly
(`final_ppl=NA`, `chunks_done=16`, `status=interrupted`).

## `accuracy/accuracy_results.csv`

| Column | Meaning |
|---|---|
| `quant` | Quantization tag |
| `question_id` | 1-based question index |
| `question` | Prompt text |
| `expected` | Expected fixed substring |
| `answer_snippet` | First 120 characters of the answer |
| `correct` | `1` or `0` |
| `timestamp` | End of the question |

## `environment.txt`

Free-form manifest written by the harness: platform, run ID, hostname,
kernel, CPU model, memory, llama.cpp version, backend/thread/quant lists,
model filenames, sizes, and SHA-256 hashes.
