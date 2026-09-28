# Automated AIPerf Analysis

Experiment: `exp-002-ref08-exploratory`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 8 | 39 | 0.821 | 82.1% | 100.0% | 0.517 | 103.3 | TTFT / pre-first-token |
| 16 | 101 | 0.802 | 80.2% | 100.0% | 1.312 | 262.3 | TTFT / pre-first-token |
| 32 | 171 | 0.702 | 70.2% | 100.0% | 1.922 | 384.4 | TTFT / pre-first-token |
| 40 | 453 | 0.386 | 93.2% | 44.4% | 2.731 | 546.2 | Decode / ITL |
| 48 | 504 | 0.183 | 91.1% | 24.4% | 1.423 | 284.7 | Decode / ITL |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 8 | 63.2% | 100.0% | 100.0% | 100.0% | 100.0% |
| 16 | 60.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| 32 | 44.7% | 95.3% | 100.0% | 100.0% | 95.3% |
| 40 | 86.3% | 100.0% | 46.0% | 42.7% | 42.7% |
| 48 | 84.5% | 97.6% | 29.4% | 19.4% | 19.4% |

## Automatic findings

- Strong temporal non-stationarity was detected, consistent with startup/warm-up effects. Whole-run exploratory GFR should not be treated as steady-state performance.
- C8: SLA-valid in the second-half steady-state proxy.
- C16: SLA-valid in the second-half steady-state proxy.
- C32: SLA-valid in the second-half steady-state proxy.
- C40: Decode / ITL in the second-half steady-state proxy.
- C48: Decode / ITL in the second-half steady-state proxy.

## Decision

**Status:** EXPLORE

**Current candidate:** C32

**Recommended next action:** Exploratory SLA knee is bracketed between C32 and C40. Fine-sweep C34, C36, C38 with stronger warm-up control.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
