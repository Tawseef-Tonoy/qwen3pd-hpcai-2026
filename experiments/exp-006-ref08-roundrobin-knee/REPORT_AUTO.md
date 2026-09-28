# Automated AIPerf Analysis

Experiment: `exp-006-ref08-roundrobin-knee`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 30 | 87 | 0.621 | 62.1% | 100.0% | 0.859 | 171.7 | TTFT / pre-first-token |
| 32 | 441 | 0.231 | 100.0% | 23.1% | 1.596 | 319.1 | Decode / ITL |
| 34 | 454 | 0.064 | 100.0% | 6.4% | 0.456 | 91.2 | Decode / ITL |
| 36 | 474 | 0.057 | 100.0% | 5.7% | 0.426 | 85.3 | Decode / ITL |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 30 | 37.2% | 86.4% | 100.0% | 100.0% | 86.4% |
| 32 | 100.0% | 100.0% | 28.6% | 17.6% | 17.6% |
| 34 | 100.0% | 100.0% | 7.5% | 5.3% | 5.3% |
| 36 | 100.0% | 100.0% | 8.9% | 2.5% | 2.5% |

## Automatic findings

- Strong temporal non-stationarity was detected, consistent with startup/warm-up effects. Whole-run exploratory GFR should not be treated as steady-state performance.
- C30: TTFT / pre-first-token in the second-half steady-state proxy.
- C32: Decode / ITL in the second-half steady-state proxy.
- C34: Decode / ITL in the second-half steady-state proxy.
- C36: Decode / ITL in the second-half steady-state proxy.

## Decision

**Status:** NO_VALID_POINT

**Current candidate:** C30

**Recommended next action:** No tested point is SLA-valid. Best steady-state candidate is C30; dominant limitation: TTFT / pre-first-token.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
