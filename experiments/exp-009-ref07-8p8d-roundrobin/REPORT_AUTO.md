# Automated AIPerf Analysis

Experiment: `exp-009-ref07-8p8d-roundrobin`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 32 | 107 | 0.570 | 57.0% | 100.0% | 0.963 | 192.6 | TTFT / pre-first-token |
| 36 | 535 | 0.970 | 100.0% | 97.0% | 8.206 | 1641.1 | SLA-valid |
| 40 | 591 | 0.966 | 100.0% | 96.6% | 8.954 | 1790.8 | SLA-valid |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 32 | 45.3% | 68.5% | 100.0% | 100.0% | 68.5% |
| 36 | 100.0% | 100.0% | 94.0% | 100.0% | 100.0% |
| 40 | 100.0% | 100.0% | 93.2% | 100.0% | 100.0% |

## Automatic findings

- Strong temporal non-stationarity was detected, consistent with startup/warm-up effects. Whole-run exploratory GFR should not be treated as steady-state performance.
- C32: TTFT / pre-first-token in the second-half steady-state proxy.
- C36: SLA-valid in the second-half steady-state proxy.
- C40: SLA-valid in the second-half steady-state proxy.

## Decision

**Status:** EXPLORE

**Current candidate:** C40

**Recommended next action:** C40 is the highest tested exploratory SLA-pass proxy. Test slightly higher concurrency before official validation.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
