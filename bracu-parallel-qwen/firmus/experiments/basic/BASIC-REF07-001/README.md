# BASIC-REF07-001

Status:

    PREPARED

Class:

    Basic reference control

Purpose:

    Faithfully reproduce Firmus reference script 07 before introducing
    BRACU Parallel tuning.

Source:

    external/firmus-reference/firmus-20260928-052951/
    07-pd-235b-8plus8.sbatch

Reference SHA256:

    5f10055bec0c1fd61527fed6cdca08bd9ad5f07e546ef8529cbbe51c7e4d3dea

Configuration represented by the source script:

    2 nodes
    16 H200 GPUs
    4 Prefill workers, TP=2
    2 Decode workers, TP=4, EP=4
    NIXL P/D transfer
    all active IB devices exposed through UCX_NET_DEVICES
    concurrency sweep: 8,16,40,48,56
    exploratory timing: 20s warmup / 60s benchmark / 15s grace

Interpretation:

    This is a reference-control experiment.

    It is NOT yet the official scored Basic benchmark because the Firmus
    reference uses shortened exploratory benchmark timing and a concurrency
    sweep.

Controlled change relative to Firmus reference 07:

    NONE

Historical boundary:

    Jobs 19782 and 19794 belong to archive/pre-reference/ and are not
    reference-07 reproductions.
