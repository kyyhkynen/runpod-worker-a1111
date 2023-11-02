# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.36.2 as download

COPY builder/clone.sh /clone.sh

# Clone the repos and clean unnecessary files
RUN . /clone.sh repositories taming-transformers https://github.com/CompVis/taming-transformers.git 24268930bf1dce879235a7fddd0b2355b84d7ea6 && \
    rm -rf data assets **/*.ipynb

RUN . /clone.sh repositories stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git 47b6b607fdd31875c9279cd2f4f16b92e4ea958e && \
    rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN . /clone.sh repositories CodeFormer https://github.com/sczhou/CodeFormer.git c5b4593074ba6214284d6acd5f1719b6c5d739af && \
    rm -rf assets inputs

RUN . /clone.sh repositories BLIP https://github.com/salesforce/BLIP.git 48211a1594f1321b00f14c9f7a5b4813144b2fb9 && \
    . /clone.sh repositories k-diffusion https://github.com/crowsonkb/k-diffusion.git 5b3af030dd83e0297272d861c19477735d0317ec && \
    . /clone.sh repositories clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 2486589f24165c8e3b303f84e9dbbea318df83e8 && \
    . /clone.sh repositories generative-models https://github.com/Stability-AI/generative-models 45c443b316737a4ab6e40413d7794a7f5657c19f

RUN . /clone.sh extensions clip-interrogator-ext https://github.com/pharmapsychotic/clip-interrogator-ext 0f1a4591f82b93859a1b854afb79494f39384662 && \
    . /clone.sh extensions ultimate-upscale-for-automatic1111 https://github.com/Coyote-A/ultimate-upscale-for-automatic1111 728ffcec7fa69c83b9e653bf5b96932acdce750f && \
    . /clone.sh extensions sd-webui-controlnet https://github.com/Mikubill/sd-webui-controlnet 7a4805c8ea3256a0eab3512280bd4f84ca0c8182

RUN mkdir -p models

# copy local models instead of downloading
#RUN apk add --no-cache wget && \
#    wget --progress=dot:giga -O /model.safetensors https://huggingface.co/XpucT/Deliberate/resolve/main/Deliberate_v3.safetensors
#    wget --progress=dot:giga -O models/ControlNet/control_v11p_sd15_lineart_fp16.safetensors https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_lineart_fp16.safetensors
#    wget --progress=dot:giga -O models/ControlNet/control_scribble-fp16.safetensors https://huggingface.co/webui/ControlNet-modules-safetensors/resolve/main/control_scribble-fp16.safetensors
#    wget --progress=dot:giga -O models/ControlNet/control_canny-fp16.safetensors https://huggingface.co/webui/ControlNet-modules-safetensors/resolve/main/control_canny-fp16.safetensors
#    wget --progress=dot:giga -O models/ControlNet/annotators/lineart/sk_model.pth https://huggingface.co/lllyasviel/Annotators/resolve/main/sk_model.pth
#    wget --progress=dot:giga -O models/ESRGAN/ESRGAN_4x.pth https://github.com/cszn/KAIR/releases/download/v1.0/ESRGAN.pth


COPY models/deliberate_v3.safetensors /model.safetensors
COPY models/control_v11p_sd15_lineart_fp16.safetensors /models/ControlNet/control_v11p_sd15_lineart_fp16.safetensors
COPY models/control_canny-fp16.safetensors /models/ControlNet/control_canny-fp16.safetensors
COPY models/control_scribble-fp16.safetensors /models/ControlNet/control_scribble-fp16.safetensors
COPY models/sk_model.pth /models/ControlNet/annotators/lineart/sk_model.pth
COPY models/ESRGAN.pth /models/ESRGAN/ESRGAN_4x.pth
COPY models/model_base_caption_capfilt_large.pth /models/BLIP/model_base_caption_capfilt_large.pth



# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.9-slim

# webui version
ARG SHA=5ef669de080814067961f28357256e8fe27544f4

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    LD_PRELOAD=libtcmalloc.so \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev procps nginx && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/cache --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${SHA} && \
    pip install -r requirements_versions.txt

COPY --from=download /repositories/ ${ROOT}/repositories/
COPY --from=download /model.safetensors /model.safetensors
RUN mkdir ${ROOT}/interrogate && cp ${ROOT}/repositories/clip-interrogator/data/* ${ROOT}/interrogate
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

COPY --from=download /extensions/ ${ROOT}/extensions/
COPY --from=download /models/ ${ROOT}/models/
COPY --from=download /models/ControlNet/annotators/lineart/ ${ROOT}/extensions/sd-webui-controlnet/annotator/downloads/lineart/
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r ${ROOT}/extensions/sd-webui-controlnet/requirements.txt && \
    pip install clip-interrogator==0.6.0

# Install Python dependencies (Worker Template)
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

ADD src .

COPY builder/cache.py /stable-diffusion-webui/cache.py
RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /model.safetensors --no-half

# NGINX Proxy
COPY nginx.conf /etc/nginx/nginx.conf

# Cleanup section (Worker Template)
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /start.sh
CMD /start.sh
