# EXP-003 — REF08 Fine SLA-Knee Search

## Status

READY TO RUN

## Objective

Determine the highest useful concurrency for the REF08 12P+4D topology
between the known C32 lower bound and C40 Decode-overloaded region.

## Background

EXP-002 established:

- C32 has strong Decode headroom after the initial temporal transient.
- C40 is Decode / ITL limited.
- C48 is more strongly Decode limited.
- strong temporal non-stationarity was observed with only 20 s warm-up.

Therefore the useful operating region is between C32 and C40.

## Fixed Serving Configuration

- Qwen3-235B-A22B-Instruct-2507-FP8
- 16 H200 GPUs
- 12 Prefill GPUs
- 4 Decode GPUs
- 6 Prefill workers × TP2
- 1 Decode worker × TP4 / EP4
- max-running-requests = 256
- mem-fraction-static = 0.90
- NIXL disaggregated KV transfer
- organizer REF08 router and UCX/IB configuration

No serving-side parameter is changed from REF08.

## Independent Variable

Concurrency:

- C32
- C34
- C36
- C38

C32 is included as a control.

## Benchmark

- warmup = 60 s
- profiling = 60 s
- grace = 30 s
- ISL = 4000
- OSL = 200
- seed = 2026
- cache-bust = first_turn_prefix

## SLA

A good request requires:

- TTFT <= 3000 ms
- average ITL <= 20 ms

Target:

- GFR >= 0.90

## Hypothesis

Longer warm-up should substantially reduce the early TTFT instability
observed in EXP-002.

C32 should remain below the Decode saturation point.

As concurrency increases toward C40, Decode ITL should progressively
become the limiting metric.

The SLA knee is expected somewhere in the C34-C38 interval.

## Decision Rule

Primary evaluation uses the entire profiling phase.

1. Reject any configuration with GFR < 0.90.
2. Among configurations with GFR >= 0.90, prefer the configuration with
   the highest SLA-qualified good output tokens/sec.
3. Use first-half vs second-half analysis only as a temporal-stability
   diagnostic.
4. If C32 still shows severe non-stationarity or fails unexpectedly,
   investigate startup behavior before selecting a higher concurrency.
5. The selected winner will be validated in the next experiment using
   the exact official 60/120/30 benchmark.

## Results

Pending.

## Decision

Pending.

---

# Experiment Closure

Status: **COMPLETE**

Full profiling GFR:

- C32: 0.574
- C34: 0.341
- C36: 0.786
- C38: 0.500

Key findings:

1. No full exploratory run achieved GFR >= 0.90.
2. C36 underwent a strong transition: deciles 4-10 achieved 100% TTFT
   pass and 100% ITL pass.
3. C38 eventually achieved healthy TTFT but became Decode/ITL limited.
4. C36 is therefore the strongest candidate for a single-point official
   validation.
5. Sequential-sweep and temporal effects remain important.

Decision:

Validate REF08 C36 alone using the exact official 60/120/30 benchmark.

See `REPORT.md`, `REPORT_AUTO.md`, and `analysis/` for details.
