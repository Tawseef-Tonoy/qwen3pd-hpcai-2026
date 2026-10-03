#!/bin/bash

set -uo pipefail

OUT=${1:?output directory required}

mkdir -p "$OUT"

hostname > "$OUT/hostname.txt"

{
    date -u
    uname -a
    cat /etc/os-release 2>/dev/null || true
} > "$OUT/system.txt" 2>&1


{
    nvidia-smi
    echo
    nvidia-smi -L
} > "$OUT/nvidia.txt" 2>&1


nvidia-smi topo -m \
> "$OUT/gpu_topology.txt" 2>&1 || true


nvidia-smi nvlink --status \
> "$OUT/nvlink_status.txt" 2>&1 || true


{
    echo "===== ibdev2netdev ====="
    ibdev2netdev || true

    echo
    echo "===== ibv_devices ====="
    ibv_devices || true

    echo
    echo "===== ibv_devinfo ====="
    ibv_devinfo || true

} > "$OUT/infiniband.txt" 2>&1


{
    echo "===== CUDA ENV ====="
    env | grep -E 'CUDA|NVIDIA' | sort || true

    echo
    echo "===== NCCL ENV ====="
    env | grep '^NCCL_' | sort || true

    echo
    echo "===== UCX ENV ====="
    env | grep '^UCX_' | sort || true

} > "$OUT/environment.txt" 2>&1

