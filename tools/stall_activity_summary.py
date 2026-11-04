#!/usr/bin/env python3

import re
from pathlib import Path
from datetime import datetime

ROOT = Path(
    "experiments/exp-004-ref08-c36-official/results"
)

WORKER_START = datetime.strptime(
    "2026-09-29 01:44:20",
    "%Y-%m-%d %H:%M:%S",
)

WORKER_END = datetime.strptime(
    "2026-09-29 01:47:05",
    "%Y-%m-%d %H:%M:%S",
)

ROUTER_START = datetime.strptime(
    "2026-09-28 17:44:20",
    "%Y-%m-%d %H:%M:%S",
)

ROUTER_END = datetime.strptime(
    "2026-09-28 17:47:05",
    "%Y-%m-%d %H:%M:%S",
)

TS = re.compile(
    r"\[?(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"
)

QUEUE = re.compile(r"#queue-req:\s*(\d+)")
RUNNING = re.compile(r"#running-req:\s*(\d+)")
TRANSFER = re.compile(r"#transfer-req:\s*(\d+)")
RETRACT = re.compile(r"#retracted-req:\s*(\d+)")

BAD = re.compile(
    r"warn|error|fail|timeout|unhealthy|"
    r"disconnect|exception|health check",
    re.I,
)


def parse_time(line):
    m = TS.search(line)

    if not m:
        return None

    try:
        return datetime.strptime(
            m.group(1),
            "%Y-%m-%d %H:%M:%S",
        )
    except ValueError:
        return None


def summarize_worker(path, start, end):
    batch = 0
    bad = 0

    max_queue = 0
    max_running = 0
    max_transfer = 0
    max_retract = 0

    first_event = None
    last_event = None

    with path.open(errors="replace") as f:
        for line in f:
            ts = parse_time(line)

            if ts is None or not (start <= ts <= end):
                continue

            if BAD.search(line):
                bad += 1

            # Count scheduler/batch activity.
            if (
                "Prefill batch" in line
                or "Decode batch" in line
            ):
                batch += 1

                if first_event is None:
                    first_event = ts

                last_event = ts

            m = QUEUE.search(line)
            if m:
                max_queue = max(
                    max_queue,
                    int(m.group(1)),
                )

            m = RUNNING.search(line)
            if m:
                max_running = max(
                    max_running,
                    int(m.group(1)),
                )

            m = TRANSFER.search(line)
            if m:
                max_transfer = max(
                    max_transfer,
                    int(m.group(1)),
                )

            m = RETRACT.search(line)
            if m:
                max_retract = max(
                    max_retract,
                    int(m.group(1)),
                )

    return {
        "batch": batch,
        "bad": bad,
        "queue": max_queue,
        "running": max_running,
        "transfer": max_transfer,
        "retract": max_retract,
        "first": first_event,
        "last": last_event,
    }


print()
print("STALL WINDOW — PREFILL / DECODE")
print("=" * 105)

print(
    f"{'worker':<14}"
    f"{'batches':>10}"
    f"{'warnings':>10}"
    f"{'max_queue':>12}"
    f"{'max_run':>10}"
    f"{'max_xfer':>10}"
    f"{'retract':>10}"
)

print("-" * 105)

for i in range(6):
    p = ROOT / f"prefill-{i}.log"
    s = summarize_worker(
        p,
        WORKER_START,
        WORKER_END,
    )

    print(
        f"{'prefill-'+str(i):<14}"
        f"{s['batch']:>10}"
        f"{s['bad']:>10}"
        f"{s['queue']:>12}"
        f"{s['running']:>10}"
        f"{s['transfer']:>10}"
        f"{s['retract']:>10}"
    )

p = ROOT / "decode-0.log"

s = summarize_worker(
    p,
    WORKER_START,
    WORKER_END,
)

print(
    f"{'decode-0':<14}"
    f"{s['batch']:>10}"
    f"{s['bad']:>10}"
    f"{s['queue']:>12}"
    f"{s['running']:>10}"
    f"{s['transfer']:>10}"
    f"{s['retract']:>10}"
)


print()
print("STALL WINDOW — ROUTER")
print("=" * 105)

router = ROOT / "router.log"

total = 0
bad_lines = []

with router.open(errors="replace") as f:

    for line in f:

        ts = parse_time(line)

        if ts is None:
            continue

        if not (
            ROUTER_START <= ts <= ROUTER_END
        ):
            continue

        total += 1

        if BAD.search(line):
            bad_lines.append(line.rstrip())

print("Router lines in window :", total)
print("Warnings/errors        :", len(bad_lines))

if bad_lines:
    print()
    print("Router abnormalities:")

    for line in bad_lines[-40:]:
        print(line)
