# APAC HPC-AI 2026 — Qwen3 Prefill/Decode Optimization

## Objective

Optimize Qwen3-235B-A22B-Instruct-2507-FP8 inference on the Firmus
16×H200 environment while satisfying the competition latency/QoS constraints.

## Repository Structure

### reference/organizer/

Unmodified Firmus organizer reference scripts.

These files are treated as ground truth and are never edited directly.

### experiments/

Controlled experiments.

Each experiment contains:

- hypothesis
- configuration choices
- exact script
- Slurm job ID
- logs
- AIPerf results
- interpretation
- final decision

### submission/

Final competition package:

- build method
- final submit.sbatch
- result logs
- optional profiling data
- presentation

## Experiment Principle

Every experiment should change one clearly motivated aspect of the system.

Workflow:

Observation
→ Hypothesis
→ Controlled change
→ Measurement
→ Decision
