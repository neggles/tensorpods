# docker-bake.hcl for tensorpod builds
group "default" {
  targets = ["xformers"]
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
  default = "23.05"
}

variable "XFORMERS_REPO" {
  default = "https://github.com/facebookresearch/xformers.git"
}

variable "XFORMERS_REF" {
  default = "v0.0.20"
}

variable "TORCH_CUDA_ARCH_LIST" {
  # sorry pascal users but your cards are no good here
  default = "7.0;7.5;8.0;8.6;8.9;9.0"
}

variable "MAX_JOBS" {
  default = ""
}

function "imagetag" {
  params = [imagename, tag]
  result = "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:${tag}-ngc${NGC_VERSION}"
}

# docker-metadata-action will populate this in GitHub Actions
target "docker-metadata-action" {}

target "common" {
  contexts = {
    ngc = "docker-image://nvcr.io/nvidia/pytorch:${NGC_VERSION}-py3"
  }
  tags = [
    "${imagetag("xformers", "latest")}",
    "${imagetag("xformers", "${XFORMERS_REF}")}",
  ]
  platforms = ["linux/amd64"]
  output = [
    "type=docker",
  ]
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
