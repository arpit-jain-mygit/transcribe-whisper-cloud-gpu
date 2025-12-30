#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# TIMESTAMP
# ============================================================
ts() { date +"%Y-%m-%d %H:%M:%S"; }

# ============================================================
# RESOLVE PATHS (ROBUST)
# This script lives in: scripts/pod_run/
# Project root = ../..
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SRC_DIR="$PROJECT_ROOT/src"
POD_SCRIPTS_DIR="$PROJECT_ROOT/scripts/pod_run"

SEGMENT_SCRIPT="$SRC_DIR/01_segment_audio.py"
TRANSCRIBE_SCRIPT="$SRC_DIR/02_transcribe_clips.py"
POSTPROCESS_SCRIPT="$SRC_DIR/03_postprocess_rules.py"
COMPRESS_SCRIPT="$POD_SCRIPTS_DIR/08_compress_output_pod.sh"

echo "============================================================"
echo "🎙️ Whisper Transcription Pipeline"
echo "Started at : $(ts)"
echo "Project    : $PROJECT_ROOT"
echo "============================================================"

# ------------------------------------------------------------
# STEP 1 — SEGMENTATION
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 1/4: Audio segmentation started"
START=$(date +%s)

python "$SEGMENT_SCRIPT"

END=$(date +%s)
echo "[$(ts)] ✅ STEP 1 completed in $((END - START)) sec"

# ------------------------------------------------------------
# STEP 2 — TRANSCRIPTION
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 2/4: Transcription started (this can take time)"
START=$(date +%s)

python "$TRANSCRIBE_SCRIPT"

END=$(date +%s)
echo "[$(ts)] ✅ STEP 2 completed in $((END - START)) sec"

# ------------------------------------------------------------
# STEP 3 — POST-PROCESSING
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 3/4: Rule-based post-processing started"
START=$(date +%s)

python "$POSTPROCESS_SCRIPT"

END=$(date +%s)
echo "[$(ts)] ✅ STEP 3 completed in $((END - START)) sec"

# ------------------------------------------------------------
# STEP 4 — COMPRESS OUTPUTS
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 4/4: Compressing outputs"
START=$(date +%s)

chmod +x "$COMPRESS_SCRIPT"
"$COMPRESS_SCRIPT"

END=$(date +%s)
echo "[$(ts)] ✅ STEP 4 completed in $((END - START)) sec"
echo "[$(ts)] 📦 outputs.tar.gz created"


# ------------------------------------------------------------
# DONE
# ------------------------------------------------------------
echo ""
echo "============================================================"
echo "✅ PIPELINE COMPLETE"
echo "Finished at : $(ts)"
echo ""
echo "📁 outputs/"
echo "   - raw_transcript.json"
echo "   - refined_transcript.json"
echo "   - raw_vs_refined.diff.txt"
echo "📦 Archive:"
echo "   - outputs.tar.gz"
echo "============================================================"
