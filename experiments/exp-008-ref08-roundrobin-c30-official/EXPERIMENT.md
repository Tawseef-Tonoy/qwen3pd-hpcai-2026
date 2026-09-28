# EXP-008 — Round-Robin C30 Official Validation

## Objective

Validate C30 using the exact official benchmark after EXP-006/007 narrowed
the Decode SLA boundary to between C30 and C31.

## Evidence

EXP-006 C30:

- ITL pass = 100%
- late-run TTFT became healthy
- final chronological decile:
  - TTFT pass = 100%
  - ITL pass = 100%

EXP-007 C31:

- TTFT pass = 100%
- ITL pass = 8.5%
- GFR = 8.5%
- ITL p90 = 20.53 ms

Therefore C30 is the highest current SLA candidate.

## Configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 GPUs
- 12 Prefill GPUs
- 4 Decode GPUs
- 6 Prefill workers × TP2
- 1 Decode worker × TP4 / EP4
- NIXL
- round-robin Prefill routing
- concurrency = 30
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
C30 becomes the first official SLA-valid baseline.

FAIL due TTFT:
investigate startup/preconditioning behavior while keeping C30.

FAIL due ITL:
the Decode knee lies below C30 and the search must continue downward.
