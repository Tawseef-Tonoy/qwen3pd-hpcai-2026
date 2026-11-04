# EXP-018 — C50 Goodput Boundary Test

## Goal

Test whether slightly increasing closed-loop concurrency from C48 to C50
increases SLA-qualified good output tokens/sec.

## Baseline

EXP-014:

- Prefill: 4 × TP2 = 8 GPUs
- Decode: 2 × TP4/EP4 = 8 GPUs
- Prefill routing: round_robin
- Decode routing: round_robin
- concurrency: 48
- GFR: 1.000
- TTFT p90: 892.44 ms
- ITL p90: 19.401 ms
- ITL p99: 19.474 ms
- good output throughput: approximately 2164 tok/s

## Change

One experimental variable only:

- concurrency: 48 -> 50
- workers-max: 48 -> 50

Everything else remains identical to EXP-014.

## Hypothesis

EXP-014 has 100% GFR but ITL is close to the 20 ms SLA.

C50 may trade a small amount of SLA headroom for higher request throughput.

The objective is not maximum GFR.

The objective is maximum SLA-qualified output throughput while maintaining:

GFR >= 0.90

## Decision

Keep C50 only if:

1. GFR >= 0.90
2. good output tok/s > EXP-014 (~2164 tok/s)

If C50 satisfies both, test C52 next.

If C50 fails GFR >= 0.90 or produces lower good output tok/s, retain C48.
