# EXP-012 — Explicit Decode Round-Robin at C48

## Objective

Determine whether explicit Decode replica load balancing improves the
current C48 8P+8D operating point.

## Baseline

EXP-011 C48:

- GFR = 0.953
- TTFT pass = 100%
- ITL pass = 95.3%
- Good req/s = 10.139
- Good output = 2027.8 tokens/s
- TTFT p90 = 894.2 ms
- ITL p90 = 19.76 ms

The system is close to the Decode SLA boundary while Prefill has
substantial latency headroom.

## Hypothesis

The two Decode replicas may benefit from explicit round-robin routing.

## Independent variable

Decode routing:

- baseline: router default
- EXP-012: round_robin

## Fixed serving configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 GPUs
- 8 Prefill GPUs
- 4 Prefill workers × TP2
- 8 Decode GPUs
- 2 Decode workers × TP4 / EP4
- Prefill routing = round_robin
- NIXL
- max-running-requests = 256
- mem-fraction-static = 0.90
- concurrency = 48

## Benchmark

- warmup = 60 s
- profile = 60 s
- grace = 15 s
- input = 4000
- output = 200
- TTFT <= 3000 ms
- ITL <= 20 ms

## Success

A useful improvement would show one or more of:

- higher GFR
- lower ITL
- higher good requests/sec
- higher good output tokens/sec

without materially hurting TTFT.

## Decision

If Decode round-robin improves C48, retain it and probe higher concurrency.

If performance is unchanged or worse, return to the existing Decode policy
and investigate continuous batching / Decode scheduling next.
