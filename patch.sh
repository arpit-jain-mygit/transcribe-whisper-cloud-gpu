#!/usr/bin/env bash
set -e

#--Added for testing---
pip uninstall -y ctranslate2

pip uninstall -y faster-whisper


pip install -U \
  torch \
  numpy \
  pydub \
  faster-whisper \
  "ctranslate2<4.4.0" \
  requests

  python - <<'EOF'
import ctranslate2
import torch

print("ctranslate2:", ctranslate2.__version__)
print("torch CUDA:", torch.cuda.is_available())
print("GPU:", torch.cuda.get_device_name(0))
EOF
#------