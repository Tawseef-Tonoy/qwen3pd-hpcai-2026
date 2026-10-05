#!/usr/bin/env python3

import csv
import statistics
from datetime import datetime, timedelta, timezone
from pathlib import Path

RUN = Path("runs/21217")

FILES = {
    "PREFILL": RUN / "gpu-head.csv",
    "DECODE": RUN / "gpu-tail.csv",
}

start_utc = datetime.fromisoformat(
    (RUN / "aiperf_start_utc.txt").read_text().strip()
    .replace("Z", "+00:00")
)

end_utc = datetime.fromisoformat(
    (RUN / "aiperf_end_utc.txt").read_text().strip()
    .replace("Z", "+00:00")
)

# nvidia-smi timestamps on Firmus are UTC+8.
NODE_OFFSET = timedelta(hours=8)

start_local = (start_utc + NODE_OFFSET).replace(tzinfo=None)
end_local = (end_utc + NODE_OFFSET).replace(tzinfo=None)


def percentile(values, q):
    values = sorted(values)

    if not values:
        return float("nan")

    pos = (len(values) - 1) * q
    lo = int(pos)
    hi = min(lo + 1, len(values) - 1)
    frac = pos - lo

    return values[lo] * (1 - frac) + values[hi] * frac


def f(row, key):
    x = row[key].strip()

    try:
        return float(x)
    except Exception:
        return None


print()
print("AIPERF WINDOW")
print("=" * 72)
print("UTC start :", start_utc)
print("UTC end   :", end_utc)
print("Local +8  :", start_local, "->", end_local)


for role, path in FILES.items():

    rows = []

    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):

            ts = datetime.strptime(
                row["timestamp"].strip(),
                "%Y/%m/%d %H:%M:%S.%f",
            )

            if not (start_local <= ts <= end_local):
                continue

            row["_ts"] = ts
            rows.append(row)

    print()
    print("=" * 72)
    print(role, "-", path.name)
    print("=" * 72)

    if not rows:
        print("NO ROWS IN AIPERF WINDOW")
        continue

    timestamps = sorted(set(r["_ts"] for r in rows))
    gpu_ids = sorted(set(int(r["index"].strip()) for r in rows))

    print("rows             :", len(rows))
    print("snapshots        :", len(timestamps))
    print("GPUs observed    :", gpu_ids)
    print("first sample     :", timestamps[0])
    print("last sample      :", timestamps[-1])

    metrics = [
        ("gpu_util_pct",       "GPU util %"),
        ("memory_util_pct",    "Memory util %"),
        ("memory_used_mib",    "Memory used MiB"),
        ("power_w",            "Power W"),
        ("sm_clock_mhz",       "SM clock MHz"),
        ("memory_clock_mhz",   "Memory clock MHz"),
        ("temperature_c",      "Temperature C"),
    ]

    print()
    print("NODE AGGREGATE")
    print("-" * 72)

    for key, label in metrics:

        vals = [
            f(r, key)
            for r in rows
            if f(r, key) is not None
        ]

        print(
            f"{label:18s}"
            f" mean={statistics.mean(vals):9.2f}"
            f" p50={percentile(vals, .50):9.2f}"
            f" p90={percentile(vals, .90):9.2f}"
            f" max={max(vals):9.2f}"
        )

    print()
    print("PER GPU")
    print("-" * 72)

    for gpu in gpu_ids:

        g = [
            r for r in rows
            if int(r["index"].strip()) == gpu
        ]

        util = [f(r, "gpu_util_pct") for r in g]
        memu = [f(r, "memory_util_pct") for r in g]
        power = [f(r, "power_w") for r in g]

        util = [x for x in util if x is not None]
        memu = [x for x in memu if x is not None]
        power = [x for x in power if x is not None]

        print(
            f"GPU {gpu}: "
            f"util avg={statistics.mean(util):6.1f}% "
            f"p90={percentile(util,.90):6.1f}% | "
            f"mem avg={statistics.mean(memu):6.1f}% "
            f"p90={percentile(memu,.90):6.1f}% | "
            f"power avg={statistics.mean(power):7.1f}W "
            f"p90={percentile(power,.90):7.1f}W"
        )

print()
