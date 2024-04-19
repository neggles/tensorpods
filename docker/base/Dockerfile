# syntax=docker/dockerfile:1

# Default upstream image for when not using buildx
ARG BASE_IMAGE=nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# settings for apt and pip (inheritable by all images)
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
ARG PIP_PREFER_BINARY=1
ARG TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0+PTX"

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
ARG INCLUDE_TRT='false'
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
  && if [ "${INCLUDE_TRT}" == "true" ]; then  \
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

# upgrade pip/wheel but don't upgrade setuptools; avoids issues with Ubuntu-provided module
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    pip install --upgrade pip wheel

# add the nVidia python index package
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    python -m pip install nvidia-pyindex

# Install PyTorch
ARG TORCH_INDEX
ARG TORCH_PACKAGE="torch"
ARG EXTRA_PIP_ARGS=" "
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    python -m pip install ${EXTRA_PIP_ARGS:-} \
      "${TORCH_PACKAGE}" \
      triton \
      torchaudio \
      torchvision \
      --index-url "${TORCH_INDEX}"

# save and enforce a constraint file to lock the torch version
RUN echo "Creating pip constraint at /etc/pip/constraints.txt to lock PyTorch module versions..." \
    && mkdir -p /etc/pip \
    && python -m pip freeze | grep -E '(^torch|triton|xformers)' | tee /etc/pip/constraints.txt \
    && echo "Adding constraint file to config in /etc/pip.conf" \
    && echo -e "[global]\nconstraint = /etc/pip/constraints.txt" | tee /etc/pip.conf
ENV PIP_CONSTRAINT=/etc/pip/constraint.txt

# do a little entrypoint setup
WORKDIR /workspace
CMD ["/bin/bash", "-l"]


# can use this target if there's a prebuilt wheel available for this torch version
FROM base as xformers-binary

# Install xformers
ARG XFORMERS_PACKAGE="xformers"
ARG XFORMERS_PIP_ARGS=""
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    python -m pip install ${XFORMERS_PIP_ARGS} "${XFORMERS_PACKAGE}" \
    || python -m pip install --pre ${XFORMERS_PIP_ARGS} "${XFORMERS_PACKAGE}"

# or if xformers has to be compiled; flash attention 2 makes this impossible
# on a public github actions runner without limiting yourself to only a handful of architectures
FROM base AS xformers-builder

# acquire global args
ARG MAX_JOBS=1
ARG NVCC_THREADS=1
ARG TORCH_CUDA_ARCH_LIST

# Set them as environment variables
ENV MAX_JOBS=${MAX_JOBS}
ENV NVCC_THREADS=${NVCC_THREADS}
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}


# clone repo and change dir
ARG XFORMERS_REPO=https://github.com/facebookresearch/xformers.git
ARG XFORMERS_REF=main
RUN git clone --recursive --shallow-submodules --single-branch \
    --branch "${XFORMERS_REF}" "${XFORMERS_REPO}" "xformers"
WORKDIR /workspace/xformers

# calculate version
RUN export BUILD_VERSION=$(python packaging/compute_wheel_version.py)
ENV BUILD_VERSION=${BUILD_VERSION}

# build xformers and output to /xformers for later extraction
ARG XFORMERS_BUILD_TYPE=Release
ENV XFORMERS_BUILD_TYPE=${XFORMERS_BUILD_TYPE}
RUN rm -fr /xformers && mkdir -p /xformers \
    && nice -n15 python setup.py bdist_wheel -d /xformers

# test install wheel
RUN python -m pip install --no-cache /xformers/*.whl

# wheel-only image
FROM scratch AS xformers-wheel
COPY --from=xformers-builder /xformers/*.whl /xformers/


# Final image using xformers built from source
FROM base AS xformers-source

# install the wheel we just built
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,from=xformers-wheel,source=/xformers,target=/xformers \
    python -m pip install /xformers/*.whl

# fin.
