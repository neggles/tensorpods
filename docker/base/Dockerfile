# syntax=docker/dockerfile:1
# Path: base/Dockerfile

# Default upstream image for when not using buildx
ARG BASE_IMAGE=nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# settings for apt and pip (inheritable by all images)
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
ARG PIP_PREFER_BINARY=1

# Build the base image.
FROM ${BASE_IMAGE} as base

# Set shell
SHELL ["/bin/bash", "-ceuxo", "pipefail"]

# Inherit args from global
ARG DEBIAN_FRONTEND
ARG DEBIAN_PRIORITY
ARG PIP_PREFER_BINARY

# make pip STFU about being root
ENV PIP_ROOT_USER_ACTION=ignore

# Removing legacy /usr/local/nvidia paths (see https://gitlab.com/nvidia/container-images/cuda/-/issues/47 )
ENV PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib:/usr/local/cuda/lib64

# add CUDA apt repo pin
COPY cuda-repo-pin.conf /etc/apt/preferences.d/cuda-container-pin-900

# Install base dependencies
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
  && apt-get -y install --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    wget \
    git \
    gnupg2 \
    nano \
    netbase \
    pkg-config \
    procps \
    rsync \
    unzip \
  && apt-get clean

# Add build tools etc.
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
  && apt-get -y install --no-install-recommends \
    build-essential \
    jq \
    dialog \
    fonts-dejavu-core \
    moreutils \
    libgoogle-perftools-dev \
    cmake \
    ninja-build \
    bison \
    flex \
  && apt-get clean

# Install python 3.10
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
  && apt-get -y install --no-install-recommends \
    python-is-python3 \
    'python3-dev=3.10*' \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-distutils \
    python3-venv\
  && apt-get clean

# Install CUDNN dev package to match existing binary package
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
  && apt-get -y install --no-install-recommends \
    libcudnn8-dev=$(dpkg-query --showformat='${Version}' --show libcudnn8) \
  && apt-get clean

# Install TensorRT libraries
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
  && apt-get -y install --no-install-recommends \
    libnvinfer-dev \
    python3-libnvinfer-dev \
  && apt-get clean

# Install PyTorch
ARG TORCH_INDEX
ARG TORCH_VERSION
ARG EXTRA_PIP_ARGS
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install ${EXTRA_PIP_ARGS} \
      --extra-index-url ${TORCH_INDEX} \
      "${TORCH_VERSION:-torch}" \
      torchaudio \
      torchvision

# Install Triton, xformers, bitsandbytes
ARG XFORMERS_VERSION
ARG BNB_VERSION
ARG TRITON_VERSION
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-deps \
      "${TRITON_VERSION}" \
      "${BNB_VERSION}" \
      "${XFORMERS_VERSION}"

# we do a little entrypoint setup
CMD ["/bin/bash", "-l"]

# Specific required versions for everything else will be installed in their respective images
# since this stuff tends to be pretty picky about versioning.
