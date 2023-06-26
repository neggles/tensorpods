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

function "imagetag" {
  params = [imagename, tag]
  result = "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:${tag}-ngc${NGC_VERSION}"
}

# docker-metadata-action will populate this in GitHub Actions
target "docker-metadata-action" {}

target "common" {
  dockerfile = "Dockerfile"
  context    = "."
  contexts = {
    ngc = "docker-image://nvcr.io/nvidia/pytorch:${NGC_VERSION}-py3"
  }
  tags = [
    "${imagetag("xformers", "latest")}",
    "${imagetag("xformers", "${XFORMERS_REF}")}",
  ]
  args = {
    XFORMERS_REPO = XFORMERS_REPO
    XFORMERS_REF  = XFORMERS_REF
  }
  platforms = ["linux/amd64"]
  output = [
    "type=docker",
  ]
}

target "xformers" {
  inherits = ["common", "docker-metadata-action"]
  target   = "xformers"
}
