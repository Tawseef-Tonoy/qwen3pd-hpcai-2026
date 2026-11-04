# Automated AIPerf Analysis

Experiment: `exp-011-ref07-8p8d-concurrency-sweep`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 40 | 20 | 1.000 | 100.0% | 100.0% | 3.247 | 649.4 | SLA-valid |
| 44 | 633 | 0.961 | 100.0% | 96.1% | 9.563 | 1912.6 | SLA-valid |
| 48 | 682 | 0.953 | 100.0% | 95.3% | 10.139 | 2027.8 | SLA-valid |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 40 | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| 44 | 100.0% | 100.0% | 92.1% | 100.0% | 100.0% |
| 48 | 100.0% | 100.0% | 90.6% | 100.0% | 100.0% |

## Automatic findings

- C40: SLA-valid in the second-half steady-state proxy.
- C44: SLA-valid in the second-half steady-state proxy.
- C48: SLA-valid in the second-half steady-state proxy.

## Decision

**Status:** EXPLORE

**Current candidate:** C48

**Recommended next action:** C48 is the highest tested exploratory SLA-pass proxy. Test slightly higher concurrency before official validation.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
