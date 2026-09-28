# EXP-002 — REF08 12+4 Exploratory Characterization

## Status

READY TO RUN

## Objective

Characterize the Firmus organizer REF08 topology across its supplied
concurrency sweep and identify the best candidate concurrency for an
official-duration validation run.

## Background

EXP-001 tested REF07 (8 Prefill GPUs + 8 Decode GPUs) at C48 using the
official benchmark.

EXP-001 showed:

- request throughput: 2.70 req/s
- goodput: 0.93 req/s
- TTFT avg: 14357.65 ms
- TTFT p50: 20766.23 ms
- TTFT p90: 26965.51 ms
- ITL avg: 14.97 ms
- ITL p99: 18.52 ms

The main bottleneck was therefore the pre-first-token path rather than
Decode token generation.

## REF08 Architecture

REF08 reallocates the 16 GPUs from:

REF07:
- 8 Prefill GPUs
- 8 Decode GPUs

to:

REF08:
- 12 Prefill GPUs
- 4 Decode GPUs

Implementation:

- 6 Prefill workers, each TP=2
- 1 Decode worker, TP=4, EP=4
- NIXL disaggregated KV transfer
- same model
- same router architecture
- same static memory fraction
- same max-running-requests setting

## Independent Variable

Serving topology:

REF07 8P+8D -> REF08 12P+4D

## Organizer Exploratory Sweep

Concurrency:

- 8
- 16
- 32
- 40
- 48

Benchmark timing:

- warmup: 20 s
- benchmark: 60 s
- grace: 15 s

Workload:

- ISL: 4000
- OSL: 200
- seed: 2026
- cache bust: first_turn_prefix

## Hypothesis

Additional Prefill capacity should reduce TTFT and prefill-side queue
accumulation relative to REF07.

However, reducing Decode capacity from 8 GPUs to 4 GPUs may increase ITL
at higher concurrency.

Therefore REF08 may have a lower or different optimal concurrency than
REF07.

## Metrics

For every concurrency:

- sent requests
- completed requests
- cancelled/errors
- good requests
- good-request fraction
- goodput req/s
- good output tokens/s
- raw request throughput
- raw output throughput
- TTFT avg/p50/p90/p99
- ITL avg/p50/p90/p99
- effective prefill concurrency
- effective decode concurrency

## Comparison

Compare REF08 against REF07 at common concurrency values:

- C8
- C16
- C40
- C48

C32 is additional REF08 characterization.

## Decision Rule

This exploratory experiment does NOT establish an official score.

Select the most promising REF08 concurrency for EXP-003 based on:

1. ability to approach or exceed GFR 0.90,
2. SLA-qualified goodput,
3. TTFT behavior,
4. ITL headroom.

EXP-003 will then validate the selected concurrency using the exact
official 60/120/30 benchmark.

## Results

Pending.

## Conclusion

Pending.

## Next Experiment

Pending.
