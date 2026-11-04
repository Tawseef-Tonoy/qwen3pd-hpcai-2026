
## Final official-timing result

EXP-010 PASSED.

Configuration:
- 8 Prefill GPUs
- 4 Prefill workers × TP2
- 8 Decode GPUs
- 2 Decode workers × TP4 / EP4
- Prefill routing = round_robin
- concurrency = 40

Official timing:
- warmup = 60 s
- benchmark = 120 s
- grace = 30 s

Results:
- Requests = 1161
- Cancelled = 0
- GFR = 0.982
- TTFT pass = 100.0%
- ITL pass = 98.2%
- TTFT p90 = 1117.9 ms
- ITL p90 = 19.16 ms
- AIPerf goodput = 9.21 req/s
- Good output throughput ≈ 1842 tokens/s

Temporal:
- First-half GFR = 96.4%
- Second-half GFR = 100.0%

Conclusion:

This is the first configuration in the project to pass the complete
official-timing SLA gate.

It is now the Basic baseline against which subsequent optimizations should
be measured.
