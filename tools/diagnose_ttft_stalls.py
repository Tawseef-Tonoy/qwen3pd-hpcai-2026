#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
from datetime import datetime, timezone


def metric(r, name):
    try:
        return float(r["metrics"][name]["value"])
    except Exception:
        return None


def fmt_time(ns, base):
    if ns is None:
        return "N/A"

    # Epoch nanoseconds
    if ns > 1e17:
        return datetime.fromtimestamp(
            ns / 1e9,
            tz=timezone.utc
        ).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3] + "Z"

    return f"+{(ns-base)/1e9:.3f}s"


parser = argparse.ArgumentParser()
parser.add_argument("experiment", type=Path)
args = parser.parse_args()

root = args.experiment / "results"

paths = list(root.glob("profile_export.jsonl"))

if not paths:
    paths = list(root.rglob("profile_export.jsonl"))

if not paths:
    raise SystemExit("profile_export.jsonl not found")

path = paths[0]

rows = []

with path.open() as f:
    for line in f:
        r = json.loads(line)
        m = r.get("metadata", {})

        if m.get("benchmark_phase") != "profiling":
            continue

        if m.get("was_cancelled"):
            continue

        start = m.get("request_start_ns")
        ttft = metric(r, "time_to_first_token")
        itl = metric(r, "inter_token_latency")

        if start is None or ttft is None:
            continue

        rows.append({
            "start": int(start),
            "end_first_token": int(start + ttft * 1e6),
            "ttft": ttft,
            "itl": itl,
            "worker": m.get("worker_id"),
            "request": m.get("x_request_id"),
            "corr": m.get("x_correlation_id"),
        })

rows.sort(key=lambda x: x["start"])

if not rows:
    raise SystemExit("No profiling requests found")

base = rows[0]["start"]

print("\nTOP 25 TTFT REQUESTS")
print("=" * 120)

for r in sorted(rows, key=lambda x: x["ttft"], reverse=True)[:25]:
    print(
        f"TTFT={r['ttft']:9.1f} ms  "
        f"ITL={r['itl'] if r['itl'] is not None else -1:6.2f} ms  "
        f"start={fmt_time(r['start'], base)}  "
        f"first_token={fmt_time(r['end_first_token'], base)}  "
        f"worker={r['worker']}  "
        f"request={r['request']}"
    )


# Merge overlapping TTFT-failure intervals.
bad = [
    r for r in rows
    if r["ttft"] > 3000
]

bad.sort(key=lambda x: x["start"])

episodes = []

for r in bad:
    if not episodes or r["start"] > episodes[-1]["end"]:
        episodes.append({
            "start": r["start"],
            "end": r["end_first_token"],
            "requests": [r],
        })
    else:
        e = episodes[-1]
        e["end"] = max(e["end"], r["end_first_token"])
        e["requests"].append(r)

print("\nSTALL EPISODES")
print("=" * 120)

for i, e in enumerate(episodes, 1):
    reqs = e["requests"]

    print(
        f"Episode {i}: "
        f"{fmt_time(e['start'], base)} -> "
        f"{fmt_time(e['end'], base)} | "
        f"bad_requests={len(reqs)} | "
        f"max_TTFT={max(x['ttft'] for x in reqs):.1f} ms | "
        f"avg_TTFT={sum(x['ttft'] for x in reqs)/len(reqs):.1f} ms"
    )

print()
print(f"Profiling requests : {len(rows)}")
print(f"TTFT failures      : {len(bad)}")
print(f"Pass rate          : {(len(rows)-len(bad))/len(rows):.1%}")
