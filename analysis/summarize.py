#!/usr/bin/env python3
"""Validate and summarize llama.cpp benchmark results.

The script uses only the Python standard library. It discovers every
``results/<platform>/<run-id>/results/all_results.csv`` file, validates the
schema, checks that raw output exists, and prints an aggregated Markdown table.

Examples:
    python3 analysis/summarize.py
    python3 analysis/summarize.py --check
    python3 analysis/summarize.py --output results/summary.md
"""

from __future__ import annotations

import argparse
import csv
import statistics
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS_ROOT = ROOT / "results"

COLUMNS = [
    "quant",
    "backend",
    "ngl",
    "threads",
    "repeat",
    "pp_tps",
    "tg_tps",
    "ram_mb",
    "model_size_mb",
    "timestamp",
]

NUMERIC_COLUMNS = ("ngl", "threads", "repeat", "model_size_mb")


def discover_csvs() -> list[Path]:
    """Return all result CSVs, sorted by platform and run id."""
    return sorted(RESULTS_ROOT.glob("*/*/results/all_results.csv"))


def parse_number(value: str, column: str, context: str) -> float | None:
    if value in ("", "NA"):
        return None
    try:
        return float(value)
    except ValueError as exc:
        raise ValueError(f"{context}: column '{column}' is not numeric: {value!r}") from exc


def load_rows(csv_path: Path) -> tuple[list[dict[str, str]], list[str]]:
    """Load and validate one CSV; return rows and a list of error messages."""
    errors: list[str] = []
    rows: list[dict[str, str]] = []

    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != COLUMNS:
            errors.append(
                f"{csv_path}: unexpected header {reader.fieldnames!r}; expected {COLUMNS!r}"
            )
            return rows, errors

        for line_number, row in enumerate(reader, start=2):
            context = f"{csv_path}:{line_number}"
            if any(row[column] in (None, "") for column in COLUMNS):
                errors.append(f"{context}: missing value in one or more columns")
                continue

            for column in NUMERIC_COLUMNS:
                try:
                    parse_number(row[column], column, context)
                except ValueError as exc:
                    errors.append(str(exc))

            for column in ("pp_tps", "tg_tps", "ram_mb"):
                try:
                    parse_number(row[column], column, context)
                except ValueError as exc:
                    errors.append(str(exc))

            if row["backend"] not in ("cpu", "gpu"):
                errors.append(f"{context}: backend must be 'cpu' or 'gpu', got {row['backend']!r}")

            rows.append(row)

    return rows, errors


def tag_for(row: dict[str, str]) -> str:
    return f"{row['quant']}-{row['backend']}-t{row['threads']}-r{row['repeat']}"


def check_raw_files(csv_path: Path, rows: list[dict[str, str]]) -> list[str]:
    raw_dir = csv_path.parent.parent / "raw"
    errors = []
    for row in rows:
        raw_file = raw_dir / f"{tag_for(row)}.txt"
        if not raw_file.is_file():
            errors.append(f"{csv_path}: missing raw output {raw_file}")
        elif raw_file.stat().st_size == 0:
            errors.append(f"{csv_path}: raw output is empty {raw_file}")
    return errors


def fmt(value: float | None, digits: int = 2) -> str:
    if value is None:
        return "—"
    return f"{value:.{digits}f}"


def summarize(csv_path: Path, rows: list[dict[str, str]]) -> list[str]:
    platform = csv_path.parents[2].name
    run_id = csv_path.parents[1].name
    lines = [f"### {platform} / {run_id}", ""]

    groups: dict[tuple[str, str, str, str], dict[str, list[float]]] = defaultdict(
        lambda: {"pp": [], "tg": [], "ram": []}
    )
    for row in rows:
        key = (row["quant"], row["backend"], row["ngl"], row["threads"])
        for metric, column in (("pp", "pp_tps"), ("tg", "tg_tps"), ("ram", "ram_mb")):
            value = parse_number(row[column], column, "aggregate")
            if value is not None:
                groups[key][metric].append(value)

    quantizations = sorted({row["quant"] for row in rows})
    threads = sorted({int(row["threads"]) for row in rows})
    backends = sorted({row["backend"] for row in rows})

    lines.append(
        f"{len(rows)} runs · quantizations: {', '.join(quantizations)} · "
        f"threads: {', '.join(str(t) for t in threads)} · "
        f"backends: {', '.join(backends)}"
    )
    lines.append("")
    lines.append(
        "| quant | backend | ngl | threads | n | pp512 (tok/s) | tg128 (tok/s) | peak RAM (MB) |"
    )
    lines.append("|---|---|---:|---:|---:|---:|---:|---:|")

    for key in sorted(groups, key=lambda k: (k[0], k[1], int(k[2]), int(k[3]))):
        quant, backend, ngl, threads_value = key
        values = groups[key]
        n = max(len(values["pp"]), len(values["tg"]))
        pp = statistics.mean(values["pp"]) if values["pp"] else None
        tg = statistics.mean(values["tg"]) if values["tg"] else None
        ram = statistics.mean(values["ram"]) if values["ram"] else None
        lines.append(
            f"| {quant} | {backend} | {ngl} | {threads_value} | {n} | "
            f"{fmt(pp)} | {fmt(tg)} | {fmt(ram, 0)} |"
        )

    lines.append("")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate schemas and raw files; do not print the table",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="write Markdown to this path instead of stdout",
    )
    args = parser.parse_args()

    csv_files = discover_csvs()
    if not csv_files:
        print("No result CSVs found under results/.", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    all_lines: list[str] = ["# Benchmark summary", ""]

    for csv_path in csv_files:
        try:
            rows, errors = load_rows(csv_path)
        except OSError as exc:
            all_errors.append(f"{csv_path}: {exc}")
            continue

        all_errors.extend(errors)
        all_errors.extend(check_raw_files(csv_path, rows))
        if rows:
            all_lines.extend(summarize(csv_path, rows))

    if all_errors:
        for error in all_errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    if args.check:
        print(f"OK: validated {len(csv_files)} result file(s).")
        return 0

    output = "\n".join(all_lines).rstrip() + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
        print(f"Wrote {args.output}")
    else:
        print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
