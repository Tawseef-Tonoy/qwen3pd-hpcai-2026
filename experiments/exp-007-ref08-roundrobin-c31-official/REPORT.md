
## Final result

EXP-007 failed the official SLA.

Results:

- Concurrency: 31
- Requests: 837
- Cancelled: 0
- GFR: 0.085
- TTFT pass: 100.0%
- ITL pass: 8.5%
- TTFT p90: 487.6 ms
- ITL p90: 20.53 ms
- Request throughput: 6.83 req/s
- AIPerf goodput: 0.58 req/s

Temporal analysis:

- First-half GFR: 13.2%
- Second-half GFR: 3.8%
- No startup/temporal TTFT limitation
- Decode / ITL is the dominant bottleneck

Interpretation:

C31 is beyond the Decode SLA boundary for the current 12P+4D topology.

Together with EXP-006:

- C30 was Decode-safe with 100% ITL pass
- C31 is Decode-limited
- C32 and above are Decode-limited

Therefore C30 is the highest currently supported concurrency candidate.

Next experiment:

EXP-008 — C30 exact official 60/120/30 validation with round-robin Prefill routing.
