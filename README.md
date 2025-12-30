# image => nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

# start command

bash -c '
set -e

cat << "EOF" > /workspace/startup.sh
#!/usr/bin/env bash
set -e

LOG="/workspace/startup.log"
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo "🚀 RunPod Bootstrap Starting"
echo "============================================================"

# ---------------- SYSTEM ----------------
apt-get update -y
apt-get install -y \
  openssh-server \
  ffmpeg \
  ca-certificates \
  libglib2.0-0 \
  libgl1 \
  curl \
  git \
  python3 \
  python3-pip \
  python3-venv

# Make python -> python3
ln -sf /usr/bin/python3 /usr/bin/python

# ---------------- SSH ----------------
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKGNu1YN1FEKOsgHeb6t0uwEiN0igFlBYZM//CBVdvpp sachin.arpit@gmail.com" >> /root/.ssh/authorized_keys

sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config

service ssh restart

# ---------------- PYTHON ----------------
python -m pip install --upgrade pip

pip install -U \
  torch \
  numpy \
  pydub \
  faster-whisper \
  ctranslate2 \
  requests

# ---------------- GPU CHECK ----------------
python - << PYEOF
import torch
assert torch.cuda.is_available()
assert torch.backends.cudnn.is_available()
print("CUDA + cuDNN OK")
PYEOF

echo "============================================================"
echo "✅ Bootstrap complete"
echo "============================================================"

tail -f /dev/null
EOF

chmod +x /workspace/startup.sh
bash /workspace/startup.sh
'

# then run
 cd /workspace

  chmod +x runpod_health_check.sh run_transcription.sh

  ./runpod_health_check.sh

  ./run_transcription.sh


# it will fail with this error in transcription step
2025-12-30 07:58:46,881 | INFO | ▶ Clip 1/46 | clip_000.wav | start=0.0s | dur=16.1s 2025-12-30 07:58:46,881 | INFO | 🧠 GPU inference started 2025-12-30 07:58:47,025 | INFO | Processing audio with duration 00:16.114 Unable to load any of {libcudnn_ops.so.9.1.0, libcudnn_ops.so.9.1, libcudnn_ops.so.9, libcudnn_ops.so} Invalid handle. Cannot load symbol cudnnCreateTensorDescriptor ./run_transcription.sh: line 33: 10232 Aborted (core dumped) python 02_transcribe_clips.py root@f6b65dbe0c81:/workspace#

# then do below
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

# Expected O/P
ctranslate2: 4.3.x
torch CUDA: True
GPU: NVIDIA RTX 3090

# Run
./run_transcription.sh

tar -czvf outputs.tar.gz -C /workspace outputs

scp -i ~/.ssh/id_ed25519 -P 40175 root@213.192.2.106:/workspace/outputs.tar.gz .

==========
