# EXP-006 — Round-Robin Decode SLA Knee Search

## Objective

Find the highest concurrency supported by the REF08 12P+4D topology after
fixing Prefill routing imbalance with round-robin routing.

## Motivation

EXP-005 eliminated catastrophic TTFT stalls:

- TTFT avg: 468 ms
- TTFT p90: 502 ms
- TTFT max: 1.70 s

However C36 became Decode limited:

- ITL avg: 20.80 ms
- ITL p90: 20.99 ms

The target ITL is <=20 ms.

## Fixed serving configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 GPUs
- 12 Prefill GPUs
- 4 Decode GPUs
- 6 Prefill workers × TP2
- 1 Decode worker × TP4 / EP4
- NIXL
- round-robin Prefill routing
- max-running-requests = 256
- mem-fraction-static = 0.90

## Concurrency sweep

- C30
- C32
- C34
- C36

## Exploratory benchmark

- warmup = 20 s
- profile = 60 s
- grace = 15 s
- input = 4000 tokens
- output = 200 tokens
- TTFT threshold = 3000 ms
- ITL threshold = 20 ms

## Question

What is the highest concurrency where the full profiling run satisfies:

- TTFT <= 3000 ms
- ITL <= 20 ms
- good-request fraction >= 0.90?

## Decision rule

Select the highest SLA-valid concurrency.

Then validate that single concurrency using the exact official
60/120/30 benchmark in EXP-007.

If none of C30-C36 is SLA-valid, extend the search below C30.

If C34 or C36 is close but Decode-limited, future experiments may test
additional Decode capacity/topology rather than further Prefill changes.
