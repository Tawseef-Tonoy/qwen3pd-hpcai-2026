# EXP-011 — 8P+8D Concurrency Knee Search

## Objective

Find whether the validated 8P+8D topology can sustain higher concurrency
than the current C40 official baseline while maintaining GFR >= 0.90.

## Baseline

EXP-010 C40 official:

- GFR = 0.982
- TTFT pass = 100%
- ITL pass = 98.2%
- TTFT p90 = 1117.9 ms
- ITL p90 = 19.16 ms
- AIPerf goodput ≈ 9.21 req/s
- Good output throughput ≈ 1842 tokens/s

## Fixed serving configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 GPUs
- Prefill: 8 GPUs
- 4 workers × TP2
- Decode: 8 GPUs
- 2 workers × TP4 / EP4
- NIXL
- Prefill routing = round_robin
- max-running-requests = 256
- mem-fraction-static = 0.90

## Independent variable

Concurrency:

- C40
- C44
- C48

## Exploratory benchmark

- warmup = 60 s
- profile = 60 s
- grace = 15 s
- input = 4000 tokens
- output = 200 tokens
- TTFT SLA = 3000 ms
- ITL SLA = 20 ms

## Decision rule

Choose the highest concurrency with:

- GFR >= 0.90

But optimize primarily for:

- good requests/sec
- good output tokens/sec

If C48 passes, search above C48.

If C44 passes and C48 fails, refine between C44 and C48.

If C44 fails, refine between C40 and C44.
