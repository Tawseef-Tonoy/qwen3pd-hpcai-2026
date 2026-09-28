
## Final result

EXP-008 failed the official SLA.

Results:

- Concurrency: 30
- Requests: 817
- GFR: 0.137
- TTFT pass: 100.0%
- ITL pass: 13.7%
- TTFT p90: 491.9 ms
- ITL p90: 20.40 ms
- Request throughput: 6.61 req/s
- AIPerf goodput: 0.91 req/s

Temporal analysis:

- First-half GFR: 22.1%
- Second-half GFR: 5.4%
- TTFT remained 100% SLA-valid
- Decode / ITL remained the dominant bottleneck

Interpretation:

C30 is beyond the stable Decode SLA boundary once Prefill routing and TTFT
are healthy.

The earlier exploratory C30 result underestimated Decode pressure because
large TTFT delays reduced sustained Decode occupancy.

Next experiment:

EXP-009 — test C28 and C29 with round-robin Prefill routing and a longer
60-second warmup to locate the true Decode SLA knee.
