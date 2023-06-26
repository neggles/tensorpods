# syntax=docker/dockerfile:1
# Path: ooba/Dockerfile

# settings for apt and pip (inheritable by all images)
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
ARG PIP_PREFER_BINARY=1

# Build the base image.
FROM base as webui

# Set shell
SHELL ["/bin/bash", "-ceuxo", "pipefail"]

# Inherit args from global
ARG DEBIAN_FRONTEND
ARG DEBIAN_PRIORITY
ARG PIP_PREFER_BINARY

# set up workdir
WORKDIR /work

# Clone main repository
ARG WEBUI_REPO_URL=https://github.com/oobabooga/text-generation-webui.git
ARG WEBUI_REPO_REF=origin/main
RUN git clone --depth=1 "${WEBUI_REPO_URL}" "textgen" \
  && cd "textgen" \
  && git fetch --depth=1 origin "${WEBUI_REPO_REF}" \
  && git reset --hard "${WEBUI_REPO_REF}" \
  && git submodule update --init --recursive

# Set it as workdir
WORKDIR /work/textgen

# Install python dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install -r requirements.txt \
    && python -m pip install \
        'protobuf<3.21.0' \
        huggingface-hub

# Clone updated GPTQ-4-Llama
ARG GPTQ4L_REPO_URL=https://github.com/qwopqwop200/GPTQ-for-LLaMa
ARG GPTQ4L_REPO_REF=triton
RUN mkdir -p repositories \
    && cd repositories \
    && git clone --depth=1 "${GPTQ4L_REPO_URL}" "GPTQ-for-LLaMa" \
    && cd "GPTQ-for-LLaMa" \
    && git fetch --depth=1 origin "${GPTQ4L_REPO_REF}" \
    && git reset --hard "${GPTQ4L_REPO_REF}" \
    && git submodule update --init --recursive

# make ExLLaMA available
ARG EXLLAMA_REPO_URL=https://github.com/turboderp/exllama
ARG EXLLAMA_REPO_REF=master
RUN mkdir -p repositories \
    && cd repositories \
    && git clone --depth=1 "${EXLLAMA_REPO_URL}" "exllama" \
    && cd "exllama" \
    && git fetch --depth=1 origin "${EXLLAMA_REPO_REF}" \
    && git reset --hard "${EXLLAMA_REPO_REF}" \
    && git submodule update --init --recursive

# Install GPTQ4L dependencies (manually)
ARG TRANSFORMERS_VERSION=transformers==4.28.1
ARG ACCELERATE_VERSION=accelerate==0.18.0
ARG DATASETS_VERSION=datasets==2.12.0
ARG SAFETENSORS_VERSION=safetensors==0.3.1
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install \
        "${SAFETENSORS_VERSION}" \
        "${DATASETS_VERSION}" \
        "${ACCELERATE_VERSION}" \
        "${TRANSFORMERS_VERSION}" \
        sentencepiece \
        texttable \
        ninja \
        numpy \
        toml

# force gradio upgrade
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install 'gradio>=3.28.3'
