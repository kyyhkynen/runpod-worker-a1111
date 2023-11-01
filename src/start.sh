#!/bin/bash

echo "WebUI Initiated"

if [[ ! -z "$START_WEBUI" ]]; then
    
    echo "Starting WebUI"
    python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /model.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --cors-allow-origins "*" --skip-version-check  --no-hashing --no-download-sd-model

else

    echo "Starting WebUI API"
    python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /model.safetensors --lowram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-download-sd-model &

    echo "Starting RunPod Handler"
    python -u /rp_handler.py

fi