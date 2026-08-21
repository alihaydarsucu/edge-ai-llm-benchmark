#!/usr/bin/env python3
"""Plot prompt-processing and token-generation throughput from benchmark CSVs.

Requires matplotlib:

    python3 -m pip install -r analysis/requirements.txt
    python3 analysis/plot_results.py
    python3 analysis/plot_results.py --platform gemstone-o1

Output: results/<platform>/plots/throughput.png
"""

from __future__ import annotations

import argparse
import csv
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS_ROOT = ROOT / "results"


def load(platform: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for csv_path in sorted(RESULTS_ROOT.glob(f"{platform}/*/results/all_results.csv")):
        with csv_path.open(newline="", encoding="utf-8") as handle:
            rows.extend(csv.DictReader(handle))
    return rows


def aggregate(rows: list[dict[str, str]], metric: str) -> dict[tuple[str, int], tuple[float, float]]:
    values: dict[tuple[str, int], list[float]] = defaultdict(list)
    for row in rows:
        try:
            value = float(row[metric])
        except (KeyError, ValueError):
            continue
        values[(row["quant"], int(row["threads"]))].append(value)

    result = {}
    for key, samples in values.items():
        mean = statistics.mean(samples)
        stdev = statistics.stdev(samples) if len(samples) > 1 else 0.0
        result[key] = (mean, stdev)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", default="gemstone-o1")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    rows = load(args.platform)
    if not rows:
        print(f"No data for platform '{args.platform}'.")
        return 1

    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib is required: pip install -r analysis/requirements.txt")
        return 1

    quants = sorted({row["quant"] for row in rows})
    threads = sorted({int(row["threads"]) for row in rows})
    pp = aggregate(rows, "pp_tps")
    tg = aggregate(rows, "tg_tps")

    figure, axes = plt.subplots(1, 2, figsize=(11, 4.5), sharex=True)
    width = 0.8 / max(len(quants), 1)

    for index, quant in enumerate(quants):
        offset = (index - (len(quants) - 1) / 2) * width

        pp_means = [pp.get((quant, thread), (0.0, 0.0))[0] for thread in threads]
        pp_errs = [pp.get((quant, thread), (0.0, 0.0))[1] for thread in threads]
        tg_means = [tg.get((quant, thread), (0.0, 0.0))[0] for thread in threads]
        tg_errs = [tg.get((quant, thread), (0.0, 0.0))[1] for thread in threads]

        positions = [thread + offset for thread in threads]
        axes[0].bar(positions, pp_means, width=width, yerr=pp_errs, capsize=3, label=quant)
        axes[1].bar(positions, tg_means, width=width, yerr=tg_errs, capsize=3, label=quant)

    axes[0].set_title("Prompt processing (pp512)")
    axes[0].set_ylabel("tokens / second")
    axes[1].set_title("Token generation (tg128)")
    axes[1].set_ylabel("tokens / second")

    for axis in axes:
        axis.set_xlabel("threads")
        axis.set_xticks(threads)
        axis.grid(axis="y", alpha=0.3)
        axis.legend(title="quantization")

    figure.suptitle(f"{args.platform}: llama.cpp throughput")
    figure.tight_layout()

    output = args.output or RESULTS_ROOT / args.platform / "plots" / "throughput.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=160)
    print(f"Wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
