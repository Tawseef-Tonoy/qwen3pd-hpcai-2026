#!/usr/bin/env python3

import argparse
import csv
import json
import math
import re
from pathlib import Path


def metric_value(record, name):
    metric = record.get("metrics", {}).get(name)
    if not isinstance(metric, dict):
        return None

    value = metric.get("value")

    if isinstance(value, (int, float)):
        return float(value)

    return None


def percentile(values, p):
    values = sorted(values)

    if not values:
        return None

    if len(values) == 1:
        return values[0]

    pos = (len(values) - 1) * p
    lo = math.floor(pos)
    hi = math.ceil(pos)

    if lo == hi:
        return values[lo]

    frac = pos - lo

    return values[lo] * (1 - frac) + values[hi] * frac


def read_csv_metrics(path):
    metrics = {}

    if not path.exists():
        return metrics

    with path.open(newline="") as f:
        reader = csv.DictReader(f)

        for row in reader:
            metric = row.get("metric") or row.get("Metric")

            if not metric:
                continue

            value = (
                row.get("mean")
                or row.get("avg")
                or row.get("value")
            )

            try:
                metrics[metric] = float(value)
            except (TypeError, ValueError):
                pass

    return metrics


def recursive_find(obj, target):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == target:
                return v

            result = recursive_find(v, target)

            if result is not None:
                return result

    elif isinstance(obj, list):
        for item in obj:
            result = recursive_find(item, target)

            if result is not None:
                return result

    return None


def detect_concurrency(run_dir):
    match = re.search(r"concurrency[_-](\d+)", run_dir.name)

    if match:
        return int(match.group(1))

    for name in ["run_config.json", "inputs.json"]:
        p = run_dir / name

        if not p.exists():
            continue

        try:
            obj = json.loads(p.read_text())

            value = recursive_find(obj, "concurrency")

            if value is not None:
                return int(value)

        except Exception:
            pass

    return None


def load_records(path):
    records = []

    with path.open() as f:
        for line in f:
            line = line.strip()

            if not line:
                continue

            r = json.loads(line)
            meta = r.get("metadata", {})

            phase = " ".join(
                str(meta.get(k, ""))
                for k in [
                    "benchmark_phase",
                    "phase_name",
                    "phase_kind",
                ]
            ).lower()

            # We only want profiling data.
            if "warmup" in phase:
                continue

            records.append(r)

    records.sort(
        key=lambda r:
        r.get("metadata", {}).get("request_start_ns", 0)
    )

    return records


def classify_segment(
    records,
    ttft_limit,
    itl_limit,
):
    total = len(records)

    cancelled = 0
    skipped = 0
    missing = 0

    ttft_pass = 0
    itl_pass = 0
    good = 0

    ttfts = []
    itls = []

    for r in records:
        meta = r.get("metadata", {})

        is_cancelled = bool(meta.get("was_cancelled", False))
        is_skipped = bool(meta.get("context_overflow_skip", False))

        if is_cancelled:
            cancelled += 1
            continue

        if is_skipped:
            skipped += 1
            continue

        ttft = metric_value(r, "time_to_first_token")
        itl = metric_value(r, "inter_token_latency")

        if ttft is None or itl is None:
            missing += 1
            continue

        ttfts.append(ttft)
        itls.append(itl)

        ttft_ok = ttft <= ttft_limit
        itl_ok = itl <= itl_limit

        if ttft_ok:
            ttft_pass += 1

        if itl_ok:
            itl_pass += 1

        if ttft_ok and itl_ok:
            good += 1

    def rate(x):
        return x / total if total else 0.0

    return {
        "total": total,
        "cancelled": cancelled,
        "skipped": skipped,
        "missing": missing,

        "ttft_pass": ttft_pass,
        "itl_pass": itl_pass,
        "good": good,

        "ttft_pass_rate": rate(ttft_pass),
        "itl_pass_rate": rate(itl_pass),
        "gfr": rate(good),

        "ttft_avg": sum(ttfts) / len(ttfts) if ttfts else None,
        "ttft_p50": percentile(ttfts, 0.50),
        "ttft_p90": percentile(ttfts, 0.90),
        "ttft_p99": percentile(ttfts, 0.99),

        "itl_avg": sum(itls) / len(itls) if itls else None,
        "itl_p50": percentile(itls, 0.50),
        "itl_p90": percentile(itls, 0.90),
        "itl_p99": percentile(itls, 0.99),
    }


def bottleneck(segment, target_gfr):
    t = segment["ttft_pass_rate"]
    i = segment["itl_pass_rate"]
    g = segment["gfr"]

    if g >= target_gfr:
        return "SLA-valid"

    if t < target_gfr and i >= target_gfr:
        return "TTFT / pre-first-token"

    if t >= target_gfr and i < target_gfr:
        return "Decode / ITL"

    return "Mixed / both"


def analyze_run(
    jsonl,
    ttft_limit,
    itl_limit,
    osl,
):
    run_dir = jsonl.parent

    records = load_records(jsonl)

    full = classify_segment(
        records,
        ttft_limit,
        itl_limit,
    )

    midpoint = len(records) // 2

    first = classify_segment(
        records[:midpoint],
        ttft_limit,
        itl_limit,
    )

    second = classify_segment(
        records[midpoint:],
        ttft_limit,
        itl_limit,
    )

    csv_metrics = read_csv_metrics(
        run_dir / "profile_export_aiperf.csv"
    )

    duration = csv_metrics.get("benchmark_duration_avg")

    goodput = None
    good_tokens = None

    if duration and duration > 0:
        goodput = full["good"] / duration
        good_tokens = goodput * osl

    concurrency = detect_concurrency(run_dir)

    return {
        "concurrency": concurrency,
        "run_dir": str(run_dir),

        "duration": duration,

        "request_throughput":
            csv_metrics.get("request_throughput_avg"),

        "output_token_throughput":
            csv_metrics.get("output_token_throughput_avg"),

        "goodput": goodput,
        "good_tokens_per_second": good_tokens,

        "full": full,
        "first": first,
        "second": second,
    }


def warmup_warning(result):
    first = result["first"]
    second = result["second"]

    if not first["total"] or not second["total"]:
        return False

    pass_gain = (
        second["ttft_pass_rate"]
        - first["ttft_pass_rate"]
    )

    f_avg = first["ttft_avg"]
    s_avg = second["ttft_avg"]

    ratio = None

    if f_avg and s_avg and s_avg > 0:
        ratio = f_avg / s_avg

    return (
        pass_gain >= 0.15
        or (ratio is not None and ratio >= 2.0)
    )


def fmt(x, decimals=2):
    if x is None:
        return "N/A"

    return f"{x:.{decimals}f}"


def write_summary_csv(path, results):
    fields = [
        "concurrency",
        "total",
        "cancelled",
        "missing",
        "ttft_pass",
        "ttft_pass_rate",
        "itl_pass",
        "itl_pass_rate",
        "good",
        "gfr",
        "good_req_s",
        "good_tok_s",
        "request_throughput",
        "output_token_throughput",
        "ttft_avg",
        "ttft_p50",
        "ttft_p90",
        "ttft_p99",
        "itl_avg",
        "itl_p50",
        "itl_p90",
        "itl_p99",
    ]

    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()

        for r in results:
            x = r["full"]

            writer.writerow({
                "concurrency": r["concurrency"],
                "total": x["total"],
                "cancelled": x["cancelled"],
                "missing": x["missing"],
                "ttft_pass": x["ttft_pass"],
                "ttft_pass_rate": x["ttft_pass_rate"],
                "itl_pass": x["itl_pass"],
                "itl_pass_rate": x["itl_pass_rate"],
                "good": x["good"],
                "gfr": x["gfr"],
                "good_req_s": r["goodput"],
                "good_tok_s": r["good_tokens_per_second"],
                "request_throughput": r["request_throughput"],
                "output_token_throughput":
                    r["output_token_throughput"],
                "ttft_avg": x["ttft_avg"],
                "ttft_p50": x["ttft_p50"],
                "ttft_p90": x["ttft_p90"],
                "ttft_p99": x["ttft_p99"],
                "itl_avg": x["itl_avg"],
                "itl_p50": x["itl_p50"],
                "itl_p90": x["itl_p90"],
                "itl_p99": x["itl_p99"],
            })


def write_temporal_csv(path, results):
    fields = [
        "concurrency",
        "segment",
        "n",
        "ttft_avg",
        "ttft_pass_rate",
        "itl_avg",
        "itl_pass_rate",
        "gfr",
    ]

    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()

        for r in results:
            for label in ["first", "second"]:
                x = r[label]

                writer.writerow({
                    "concurrency": r["concurrency"],
                    "segment": label,
                    "n": x["total"],
                    "ttft_avg": x["ttft_avg"],
                    "ttft_pass_rate":
                        x["ttft_pass_rate"],
                    "itl_avg": x["itl_avg"],
                    "itl_pass_rate":
                        x["itl_pass_rate"],
                    "gfr": x["gfr"],
                })


def make_decision(results, mode, target_gfr):
    results = sorted(
        results,
        key=lambda r:
            r["concurrency"]
            if r["concurrency"] is not None
            else -1
    )

    warm = any(warmup_warning(r) for r in results)

    full_valid = [
        r for r in results
        if r["full"]["gfr"] >= target_gfr
    ]

    steady_valid = [
        r for r in results
        if r["second"]["gfr"] >= target_gfr
    ]

    decision = {
        "mode": mode,
        "warmup_contamination_detected": warm,
        "status": None,
        "best_concurrency": None,
        "next_action": None,
    }

    if mode == "official":
        if full_valid:
            best = max(
                full_valid,
                key=lambda r:
                    r["goodput"] or 0
            )

            decision["status"] = "PASS"
            decision["best_concurrency"] = best["concurrency"]
            decision["next_action"] = (
                "Official SLA passed. Use this as the current "
                "baseline and optimize for higher goodput while "
                "preserving GFR."
            )

        else:
            best = max(
                results,
                key=lambda r:
                    r["full"]["gfr"]
            )

            b = bottleneck(
                best["full"],
                target_gfr
            )

            decision["status"] = "FAIL"
            decision["best_concurrency"] = best["concurrency"]
            decision["next_action"] = (
                f"Official SLA failed. Dominant limitation: {b}. "
                "Optimize the corresponding serving path before "
                "another official validation."
            )

        return decision

    # Exploratory mode
    if steady_valid:
        highest = max(
            steady_valid,
            key=lambda r:
                r["concurrency"]
            )

        higher = [
            r for r in results
            if (
                r["concurrency"] is not None
                and highest["concurrency"] is not None
                and r["concurrency"] > highest["concurrency"]
            )
        ]

        decision["status"] = "EXPLORE"
        decision["best_concurrency"] = highest["concurrency"]

        if higher:
            upper = min(
                higher,
                key=lambda r: r["concurrency"]
            )

            lo = highest["concurrency"]
            hi = upper["concurrency"]

            candidates = list(
                range(lo + 2, hi, 2)
            )

            if candidates:
                candidate_text = ", ".join(
                    f"C{x}" for x in candidates
                )

                decision["next_action"] = (
                    f"Steady-state SLA knee is bracketed between "
                    f"C{lo} and C{hi}. Fine-sweep "
                    f"{candidate_text} with stronger warm-up control."
                )
            else:
                decision["next_action"] = (
                    f"Steady-state SLA knee lies between "
                    f"C{lo} and C{hi}. Test an intermediate "
                    "concurrency."
                )

        else:
            decision["next_action"] = (
                f"C{highest['concurrency']} is the highest tested "
                "steady-state SLA-valid point. Test slightly higher "
                "concurrency before official validation."
            )

    elif full_valid:
        best = max(
            full_valid,
            key=lambda r:
                r["goodput"] or 0
        )

        decision["status"] = "EXPLORE"
        decision["best_concurrency"] = best["concurrency"]
        decision["next_action"] = (
            f"C{best['concurrency']} is the best full-run "
            "SLA-valid exploratory point. Validate it using the "
            "official benchmark."
        )

    else:
        best = max(
            results,
            key=lambda r: r["second"]["gfr"]
        )

        b = bottleneck(
            best["second"],
            target_gfr
        )

        decision["status"] = "NO_VALID_POINT"
        decision["best_concurrency"] = best["concurrency"]
        decision["next_action"] = (
            f"No tested point is SLA-valid. Best steady-state "
            f"candidate is C{best['concurrency']}; dominant "
            f"limitation: {b}."
        )

    return decision


def write_report(
    path,
    experiment,
    results,
    decision,
    ttft_limit,
    itl_limit,
    target_gfr,
):
    lines = []

    lines.append("# Automated AIPerf Analysis")
    lines.append("")
    lines.append(f"Experiment: `{experiment.name}`")
    lines.append("")
    lines.append("## SLA")
    lines.append("")
    lines.append(f"- TTFT <= {ttft_limit:.0f} ms")
    lines.append(f"- average ITL <= {itl_limit:.0f} ms")
    lines.append(f"- GFR >= {target_gfr:.2f}")
    lines.append("")
    lines.append("## Full-run results")
    lines.append("")
    lines.append(
        "| C | Requests | GFR | TTFT pass | ITL pass | "
        "Good req/s | Good tok/s | Bottleneck |"
    )
    lines.append(
        "|---:|---:|---:|---:|---:|---:|---:|---|"
    )

    for r in results:
        x = r["full"]

        lines.append(
            f"| {r['concurrency']} "
            f"| {x['total']} "
            f"| {x['gfr']:.3f} "
            f"| {x['ttft_pass_rate']:.1%} "
            f"| {x['itl_pass_rate']:.1%} "
            f"| {fmt(r['goodput'], 3)} "
            f"| {fmt(r['good_tokens_per_second'], 1)} "
            f"| {bottleneck(x, target_gfr)} |"
        )

    lines.append("")
    lines.append("## Temporal / warm-state analysis")
    lines.append("")
    lines.append(
        "| C | First TTFT pass | Second TTFT pass | "
        "First ITL pass | Second ITL pass | "
        "Second-half GFR |"
    )
    lines.append(
        "|---:|---:|---:|---:|---:|---:|"
    )

    for r in results:
        f = r["first"]
        s = r["second"]

        lines.append(
            f"| {r['concurrency']} "
            f"| {f['ttft_pass_rate']:.1%} "
            f"| {s['ttft_pass_rate']:.1%} "
            f"| {f['itl_pass_rate']:.1%} "
            f"| {s['itl_pass_rate']:.1%} "
            f"| {s['gfr']:.1%} |"
        )

    lines.append("")
    lines.append("## Automatic findings")
    lines.append("")

    if decision["warmup_contamination_detected"]:
        lines.append(
            "- Strong warm-up/transient behavior was detected. "
            "Whole-run exploratory GFR should not be treated as "
            "steady-state performance."
        )

    for r in results:
        lines.append(
            f"- C{r['concurrency']}: "
            f"{bottleneck(r['second'], target_gfr)} "
            f"in the second-half steady-state proxy."
        )

    lines.append("")
    lines.append("## Decision")
    lines.append("")
    lines.append(
        f"**Status:** {decision['status']}"
    )
    lines.append("")

    if decision["best_concurrency"] is not None:
        lines.append(
            f"**Current candidate:** "
            f"C{decision['best_concurrency']}"
        )
        lines.append("")

    lines.append(
        f"**Recommended next action:** "
        f"{decision['next_action']}"
    )
    lines.append("")
    lines.append(
        "> This report is an automated decision aid. "
        "Official competition claims should be based on exact "
        "official benchmark runs rather than exploratory steady-state "
        "proxies."
    )
    lines.append("")

    path.write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "experiment",
        type=Path,
        help="Experiment directory containing results/",
    )

    parser.add_argument(
        "--mode",
        choices=["exploratory", "official"],
        default="exploratory",
    )

    parser.add_argument(
        "--concurrency",
        type=int,
        default=None,
        help="Fallback concurrency for a single official run",
    )

    parser.add_argument(
        "--ttft",
        type=float,
        default=3000,
    )

    parser.add_argument(
        "--itl",
        type=float,
        default=20,
    )

    parser.add_argument(
        "--gfr",
        type=float,
        default=0.90,
    )

    parser.add_argument(
        "--osl",
        type=int,
        default=200,
    )

    args = parser.parse_args()

    experiment = args.experiment.resolve()
    results_root = experiment / "results"

    paths = sorted(
        results_root.rglob("profile_export.jsonl")
    )

    if not paths:
        raise SystemExit(
            f"No profile_export.jsonl files found under {results_root}"
        )

    results = []

    for path in paths:
        result = analyze_run(
            path,
            args.ttft,
            args.itl,
            args.osl,
        )

        if result["concurrency"] is None:
            result["concurrency"] = args.concurrency

        results.append(result)

    # Remove accidental duplicate concurrency entries.
    dedup = {}

    for r in results:
        key = r["concurrency"]

        if key not in dedup:
            dedup[key] = r

    results = list(dedup.values())

    results.sort(
        key=lambda r:
            r["concurrency"]
            if r["concurrency"] is not None
            else -1
    )

    analysis_dir = experiment / "analysis"
    analysis_dir.mkdir(parents=True, exist_ok=True)

    write_summary_csv(
        analysis_dir / "summary_auto.csv",
        results,
    )

    write_temporal_csv(
        analysis_dir / "temporal_auto.csv",
        results,
    )

    decision = make_decision(
        results,
        args.mode,
        args.gfr,
    )

    (
        analysis_dir / "decision_auto.json"
    ).write_text(
        json.dumps(decision, indent=2)
    )

    write_report(
        experiment / "REPORT_AUTO.md",
        experiment,
        results,
        decision,
        args.ttft,
        args.itl,
        args.gfr,
    )

    print()
    print("=" * 94)
    print("AIPERF SLA ANALYSIS")
    print("=" * 94)

    print(
        f"{'C':>4} "
        f"{'REQ':>6} "
        f"{'GFR':>7} "
        f"{'TTFT%':>8} "
        f"{'ITL%':>8} "
        f"{'GOOD/s':>9} "
        f"{'TOK/s':>9} "
        f"{'2H-GFR':>8} "
        f"{'BOTTLENECK':>24}"
    )

    print("-" * 94)

    for r in results:
        x = r["full"]
        s = r["second"]

        print(
            f"{str(r['concurrency']):>4} "
            f"{x['total']:>6} "
            f"{x['gfr']:>7.3f} "
            f"{x['ttft_pass_rate']*100:>7.1f}% "
            f"{x['itl_pass_rate']*100:>7.1f}% "
            f"{fmt(r['goodput'],3):>9} "
            f"{fmt(r['good_tokens_per_second'],1):>9} "
            f"{s['gfr']*100:>7.1f}% "
            f"{bottleneck(s,args.gfr):>24}"
        )

    print()
    print("Warm-up contamination:",
          "YES" if decision["warmup_contamination_detected"]
          else "NO")

    print("Status:", decision["status"])

    if decision["best_concurrency"] is not None:
        print(
            "Current candidate:",
            f"C{decision['best_concurrency']}"
        )

    print()
    print("NEXT ACTION:")
    print(decision["next_action"])

    print()
    print("Generated:")
    print(" ", analysis_dir / "summary_auto.csv")
    print(" ", analysis_dir / "temporal_auto.csv")
    print(" ", analysis_dir / "decision_auto.json")
    print(" ", experiment / "REPORT_AUTO.md")


if __name__ == "__main__":
    main()
