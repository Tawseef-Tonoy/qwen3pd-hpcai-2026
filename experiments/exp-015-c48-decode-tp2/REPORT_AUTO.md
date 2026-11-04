# Automated AIPerf Analysis

Experiment: `exp-015-c48-decode-tp2`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 48 | 628 | 0.065 | 100.0% | 6.5% | N/A | N/A | Decode / ITL |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 48 | 100.0% | 100.0% | 10.2% | 2.9% | 2.9% |

## Automatic findings

- Strong temporal non-stationarity was detected, consistent with startup/warm-up effects. Whole-run exploratory GFR should not be treated as steady-state performance.
- C48: Decode / ITL in the second-half steady-state proxy.

## Decision

**Status:** NO_VALID_POINT

**Current candidate:** C48

**Recommended next action:** No tested point is SLA-valid. Best steady-state candidate is C48; dominant limitation: Decode / ITL.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
