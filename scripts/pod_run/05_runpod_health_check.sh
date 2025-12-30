#!/usr/bin/env bash
set -e

echo "============================================================"
echo "🩺 RunPod Whisper GPU Health Check (FINAL STABLE)"
echo "============================================================"

WORKDIR="/workspace"
TEST_AUDIO="215.wav"
cd "$WORKDIR"

# ---------------- GPU INFO ----------------
command -v nvidia-smi >/dev/null || { echo "❌ nvidia-smi missing"; exit 1; }
nvidia-smi
echo "ℹ️ Driver CUDA version is informational only"

# ---------------- Python deps ----------------
python -m pip install --upgrade pip

python -m pip uninstall -y \
  torch \
  ctranslate2 \
  faster-whisper \
  pydub \
  numpy || true

python -m pip install --no-cache-dir \
  torch \
  ctranslate2 \
  faster-whisper \
  pydub \
  numpy

# ---------------- Python CUDA check ----------------
python - << 'EOF'
import torch
print("CUDA available:", torch.cuda.is_available())
print("Torch CUDA:", torch.version.cuda)
print("GPU:", torch.cuda.get_device_name(0))
print("cuDNN:", torch.backends.cudnn.version())
assert torch.cuda.is_available()
assert torch.backends.cudnn.is_available()
EOF

# ---------------- Whisper load ----------------
python - << 'EOF'
from faster_whisper import WhisperModel
WhisperModel("large-v3", device="cuda", compute_type="float16")
print("✅ Whisper model loaded on GPU")
EOF

# ---------------- Real inference ----------------
if [ -f "$TEST_AUDIO" ]; then
python - << EOF
from faster_whisper import WhisperModel
m = WhisperModel("large-v3", device="cuda", compute_type="float16")
segs, _ = m.transcribe("$TEST_AUDIO", language="hi")
segs = list(segs)
print("Segments:", len(segs))
assert len(segs) > 0
print("✅ REAL GPU INFERENCE OK")
EOF
fi


echo "============================================================"
echo "✅ HEALTH CHECK PASSED"
echo "============================================================"