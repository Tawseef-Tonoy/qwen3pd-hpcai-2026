
## Final diagnosis

Official C36 validation failed:

- GFR: 0.379
- TTFT pass: 37.9%
- ITL pass: 100.0%
- TTFT p90: 104.8 s
- ITL p90: 17.19 ms

The failure was dominated by intermittent pre-first-token stalls.

During the principal stall window, Prefill activity was strongly imbalanced:

| Worker | Batches | Max queue |
|---|---:|---:|
| prefill-0 | 21 | 30 |
| prefill-1 | 3 | 0 |
| prefill-2 | 19 | 28 |
| prefill-3 | 3 | 0 |
| prefill-4 | 3 | 0 |
| prefill-5 | 79 | 30 |

Decode remained healthy:

- Decode batches: 263
- Decode max queue: 0
- Decode max running: 22
- Decode max transfer: 35
- Decode warnings: 0

The router also reported no warnings/errors during the stall window.

Leading hypothesis:
cache-aware Prefill routing is producing severe worker imbalance at this workload.

Next experiment:
EXP-005 changes only the Prefill routing policy to round-robin.
