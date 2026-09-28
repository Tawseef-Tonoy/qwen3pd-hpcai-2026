# ADR-002 — Establish Firmus Reference 07 as the First Post-Discovery Control

Status: Accepted
Date: 2026-09-28

## Context

A frozen copy of the Firmus-provided reference scripts is preserved at:

    external/firmus-reference/firmus-20260928-052951/

Reference 07 SHA256:

    5f10055bec0c1fd61527fed6cdca08bd9ad5f07e546ef8529cbbe51c7e4d3dea

Reference 07 demonstrates:

    4 Prefill workers at TP=2
    2 Decode workers at TP=4, EP=4
    16 H200 GPUs total
    P/D disaggregation
    NIXL transfer backend
    all active IB devices exposed through UCX_NET_DEVICES
    exploratory concurrency sweep

## Decision

The first post-discovery control experiment will be named:

    BASIC-REF07-001

Its objective is faithful reproduction of the frozen Firmus reference 07
configuration before optimization.

## Constraint

No tuning should be mixed into BASIC-REF07-001.

Any BRACU modification must be separately identified and documented.
