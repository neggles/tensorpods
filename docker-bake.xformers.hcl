# docker-bake.hcl for tensorpod builds
group "default" {
  targets = ["base"]
}

variable "IMAGE_REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAMESPACE" {
  default = "neggles/tensorpods"
}

variable "IMAGE_NAME" {
  default = "xformers"
}

variable "NGC_VERSION" {
  default = "23.08"
}

variable "XFORMERS_REPO" {
  default = "https://github.com/neggles/xformers.git"
}

variable "XFORMERS_REF" {
  default = "tensorpods"
}

variable "TORCH_CUDA_ARCH_LIST" {
  # sorry pascal users but your cards are no good here
  default = "7.0;7.5;8.0;8.6;8.9;9.0"
}

variable "MAX_JOBS" {
  default = "1"
}

function "imagetag" {
  params = [imagename, tag]
  result = "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${imagename}:${tag}-ngc${NGC_VERSION}"
}

# docker-metadata-action will populate this in GitHub Actions
target "docker-metadata-action" {}

# Shared amongst all containers
target "common" {
  context = "."
  contexts = {
    ngc = "docker-image://nvcr.io/nvidia/pytorch:${NGC_VERSION}-py3"
  }
  args = {
    XFORMERS_IMAGE = "xformers"
    BASE_IMAGE     = "ngc"
  }
  platforms = ["linux/amd64"]
}

target "xformers" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "docker/xformers"
  dockerfile = "Dockerfile"
  target     = "xformers"
  args = {
    XFORMERS_REPO        = XFORMERS_REPO
    XFORMERS_REF         = XFORMERS_REF
    TORCH_CUDA_ARCH_LIST = TORCH_CUDA_ARCH_LIST
    MAX_JOBS             = MAX_JOBS
  }
}
