# Automated AIPerf Analysis

Experiment: `exp-012-ref07-c48-decode-roundrobin`

## SLA

- TTFT <= 3000 ms
- average ITL <= 20 ms
- GFR >= 0.90

## Full-run results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | Bottleneck |
|---:|---:|---:|---:|---:|---:|---:|---|
| None | 689 | 1.000 | 100.0% | 100.0% | N/A | N/A | SLA-valid |

## Temporal / warm-state analysis

| C | First TTFT pass | Second TTFT pass | First ITL pass | Second ITL pass | Second-half GFR |
|---:|---:|---:|---:|---:|---:|
| None | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |

## Automatic findings

- CNone: SLA-valid in the second-half steady-state proxy.

## Decision

**Status:** EXPLORE

**Recommended next action:** CNone is the highest tested exploratory SLA-pass proxy. Test slightly higher concurrency before official validation.

> This report is an automated decision aid. Official competition claims should be based on exact official benchmark runs rather than exploratory steady-state proxies.
