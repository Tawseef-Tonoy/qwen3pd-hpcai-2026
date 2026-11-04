# EXP-012 — Explicit Decode Round-Robin at C48

## Status

COMPLETE — IMPROVEMENT

## Objective

Test whether explicitly round-robin routing requests across the two Decode
replicas improves the C48 8P+8D operating point.

## Independent variable

Only Decode routing changed.

EXP-011:
- Decode policy = router default

EXP-012:
- Decode policy = round_robin

Everything else remained unchanged.

## Configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 H200 GPUs
- Prefill: 8 GPUs
- 4 workers × TP2
- Decode: 8 GPUs
- 2 workers × TP4 / EP4
- Prefill policy = round_robin
- Decode policy = round_robin
- NIXL
- concurrency = 48

Benchmark:
- warmup = 60 s
- profile = 60 s
- grace = 15 s

## Results

- Requests = 689
- Cancelled = 0
- GFR = 1.000
- TTFT pass = 100%
- ITL pass = 100%
- TTFT p90 = 678.5 ms
- ITL p90 = 19.38 ms
- Request throughput = 10.85 req/s
- AIPerf goodput = 10.85 req/s
- Good output throughput ≈ 2170 tokens/s

Temporal:

- first-half GFR = 100%
- second-half GFR = 100%

## Comparison against EXP-011 C48

EXP-011:
- GFR = 95.3%
- Good req/s = 10.139
- Good output = 2027.8 tokens/s
- TTFT p90 = 894.2 ms
- ITL p90 = 19.76 ms

EXP-012:
- GFR = 100%
- Good req/s = 10.85
- Good output ≈ 2170 tokens/s
- TTFT p90 = 678.5 ms
- ITL p90 = 19.38 ms

Explicit Decode round-robin therefore improved both SLA margin and
SLA-valid throughput at C48.

## Decision

Retain explicit Decode round-robin.

Next:
probe higher concurrency using the same serving configuration.
