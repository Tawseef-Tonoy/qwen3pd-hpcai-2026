# EXP-002 Analysis Files

- `performance-summary.csv` — aggregate AIPerf performance metrics for each concurrency.
- `sla-summary.csv` — per-request SLA classification using TTFT <= 3000 ms and average ITL <= 20 ms.
- `temporal-analysis.csv` — first-half vs second-half latency behavior used to identify warm-up/transient effects.

The full interpretation is in `../REPORT.md`.

Raw AIPerf artifacts are preserved under `../results/`.
