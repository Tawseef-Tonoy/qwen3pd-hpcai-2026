# BRACU Parallel — APAC 2026 Qwen Track

Canonical workspace:

    /home/apacsc04/bracu-parallel-qwen

Legacy compatibility path:

    /home/apacsc04/qwen235b-phase2

## Project eras

### 1. Pre-reference reconstruction era

Location:

    archive/pre-reference/

This contains BRACU Parallel work performed before discovery of the
Firmus-staged reference scripts on 2026-09-28.

Important historical runs:

    FIRMUS-QWEN235B-PD-001
    Slurm job 19782

    FIRMUS-QWEN235B-AIPERF-001
    Slurm job 19794

These are valid historical measurements, but they are NOT Firmus
reference-script reproductions.

### 2. Reference-control and Basic era

External organizer material:

    external/firmus-reference/

Basic experiments:

    experiments/basic/
    runs/basic/

The first control experiment in this era is:

    BASIC-REF07-001

Its purpose is to reproduce the frozen Firmus reference 07 configuration
before any BRACU tuning is introduced.

### 3. Bonus optimization era

Location:

    experiments/bonus/
    runs/bonus/

Bonus experiments must branch from a known Basic configuration and make
one controlled change at a time.

## Directory roles

    docs/
        rules, organizer clarifications, platform facts, decisions,
        and engineering findings

    external/
        immutable external reference material

    scripts/
        BRACU-authored reusable scripts

    configs/
        explicit configuration inputs

    experiments/
        hypotheses, metadata, submitted scripts, result interpretation

    runs/
        immutable raw runtime evidence

    analysis/
        post-run analysis, tables, figures, comparisons

    provenance/
        hashes, environment capture, repository state, migration history

    submission/
        material intended for final competition submission

    archive/pre-reference/
        historical work from before reference-script discovery

    scratch/
        disposable work only

## Evidence rule

Do not silently edit completed raw run artifacts.

Facts, observations, interpretations, hypotheses, and unresolved questions
must remain distinguishable.

## Competition organization

Work is organized primarily as:

    Basic
    Bonus

rather than chronological phase numbers.

Phase terminology may be used temporarily for daily workflow, but it is
not part of the canonical experiment naming scheme.
