#!/usr/bin/env bash
set -e

# ============================================================
# LOAD POD CONFIG
# ============================================================
ENV_FILE="./pod.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ ERROR: pod.env not found"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

# ============================================================
# VALIDATION
# ============================================================
for var in POD_HOST POD_PORT POD_USER SSH_KEY REMOTE_DIR; do
  if [ -z "${!var}" ]; then
    echo "❌ ERROR: $var not set in pod.env"
    exit 1
  fi
done

SSH_KEY_EXPANDED=$(eval echo "$SSH_KEY")

if [ ! -f "$SSH_KEY_EXPANDED" ]; then
  echo "❌ ERROR: SSH key not found → $SSH_KEY_EXPANDED"
  exit 1
fi

# ============================================================
# FILES TO UPLOAD
# ============================================================
FILES=(
  "215.wav"
  "01_segment_audio.py"
  "02_transcribe_clips.py"
  "03_postprocess_rules.py"
  "run_transcription.sh"
  "runpod_health_check.sh"
  "patch.sh"
)

# ============================================================
# START
# ============================================================
echo "============================================================"
echo "📤 Uploading files to RunPod"
echo "Host : $POD_HOST"
echo "Port : $POD_PORT"
echo "User : $POD_USER"
echo "Dest : $REMOTE_DIR"
echo "============================================================"

# -----------------------------
# CHECK FILES EXIST LOCALLY
# -----------------------------
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "❌ ERROR: Local file not found → $f"
    exit 1
  fi
done

echo "✅ All local files found"

# -----------------------------
# SCP UPLOAD
# -----------------------------
echo "📡 Uploading via SCP..."

scp -i "$SSH_KEY_EXPANDED" -P "$POD_PORT" \
  "${FILES[@]}" \
  "$POD_USER@$POD_HOST:$REMOTE_DIR/"

echo "============================================================"
echo "✅ Upload complete"
echo "============================================================"

echo "NEXT STEPS (inside pod):"
echo "  cd $REMOTE_DIR"
echo "  chmod +x runpod_health_check.sh patch.sh compress_output.sh download_output.sh run_transcription.sh"
echo "  ./runpod_health_check.sh"
echo "  ./patch.sh"
echo "  ./run_transcription.sh"
echo "  ./compress_output.sh"
echo "  ./download_output.sh"
