#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# TIMESTAMP
# ============================================================
ts() { date +"%Y-%m-%d %H:%M:%S"; }

ARCHIVE="transcribe-whisper-cloud-gpu.tar.gz"
DEST="/workspace"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "❌ Archive not found: $ARCHIVE"
  exit 1
fi

echo "============================================================"
echo "📂 [$(ts)] Extracting $ARCHIVE → $DEST"
echo "============================================================"

tar \
  --no-same-owner \
  --no-same-permissions \
  -xzf "$ARCHIVE" \
  -C "$DEST"

echo "============================================================"
echo "✅ [$(ts)] Extraction completed successfully"
echo "============================================================"
