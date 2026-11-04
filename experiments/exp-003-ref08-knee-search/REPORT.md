# EXP-003 — REF08 Fine SLA-Knee Search

## Status

**COMPLETE**

## Objective

Locate the useful concurrency region of REF08 between the previously
identified C32 Decode-safe region and C40 Decode-overloaded region.

## Configuration

Serving topology remained unchanged from organizer REF08:

- 12 Prefill GPUs
- 4 Decode GPUs
- 6 Prefill workers × TP2
- 1 Decode worker × TP4 / EP4
- EP4
- max-running-requests = 256
- mem-fraction-static = 0.90
- NIXL
- organizer UCX/IB configuration
- Qwen3-235B-A22B-Instruct-2507-FP8

Concurrency:

- C32
- C34
- C36
- C38

Benchmark:

- warmup = 60 s
- profiling = 60 s
- grace = 30 s

---

## Full Profiling Results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s | TTFT p90 | ITL p90 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 32 | 54 | 0.574 | 57.4% | 100.0% | 0.502 | 100.4 | 6556.5 ms | 16.85 ms |
| 34 | 182 | 0.341 | 34.1% | 100.0% | 0.734 | 146.8 | 29078.8 ms | 17.45 ms |
| 36 | 126 | 0.786 | 78.6% | 100.0% | 1.591 | 318.1 | 5772.2 ms | 18.01 ms |
| 38 | 308 | 0.500 | 79.9% | 68.5% | 2.379 | 475.8 | 20095.3 ms | 20.66 ms |

No complete profiling run reached the required GFR >= 0.90.

---

## Temporal Findings

### C36 shows a clear state transition

C36 chronological deciles:

- decile 1: GFR 50.0%
- decile 2: GFR 15.4%
- decile 3: GFR 16.7%
- deciles 4-10: GFR 100%

From decile 4 onward both conditions were consistently satisfied:

- TTFT pass = 100%
- ITL pass = 100%

Later C36 TTFT was approximately 0.38-0.59 s and ITL approximately
12-18 ms.

This is substantially different from random intermittent failure. The run
appears to transition from an initially poor state into a stable,
high-performing state.

### C38 reaches the Decode limit

At C38, TTFT eventually becomes healthy:

- later deciles: TTFT pass = 100%

However ITL deteriorates:

- decile 6: ITL pass 50.0%
- decile 7: 32.3%
- decile 8: 41.9%
- decile 9: 35.5%

Therefore C38 is too close to or beyond the Decode SLA boundary with the
current 4-GPU Decode allocation.

### C32

C32 eventually reaches a very healthy state:

- final four deciles: TTFT pass = 100%
- ITL pass = 100%

However the early profiling period still contains severe TTFT failures.

### C34

C34 exhibits unusually poor and irregular TTFT behavior while maintaining
100% ITL pass.

Because only one run was performed at each concurrency, C34 is treated as
an anomalous observation rather than sufficient evidence for a separate
architectural conclusion.

---

## Interpretation

The useful operating region is now more precise.

C38 provides evidence that the Decode boundary has been reached.

C36 provides the strongest evidence of a potentially SLA-valid operating
point once the system enters its stable state.

Therefore further fine-grained concurrency search is not the highest-value
next experiment.

The next question is whether C36, when tested alone under the exact
official timing, can maintain enough of its stable behavior for the full
profiling period to achieve GFR >= 0.90.

---

## Decision

**C36 selected for official-timing validation.**

Next experiment:

**EXP-004 — REF08 C36 exact official 60/120/30 validation.**

EXP-004 will:

- run C36 only;
- eliminate sequential-sweep effects;
- preserve the REF08 serving configuration;
- use exact official benchmark timing and AIPerf SLA settings.

If C36 passes GFR >= 0.90, it becomes the new official baseline.

If C36 fails primarily because of an early TTFT transition, the following
experiment will investigate startup/preconditioning behavior.

If C36 fails because ITL deteriorates, a lower concurrency will be
considered.
