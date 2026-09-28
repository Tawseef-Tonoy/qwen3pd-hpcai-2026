#!/usr/bin/env python3

import argparse
import csv
import json
from pathlib import Path


# ─────────────────────────────────────────────────────────────
# Terminal formatting
# ─────────────────────────────────────────────────────────────

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"

RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"


def heading(text):
    print()
    print(BOLD + CYAN + "=" * 100 + RESET)
    print(BOLD + CYAN + text + RESET)
    print(BOLD + CYAN + "=" * 100 + RESET)


def subheading(text):
    print()
    print(BOLD + text + RESET)
    print("-" * min(100, len(text) + 10))


def pct(value):
    if value in (None, ""):
        return "N/A"

    try:
        return f"{float(value) * 100:.1f}%"
    except Exception:
        return str(value)


def num(value, decimals=2):
    if value in (None, ""):
        return "N/A"

    try:
        return f"{float(value):.{decimals}f}"
    except Exception:
        return str(value)


def status_color(value, threshold, higher_is_better=True):
    try:
        x = float(value)
    except Exception:
        return str(value)

    passed = x >= threshold if higher_is_better else x <= threshold

    if passed:
        return GREEN + f"{x:.3f}" + RESET

    return RED + f"{x:.3f}" + RESET


# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────

def show_summary(path, target_gfr):
    if not path.exists():
        print(YELLOW + f"Missing: {path}" + RESET)
        return

    rows = list(csv.DictReader(path.open()))

    subheading("1. FULL-RUN SLA SUMMARY")

    headers = [
        "C",
        "Req",
        "Cancel",
        "GFR",
        "TTFT%",
        "ITL%",
        "Good/s",
        "Good tok/s",
        "TTFT p90",
        "ITL p90",
    ]

    print(
        f"{headers[0]:>5}"
        f"{headers[1]:>8}"
        f"{headers[2]:>9}"
        f"{headers[3]:>10}"
        f"{headers[4]:>10}"
        f"{headers[5]:>10}"
        f"{headers[6]:>11}"
        f"{headers[7]:>13}"
        f"{headers[8]:>13}"
        f"{headers[9]:>11}"
    )

    print("-" * 100)

    for r in rows:
        try:
            gfr = float(r["gfr"])
        except Exception:
            gfr = 0

        gfr_text = f"{gfr:.3f}"

        if gfr >= target_gfr:
            gfr_text = GREEN + gfr_text + RESET
        else:
            gfr_text = RED + gfr_text + RESET

        print(
            f"{r.get('concurrency', 'N/A'):>5}"
            f"{r.get('total', 'N/A'):>8}"
            f"{r.get('cancelled', 'N/A'):>9}"
            f"{gfr_text:>19}"
            f"{pct(r.get('ttft_pass_rate')):>10}"
            f"{pct(r.get('itl_pass_rate')):>10}"
            f"{num(r.get('good_req_s'), 3):>11}"
            f"{num(r.get('good_tok_s'), 1):>13}"
            f"{num(r.get('ttft_p90'), 1):>13}"
            f"{num(r.get('itl_p90'), 2):>11}"
        )


# ─────────────────────────────────────────────────────────────
# Temporal analysis
# ─────────────────────────────────────────────────────────────

def show_temporal(path):
    if not path.exists():
        print(YELLOW + f"Missing: {path}" + RESET)
        return

    rows = list(csv.DictReader(path.open()))

    subheading("2. FIRST-HALF vs SECOND-HALF / WARM-UP ANALYSIS")

    print(
        f"{'C':>5}"
        f"{'Segment':>14}"
        f"{'N':>8}"
        f"{'TTFT avg':>13}"
        f"{'TTFT pass':>13}"
        f"{'ITL avg':>11}"
        f"{'ITL pass':>12}"
        f"{'GFR':>10}"
    )

    print("-" * 86)

    for r in rows:
        print(
            f"{r.get('concurrency', 'N/A'):>5}"
            f"{r.get('segment', 'N/A'):>14}"
            f"{r.get('n', 'N/A'):>8}"
            f"{num(r.get('ttft_avg'), 1):>13}"
            f"{pct(r.get('ttft_pass_rate')):>13}"
            f"{num(r.get('itl_avg'), 2):>11}"
            f"{pct(r.get('itl_pass_rate')):>12}"
            f"{pct(r.get('gfr')):>10}"
        )


# ─────────────────────────────────────────────────────────────
# Decision
# ─────────────────────────────────────────────────────────────

def show_decision(path):
    if not path.exists():
        print(YELLOW + f"Missing: {path}" + RESET)
        return

    decision = json.loads(path.read_text())

    subheading("3. AUTOMATIC DECISION")

    status = decision.get("status", "UNKNOWN")

    if status == "PASS":
        status_text = GREEN + BOLD + status + RESET
    elif status in ("FAIL", "NO_VALID_POINT"):
        status_text = RED + BOLD + status + RESET
    else:
        status_text = YELLOW + BOLD + status + RESET

    print(f"Status                  : {status_text}")

    warmup = decision.get("warmup_contamination_detected", False)

    warmup_text = (
        YELLOW + "YES" + RESET
        if warmup
        else GREEN + "NO" + RESET
    )

    print(f"Temporal/startup effects: {warmup_text}")

    candidate = decision.get("best_concurrency")

    if candidate is not None:
        print(f"Current candidate        : C{candidate}")

    print()
    print(BOLD + "Recommended next action:" + RESET)
    print(decision.get("next_action", "No recommendation available."))


# ─────────────────────────────────────────────────────────────
# Human-readable report
# ─────────────────────────────────────────────────────────────

def show_report(path):
    if not path.exists():
        print(YELLOW + f"Missing: {path}" + RESET)
        return

    subheading("4. GENERATED REPORT")

    text = path.read_text()

    # Make Markdown a little cleaner in a plain terminal.
    for line in text.splitlines():

        if line.startswith("# "):
            print()
            print(BOLD + CYAN + line[2:] + RESET)

        elif line.startswith("## "):
            print()
            print(BOLD + line[3:] + RESET)

        elif line.startswith("### "):
            print(BOLD + line[4:] + RESET)

        elif line.startswith("**") and line.endswith("**"):
            print(BOLD + line.strip("*") + RESET)

        else:
            print(line)


# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Display generated AIPerf analysis in the terminal."
    )

    parser.add_argument(
        "experiment",
        type=Path,
        help="Experiment directory, e.g. experiments/exp-002-ref08-exploratory",
    )

    parser.add_argument(
        "--gfr",
        type=float,
        default=0.90,
        help="Required good-request fraction (default: 0.90)",
    )

    parser.add_argument(
        "--no-report",
        action="store_true",
        help="Do not print the full REPORT_AUTO.md",
    )

    args = parser.parse_args()

    experiment = args.experiment.resolve()
    analysis = experiment / "analysis"

    if not experiment.exists():
        raise SystemExit(f"Experiment does not exist: {experiment}")

    heading(f"AIPerf Experiment Analysis — {experiment.name}")

    print(DIM + f"Path: {experiment}" + RESET)

    show_summary(
        analysis / "summary_auto.csv",
        args.gfr,
    )

    show_temporal(
        analysis / "temporal_auto.csv",
    )

    show_decision(
        analysis / "decision_auto.json",
    )

    if not args.no_report:
        show_report(
            experiment / "REPORT_AUTO.md",
        )

    print()
    print(BOLD + CYAN + "=" * 100 + RESET)
    print(BOLD + "END OF ANALYSIS" + RESET)
    print(BOLD + CYAN + "=" * 100 + RESET)
    print()


if __name__ == "__main__":
    main()
