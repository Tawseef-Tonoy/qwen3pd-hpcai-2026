# Pre-Reference BRACU Parallel Qwen Work

## Classification

This directory contains work performed BEFORE discovery of the
Firmus-staged reference scripts under:

    /scratch/reference-scripts/

Discovery date:

    2026-09-28

These files are preserved as historical engineering evidence.

They MUST NOT be described as reproductions of Firmus reference script 07.

## Historical experiments

### FIRMUS-QWEN235B-PD-001

Slurm job:

    19782

Purpose:

    BRACU reconstructed 16-H200 P/D functional baseline.

Architecture:

    4 Prefill workers, TP=2
    2 Decode workers, TP=4, EP=4

Result:

    Functional PASS.

### FIRMUS-QWEN235B-AIPERF-001

Slurm job:

    19794

Purpose:

    Exploratory AIPerf measurement of the BRACU reconstructed deployment.

Important characteristics:

    one-shot concurrency C=16
    BRACU reconstruction selected one active IB device for UCX
    rather than the all-active-IB behavior later found in Firmus REF07

Observed result:

    45 profiling requests sent
    31 completed
    14 cancelled after grace
    good_request_fraction = 0.7741935483870968

Post-discovery forensic analysis localized the non-completing population
to the P/D bootstrap / handoff / transfer-readiness path.

The exact root cause remains unproven.

## Preservation rule

Files in this directory are historical evidence.

Do not edit completed raw run artifacts in place.
New interpretation and analysis belongs under the canonical docs/ or
analysis/ directories.
