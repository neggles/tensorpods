# syntax=docker/dockerfile:1
# Path: base/Dockerfile

# Default upstream image for when not using buildx
ARG BASE_IMAGE=nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# settings for apt and pip (inheritable by all images)
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
ARG PIP_PREFER_BINARY=1
ARG TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9;9.0"

# Build the base image.
FROM ${BASE_IMAGE} as base

# Set shell
SHELL ["/bin/bash", "-ceuxo", "pipefail"]

# Inherit args from global
ARG DEBIAN_FRONTEND
ARG DEBIAN_PRIORITY
ARG PIP_PREFER_BINARY
ARG TORCH_CUDA_ARCH_LIST

# make pip STFU about being root
ENV PIP_ROOT_USER_ACTION=ignore
ENV _PIP_LOCATIONS_NO_WARN_ON_MISMATCH=1

# torch architecture list for from-source builds
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}

# Removing legacy /usr/local/nvidia paths (see https://gitlab.com/nvidia/container-images/cuda/-/issues/47 )
ENV PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib:/usr/local/cuda/lib64

# add CUDA apt repo pin
COPY cuda-repo-pin.conf /etc/apt/preferences.d/cuda-container-pin-900

# set up apt to cache packages and not auto-upgrade
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
    && echo 'APT::Get::Upgrade "false";' > /etc/apt/apt.conf.d/upgrade-false

# Install base dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
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
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
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
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
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
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
  && apt-get -y install --no-install-recommends \
    libcudnn8-dev=$(dpkg-query --showformat='${Version}' --show libcudnn8) \
  && apt-get clean

# Install TensorRT libraries
ARG INCLUDE_TRT=1
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
  && if [ "${INCLUDE_TRT:-}" == "1" ]; then  \
    apt-get -y install --no-install-recommends \
        libnvinfer-dev \
        python3-libnvinfer-dev \
    ; fi \
  && apt-get clean

# Install other CUDA libraries
ARG CUDA_RELEASE
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update \
  && apt-get -y install --no-install-recommends \
    cuda-compiler-${CUDA_RELEASE} \
    libgl1 \
    libgl-dev \
    libglx-dev \
  && apt-get clean

# upgrade pip
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade \
    pip \
    wheel

# add the nVidia python index
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    python -m pip install nvidia-pyindex

# Install PyTorch
ARG TORCH_INDEX
ARG TORCH_VERSION
ARG EXTRA_PIP_ARGS
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    python -m pip install ${EXTRA_PIP_ARGS:-} \
      --extra-index-url ${TORCH_INDEX} \
      "${TORCH_VERSION:-torch}" \
      torchaudio \
      torchvision

# Install xformers
ARG XFORMERS_VERSION
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    python -m pip install ${EXTRA_PIP_ARGS} "${XFORMERS_VERSION}"

# we do a little entrypoint setup
CMD ["/bin/bash", "-l"]

# Specific required versions for everything else will be installed in their respective images
# since this stuff tends to be pretty picky about versioning.
