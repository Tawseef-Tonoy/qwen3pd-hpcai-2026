#!/bin/bash
#SBATCH --job-name=bracu-235b-aiperf-vanilla
#SBATCH --partition=hpcai
#SBATCH --nodes=2
#SBATCH --nodelist=g1,g4
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128
#SBATCH --gres=gpu:nvidia_h200:8
#SBATCH --mem=0
#SBATCH --time=00:17:00
#SBATCH --chdir=/home/apacsc04/qwen235b-phase2
#SBATCH --output=/home/apacsc04/qwen235b-phase2/logs/%x-%j.out
#SBATCH --error=/home/apacsc04/qwen235b-phase2/logs/%x-%j.err

set -Eeuo pipefail

HEAD_NODE=g1
TAIL_NODE=g4

MODEL=/scratch/models/Qwen3-235B-A22B-Instruct-2507-FP8
SGLANG_IMAGE=/scratch/enroot-images/sglang-harbor.sqsh
AIPERF_IMAGE=/scratch/enroot-images/aiperf.sqsh

PHASE2=/home/apacsc04/qwen235b-phase2
RUN_DIR="${PHASE2}/results/run-${SLURM_JOB_ID}"

PREFILL_STEP_PID=""
DECODE_STEP_PID=""
ROUTER_STEP_PID=""

mkdir -p "$RUN_DIR"
cp "$0" "$RUN_DIR/submitted-script.sbatch" 2>/dev/null || true


cleanup() {
    set +e

    echo "=== CLEANUP ==="

    for pid in \
        "$ROUTER_STEP_PID" \
        "$DECODE_STEP_PID" \
        "$PREFILL_STEP_PID"
    do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done

    for pid in \
        "$ROUTER_STEP_PID" \
        "$DECODE_STEP_PID" \
        "$PREFILL_STEP_PID"
    do
        if [[ -n "$pid" ]]; then
            wait "$pid" 2>/dev/null || true
        fi
    done
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM


resolve_ipv4() {
    getent ahostsv4 "$1" |
        awk '$2 == "STREAM" {print $1; exit}'
}


wait_health_until() {
    local label="$1"
    local url="$2"
    local step_pid="$3"
    local deadline="$4"

    echo "Waiting for ${label}: ${url}/health"

    while (( SECONDS < deadline )); do

        if curl -fsS --max-time 2 \
            "${url}/health" >/dev/null 2>&1
        then
            echo "HEALTHY: ${label} at t=${SECONDS}s"
            return 0
        fi

        if ! kill -0 "$step_pid" 2>/dev/null; then
            echo "FAILED: parent srun for ${label} exited before health succeeded"
            return 2
        fi

        sleep 2
    done

    echo "TIMEOUT: ${label} did not become healthy before shared deadline"
    return 1
}


dump_worker_logs() {

    echo "=== PREFILL LOG TAILS ==="

    for f in \
        "$RUN_DIR"/prefill-*.out \
        "$RUN_DIR"/prefill-*.err
    do
        [[ -e "$f" ]] || continue

        echo "--- $f ---"
        tail -n 80 "$f" || true
    done

    echo "=== DECODE LOG TAILS ==="

    for f in \
        "$RUN_DIR"/decode-*.out \
        "$RUN_DIR"/decode-*.err
    do
        [[ -e "$f" ]] || continue

        echo "--- $f ---"
        tail -n 80 "$f" || true
    done
}


echo "=== BRACU 235B P/D BASELINE ==="
date -u

echo "JOB=$SLURM_JOB_ID"
echo "NODELIST=$SLURM_JOB_NODELIST"
echo "MODEL=$MODEL"
echo "RUN_DIR=$RUN_DIR"


# ------------------------------------------------------------
# Validate node allocation
# ------------------------------------------------------------

mapfile -t ALLOC_NODES < <(
    scontrol show hostnames "$SLURM_JOB_NODELIST"
)

printf 'ALLOCATED NODE: %s\n' "${ALLOC_NODES[@]}"

if ! printf '%s\n' "${ALLOC_NODES[@]}" |
    grep -qx "$HEAD_NODE"
then
    echo "ERROR: $HEAD_NODE is not in allocation"
    exit 10
fi

if ! printf '%s\n' "${ALLOC_NODES[@]}" |
    grep -qx "$TAIL_NODE"
then
    echo "ERROR: $TAIL_NODE is not in allocation"
    exit 11
fi


# ------------------------------------------------------------
# Resolve control-plane addresses
# ------------------------------------------------------------

HEAD_IP=$(resolve_ipv4 "$HEAD_NODE")
TAIL_IP=$(resolve_ipv4 "$TAIL_NODE")

if [[ -z "$HEAD_IP" || -z "$TAIL_IP" ]]; then
    echo "ERROR: failed to resolve compute-node IPv4 addresses"
    exit 12
fi

echo "HEAD_NODE=$HEAD_NODE HEAD_IP=$HEAD_IP"
echo "TAIL_NODE=$TAIL_NODE TAIL_IP=$TAIL_IP"


# ------------------------------------------------------------
# Preserve repository state
# ------------------------------------------------------------

REPO_COMMIT=$(
    git -C /home/apacsc04/2026-APAC-HPC-AI \
        rev-parse HEAD 2>/dev/null ||
        echo UNKNOWN
)

echo "REPO_COMMIT=$REPO_COMMIT"


# ------------------------------------------------------------
# Detect node-local active IB device
#
# IMPORTANT:
# The public Firmus notes say their missing reference script
# detects a node-local active IB device and exports it through
# UCX_NET_DEVICES.
#
# The exact original selection algorithm is unavailable.
#
# Our reconstructed baseline selects the first UP IB netdev
# reported by ibdev2netdev and converts:
#
#     mlx5_X port Y
#
# to:
#
#     mlx5_X:Y
#
# This is a WORKING HYPOTHESIS, not an official-script claim.
# ------------------------------------------------------------

G1_IB_MAP=$(
    srun \
        --nodes=1 \
        --nodelist="$HEAD_NODE" \
        --ntasks=1 \
        --cpus-per-task=1 \
        --mem=1G \
        --gres=none \
        --exact \
        bash -lc 'ibdev2netdev'
)

G4_IB_MAP=$(
    srun \
        --nodes=1 \
        --nodelist="$TAIL_NODE" \
        --ntasks=1 \
        --cpus-per-task=1 \
        --mem=1G \
        --gres=none \
        --exact \
        bash -lc 'ibdev2netdev'
)

printf '%s\n' "$G1_IB_MAP" |
    tee "$RUN_DIR/g1-ibdev2netdev.txt"

printf '%s\n' "$G4_IB_MAP" |
    tee "$RUN_DIR/g4-ibdev2netdev.txt"


UCX_G1=$(
    awk '
        $5 ~ /^ib/ && $6 == "(Up)" {
            print $1 ":" $3
            exit
        }
    ' <<<"$G1_IB_MAP"
)

UCX_G4=$(
    awk '
        $5 ~ /^ib/ && $6 == "(Up)" {
            print $1 ":" $3
            exit
        }
    ' <<<"$G4_IB_MAP"
)


if [[ ! "$UCX_G1" =~ ^mlx5_[0-9]+:[0-9]+$ ]]; then
    echo "ERROR: unable to derive UCX device for $HEAD_NODE"
    exit 13
fi

if [[ ! "$UCX_G4" =~ ^mlx5_[0-9]+:[0-9]+$ ]]; then
    echo "ERROR: unable to derive UCX device for $TAIL_NODE"
    exit 14
fi


echo "UCX_NET_DEVICES[$HEAD_NODE]=$UCX_G1"
echo "UCX_NET_DEVICES[$TAIL_NODE]=$UCX_G4"


# ------------------------------------------------------------
# Experiment metadata
# ------------------------------------------------------------

cat > "$RUN_DIR/metadata.txt" <<META
job_id=$SLURM_JOB_ID
date_utc=$(date -u +%FT%TZ)
repo_commit=$REPO_COMMIT

head_node=$HEAD_NODE
head_ip=$HEAD_IP
head_ucx_device=$UCX_G1

tail_node=$TAIL_NODE
tail_ip=$TAIL_IP
tail_ucx_device=$UCX_G4

model=$MODEL
sglang_image=$SGLANG_IMAGE

layout=4x_prefill_tp2__2x_decode_tp4_ep4
META


# ============================================================
# PREFILL
#
# 4 tasks
# 2 H200 per task
# TP=2
#
# Slurm is responsible for GPU isolation/binding.
# ============================================================

echo
echo "=== START PREFILL STEP: 4 tasks x 2 H200 ==="

srun \
    --nodes=1 \
    --nodelist="$HEAD_NODE" \
    --ntasks=4 \
    --ntasks-per-node=4 \
    --cpus-per-task=16 \
    --mem=1600G \
    --gpus-per-task=nvidia_h200:2 \
    --gpu-bind=verbose,per_task:2 \
    --cpu-bind=cores \
    --distribution=block:block \
    --exact \
    --kill-on-bad-exit=1 \
    --export=ALL,MODEL="$MODEL",UCX_NET_DEVICES="$UCX_G1" \
    --container-image="$SGLANG_IMAGE" \
    --container-mounts=/scratch:/scratch \
    --output="$RUN_DIR/prefill-%t.out" \
    --error="$RUN_DIR/prefill-%t.err" \
    bash -lc '

        set -Eeuo pipefail

        idx=${SLURM_LOCALID:?}

        port=$((30100 + idx))
        boot=$((9000 + idx))

        export HOME="/tmp/bracu-prefill-${idx}"
        export XDG_CACHE_HOME="$HOME/.cache"
        export PYTHONUNBUFFERED=1

        mkdir -p "$XDG_CACHE_HOME"

        echo "=== PREFILL ${idx} ==="
        date -u
        hostname

        echo "SLURM_PROCID=${SLURM_PROCID:-unset}"
        echo "SLURM_LOCALID=${SLURM_LOCALID:-unset}"
        echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
        echo "UCX_NET_DEVICES=${UCX_NET_DEVICES:-unset}"
        echo "PORT=$port"
        echo "BOOTSTRAP=$boot"

        nvidia-smi -L

        visible=$(
            python3 -c "
import torch
print(torch.cuda.device_count())
"
        )

        echo "torch.cuda.device_count=$visible"

        if [[ "$visible" -ne 2 ]]; then
            echo "ERROR: Prefill worker expected exactly 2 visible GPUs"
            exit 42
        fi


        exec python3 -m sglang.launch_server \
            --model-path "$MODEL" \
            --served-model-name qwen \
            --trust-remote-code \
            --context-length 8192 \
            --tp-size 2 \
            --mem-fraction-static 0.90 \
            --disaggregation-mode prefill \
            --disaggregation-transfer-backend nixl \
            --disaggregation-bootstrap-port "$boot" \
            --host 0.0.0.0 \
            --port "$port"
    ' &

PREFILL_STEP_PID=$!

echo "PREFILL_STEP_PID=$PREFILL_STEP_PID"


# Give Slurm a moment to establish the first step before
# launching the second node's step.

sleep 2


# ============================================================
# DECODE
#
# 2 tasks
# 4 H200 per task
# TP=4
# EP=4
# ============================================================

echo
echo "=== START DECODE STEP: 2 tasks x 4 H200 ==="

srun \
    --nodes=1 \
    --nodelist="$TAIL_NODE" \
    --ntasks=2 \
    --ntasks-per-node=2 \
    --cpus-per-task=32 \
    --mem=1600G \
    --gpus-per-task=nvidia_h200:4 \
    --gpu-bind=verbose,per_task:4 \
    --cpu-bind=cores \
    --distribution=block:block \
    --exact \
    --kill-on-bad-exit=1 \
    --export=ALL,MODEL="$MODEL",UCX_NET_DEVICES="$UCX_G4" \
    --container-image="$SGLANG_IMAGE" \
    --container-mounts=/scratch:/scratch \
    --output="$RUN_DIR/decode-%t.out" \
    --error="$RUN_DIR/decode-%t.err" \
    bash -lc '

        set -Eeuo pipefail

        idx=${SLURM_LOCALID:?}

        port=$((30200 + idx))

        export HOME="/tmp/bracu-decode-${idx}"
        export XDG_CACHE_HOME="$HOME/.cache"
        export PYTHONUNBUFFERED=1

        mkdir -p "$XDG_CACHE_HOME"

        echo "=== DECODE ${idx} ==="
        date -u
        hostname

        echo "SLURM_PROCID=${SLURM_PROCID:-unset}"
        echo "SLURM_LOCALID=${SLURM_LOCALID:-unset}"
        echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
        echo "UCX_NET_DEVICES=${UCX_NET_DEVICES:-unset}"
        echo "PORT=$port"

        nvidia-smi -L

        visible=$(
            python3 -c "
import torch
print(torch.cuda.device_count())
"
        )

        echo "torch.cuda.device_count=$visible"

        if [[ "$visible" -ne 4 ]]; then
            echo "ERROR: Decode worker expected exactly 4 visible GPUs"
            exit 43
        fi


        exec python3 -m sglang.launch_server \
            --model-path "$MODEL" \
            --served-model-name qwen \
            --trust-remote-code \
            --context-length 8192 \
            --tp-size 4 \
            --mem-fraction-static 0.90 \
            --disaggregation-mode decode \
            --disaggregation-transfer-backend nixl \
            --ep-size 4 \
            --max-running-requests 256 \
            --host 0.0.0.0 \
            --port "$port"
    ' &

DECODE_STEP_PID=$!

echo "DECODE_STEP_PID=$DECODE_STEP_PID"


# ============================================================
# WORKER HEALTH
#
# Shared 600-second worker startup budget.
#
# The official notes mention a 600-second health-check
# timeout budget per endpoint. Because Firmus jobs have a
# 17-minute maximum, this reconstruction uses one shared
# 600-second deadline for the six simultaneously started
# workers.
# ============================================================

echo
echo "=== WAIT FOR ALL SIX WORKERS ==="

WORKER_DEADLINE=$((SECONDS + 600))


for spec in \
    "prefill-0|http://${HEAD_IP}:30100|$PREFILL_STEP_PID" \
    "prefill-1|http://${HEAD_IP}:30101|$PREFILL_STEP_PID" \
    "prefill-2|http://${HEAD_IP}:30102|$PREFILL_STEP_PID" \
    "prefill-3|http://${HEAD_IP}:30103|$PREFILL_STEP_PID" \
    "decode-0|http://${TAIL_IP}:30200|$DECODE_STEP_PID" \
    "decode-1|http://${TAIL_IP}:30201|$DECODE_STEP_PID"
do

    IFS='|' read -r label url step_pid <<<"$spec"

    if ! wait_health_until \
        "$label" \
        "$url" \
        "$step_pid" \
        "$WORKER_DEADLINE"
    then
        dump_worker_logs
        exit 50
    fi

done


echo
echo "=== ALL WORKERS HEALTHY ==="


# ============================================================
# ROUTER
# ============================================================

echo
echo "=== START ROUTER ==="

srun \
    --nodes=1 \
    --nodelist="$HEAD_NODE" \
    --ntasks=1 \
    --cpus-per-task=8 \
    --mem=32G \
    --gres=none \
    --exact \
    --kill-on-bad-exit=1 \
    --export=ALL,HEAD_IP="$HEAD_IP",TAIL_IP="$TAIL_IP" \
    --container-image="$SGLANG_IMAGE" \
    --container-mounts=/scratch:/scratch \
    --output="$RUN_DIR/router.out" \
    --error="$RUN_DIR/router.err" \
    bash -lc '

        set -Eeuo pipefail

        export HOME=/tmp/bracu-router
        export XDG_CACHE_HOME="$HOME/.cache"
        export PYTHONUNBUFFERED=1

        mkdir -p "$XDG_CACHE_HOME"

        exec python3 -m sglang_router.launch_router \
            --pd-disaggregation \
            --prefill "http://${HEAD_IP}:30100" 9000 \
            --prefill "http://${HEAD_IP}:30101" 9001 \
            --prefill "http://${HEAD_IP}:30102" 9002 \
            --prefill "http://${HEAD_IP}:30103" 9003 \
            --decode "http://${TAIL_IP}:30200" \
            --decode "http://${TAIL_IP}:30201" \
            --host 0.0.0.0 \
            --port 8000
    ' &

ROUTER_STEP_PID=$!

echo "ROUTER_STEP_PID=$ROUTER_STEP_PID"


ROUTER_DEADLINE=$((SECONDS + 120))

if ! wait_health_until \
    "router" \
    "http://${HEAD_IP}:8000" \
    "$ROUTER_STEP_PID" \
    "$ROUTER_DEADLINE"
then

    echo "=== ROUTER OUT ==="
    tail -n 120 "$RUN_DIR/router.out" 2>/dev/null || true

    echo "=== ROUTER ERR ==="
    tail -n 120 "$RUN_DIR/router.err" 2>/dev/null || true

    dump_worker_logs

    exit 60
fi


# ============================================================
# FUNCTIONAL GATEWAY VALIDATION
#
# This is NOT the official AIPerf benchmark.
# It is only the first 235B P/D functional baseline.
# ============================================================

echo
echo "=== /v1/models THROUGH ROUTER ==="

curl -fsS \
    --max-time 10 \
    "http://${HEAD_IP}:8000/v1/models" \
    | tee "$RUN_DIR/v1-models.json"

echo


echo
echo "=== NETWORK WARM-UP (PREVENT COLD START STALL) ==="
# Best-effort connection warm-up before AIPerf.
# This does not prove every possible P/D connection has been exercised.
for i in {1..16}; do
    curl -fsS -N --max-time 10 -X POST "http://${HEAD_IP}:8000/v1/chat/completions" \
        -H 'Content-Type: application/json' -H 'Accept: text/event-stream' \
        -d '{"model": "qwen", "messages": [{"role": "user", "content": "hello"}], "max_tokens": 10, "stream": true}' > /dev/null 2>&1 || true
done
echo "Warm-up complete."

echo
echo "=== AIPERF BENCHMARK (VANILLA BASELINE) ==="
srun \
    --nodes=1 \
    --nodelist="$HEAD_NODE" \
    --ntasks=1 \
    --cpus-per-task=8 \
    --mem=32G \
    --gres=none \
    --exact \
    --container-image="$AIPERF_IMAGE" \
    --container-mounts="/scratch:/scratch,${RUN_DIR}:/results" \
    bash -lc "
        export HOME=/tmp
        export XDG_CACHE_HOME=/tmp/.cache
        cd /results

        aiperf profile \
          --url 'http://${HEAD_IP}:8000' \
          --endpoint-type chat \
          --endpoint /v1/chat/completions \
          --model qwen \
          --tokenizer '$MODEL' \
          --streaming \
          -H 'Accept: text/event-stream' \
          --concurrency 16 \
          --workers-max 16 \
          --api-key NOT_USED \
          --warmup-duration 15 \
          --benchmark-duration 20 \
          --benchmark-grace-period 30 \
          --synthetic-input-tokens-mean 4000 \
          --synthetic-input-tokens-stddev 0 \
          --output-tokens-mean 200 \
          --output-tokens-stddev 0 \
          --extra-inputs min_tokens:200 \
          --extra-inputs max_tokens:200 \
          --extra-inputs ignore_eos:true \
          --extra-inputs temperature:0.0 \
          --extra-inputs repetition_penalty:1.0 \
          --num-dataset-entries 12800 \
          --random-seed 2026 \
          --cache-bust first_turn_prefix \
          --goodput 'time_to_first_token:3000 inter_token_latency:20' \
          --ui simple
    " | tee "$RUN_DIR/aiperf-results.txt"

echo "AIPERF_COMPLETE" > "$RUN_DIR/STATUS"
echo
echo "=== AIPERF RUN COMPLETE ==="
echo "Artifacts: $RUN_DIR"
