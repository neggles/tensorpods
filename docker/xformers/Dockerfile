# syntax=docker/dockerfile:1
# Path: base/Dockerfile

# Default upstream image for when not using buildx
ARG BASE_IMAGE="nvcr.io/nvidia/pytorch:23.07-py3"

# settings for apt and pip (inheritable by all images)
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_PRIORITY=critical
ARG PIP_PREFER_BINARY=1

# Build xformers
FROM ${BASE_IMAGE} as builder

# Set shell
SHELL ["/bin/bash", "-ceuxo", "pipefail"]

# Inherit args from global
ARG DEBIAN_FRONTEND
ARG DEBIAN_PRIORITY
ARG PIP_PREFER_BINARY

# build options
ARG TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9;9.0"
ARG MAX_JOBS=32

# make pip STFU about being root
ENV PIP_ROOT_USER_ACTION=ignore
ENV _PIP_LOCATIONS_NO_WARN_ON_MISMATCH=1

# torch architecture list for from-source builds
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}

# working dir
WORKDIR /workspace

# get build deps such as they are
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade \
    pip \
    setuptools \
    wheel

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade \
    cmake \
    ninja \
    build \
    packaging \
    twine

# clone repo and change dir
ARG XFORMERS_REPO=https://github.com/facebookresearch/xformers.git
ARG XFORMERS_REF=main
RUN git clone --recursive --shallow-submodules --single-branch \
    --branch "${XFORMERS_REF}" "${XFORMERS_REPO}" "xformers"
WORKDIR /workspace/xformers

# calculate version
RUN export BUILD_VERSION=$(python3 packaging/compute_wheel_version.py)
ENV BUILD_VERSION=${BUILD_VERSION}

# build xformers and output to /xformers for later extraction
ENV MAX_JOBS=${MAX_JOBS}
RUN rm -fr /xformers \
    && mkdir -p /xformers \
    && nice -n20 python3 setup.py bdist_wheel \
        -d /xformers \
        -k

# Build the final image (empty save for xformers wheel)
FROM scratch AS xformers
COPY --from=builder /xformers /xformers
