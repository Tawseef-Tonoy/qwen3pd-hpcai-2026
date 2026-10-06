# EXP-016 — Steady-State Decode Profiling

## Goal

Determine what consumes GPU execution time in the current best Decode
configuration.

This is an instrumentation experiment, not a topology experiment.

## Serving configuration

Identical to EXP-014:

- 16 H200 GPUs
- Prefill: 4 × TP2 = 8 GPUs
- Decode: 2 × TP4/EP4 = 8 GPUs
- concurrency: 48
- Prefill routing: round_robin
- Decode routing: round_robin
- Qwen3-235B-A22B-Instruct-2507-FP8
- same NIXL / UCX configuration
- same C48 AIPerf workload
- same lightweight GPU telemetry

## Why

EXP-014 showed:

- GFR = 1.0
- ITL p90 ≈ 19.40 ms
- ITL p99 ≈ 19.47 ms
- Decode GPU activity ≈ 94%
- Decode replicas balanced
- no meaningful queue
- no retractions
- CUDA graph usage = 100%

EXP-015 tested four TP2/EP2 Decode replicas and failed badly:

- GFR ≈ 0.065
- ITL p90 ≈ 21.90 ms

Therefore TP4/EP4 remains the winning Decode topology.

## Question

What consumes Decode GPU time under the TP4/EP4 configuration?

Candidate contributors:

1. MoE / FP8 GEMM execution
2. TP collectives
3. EP / expert communication
4. attention / KV kernels
5. synchronization / launch overhead
6. memory movement

## Instrumentation

During AIPerf:

1. Wait for the log marker:
   `Phase profiling (profiling) started`
2. Wait 10 seconds for steady-state load.
3. Start SGLang PyTorch profiling on decode-0 only.
4. Capture 20 Decode steps.
5. Profile CPU and GPU activities.
6. Save trace under the run artifact directory.

Only one Decode replica is profiled to reduce measurement perturbation.

## Important

Performance values from this run are not treated as a new candidate score,
because torch profiling adds overhead.

EXP-014 remains the clean performance baseline.

## Decision rule

If GPU time is dominated by:

- NCCL / collectives:
  investigate TP/EP communication and topology.

- MoE / grouped GEMM:
  investigate MoE backend, kernels, and batch shapes.

- attention / KV kernels:
  investigate attention backend and KV execution.

- many short kernels / gaps:
  investigate synchronization, launch overhead, and CUDA-graph behavior.

