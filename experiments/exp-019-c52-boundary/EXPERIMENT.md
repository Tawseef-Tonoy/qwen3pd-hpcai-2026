# EXP-019 — C52 Goodput Boundary Test

## Goal

Continue the concurrency boundary search using the current best
8P/8D TP4 Decode configuration.

## Baseline

EXP-014 C48:
- GFR = 1.000
- ITL p90 = 19.401 ms
- ITL p99 = 19.474 ms

EXP-018 C50:
- GFR = 1.000
- TTFT pass = 100%
- ITL pass = 100%
- ITL avg = 18.958 ms
- ITL p90 = 19.360 ms
- ITL p99 = 19.437 ms

C50 therefore did not reach the SLA boundary.

## Change

Only:

- concurrency 48 -> 52
- workers-max 48 -> 52

Serving topology, routing, model, precision, benchmark workload and all
other settings remain identical to EXP-014.

## Decision

A candidate is valid only if GFR >= 0.90.

Primary objective:
maximize throughput while remaining above the GFR gate.

If C52 remains valid and throughput increases, continue toward C54.

If C52 is valid but throughput is flat, stop increasing concurrency:
Decode throughput has saturated.

If GFR falls below 0.90, the optimum lies below C52.
