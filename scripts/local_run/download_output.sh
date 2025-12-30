#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Load pod configuration
# -------------------------------
ENV_FILE="./config/pod.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ pod.env not found"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

# -------------------------------
# Validation
# -------------------------------
: "${POD_USER:?Missing POD_USER}"
: "${POD_HOST:?Missing POD_HOST}"
: "${POD_PORT:?Missing POD_PORT}"
: "${SSH_KEY:?Missing POD_KEY}"
: "${REMOTE_DIR:?Missing REMOTE_DIR}"
: "${LOCAL_PATH:?Missing LOCAL_PATH}"

# Expand ~ in key path
SSH_KEY_EXPANDED=$(eval echo "$SSH_KEY")

# -------------------------------
# Download
# -------------------------------
echo "📥 Downloading from pod..."
echo "➡ ${POD_USER}@${POD_HOST}:${REMOTE_DIR}"

scp \
  -i "$SSH_KEY_EXPANDED" \
  -P "$POD_PORT" \
  "${POD_USER}@${POD_HOST}:${REMOTE_DIR}" \
  "$LOCAL_PATH"

echo "✅ Download complete"
