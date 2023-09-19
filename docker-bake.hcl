# docker-bake.hcl for tensorpod builds
group "default" {
  targets = ["base-cu121-torch201", "base-cu121-torch210"]
}

group "all" {
  targets = ["base"]
}

group "cuda11" {
  targets = ["base-cu118-torch201", "base-cu118-torch210"]
}

group "cuda12" {
  targets = ["base-cu121-torch201", "base-cu121-torch210", "base-cu121-nightly"]
}

variable "IMAGE_REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAMESPACE" {
  default = "neggles/tensorpods"
}

variable "TORCH_CUDA_ARCH_LIST" {
  default = "7.0;7.5;8.0;8.6;8.9;9.0"
}

variable "XFORMERS_VERSION" {
  default = "xformers==0.0.21"
}

function "cudatag" {
  params = [version, type, cudnn]
  result = notequal("false", cudnn) ? "${version}-${cudnn}-${type}-ubuntu22.04" : "${version}-${type}-ubuntu22.04"
}

function "cudarelease" {
  params = [version]
  result = regex_replace(version, "^(\\d+)\\.(\\d).*", "$1-$2")
}

function "imagetag" {
  params = [imagename, tag]
  result = "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${imagename}:${tag}"
}

# docker-metadata-action will populate this in GitHub Actions
target "docker-metadata-action" {}

# Shared amongst all containers
target "common" {
  context = "."
  args = {
    TORCH_CUDA_ARCH_LIST = TORCH_CUDA_ARCH_LIST
    XFORMERS_VERSION     = XFORMERS_VERSION
  }
  platforms = ["linux/amd64"]
  output = [
    "type=docker",
  ]
}

target "base" {
  name     = "base-${item.variant}"
  inherits = ["common", "docker-metadata-action"]
  context  = "./docker/base"
  contexts = {
    cuda-base = "docker-image://nvidia/cuda:${cudatag(item.cudaVersion, "devel", "cudnn8")}"
  }
  dockerfile = "Dockerfile"
  target     = "base"
  matrix = {
    item = [
      ### CUDA 11.8 ###
      {
        # python3.10 cuda 11.8 torch 2.0.1+cu118
        variant     = "cu118-torch201"
        cudaVersion = "11.8.0"

        pipArgs         = " "
        torchIndex      = "https://download.pytorch.org/whl/cu118"
        torchVersion    = "torch"
        tritonVersion   = "triton"
        xformersVersion = XFORMERS_VERSION
      },
      {
        # python3.10 cuda 11.8 torch 2.1.0+cu118
        variant     = "cu118-torch210"
        cudaVersion = "11.8.0"

        pipArgs         = " "
        torchIndex      = "https://download.pytorch.org/whl/test/cu118"
        torchVersion    = "torch"
        tritonVersion   = "triton"
        xformersVersion = XFORMERS_VERSION
      },
      ### CUDA 12.1 ###
      {
        # python3.10 cuda 12.1 torch 2.0.1+cu118
        variant     = "cu121-torch201"
        cudaVersion = "12.1.1"

        pipArgs         = " "
        torchIndex      = "https://download.pytorch.org/whl/cu118"
        torchVersion    = "torch"
        tritonVersion   = "triton"
        xformersVersion = XFORMERS_VERSION
      },
      {
        # python3.10 cuda 12.1 torch 2.1.0+cu121
        variant     = "cu121-torch210"
        cudaVersion = "12.1.1"

        pipArgs         = " "
        torchIndex      = "https://download.pytorch.org/whl/test/cu121"
        torchVersion    = "torch"
        tritonVersion   = "triton"
        xformersVersion = XFORMERS_VERSION
      },
      {
        # python3.10 cuda 12.1 torch 2.2 nightly
        variant     = "cu121-nightly"
        cudaVersion = "12.1.1"

        pipArgs         = "--pre"
        torchIndex      = "https://download.pytorch.org/whl/nightly/cu121"
        torchVersion    = "torch"
        tritonVersion   = "git+https://github.com/openai/triton.git#subdirectory=python"
        xformersVersion = "xformers"
      }
    ]
  }
  tags = [
    "${imagetag("base", item.variant)}"
  ]
  args = {
    BASE_IMAGE   = "cuda-base"
    CUDA_VERSION = item.cudaVersion
    CUDA_RELEASE = "${cudarelease(item.cudaVersion)}"

    EXTRA_PIP_ARGS   = item.pipArgs
    TORCH_INDEX      = item.torchIndex
    TORCH_VERSION    = item.torchVersion
    TRITON_VERSION   = item.tritonVersion
    XFORMERS_VERSION = item.xformersVersion
  }
}
