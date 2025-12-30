#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# RESOLVE PATHS
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# -------------------------------
# Load pod configuration
# -------------------------------
ENV_FILE="$PROJECT_ROOT/config/pod.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ pod.env not found → $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

# -------------------------------
# PATCH 1: backward-compatible REMOTE path
# -------------------------------
if [[ -z "${REMOTE_DIR:-}" ]]; then
  if [[ -z "${REMOTE_OUTPUT_FILE:-}" ]]; then
    echo "❌ Missing REMOTE_DIR and REMOTE_OUTPUT_FILE in pod.env"
    exit 1
  fi
  REMOTE_DIR="$REMOTE_OUTPUT_FILE"
fi

# -------------------------------
# PATCH 2: backward-compatible LOCAL path
# -------------------------------
if [[ -z "${LOCAL_PATH:-}" ]]; then
  if [[ -n "${LOCAL_OUTPUT_PATH:-}" ]]; then
    LOCAL_PATH="$LOCAL_OUTPUT_PATH"
  else
    # sensible default, no behavior change
    LOCAL_PATH="outputs/outputs.tar.gz"
  fi
fi

# -------------------------------
# Validation (UNCHANGED)
# -------------------------------
: "${POD_USER:?Missing POD_USER}"
: "${POD_HOST:?Missing POD_HOST}"
: "${POD_PORT:?Missing POD_PORT}"
: "${SSH_KEY:?Missing SSH_KEY}"
: "${REMOTE_DIR:?Missing REMOTE_DIR}"
: "${LOCAL_PATH:?Missing LOCAL_PATH}"

SSH_KEY_EXPANDED="$(eval echo "$SSH_KEY")"

if [[ ! -f "$SSH_KEY_EXPANDED" ]]; then
  echo "❌ SSH key not found → $SSH_KEY_EXPANDED"
  exit 1
fi

# -------------------------------
# Resolve LOCAL_PATH relative to PROJECT_ROOT
# -------------------------------
LOCAL_ABS_PATH="$PROJECT_ROOT/$LOCAL_PATH"

# Ensure destination directory exists
mkdir -p "$(dirname "$LOCAL_ABS_PATH")"

# -------------------------------
# Download
# -------------------------------
echo "============================================================"
echo "📥 Downloading from pod"
echo "Host  : $POD_USER@$POD_HOST:$POD_PORT"
echo "Remote: $REMOTE_DIR"
echo "Local : $LOCAL_ABS_PATH"
echo "============================================================"

scp \
  -i "$SSH_KEY_EXPANDED" \
  -P "$POD_PORT" \
  "$POD_USER@$POD_HOST:$REMOTE_DIR" \
  "$LOCAL_ABS_PATH"

echo "============================================================"
echo "✅ Download complete"
echo "============================================================"
