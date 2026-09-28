# EXP-009 — REF07 8P+8D Round-Robin

## Status

COMPLETE — Best configuration so far.

## Objective

Test whether reallocating GPUs from the overprovisioned Prefill side to
Decode improves SLA-valid throughput.

## Configuration

Model:
- Qwen3-235B-A22B-Instruct-2507-FP8

Topology:
- 16 GPUs total
- Prefill: 8 GPUs
- 4 workers × TP2
- Decode: 8 GPUs
- 2 workers × TP4 / EP4
- NIXL KV transfer

Routing:
- Prefill policy = round_robin

Benchmark:
- Input = 4000 tokens
- Output = 200 tokens
- Warmup = 60 s
- Profile = 60 s
- Grace = 15 s

Exploratory concurrency:
- C32
- C36
- C40

SLA:
- TTFT <= 3000 ms
- ITL <= 20 ms
- Required GFR >= 0.90

## Results

| C | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | TTFT p90 | ITL p90 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 32 | 0.570 | 57.0% | 100.0% | 0.963 | 192.6 | 51343.5 ms | 18.33 ms |
| 36 | 0.970 | 100.0% | 97.0% | 8.206 | 1641.1 | 996.3 ms | 18.74 ms |
| 40 | 0.966 | 100.0% | 96.6% | 8.954 | 1790.8 | 762.0 ms | 18.70 ms |

## Temporal analysis

C36:
- first-half GFR = 94.0%
- second-half GFR = 100.0%

C40:
- first-half GFR = 93.2%
- second-half GFR = 100.0%

Therefore C36 and C40 are not merely second-half passes. Their complete
profiling windows clear the 90% SLA gate.

C32 was affected by severe initial TTFT/cold-path behavior while Decode ITL
remained healthy.

## Comparison against 12P+4D

At C36:

12P+4D round-robin:
- GFR = 3.8%
- TTFT pass = 100%
- ITL pass = 3.8%
- ITL p90 = 20.99 ms

8P+8D round-robin:
- GFR = 97.0%
- TTFT pass = 100%
- ITL pass = 97.0%
- ITL p90 = 18.74 ms

Reallocating four GPUs from Prefill to Decode therefore removed the stable
Decode bottleneck and dramatically increased SLA-valid throughput.

## Current best

C40:
- GFR = 96.6%
- Good requests/sec = 8.954
- Good output tokens/sec = 1790.8
- TTFT p90 = 762 ms
- ITL p90 = 18.70 ms

This is the strongest Basic-compatible candidate obtained so far.

## Interpretation

The previous 12P+4D topology overprovisioned Prefill while starving Decode.

The 8P+8D topology produces a substantially better balance between:
- Prefill latency
- Decode latency
- SLA-valid throughput

## Next step

Do not declare C40 final yet.

C40 still has latency headroom:
- TTFT p90 0.762 s vs 3.0 s SLA
- ITL p90 18.70 ms vs 20 ms SLA

Next:
search above C40 using the same 8P+8D topology and routing.

After locating the throughput/SLA knee, run the best point with the exact
official 60/120/30 AIPerf command.
