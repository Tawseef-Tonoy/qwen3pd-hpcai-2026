# EXP-001 — REF07 C48 Official-Timing Validation

## Status

READY TO RUN

## Objective

Determine whether the frozen Firmus REF07 serving configuration at
concurrency 48 satisfies the competition SLA under the official benchmark
timing.

## Background

Previous REF07 exploratory testing found C48 to be the highest-goodput
tested point.

Exploratory C48:

- completed requests: 535
- good requests: 438
- good_request_fraction: 0.818692
- diagnostic goodput: 6.6213 req/s
- diagnostic good output throughput: 1324.26 tokens/s
- TTFT average: 2117.02 ms
- TTFT p90: 3543.90 ms
- TTFT p99: 9535.65 ms
- ITL average: 17.65 ms
- ITL p99: 19.83 ms

The exploratory run did not satisfy GFR >= 0.90.

TTFT was the dominant SLA failure while ITL was almost entirely within
the 20 ms threshold.

## Question

Can REF07 at concurrency 48 satisfy good_request_fraction >= 0.90 when
evaluated using the official 60/120/30 benchmark timing?

## Hypothesis

The longer official warm-up and benchmark period may reduce the influence
of startup/transient behavior.

If GFR remains below 0.90 and TTFT remains the dominant failure, the next
experiment should investigate a Prefill-oriented serving topology rather
than Decode tuning.

## Serving Configuration

UNCHANGED from organizer REF07.

Do not modify:

- Prefill/Decode GPU allocation
- TP
- EP
- NIXL
- IB/UCX configuration
- router
- memory configuration
- scheduling configuration
- max-running-requests
- model

## Benchmark Configuration

- concurrency = 48
- workers-max = 48
- warmup-duration = 60 seconds
- benchmark-duration = 120 seconds
- benchmark-grace-period = 30 seconds
- synthetic input = 4000 tokens
- output = 200 tokens
- seed = 2026
- cache bust = first_turn_prefix
- TTFT SLA = 3000 ms
- average ITL SLA = 20 ms

## Decision Rule

### PASS

If:

good_request_fraction >= 0.90

Then REF07 C48 becomes the official baseline configuration.

Record its goodput and good output token throughput and attempt to improve
on it in subsequent experiments.

### FAIL

If:

good_request_fraction < 0.90

and TTFT remains the primary failure while ITL mostly passes,

then the next experiment will investigate a Prefill-oriented configuration,
most likely REF08 (12+4).

## Results

Pending.

## Interpretation

Pending.

## Decision

Pending.

## Results

Job: 20067

Official benchmark:
- concurrency: 48
- warmup: 60 s
- benchmark: 120 s
- grace: 30 s

Headline results:
- request throughput: 2.70 req/s
- output token throughput: 540.86 tokens/s
- goodput: 0.93 req/s
- approximate good-request fraction: ~0.34

TTFT:
- avg: 14357.65 ms
- p50: 20766.23 ms
- p90: 26965.51 ms
- p99: 27331.58 ms

ITL:
- avg: 14.97 ms
- p90: 17.27 ms
- p99: 18.52 ms

Effective concurrency:
- total avg: 46.89
- prefill avg: 38.83
- decode avg: 8.06

## Interpretation

REF07 at C48 is not a viable official configuration.

The dominant bottleneck is the pre-first-token path. ITL remains within
the 20 ms SLA even at p99, while TTFT exceeds the 3000 ms SLA by a very
large margin.

The long official run exposes substantial queue accumulation that was not
visible in the shorter exploratory C48 run.

The next experiment should target additional Prefill-side capacity rather
than Decode optimization.

## Decision

FAIL.

Do not use REF07 C48 as the final baseline.

Next: inspect organizer REF08 (12+4) and design a controlled comparison.
