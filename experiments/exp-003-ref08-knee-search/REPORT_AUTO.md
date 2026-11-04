# Automated AIPerf Analysis

Experiment: `exp-003-ref08-knee-search`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 32 | 54 | 0.574 | 57.4% | 100.0% | 0.502 | 100.4 | TTFT / pre-first-token |
| 34 | 182 | 0.341 | 34.1% | 100.0% | 0.734 | 146.8 | TTFT / pre-first-token |
| 36 | 126 | 0.786 | 78.6% | 100.0% | 1.591 | 318.1 | TTFT / pre-first-token |
| 38 | 308 | 0.500 | 79.9% | 68.5% | 2.379 | 475.8 | Mixed / both |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 32 | 29.6% | 85.2% | 100.0% | 100.0% | 85.2% |
| 34 | 16.5% | 51.6% | 100.0% | 100.0% | 51.6% |
| 36 | 57.1% | 100.0% | 100.0% | 100.0% | 100.0% |
| 38 | 59.7% | 100.0% | 88.3% | 48.7% | 48.7% |

## Automatic findings

- Strong temporal non-stationarity was detected, consistent with startup/warm-up effects. Whole-run exploratory GFR should not be treated as steady-state performance.
- C32: TTFT / pre-first-token in the second-half steady-state proxy.
- C34: TTFT / pre-first-token in the second-half steady-state proxy.
- C36: SLA-valid in the second-half steady-state proxy.
- C38: Decode / ITL in the second-half steady-state proxy.

## Decision

**Status:** EXPLORE

**Current candidate:** C36

**Recommended next action:** Exploratory SLA knee lies between C36 and C38. Test an intermediate concurrency.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
