# EXP-002 — REF08 12P + 4D Exploratory Characterization

## Status

**COMPLETE**

## Objective

Characterize the organizer REF08 topology and locate the approximate
concurrency region where TTFT and Decode ITL remain compatible with the
competition SLA.

## Topology

REF08 allocates the 16 GPUs as:

- 12 Prefill GPUs
- 4 Decode GPUs
- 6 Prefill workers, TP=2 each
- 1 Decode worker, TP=4, EP=4
- NIXL disaggregated KV transfer
- FP8 Qwen3-235B-A22B-Instruct-2507

Exploratory concurrency sweep:

- C8
- C16
- C32
- C40
- C48

Benchmark configuration:

- warmup: 20 s
- profiling: 60 s
- grace: 15 s
- input length: 4000
- output length: 200

This was an exploratory run, not an official scored validation.

---

## Correct Profiling-Phase Counts

AIPerf JSONL contains separate warmup and profiling records.

Only records whose benchmark phase is `profiling` are used for:

- GFR
- TTFT pass rate
- ITL pass rate
- good-request count
- goodput

| C | Warmup records | Profiling records |
|---:|---:|---:|
| 8 | 1 | 39 |
| 16 | 9 | 101 |
| 32 | 9 | 171 |
| 40 | 9 | 453 |
| 48 | 9 | 504 |

Earlier larger request counts came from accidentally combining warmup and
profiling records.

---

## Competition SLA

A request passes when:

- TTFT <= 3000 ms
- average ITL <= 20 ms

A scored run requires:

- GFR >= 0.90

---

## Full Profiling Results

| C | Requests | GFR | TTFT pass | ITL pass | Good req/s | Good tok/s |
|---:|---:|---:|---:|---:|---:|---:|
| 8 | 39 | 0.821 | 82.1% | 100.0% | 0.517 | 103.3 |
| 16 | 101 | 0.802 | 80.2% | 100.0% | 1.312 | 262.3 |
| 32 | 171 | 0.702 | 70.2% | 100.0% | 1.922 | 384.4 |
| 40 | 453 | 0.386 | 93.2% | 44.4% | 2.731 | 546.2 |
| 48 | 504 | 0.183 | 91.1% | 24.4% | 1.423 | 284.7 |

Good req/s is calculated using the actual AIPerf-reported profiling
duration rather than the nominal 60 second configuration.

Measured durations:

- C8: 61.93 s
- C16: 61.75 s
- C32: 62.44 s
- C40: 64.08 s
- C48: 64.64 s

---

## Temporal Analysis

A strong time-dependent change was observed inside the profiling phases.

### C8

First half:

- TTFT avg: 19617.3 ms
- TTFT pass: 63.2%
- ITL avg: 13.05 ms
- ITL pass: 100%

Second half:

- TTFT avg: 385.4 ms
- TTFT pass: 100%
- ITL avg: 10.55 ms
- ITL pass: 100%

### C16

First half:

- TTFT avg: 7612.9 ms
- TTFT pass: 60.0%
- ITL avg: 14.45 ms
- ITL pass: 100%

Second half:

- TTFT avg: 420.7 ms
- TTFT pass: 100%
- ITL avg: 13.02 ms
- ITL pass: 100%

### C32

First half:

- TTFT avg: 13510.8 ms
- TTFT pass: 44.7%
- ITL avg: 17.00 ms
- ITL pass: 100%

Second half:

- TTFT avg: 1977.7 ms
- TTFT pass: 95.3%
- ITL avg: 15.04 ms
- ITL pass: 100%

### C40

First half:

- TTFT avg: 1833.2 ms
- TTFT pass: 86.3%
- ITL avg: 19.80 ms
- ITL pass: 46.0%

Second half:

- TTFT avg: 1293.5 ms
- TTFT pass: 100%
- ITL avg: 20.12 ms
- ITL pass: 42.7%

### C48

First half:

- TTFT avg: 2229.7 ms
- TTFT pass: 84.5%
- ITL avg: 20.41 ms
- ITL pass: 29.4%

Second half:

- TTFT avg: 1438.8 ms
- TTFT pass: 97.6%
- ITL avg: 20.64 ms
- ITL pass: 19.4%

---

# Findings

## 1. Strong temporal non-stationarity exists

C8, C16 and C32 show extremely large TTFT improvements between the first
and second halves of profiling.

This is consistent with startup/warm-up effects, which may include:

- kernel/compiler warm-up
- cache effects
- KV-transfer-path establishment
- worker/router stabilization
- sequential sweep effects

The experiment does not isolate which mechanism is responsible.

Therefore the whole-run exploratory values should not be interpreted as
pure steady-state measurements.

---

## 2. C32 remains below the Decode saturation point

During the second half of C32:

- TTFT pass: 95.3%
- ITL pass: 100%
- ITL average: 15.04 ms

This provides substantial Decode latency headroom.

C32 is therefore a strong lower bound for the useful operating region.

---

## 3. C40 crosses the Decode SLA knee

During the second half of C40:

- TTFT pass: 100%
- TTFT average: 1293.5 ms

but:

- ITL pass: 42.7%
- ITL average: 20.12 ms

This indicates that the pre-first-token path is healthy while Decode has
become the dominant limitation.

---

## 4. C48 is clearly Decode overloaded

During the second half of C48:

- TTFT pass: 97.6%
- ITL pass: 19.4%
- ITL average: 20.64 ms

Increasing concurrency beyond C40 therefore adds Decode pressure without
producing an SLA-viable operating point.

---

## 5. REF08 shifts the bottleneck compared with REF07

REF07:

    8 Prefill + 8 Decode
             |
             v
    severe pre-first-token pressure
             |
             v
          TTFT bottleneck

REF08:

    12 Prefill + 4 Decode
             |
             v
    much stronger Prefill behavior
             |
             v
    Decode becomes limiting near C40+

The GPU reallocation therefore worked as intended on the Prefill side but
reduced Decode capacity enough to introduce a new bottleneck at higher
concurrency.

---

# Decision

The current useful search interval is:

    C32 ------------------------------- C40
     |                                   |
     |                                   |
 Decode headroom                    Decode overloaded

The next experiment should search between them:

- C34
- C36
- C38

with stronger startup/warm-up control.

The purpose of the next experiment is to identify the highest concurrency
whose exploratory behavior still satisfies both TTFT and ITL sufficiently
to justify an official-duration validation.

No claim from the second-half analysis should be treated as an official
competition result.

---

## Final EXP-002 Decision

**Retain REF08 as the current topology.**

**Reject C48.**

**C40 is above the Decode SLA knee.**

**C32 is below the knee and retains significant Decode headroom.**

**Next: fine-grained exploratory search at C34/C36/C38.**
