# EXP-014 — C48 Instrumented Control

## Goal

Validate the current best C48 serving configuration while collecting lightweight
GPU telemetry to identify whether Prefill or Decode is the current hardware-side
bottleneck.

This experiment changes instrumentation only relative to the C48 control.

## Configuration

- Layout: 8 Prefill GPUs + 8 Decode GPUs
- Prefill: 4 workers × TP2
- Decode: 2 workers × TP4 / EP4
- Concurrency: 48
- Prefill routing: round-robin
- Decode routing: round-robin
- Model: Qwen3-235B-A22B-Instruct-2507-FP8
- Input length: 4000 tokens
- Output length: 200 tokens
- TTFT SLA: <= 3000 ms
- ITL SLA: <= 20 ms
- AIPerf warmup: 60 s
- AIPerf profiling: 60 s
- Grace period: 15 s
- External GPU telemetry: nvidia-smi sampled approximately once per second

## AIPerf result

Requests: 688

- GFR: 1.000
- TTFT pass rate: 100%
- ITL pass rate: 100%

Latency:

| Metric | Value |
|---|---:|
| TTFT avg | 556.50 ms |
| TTFT p50 | 385.49 ms |
| TTFT p90 | 892.44 ms |
| TTFT p99 | 2764.46 ms |
| ITL avg | 18.964 ms |
| ITL p50 | 19.169 ms |
| ITL p90 | 19.401 ms |
| ITL p99 | 19.474 ms |

AIPerf profiling completed 688 requests in 63.57 s including final request drain.

Approximate SLA-qualified goodput:

- 688 / 63.57 = ~10.82 good requests/s
- ~2164 good output tokens/s

## Temporal stability

First half:

- requests: 344
- GFR: 1.000
- TTFT avg: 722.30 ms
- ITL avg: 18.850 ms

Second half:

- requests: 344
- GFR: 1.000
- TTFT avg: 390.70 ms
- ITL avg: 19.079 ms

No second-half SLA degradation was observed.

## GPU telemetry during profiling

### Prefill node

- GPU utilization mean: 49.28%
- GPU utilization p50: 50%
- GPU utilization p90: 99%
- Memory-controller utilization mean: 18.19%
- Power mean: 458.61 W

Per-GPU mean utilization ranged approximately 42–54%.

### Decode node

- GPU utilization mean: 94.34%
- GPU utilization p50: 100%
- GPU utilization p90: 100%
- Memory-controller utilization mean: 43.68%
- Power mean: 477.92 W

All eight Decode GPUs showed approximately 94.3% mean GPU utilization.

This is consistent with the previous worker-side evidence showing balanced Decode
replicas, no meaningful scheduler queue, no retractions, and full CUDA-graph use.

## Interpretation

The current 8P+8D C48 system is Decode-heavy.

Evidence does not support routing imbalance, Decode replica imbalance, KV capacity,
scheduler queueing, retractions, or CUDA-graph coverage as the primary bottleneck.

Decode is almost continuously GPU-active while Prefill has substantially more idle
capacity.

However, nvidia-smi GPU utilization does not distinguish useful model compute from
communication or synchronization kernels. Therefore 94% GPU utilization does not
prove that Decode is compute-bound.

The remaining high-value question is what consumes Decode GPU time:

- MoE / GEMM execution
- attention / KV work
- TP collectives
- EP / expert communication
- synchronization or kernel-launch overhead

## Additional observation

The 60-second AIPerf warmup took 138.73 seconds to fully drain its initial 48
requests before profiling began.

The subsequent profiling phase behaved normally and completed 688 requests in
63.57 seconds with GFR 1.0.

This cold/first-burst behavior should be investigated separately and should not be
mixed with the next Decode optimization experiment.

## Decision

EXP-014 establishes the instrumented C48 baseline.

Current working bottleneck:

**Decode execution**

Next experiment:

**EXP-015 — profile steady-state Decode execution without changing the serving
configuration.**

The objective is to attribute Decode GPU time to compute, attention/KV, TP/EP
communication, and synchronization before making further tuning changes.
