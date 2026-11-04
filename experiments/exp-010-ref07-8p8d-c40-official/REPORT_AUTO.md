# Automated AIPerf Analysis

Experiment: `exp-010-ref07-8p8d-c40-official`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| 40 | 1161 | 0.982 | 100.0% | 98.2% | N/A | N/A | SLA-valid |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| 40 | 100.0% | 100.0% | 96.4% | 100.0% | 100.0% |

## Automatic findings

- C40: SLA-valid in the second-half steady-state proxy.

## Decision

**Status:** PASS

**Current candidate:** C40

**Recommended next action:** Official SLA passed. Use this as the current baseline and optimize for higher goodput while preserving GFR.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
