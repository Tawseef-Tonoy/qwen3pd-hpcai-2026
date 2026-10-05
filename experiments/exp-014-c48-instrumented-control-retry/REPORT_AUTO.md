# Automated AIPerf Analysis

Experiment: `exp-014-c48-instrumented-control-retry`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 48 | 688 | 1.000 | 100.0% | 100.0% | N/A | N/A | SLA-valid |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 48 | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |

## Automatic findings

- C48: SLA-valid in the second-half steady-state proxy.

## Decision

**Status:** EXPLORE

**Current candidate:** C48

**Recommended next action:** C48 is the highest tested exploratory SLA-pass proxy. Test slightly higher concurrency before official validation.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
