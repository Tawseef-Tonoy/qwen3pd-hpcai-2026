# EXP-011 — 8P+8D Concurrency Knee Search

## Status

COMPLETE

## Objective

Determine whether the validated 8P+8D topology can sustain higher
closed-loop concurrency than the C40 official baseline.

## Fixed configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 H200 GPUs
- Prefill: 8 GPUs
- 4 Prefill workers × TP2
- Decode: 8 GPUs
- 2 Decode workers × TP4 / EP4
- NIXL
- Prefill routing = round_robin
- max-running-requests = 256
- mem-fraction-static = 0.90

## Benchmark

- warmup = 60 s
- profile = 60 s
- grace = 15 s
- input = 4000 tokens
- output = 200 tokens
- TTFT SLA = 3000 ms
- ITL SLA = 20 ms

## Results

| C | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | TTFT p90 | ITL p90 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 40 | 1.000 | 100.0% | 100.0% | 3.247 | 649.4 | 2599.2 ms | 17.87 ms |
| 44 | 0.961 | 100.0% | 96.1% | 9.563 | 1912.6 | 829.3 ms | 19.44 ms |
| 48 | 0.953 | 100.0% | 95.3% | 10.139 | 2027.8 | 894.2 ms | 19.76 ms |

## Temporal analysis

C44:
- first-half GFR = 92.1%
- second-half GFR = 100.0%

C48:
- first-half GFR = 90.6%
- second-half GFR = 100.0%

No major temporal/startup instability was identified by the analyzer.

## Interpretation

C48 is the highest tested SLA-valid exploratory point.

The system is now close to the Decode latency boundary:

- TTFT remains far below the 3000 ms limit.
- ITL p90 at C48 is 19.76 ms, very close to the 20 ms limit.

Therefore further optimization should focus primarily on Decode rather than
Prefill.

## Current best exploratory point

C48:

- GFR = 95.3%
- Good req/s = 10.139
- Good output throughput = 2027.8 tokens/s
- TTFT p90 = 894.2 ms
- ITL p90 = 19.76 ms

## Next experiment

Test whether explicit Decode load balancing improves the C48 operating
point.

Change only:

Decode routing policy:
default -> round_robin

Keep the 8P+8D topology and all other serving parameters unchanged.
