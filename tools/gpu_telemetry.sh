#!/bin/bash

set -uo pipefail

OUT=${1:?output CSV required}

echo \
"timestamp,node,index,uuid,gpu_util_pct,memory_util_pct,memory_used_mib,memory_total_mib,power_w,power_limit_w,sm_clock_mhz,memory_clock_mhz,temperature_c" \
> "$OUT"

while true; do

    NODE=$(hostname)

    nvidia-smi \
      --query-gpu=timestamp,index,uuid,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,power.limit,clocks.sm,clocks.mem,temperature.gpu \
      --format=csv,noheader,nounits \
    | while IFS= read -r line; do

        echo "${line%%,*},${NODE},${line#*,}" >> "$OUT"

    done

    sleep 1

done
