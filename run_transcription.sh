#!/usr/bin/env bash
set -e

ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

echo "============================================================"
echo "🎙️ Whisper Transcription Pipeline"
echo "Started at: $(ts)"
echo "Working dir: $(pwd)"
echo "============================================================"

# ------------------------------------------------------------
# STEP 1 — SEGMENTATION
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 1/3: Audio segmentation started"
START=$(date +%s)

python 01_segment_audio.py

END=$(date +%s)
echo "[$(ts)] ✅ STEP 1 completed in $((END - START)) sec"

# ------------------------------------------------------------
# STEP 2 — TRANSCRIPTION
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 2/3: Transcription started (this can take time)"
START=$(date +%s)

python 02_transcribe_clips.py

END=$(date +%s)
echo "[$(ts)] ✅ STEP 2 completed in $((END - START)) sec"

# ------------------------------------------------------------
# STEP 3 — POST-PROCESSING
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 3/3: Rule-based post-processing started"
START=$(date +%s)

python 03_postprocess_rules.py

END=$(date +%s)
echo "[$(ts)] ✅ STEP 3 completed in $((END - START)) sec"

# ------------------------------------------------------------
# STEP 4 — COMPRESS OUTPUTS
# ------------------------------------------------------------
echo ""
echo "[$(ts)] ▶ STEP 4/4: Compressing outputs"
START=$(date +%s)

chmod +x compress_output.sh
./compress_output.sh

END=$(date +%s)
echo "[$(ts)] ✅ STEP 4 completed in $((END - START)) sec"
echo "[$(ts)] 📦 outputs.tar.gz created"

# ------------------------------------------------------------
# DONE
# ------------------------------------------------------------
echo ""
echo "============================================================"
echo "✅ PIPELINE COMPLETE"
echo "Finished at: $(ts)"
echo ""
echo "📁 outputs/"
echo "   - raw_transcript.json"
echo "   - refined_transcript.json"
echo "   - raw_vs_refined.diff.txt"
echo "📦 Archive:"
echo "   - outputs.tar.gz"
echo "============================================================"
