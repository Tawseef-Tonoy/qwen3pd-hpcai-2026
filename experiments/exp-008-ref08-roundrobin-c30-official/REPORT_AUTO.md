# Automated AIPerf Analysis

Experiment: `exp-008-ref08-roundrobin-c30-official`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 30 | 817 | 0.137 | 100.0% | 13.7% | N/A | N/A | Decode / ITL |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 30 | 100.0% | 100.0% | 22.1% | 5.4% | 5.4% |

## Automatic findings

- C30: Decode / ITL in the second-half steady-state proxy.

## Decision

**Status:** FAIL

**Current candidate:** C30

**Recommended next action:** Official SLA failed. Dominant limitation: Decode / ITL. Optimize the corresponding serving path before another official validation.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
