#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# RESOLVE PROJECT ROOT
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================================
# TIMESTAMP
# ============================================================
ts() { date +"%Y-%m-%d %H:%M:%S"; }

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
for var in POD_HOST POD_PORT POD_USER SSH_KEY; do
  if [[ -z "${!var:-}" ]]; then
    echo "❌ ERROR: $var not set in pod.env"
    exit 1
  fi
done

SSH_KEY_EXPANDED="$(eval echo "$SSH_KEY")"

if [[ ! -f "$SSH_KEY_EXPANDED" ]]; then
  echo "❌ ERROR: SSH key not found → $SSH_KEY_EXPANDED"
  exit 1
fi

# ============================================================
# SCP (LOG + EXECUTE)
# ============================================================
LOCAL_FILE="${PROJECT_ROOT}/scripts/pod_run/03_untar_pod_project.sh"
REMOTE_DIR="/workspace"

if [[ ! -f "$LOCAL_FILE" ]]; then
  echo "❌ ERROR: File not found → $LOCAL_FILE"
  exit 1
fi

SCP_CMD=(
  scp
  -i "$SSH_KEY_EXPANDED"
  -P "$POD_PORT"
  "$LOCAL_FILE"
  "$POD_USER@$POD_HOST:$REMOTE_DIR/"
)

echo "============================================================"
echo "📤 [$(ts)] Executing SCP command:"
echo "👉 ${SCP_CMD[*]}"
echo "============================================================"

"${SCP_CMD[@]}"

echo "✅ [$(ts)] SCP upload completed"
