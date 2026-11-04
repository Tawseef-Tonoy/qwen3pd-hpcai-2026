# EXP-015 — C48 Decode TP2

## Goal

Test whether reducing Decode parallelism per replica improves Decode efficiency.

Baseline EXP-014 used:

- 8 Prefill GPUs
- 4 × Prefill TP2
- 8 Decode GPUs
- 2 × Decode TP4/EP4
- concurrency 48
- Prefill round-robin
- Decode round-robin

EXP-015 changed only the Decode topology:

- 2 × TP4/EP4
- to 4 × TP2/EP2

The total Decode GPU allocation remained 8 H200 GPUs.

## Hypothesis

TP4/EP4 may incur enough tensor/expert-parallel communication overhead that
four smaller TP2/EP2 Decode replicas could provide higher aggregate throughput
and lower ITL.

## Result

**REJECT**

EXP-015 performed substantially worse than EXP-014.

| Metric | EXP-014 | EXP-015 |
|---|---:|---:|
| Decode topology | 2 × TP4/EP4 | 4 × TP2/EP2 |
| Requests | 688 | 628 |
| GFR | 1.000 | 0.0653 |
| TTFT pass rate | 100% | 100% |
| ITL pass rate | 100% | 6.53% |
| TTFT avg | 556.50 ms | 528.41 ms |
| TTFT p90 | 892.44 ms | 906.57 ms |
| TTFT p99 | 2764.46 ms | 2517.90 ms |
| ITL avg | 18.964 ms | 21.307 ms |
| ITL p90 | 19.401 ms | 21.898 ms |
| ITL p99 | 19.474 ms | 21.998 ms |

AIPerf reported approximately:

- request throughput: 9.86 req/s
- output token throughput: 1971 tok/s
- goodput: 0.64 req/s

At 200 output tokens per request, this corresponds to only about:

- 128 SLA-qualified output tok/s

The failure was almost entirely Decode / ITL related.

## Temporal behavior

First half:

- requests: 314
- TTFT avg: 751.21 ms
- ITL avg: 21.038 ms
- ITL pass rate: 10.19%
- GFR: 10.19%

Second half:

- requests: 314
- TTFT avg: 305.62 ms
- ITL avg: 21.575 ms
- ITL pass rate: 2.87%
- GFR: 2.87%

The analyzer detected warm-up contamination, but steady-state behavior does not
rescue the configuration.

The second half had worse ITL and lower GFR than the first half.

## Interpretation

The hypothesis that lower Decode TP/EP degree would improve performance was not
supported.

Although TP2/EP2 may reduce communication within an individual Decode replica,
the loss of per-request parallel execution was more important for this model and
workload.

Four TP2 Decode replicas did not compensate for the slower Decode execution.

For this Qwen3-235B-A22B FP8 workload on H200:

**2 × TP4/EP4 Decode is clearly superior to 4 × TP2/EP2 at C48.**

This conclusion is specific to the tested model, serving stack, hardware, and
workload.

## Search-space decision

Do not continue with the previously proposed:

- 6 Prefill GPUs
- 10 Decode GPUs
- 5 × TP2 Decode

because EXP-015 shows that TP2 Decode is already strongly SLA-invalid at C48.

Retain:

- 8 Prefill GPUs
- 8 Decode GPUs
- 4 × Prefill TP2
- 2 × Decode TP4/EP4

## What EXP-015 ruled out

The following optimization direction is rejected:

**Decode replica scale-out by reducing TP4/EP4 to TP2/EP2.**

Together with previous experiments, lower-priority explanations now include:

- Decode routing imbalance
- Decode replica imbalance
- scheduler queueing
- retractions
- KV capacity
- CUDA graph coverage
- TP2 Decode scale-out

## Next experiment

Return to the EXP-014 topology and profile steady-state TP4/EP4 Decode execution.

The next question is:

**Where does Decode GPU time go?**

Candidate contributors:

- MoE / FP8 GEMM execution
- tensor-parallel collectives
- expert-parallel communication
- attention / KV kernels
- synchronization / kernel-launch overhead

The next experiment should change instrumentation only, not serving topology.
