# Automated AIPerf Analysis

Experiment: `exp-007-ref08-roundrobin-c31-official`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 31 | 837 | 0.085 | 100.0% | 8.5% | N/A | N/A | Decode / ITL |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 31 | 100.0% | 100.0% | 13.2% | 3.8% | 3.8% |

## Automatic findings

- C31: Decode / ITL in the second-half steady-state proxy.

## Decision

**Status:** FAIL

**Current candidate:** C31

**Recommended next action:** Official SLA failed. Dominant limitation: Decode / ITL. Optimize the corresponding serving path before another official validation.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
