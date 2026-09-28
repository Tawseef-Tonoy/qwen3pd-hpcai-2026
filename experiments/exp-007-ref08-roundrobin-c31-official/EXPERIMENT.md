# EXP-007 — Round-Robin C31 Official Validation

## Objective

Determine whether C31 is the highest SLA-valid concurrency for the REF08
12P+4D topology with round-robin Prefill routing.

## Evidence

EXP-006 established:

- C30: Decode-safe, ITL pass 100%, but affected by first-point startup TTFT
- C32: TTFT pass 100%, ITL pass only 23.1%
- C34/C36: clearly Decode limited

Therefore the SLA knee lies between C30 and C32.

## Configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 GPUs
- 12 Prefill GPUs
- 4 Decode GPUs
- 6 Prefill workers × TP2
- 1 Decode worker × TP4 / EP4
- NIXL
- round-robin Prefill routing
- concurrency = 31
- max-running-requests = 256
- mem-fraction-static = 0.90

## Official benchmark

- warmup = 60 s
- benchmark = 120 s
- grace = 30 s
- input = 4000 tokens
- output = 200 tokens
- TTFT <= 3000 ms
- ITL <= 20 ms

## Success criterion

good_request_fraction >= 0.90

## Decision

PASS:
C31 becomes the official baseline.

FAIL due ITL:
C30 becomes the next official validation point.

FAIL due TTFT/startup:
investigate startup stabilization separately.
