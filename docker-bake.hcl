# docker-bake.hcl for tensorpod builds
group "default" {
  targets = ["cuda11"]
}

group "cuda11" {
  targets = ["base-cu118"]
}

group "cuda12" {
  targets = ["base-cu121"]
}

group "edge" {
  targets = ["base-edge"]
}

variable "IMAGE_REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAMESPACE" {
  default = "neggles/tensorpods"
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
  contexts = {
    cuda-11-8 = "docker-image://nvidia/cuda:${cudatag("11.8.0", "devel", "cudnn8")}"
    cuda-12-1 = "docker-image://nvidia/cuda:${cudatag("12.1.1", "devel", "cudnn8")}"
  }
  args = {
    XFORMERS_VERSION = "xformers>=0.0.20"
    BNB_VERSION      = "bitsandbytes>=0.39.0"
  }
  platforms = ["linux/amd64"]
  output = [
    "type=docker",
  ]
}


target "matrix" {
  name       = "base-${item.variant}"
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/base"
  dockerfile = "Dockerfile"
  target     = "base"
  matrix = {
    item = [
      {
        # python3.10 cuda 11.8 torch 2.0.1+cu118
        variant     = "cu118"
        baseContext = "cuda-11-8"

        pipArgs       = " "
        torchIndex    = "https://download.pytorch.org/whl/cu118"
        torchVersion  = "torch==2.0.1+cu118"
        tritonVersion = "triton"
      },
      {
        # python3.10 cuda 12.1 torch 2.0.1+cu118
        variant     = "cu121"
        baseContext = "cuda-12-1"

        pipArgs       = " "
        torchIndex    = "https://download.pytorch.org/whl/cu118"
        torchVersion  = "torch==2.0.1+cu118"
        tritonVersion = "triton"
      },
      {
        # python3.10 cuda 12.1 torch 2.1 nightly
        variant     = "edge"
        baseContext = "cuda-12-1"

        pipArgs       = "--pre"
        torchIndex    = "https://download.pytorch.org/whl/nightly/cu121"
        torchVersion  = "torch"
        tritonVersion = "git+https://github.com/openai/triton.git#subdirectory=python"
      }
    ]
  }
  tags = [
    "${imagetag("base", item.variant)}"
  ]
  args = {
    BASE_IMAGE = item.baseContext

    EXTRA_PIP_ARGS = item.pipArgs
    TORCH_INDEX    = item.torchIndex
    TORCH_VERSION  = item.torchVersion
    TRITON_VERSION = item.tritonVersion
  }
}
