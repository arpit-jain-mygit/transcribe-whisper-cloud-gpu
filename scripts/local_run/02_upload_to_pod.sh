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
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

ARCHIVE_NAME="${PROJECT_NAME}.tar.gz"
ARCHIVE_PATH="${PROJECT_ROOT}/${ARCHIVE_NAME}"

# ============================================================
# EXCLUDES (MAC SAFE)
# ============================================================
EXCLUDES=(
  ".git"
  ".idea"
  "__pycache__"
  "*.pyc"
  "*.tar.gz"
  ".DS_Store"
  "._*"
)

# ============================================================
# LOAD POD CONFIG
# ============================================================
ENV_FILE="${PROJECT_ROOT}/config/pod.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ pod.env not found → $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

# ============================================================
# VALIDATION
# ============================================================
for var in POD_HOST POD_PORT POD_USER SSH_KEY REMOTE_DIR; do
  if [[ -z "${!var:-}" ]]; then
    echo "❌ $var not set in pod.env"
    exit 1
  fi
done

SSH_KEY_EXPANDED="$(eval echo "$SSH_KEY")"

if [[ ! -f "$SSH_KEY_EXPANDED" ]]; then
  echo "❌ SSH key not found → $SSH_KEY_EXPANDED"
  exit 1
fi

# ============================================================
# CREATE TAR
# ============================================================
echo "============================================================"
echo "📦 [$(ts)] Creating archive"
echo "Project : $PROJECT_NAME"
echo "Root    : $PROJECT_ROOT"
echo "Archive : $ARCHIVE_PATH"
echo "============================================================"

TAR_EXCLUDES=()
for e in "${EXCLUDES[@]}"; do
  TAR_EXCLUDES+=( "--exclude=${e}" )
done

tar \
  --disable-copyfile \
  --no-xattrs \
  -czf "$ARCHIVE_PATH" \
  -C "$(dirname "$PROJECT_ROOT")" \
  "${TAR_EXCLUDES[@]}" \
  "$PROJECT_NAME"

echo "✅ [$(ts)] Archive created"

# ============================================================
# UPLOAD (LOGGED)
# ============================================================
echo "============================================================"
echo "📤 [$(ts)] Uploading to RunPod"
echo "Host : $POD_HOST"
echo "Port : $POD_PORT"
echo "User : $POD_USER"
echo "Dest : $REMOTE_DIR"
echo "============================================================"

SCP_CMD="scp -i \"$SSH_KEY_EXPANDED\" -P \"$POD_PORT\" \"$ARCHIVE_PATH\" \"$POD_USER@$POD_HOST:$REMOTE_DIR/\""

echo "🔍 [$(ts)] Executing SCP command:"
echo "    $SCP_CMD"

eval "$SCP_CMD"

echo "============================================================"
echo "✅ [$(ts)] Upload complete"
echo "============================================================"

# ============================================================
# NEXT STEPS
# ============================================================
echo ""
echo "🚀 NEXT STEPS (inside pod):"
echo "------------------------------------------------------------"
echo "cd $REMOTE_DIR"
echo "chmod +x scripts/pod_run/*.sh"
echo "./scripts/pod_run/03_untar_pod_project.sh"
echo "./scripts/pod_run/04_make_executable_pod.sh"
echo "./scripts/pod_run/05_runpod_health_check.sh"
echo "./scripts/pod_run/06_patch_pod.sh"
echo "./scripts/pod_run/07_run_transcription_pod.sh"
echo "./scripts/pod_run/08_compress_output_pod.sh"
echo "------------------------------------------------------------"
