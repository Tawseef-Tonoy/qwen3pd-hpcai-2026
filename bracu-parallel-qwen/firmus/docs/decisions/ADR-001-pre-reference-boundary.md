# ADR-001 — Preserve the Pre-Reference Boundary

Status: Accepted
Date: 2026-09-28

## Context

BRACU Parallel constructed and tested a 16-H200 Qwen P/D deployment
before discovering the Firmus-staged reference scripts under:

    /scratch/reference-scripts/

The historical BRACU configuration was therefore independently
reconstructed rather than copied from Firmus reference 07.

## Decision

All work completed before reference-script discovery is classified under:

    archive/pre-reference/

Historical job IDs include:

    19782
    19794

Compatibility symlinks are retained so old absolute paths continue to
resolve.

## Consequence

Historical results remain valid evidence for the configurations that
produced them, but must not be relabeled as Firmus reference results.
