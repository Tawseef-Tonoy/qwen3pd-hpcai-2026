# EXP-002 Report — REF08 12P + 4D Exploratory Characterization

## Experiment

**Topology:** Firmus organizer REF08

- 12 GPUs allocated to Prefill
- 4 GPUs allocated to Decode
- 6 Prefill workers, TP=2 each
- 1 Decode worker, TP=4, EP=4
- NIXL disaggregated KV transfer
- FP8 Qwen3-235B-A22B-Instruct-2507
- concurrency sweep: 8, 16, 32, 40, 48
- warmup: 20 s
- benchmark: 60 s
- grace: 15 s

This experiment was exploratory. It was not an official scored run.

---

## Motivation

EXP-001 tested REF07 (8 Prefill GPUs + 8 Decode GPUs) at concurrency 48
using official benchmark timing.

That experiment showed extremely poor TTFT while ITL remained healthy,
indicating that the dominant bottleneck was before generation began.

REF08 reallocates four GPUs from Decode to Prefill:

REF07:

    8 Prefill + 8 Decode

REF08:

    12 Prefill + 4 Decode

The hypothesis was that additional Prefill capacity would improve TTFT,
potentially at the cost of higher Decode latency.

---

## Whole-run SLA Analysis

A request is considered good when:

- TTFT <= 3000 ms
- average ITL <= 20 ms

| C | Requests | TTFT Pass | ITL Pass | Good | GFR | Good req/s | Good tok/s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 8  | 40  | 32  | 40  | 32  | 0.8000 | 0.5167 | 103.34 |
| 16 | 110 | 90  | 110 | 90  | 0.8182 | 1.4575 | 291.50 |
| 32 | 180 | 129 | 180 | 129 | 0.7167 | 2.0660 | 413.20 |
| 40 | 462 | 431 | 210 | 184 | 0.3983 | 2.8714 | 574.28 |
| 48 | 513 | 468 | 132 | 101 | 0.1969 | 1.5625 | 312.50 |

No exploratory sweep point achieved the required GFR >= 0.90 when the
entire profiling interval was evaluated.

However, these whole-run numbers hide an important temporal effect.

---

## Temporal Analysis

### C8

First half:

- TTFT avg: 19850.8 ms
- TTFT pass: 60.0%
- ITL avg: 12.93 ms
- ITL pass: 100%

Second half:

- TTFT avg: 385.4 ms
- TTFT pass: 100%
- ITL avg: 10.55 ms
- ITL pass: 100%

### C16

First half:

- TTFT avg: 6948.2 ms
- TTFT pass: 63.6%
- ITL pass: 100%

Second half:

- TTFT avg: 419.0 ms
- TTFT pass: 100%
- ITL pass: 100%

### C32

First half:

- TTFT avg: 12754.4 ms
- TTFT pass: 47.8%
- ITL avg: 16.48 ms
- ITL pass: 100%

Second half:

- TTFT avg: 1930.3 ms
- TTFT pass: 95.6%
- ITL avg: 14.99 ms
- ITL pass: 100%

### C40

First half:

- TTFT avg: 1794.3 ms
- TTFT pass: 86.6%
- ITL avg: 19.45 ms
- ITL pass: 47.2%

Second half:

- TTFT avg: 1283.8 ms
- TTFT pass: 100%
- ITL avg: 20.10 ms
- ITL pass: 43.7%

### C48

First half:

- TTFT avg: 2198.3 ms
- TTFT pass: 84.8%
- ITL avg: 20.04 ms
- ITL pass: 32.4%

Second half:

- TTFT avg: 1419.4 ms
- TTFT pass: 97.7%
- ITL avg: 20.66 ms
- ITL pass: 19.1%

---

# Findings

## 1. The original sweep is strongly affected by warm-up/transient behavior

The low-concurrency measurements cannot be interpreted simply as
steady-state performance.

Examples:

- C8 TTFT falls from 19.85 s in the first half to 0.385 s in the second.
- C16 falls from 6.95 s to 0.419 s.
- C32 falls from 12.75 s to 1.93 s.

At all three concurrency levels, Decode remains completely inside the ITL
SLA.

This strongly suggests that startup/compiler/kernel/cache and serving-path
warm-up effects contaminate the early portions of the exploratory sweep.

Because the concurrency sweep executes sequentially on the same long-lived
serving processes, later sweep points also benefit from a more fully warmed
system.

Therefore raw GFR values across the five sweep points are not a clean
apples-to-apples topology/concurrency comparison.

---

## 2. C32 has substantial steady-state headroom

In the second half of C32:

- TTFT pass = 95.6%
- ITL pass = 100%
- ITL average = 14.99 ms

This indicates that the 12P+4D topology can comfortably support at least
roughly C32 after the serving stack is warm.

C32 therefore appears to be below the Decode saturation point.

---

## 3. C40 crosses into Decode saturation

At C40, TTFT becomes very healthy after warm-up:

- second-half TTFT pass = 100%
- second-half TTFT average = 1283.8 ms

However Decode fails badly:

- first-half ITL pass = 47.2%
- second-half ITL pass = 43.7%
- second-half ITL average = 20.10 ms

The fact that TTFT improves while ITL remains poor shows that the main
limitation at C40 is no longer Prefill.

The single TP4 Decode worker has become the bottleneck.

---

## 4. C48 further confirms Decode saturation

At C48:

- second-half TTFT pass = 97.7%
- second-half TTFT average = 1419.4 ms

but:

- second-half ITL pass = only 19.1%
- second-half ITL average = 20.66 ms

Increasing concurrency from C40 to C48 therefore adds Decode pressure
without producing an SLA-viable operating point.

C48 should not be considered for official validation using the current
REF08 topology.

---

## 5. REF08 successfully shifts the system bottleneck

The intended architecture change worked.

REF07 exhibited a severe pre-first-token bottleneck.

Increasing Prefill allocation in REF08 makes TTFT substantially healthier
once the system is warm.

At higher concurrency, however, the reduced Decode allocation becomes the
new limiting resource.

Conceptually:

    REF07 8P + 8D
        |
        +-- insufficient pre-first-token capacity
        +-- TTFT bottleneck

               ↓ GPU reallocation

    REF08 12P + 4D
        |
        +-- much stronger Prefill side
        +-- Decode becomes limiting near C40+

This is useful evidence that the optimization problem is now one of
balancing Prefill and Decode capacity rather than simply maximizing either
side.

---

# Important Experimental Limitation

The organizer sweep uses only 20 seconds of warm-up per concurrency and
runs the concurrency values sequentially on the same serving stack.

The temporal analysis demonstrates that this is not enough to eliminate
large startup/transient effects at several sweep points.

For this reason:

- whole-run GFR values from EXP-002 should not be treated as final scores;
- C8/C16/C32 TTFT averages significantly underestimate warmed performance;
- later sweep points benefit from a more fully warmed serving environment.

A follow-up experiment should therefore use a longer warm-up period before
drawing conclusions about the exact SLA knee.

---

# Conclusion

EXP-002 validates the architectural direction of REF08.

The 12P+4D topology provides substantially more effective pre-first-token
capacity than REF07 once warm.

The operating region appears to lie between C32 and C40:

    C32:
        Decode has significant SLA headroom.

    C40:
        Prefill/TTFT is healthy,
        but Decode is already overloaded.

Therefore the next search should focus narrowly between these points rather
than testing additional high concurrency values.

Candidate region:

    approximately C34-C38

The next experiment should use longer warm-up and search this interval for
the highest concurrency that maintains:

- TTFT <= 3000 ms
- average ITL <= 20 ms
- good_request_fraction >= 0.90

Only after identifying that candidate should an exact official
60/120/30 validation run be performed.

---

## EXP-002 Decision

**COMPLETE**

REF08 is retained as the current most promising serving topology.

C48 is rejected.

C40 is above the Decode SLA knee.

C32 is below the knee and has substantial Decode headroom after warm-up.

Next experiment:

**REF08 fine-grained concurrency search between C32 and C40 with improved
warm-up control.**
