# create POD using image => nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04 and refer start command from pod-start-command.txt 

# Commands from local
cd scripts/local_run

./01-tar_local_project.sh

./02_upload_to_pod.sh 

ssh root@213.192.2.85 -p 40070 -i ~/.ssh/id_ed25519

# Commands from POD
cd /workspace
./03_untar_pod_project.sh
cd transcribe-whisper-cloud-gpu/scripts/pod_run/
 ./07_run_transcription_pod.sh
 exit

# Commands from local
./09_download_output.sh
==========
