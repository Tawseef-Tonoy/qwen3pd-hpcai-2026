# Automated AIPerf Analysis

Experiment: `exp-005-ref08-c36-roundrobin`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 36 | 952 | 0.038 | 100.0% | 3.8% | N/A | N/A | Decode / ITL |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 36 | 100.0% | 100.0% | 4.2% | 3.4% | 3.4% |

## Automatic findings

- C36: Decode / ITL in the second-half steady-state proxy.

## Decision

**Status:** FAIL

**Current candidate:** C36

**Recommended next action:** Official SLA failed. Dominant limitation: Decode / ITL. Optimize the corresponding serving path before another official validation.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
