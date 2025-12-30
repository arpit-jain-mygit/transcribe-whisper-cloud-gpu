#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# TIMESTAMP
# ============================================================
ts() { date +"%Y-%m-%d %H:%M:%S"; }

# ============================================================
# RESOLVE PATHS
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================================
# LOAD POD CONFIG
# ============================================================
ENV_FILE="$PROJECT_ROOT/config/pod.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ pod.env not found → $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

# ============================================================
# VALIDATION
# ============================================================
for var in POD_HOST POD_PORT POD_USER SSH_KEY REMOTE_WORKDIR; do
  if [[ -z "${!var:-}" ]]; then
    echo "❌ ERROR: $var not set in pod.env"
    exit 1
  fi
done

SSH_KEY_EXPANDED="$(eval echo "$SSH_KEY")"

if [[ ! -f "$SSH_KEY_EXPANDED" ]]; then
  echo "❌ SSH key not found → $SSH_KEY_EXPANDED"
  exit 1
fi

# ============================================================
# START
# ============================================================
echo "============================================================"
echo "🚀 Whisper GPU Pipeline — FULL RUN"
echo "Started at : $(ts)"
echo "Project    : $PROJECT_ROOT"
echo "Pod        : $POD_USER@$POD_HOST:$POD_PORT"
echo "============================================================"

# ============================================================
# STEP 1 — TAR LOCAL PROJECT
# ============================================================
echo ""
echo "[$(ts)] ▶ STEP 1: Creating project archive"
cd "$SCRIPT_DIR"
./01-tar_local_project.sh
echo "[$(ts)] ✅ Archive created"

# ============================================================
# STEP 2 — UPLOAD TO POD
# ============================================================
echo ""
echo "[$(ts)] ▶ STEP 2: Uploading archive to pod"
./02_upload_to_pod.sh
echo "[$(ts)] ✅ Upload completed"

# ============================================================
# STEP 3 — SSH INTO POD & RUN PIPELINE
# ============================================================
echo ""
echo "[$(ts)] ▶ STEP 3: Connecting to pod and running pipeline"

ssh -i "$SSH_KEY_EXPANDED" -p "$POD_PORT" "$POD_USER@$POD_HOST" <<EOF
set -euo pipefail

echo "============================================================"
echo "🖥️  Inside POD"
echo "Host      : \$(hostname)"
echo "Working   : \$(pwd)"
echo "============================================================"

cd "$REMOTE_WORKDIR"

echo "📦 Untarring project..."
./03_untar_pod_project.sh

cd transcribe-whisper-cloud-gpu/scripts/pod_run

echo "🎙️ Running transcription pipeline..."
./07_run_transcription_pod.sh

echo "✅ Pipeline finished inside pod"
echo "============================================================"
exit
EOF

echo "[$(ts)] ✅ Pod execution complete"

# ============================================================
# STEP 4 — DOWNLOAD OUTPUTS
# ============================================================
echo ""
echo "[$(ts)] ▶ STEP 4: Downloading outputs from pod"
./09_download_output.sh
echo "[$(ts)] ✅ Outputs downloaded"

# ============================================================
# DONE
# ============================================================
echo ""
echo "============================================================"
echo "🎉 FULL PIPELINE COMPLETED SUCCESSFULLY"
echo "Finished at : $(ts)"
echo "============================================================"
