
# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 as download

# NOTE: CivitAI usually requires an API token, so you need to add it in the header
#       of the wget command if you're using a model from CivitAI.
# RUN apk add --no-cache wget && \
#     wget -q -O /model.safetensors https://huggingface.co/XpucT/Deliberate/resolve/main/Deliberate_v6.safetensors

ADD dreamshaper_8.safetensors /
ADD controlnetQRPatternQR_v1Sd15.safetensors /
ADD control_v11f1e_sd15_tile.pth /
ADD control_v1p_sd15_brightness.safetensors /

# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim as build_final_image

ARG A1111_RELEASE=v1.10.0
ARG CONTROLNET_RELEASE=v1.1.313

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN export COMMANDLINE_ARGS="--skip-torch-cuda-test --precision full --no-half"
RUN export TORCH_COMMAND='pip install ---no-cache-dir torch==2.1.2+cu118 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118'

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/cache --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    ${TORCH_COMMAND} && \
    pip install --no-cache-dir xformers==0.0.23.post1 --index-url https://download.pytorch.org/whl/cu118

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${A1111_RELEASE} && \
    cd extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet && \
    cd .. && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test && \
    cd ..

# COPY --from=download /model.safetensors /model.safetensors

COPY --from=download /dreamshaper_8.safetensors /stable-diffusion-webui/models/Stable-diffusion/dreamshaper_8.safetensors
COPY --from=download /controlnetQRPatternQR_v1Sd15.safetensors /stable-diffusion-webui/models/ControlNet/controlnetQRPatternQR_v1Sd15.safetensors
COPY --from=download /control_v11f1e_sd15_tile.pth /stable-diffusion-webui/models/ControlNet/control_v11f1e_sd15_tile.pth
COPY --from=download /control_v1p_sd15_brightness.safetensors /stable-diffusion-webui/models/ControlNet/control_v1p_sd15_brightness.safetensors

# Install RunPod SDK
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir runpod
    
# Install supabase
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir supabase

# Install pillow
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir pillow

ADD src .

COPY builder/cache.py /stable-diffusion-webui/cache.py
# RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /model.safetensors

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
