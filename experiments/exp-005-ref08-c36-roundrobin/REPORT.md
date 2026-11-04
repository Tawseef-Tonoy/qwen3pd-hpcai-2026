
## Official SLA evaluation

The profiling-only analyzer produced:

- Requests: 952
- Cancelled: 0
- Good-request fraction: **0.038**
- TTFT pass rate: **100.0%**
- ITL pass rate: **3.8%**
- TTFT p90: **502.2 ms**
- ITL p90: **20.99 ms**

Temporal analysis:

- First half GFR: 4.2%
- Second half GFR: 3.4%
- No meaningful startup/temporal effect remained.

Therefore EXP-005 is a clear routing success but an official SLA failure.

Round-robin eliminated the catastrophic Prefill/TTFT failure from EXP-004,
but C36 now operates beyond the Decode ITL boundary. The Decode limitation
is stable rather than transient.

The next experiment will keep round-robin routing unchanged and locate the
highest concurrency that moves the ITL distribution below the 20 ms SLA.
