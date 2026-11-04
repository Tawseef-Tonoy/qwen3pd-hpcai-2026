#!/bin/bash
#SBATCH -J exp016-c48-decode-profile
#SBATCH -p hpcai
#SBATCH -N 2
#SBATCH -t 00:17:00
#SBATCH --gres=gpu:8
#SBATCH --propagate=NONE
#SBATCH -o runs/%j.out
#SBATCH -e runs/%j.err

# ============================================================
# EXP-013
# C48 instrumented control
#
# IMPORTANT:
# Keep the existing #!/bin/bash and #SBATCH lines from EXP-012
# ABOVE this block unchanged.
# ============================================================

set -euo pipefail


# ============================================================
# CONFIG
# ============================================================

SGLANG=/scratch/enroot-images/sglang-harbor.sqsh
AIPERF=/scratch/enroot-images/aiperf.sqsh
MODEL=/scratch/models/Qwen3-235B-A22B-Instruct-2507-FP8

R_PORT=8000

# /health usually comes up in a few minutes.
# Fail if still unavailable after 10 minutes.
READY_SECS=600

ISL=4000
OSL=200
N=48

ROOT="${SLURM_SUBMIT_DIR}"
ART="${ROOT}/runs/${SLURM_JOB_ID}"

mkdir -p "${ART}"
mkdir -p "${ART}/system/head"
mkdir -p "${ART}/system/tail"
mkdir -p "${ART}/aiperf-artifacts"


# ============================================================
# NODE INFORMATION
# ============================================================

NODES=($(scontrol show hostnames "${SLURM_JOB_NODELIST}"))

HEAD=${NODES[0]}
TAIL=${NODES[1]}

ip_of() {
    getent ahostsv4 "$1" |
        awk '{print $1; exit}'
}

HEAD_IP=$(ip_of "${HEAD}")
TAIL_IP=$(ip_of "${TAIL}")


# ============================================================
# CONTAINER MOUNTS
# ============================================================

mounts() {
    mkdir -p "${ROOT}/home/$1"

    echo "/scratch:/scratch,${ROOT}/home/$1:${HOME},${ROOT}:${ROOT}"
}


# ============================================================
# HEALTH CHECK
# ============================================================

wait_http() {
    timeout "${READY_SECS}" curl -sf \
        --retry-connrefused \
        --retry-all-errors \
        --retry-delay 2 \
        --retry 300 \
        --max-time 2 \
        -o /dev/null "$1"
}


# ============================================================
# TELEMETRY CLEANUP
# ============================================================

GPU_MON_HEAD_PID=""
GPU_MON_TAIL_PID=""

stop_gpu_monitors() {

    set +e

    echo "=== STOP GPU TELEMETRY ==="

    for pid in \
        "${GPU_MON_HEAD_PID}" \
        "${GPU_MON_TAIL_PID}"
    do
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill -TERM "${pid}" 2>/dev/null || true
            wait "${pid}" 2>/dev/null || true
        fi
    done

    set -e
}


cleanup() {

    set +e

    stop_gpu_monitors

    for pid in \
        "${R_PID:-}" \
        "${D0_PID:-}" \
        "${D1_PID:-}" \
        "${P0_PID:-}" \
        "${P1_PID:-}" \
        "${P2_PID:-}" \
        "${P3_PID:-}"
    do
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill -TERM "${pid}" 2>/dev/null || true
        fi
    done
}

trap cleanup EXIT INT TERM


# ============================================================
# BASIC RUN METADATA
# ============================================================

echo "$(date --iso-8601=seconds) job=${SLURM_JOB_ID} user=$(whoami)"

echo \
"head=${HEAD}(${HEAD_IP}) tail=${TAIL}(${TAIL_IP}) model=${MODEL} isl=${ISL} osl=${OSL} N=${N}"

test -r "${SGLANG}"
test -r "${AIPERF}"
test -r "${MODEL}/config.json"

mkdir -p "${ART}"


# ============================================================
# NODE INVENTORY
#
# Cheap metadata collection before using the GPUs for inference.
# ============================================================

echo
echo "=== CAPTURE NODE INVENTORY ==="

srun \
    --overlap \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --cpus-per-task=1 \
    --mem=1G \
    bash "${ROOT}/tools/capture_node_inventory.sh" \
    "${ART}/system/head"


srun \
    --overlap \
    -N1 \
    -n1 \
    -w "${TAIL}" \
    --cpus-per-task=1 \
    --mem=1G \
    bash "${ROOT}/tools/capture_node_inventory.sh" \
    "${ART}/system/tail"


# ============================================================
# WORKER SCRIPT
# ============================================================

cat > "${ART}/worker.sh" <<'EOF'
#!/bin/bash

set -euo pipefail

name=$1
port=$2
model=$3
tp=$4

shift 4

role=${name%%-*}


# ------------------------------------------------------------
# Detect active InfiniBand devices
# ------------------------------------------------------------

UCX_IB=$(
    for d in /sys/class/infiniband/*
    do
        [ -e "$d" ] || continue

        [ "$(cat "$d/ports/1/link_layer" 2>/dev/null)" = "InfiniBand" ] \
            || continue

        [ "$(cat "$d/ports/1/state" 2>/dev/null)" = "4: ACTIVE" ] \
            || continue

        echo "$(basename "$d"):1"

    done | paste -sd, -
)


if [ -z "${UCX_IB}" ]; then
    echo "FATAL: no active IB on $(hostname)"
    exit 1
fi


export UCX_NET_DEVICES="${UCX_IB}"

# Preserve existing working UCX setting.
export UCX_RNDV_USE_RKEY_PTR=n


# ------------------------------------------------------------
# Per-worker cache directories
# ------------------------------------------------------------

export TRITON_CACHE_DIR="/tmp/sglang-${name}/triton"
export TORCHINDUCTOR_CACHE_DIR="/tmp/sglang-${name}/inductor"

mkdir -p \
    "${TRITON_CACHE_DIR}" \
    "${TORCHINDUCTOR_CACHE_DIR}"


echo \
"${name} host=$(hostname) ib=${UCX_IB} gpu=${CUDA_VISIBLE_DEVICES:-unset} tp=${tp}"


# ------------------------------------------------------------
# SGLang worker
# ------------------------------------------------------------

exec python3 -m sglang.launch_server \
    --model-path "${model}" \
    --served-model-name qwen \
    --trust-remote-code \
    --context-length 8192 \
    --tp-size "${tp}" \
    --mem-fraction-static 0.90 \
    --disaggregation-mode "${role}" \
    --disaggregation-transfer-backend nixl \
    "$@" \
    --host 0.0.0.0 \
    --port "${port}"

EOF

chmod +x "${ART}/worker.sh"


# ============================================================
# PREFILL
#
# 4 replicas × TP2
# 8 H200 total
# ============================================================

echo
echo "=== START PREFILL ==="


srun \
    --exact \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --gres=gpu:2 \
    --cpus-per-task=16 \
    --container-image="${SGLANG}" \
    --container-mounts="$(mounts prefill-0)" \
    bash "${ART}/worker.sh" \
        prefill-0 \
        30100 \
        "${MODEL}" \
        2 \
        --disaggregation-bootstrap-port 9000 \
    >"${ART}/prefill-0.log" 2>&1 &

P0_PID=$!


srun \
    --exact \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --gres=gpu:2 \
    --cpus-per-task=16 \
    --container-image="${SGLANG}" \
    --container-mounts="$(mounts prefill-1)" \
    bash "${ART}/worker.sh" \
        prefill-1 \
        30101 \
        "${MODEL}" \
        2 \
        --disaggregation-bootstrap-port 9001 \
    >"${ART}/prefill-1.log" 2>&1 &

P1_PID=$!


srun \
    --exact \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --gres=gpu:2 \
    --cpus-per-task=16 \
    --container-image="${SGLANG}" \
    --container-mounts="$(mounts prefill-2)" \
    bash "${ART}/worker.sh" \
        prefill-2 \
        30102 \
        "${MODEL}" \
        2 \
        --disaggregation-bootstrap-port 9002 \
    >"${ART}/prefill-2.log" 2>&1 &

P2_PID=$!


srun \
    --exact \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --gres=gpu:2 \
    --cpus-per-task=16 \
    --container-image="${SGLANG}" \
    --container-mounts="$(mounts prefill-3)" \
    bash "${ART}/worker.sh" \
        prefill-3 \
        30103 \
        "${MODEL}" \
        2 \
        --disaggregation-bootstrap-port 9003 \
    >"${ART}/prefill-3.log" 2>&1 &

P3_PID=$!


# ============================================================
# DECODE
#
# 2 replicas × TP4 / EP4
# 8 H200 total
# ============================================================

echo
echo "=== START DECODE ==="


srun \
    --exact \
    -N1 \
    -n1 \
    -w "${TAIL}" \
    --gres=gpu:4 \
    --cpus-per-task=32 \
    --container-image="${SGLANG}" \
    --container-mounts="$(mounts decode-0)" \
    bash "${ART}/worker.sh" \
        decode-0 \
        30200 \
        "${MODEL}" \
        4 \
        --ep-size 4 \
        --max-running-requests 256 \
    >"${ART}/decode-0.log" 2>&1 &

D0_PID=$!


srun \
    --exact \
    -N1 \
    -n1 \
    -w "${TAIL}" \
    --gres=gpu:4 \
    --cpus-per-task=32 \
    --container-image="${SGLANG}" \
    --container-mounts="$(mounts decode-1)" \
    bash "${ART}/worker.sh" \
        decode-1 \
        30201 \
        "${MODEL}" \
        4 \
        --ep-size 4 \
        --max-running-requests 256 \
    >"${ART}/decode-1.log" 2>&1 &

D1_PID=$!


# ============================================================
# WAIT FOR WORKERS
# ============================================================

echo
echo "=== WAIT FOR WORKERS ==="

wait_http "http://${HEAD_IP}:30100/health"
echo "prefill-0 ready"

wait_http "http://${HEAD_IP}:30101/health"
echo "prefill-1 ready"

wait_http "http://${HEAD_IP}:30102/health"
echo "prefill-2 ready"

wait_http "http://${HEAD_IP}:30103/health"
echo "prefill-3 ready"

wait_http "http://${TAIL_IP}:30200/health"
echo "decode-0 ready"

wait_http "http://${TAIL_IP}:30201/health"
echo "decode-1 ready"


# ============================================================
# ROUTER
#
# Explicit RR for BOTH Prefill and Decode.
# This is the EXP-012 winning routing configuration.
# ============================================================

echo
echo "=== START ROUTER ==="

srun \
    --overlap \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --cpus-per-task=2 \
    --container-image="${SGLANG}" \
    --container-mounts="$(mounts router)" \
    python3 -m sglang_router.launch_router \
        --pd-disaggregation \
        --prefill-policy round_robin \
        --decode-policy round_robin \
        --prefill "http://${HEAD_IP}:30100" 9000 \
        --prefill "http://${HEAD_IP}:30101" 9001 \
        --prefill "http://${HEAD_IP}:30102" 9002 \
        --prefill "http://${HEAD_IP}:30103" 9003 \
        --decode "http://${TAIL_IP}:30200" \
        --decode "http://${TAIL_IP}:30201" \
        --host 0.0.0.0 \
        --port "${R_PORT}" \
    >"${ART}/router.log" 2>&1 &

R_PID=$!


wait_http "http://${HEAD_IP}:${R_PORT}/health"

echo
echo "READY after ${SECONDS}s"


# ============================================================
# START GPU TELEMETRY
#
# Starts AFTER model initialization/router health so the CSV is
# focused on the actual workload rather than model loading and
# CUDA graph capture.
# ============================================================

echo
echo "=== START GPU TELEMETRY ==="

date -u +%FT%TZ \
    | tee "${ART}/telemetry_start_utc.txt"


srun \
    --overlap \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --cpus-per-task=1 \
    --mem=1G \
    bash "${ROOT}/tools/gpu_telemetry.sh" \
        "${ART}/gpu-head.csv" \
    >"${ART}/gpu-head-monitor.out" \
    2>"${ART}/gpu-head-monitor.err" &

GPU_MON_HEAD_PID=$!


srun \
    --overlap \
    -N1 \
    -n1 \
    -w "${TAIL}" \
    --cpus-per-task=1 \
    --mem=1G \
    bash "${ROOT}/tools/gpu_telemetry.sh" \
        "${ART}/gpu-tail.csv" \
    >"${ART}/gpu-tail-monitor.out" \
    2>"${ART}/gpu-tail-monitor.err" &

GPU_MON_TAIL_PID=$!


echo "GPU_MON_HEAD_PID=${GPU_MON_HEAD_PID}"
echo "GPU_MON_TAIL_PID=${GPU_MON_TAIL_PID}"

sleep 2


# ============================================================
# AIPERF C48
#
# Keep workload identical to EXP-012.
# ============================================================


# ============================================================
# EXP-016: STEADY-STATE DECODE PROFILING WATCHER
#
# This experiment keeps the EXP-014 serving topology unchanged.
#
# Wait until AIPerf enters its real profiling phase, then wait
# another 10 seconds so C48 is established, and profile only
# decode-0 for 20 Decode steps.
#
# IMPORTANT:
# This run is for attribution/profiling, NOT for reporting a
# new performance score. Torch profiler adds overhead.
# ============================================================

PROFILE_DIR="${ART}/torch-profiler/decode-0"
mkdir -p "${PROFILE_DIR}"

(
    set +e

    AIPERF_LOG="${ART}/aiperf-artifacts/logs/aiperf.log"

    echo "Profiler watcher started at $(date -u +%FT%TZ)" \
        | tee "${ART}/profiler-watcher.log"

    # Wait up to ~5 minutes for AIPerf to reach the scored
    # profiling phase. Warm-up drain time can vary substantially.
    found=0

    for _ in $(seq 1 300); do

        if [[ -f "${AIPERF_LOG}" ]] && \
           grep -q 'Phase profiling (profiling) started' "${AIPERF_LOG}"
        then
            found=1
            break
        fi

        sleep 1
    done

    if [[ "${found}" -ne 1 ]]; then
        echo "ERROR: profiling phase marker not observed" \
            | tee -a "${ART}/profiler-watcher.log"
        exit 71
    fi

    echo "AIPerf profiling phase detected at $(date -u +%FT%TZ)" \
        | tee -a "${ART}/profiler-watcher.log"

    # Let the closed-loop C48 workload settle.
    sleep 10

    echo "Starting Decode-0 torch profiler at $(date -u +%FT%TZ)" \
        | tee -a "${ART}/profiler-watcher.log"

    curl -fsS \
        --max-time 30 \
        -X POST \
        "http://${TAIL_IP}:30200/start_profile" \
        -H 'Content-Type: application/json' \
        -d "{
              \"output_dir\": \"${PROFILE_DIR}\",
              \"num_steps\": 20,
              \"activities\": [\"CPU\", \"GPU\"]
            }" \
        >"${ART}/start-profile-response.txt" \
        2>"${ART}/start-profile-error.txt"

    rc=$?

    echo "start_profile rc=${rc}" \
        | tee -a "${ART}/profiler-watcher.log"

    if [[ "${rc}" -ne 0 ]]; then
        echo "ERROR: /start_profile failed" \
            | tee -a "${ART}/profiler-watcher.log"
        cat "${ART}/start-profile-error.txt" \
            | tee -a "${ART}/profiler-watcher.log"
        exit "${rc}"
    fi

    echo "Profiler request accepted" \
        | tee -a "${ART}/profiler-watcher.log"

) &

PROFILE_WATCHER_PID=$!

echo "PROFILE_WATCHER_PID=${PROFILE_WATCHER_PID}"


echo
echo "=== START AIPERF C48 ==="

date -u +%FT%TZ \
    | tee "${ART}/aiperf_start_utc.txt"


srun \
    --overlap \
    -N1 \
    -n1 \
    -w "${HEAD}" \
    --container-image="${AIPERF}" \
    --container-mounts="$(mounts aiperf)" \
    aiperf profile \
        --artifact-dir "${ART}/aiperf-artifacts" \
        --model qwen \
        --tokenizer Qwen/Qwen3-235B-A22B-Instruct-2507 \
        --url "http://${HEAD_IP}:${R_PORT}" \
        --endpoint-type chat \
        --endpoint /v1/chat/completions \
        --streaming \
        --concurrency "${N}" \
        --api-key NOT_USED \
        --warmup-duration 60 \
        --benchmark-duration 60 \
        --benchmark-grace-period 15 \
        --synthetic-input-tokens-mean "${ISL}" \
        --synthetic-input-tokens-stddev 0 \
        --output-tokens-mean "${OSL}" \
        --output-tokens-stddev 0 \
        --num-dataset-entries 12800 \
        --random-seed 2026 \
        --cache-bust first_turn_prefix \
        --extra-inputs "min_tokens:${OSL}" \
        --extra-inputs "max_tokens:${OSL}" \
        --extra-inputs ignore_eos:true \
        --extra-inputs temperature:0.0 \
        --extra-inputs repetition_penalty:1.0 \
        --goodput "time_to_first_token:3000 inter_token_latency:20" \
        --ui simple


echo
echo "=== WAIT FOR TORCH PROFILER OUTPUT ==="

# The profiler can take time to compress/write the trace.
for i in $(seq 1 120); do

    count=$(
        find "${ART}/torch-profiler" \
            -type f \
            \( -name '*.trace.json' -o -name '*.trace.json.gz' \) \
            2>/dev/null \
            | wc -l
    )

    if [[ "$count" -gt 0 ]]; then
        echo "Profiler traces found: $count"
        break
    fi

    sleep 1
done

echo
echo "=== PROFILER FILES ==="

find "${ART}/torch-profiler" \
    -type f \
    -printf '%p %s bytes\n' \
    2>/dev/null \
    | sort \
    | tee "${ART}/profiler-files.txt"

if [[ -n "${PROFILE_WATCHER_PID:-}" ]]; then
    wait "${PROFILE_WATCHER_PID}" || true
fi
# ============================================================
# END BENCHMARK / TELEMETRY
# ============================================================

date -u +%FT%TZ \
    | tee "${ART}/aiperf_end_utc.txt"

stop_gpu_monitors

GPU_MON_HEAD_PID=""
GPU_MON_TAIL_PID=""

date -u +%FT%TZ \
    | tee "${ART}/telemetry_end_utc.txt"


echo
echo "=========================================="
echo "EXP-016 COMPLETE"
echo "=========================================="
echo "Artifacts: ${ART}"
echo

set +e
kill "${P0_PID}" "${P1_PID}" "${P2_PID}" "${P3_PID}" "${D0_PID}" "${D1_PID}" "${R_PID}"
wait "${P0_PID}" "${P1_PID}" "${P2_PID}" "${P3_PID}" "${D0_PID}" "${D1_PID}" "${R_PID}"
set -e
