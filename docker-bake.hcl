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

variable "CUDA_BASE_IMAGE" {
  default = "nvidia/cuda"
}

variable "CUDA_VERSION" {
  default = "12.1.1"
}

function "cudatag" {
  params = [type, cudnn]
  result = notequal("false", cudnn) ? "${CUDA_VERSION}-${cudnn}-${type}-ubuntu22.04" : "${CUDA_VERSION}-${type}-ubuntu22.04"
}

variable "CUDA_DEVEL_TAG" {
  default = cudatag("devel", "cudnn8")
}

variable "CUDA_RUNTIME_TAG" {
  default = cudatag("runtime", "cudnn8")
}

variable "CUDA_RELEASE" {
  default = regex_replace(CUDA_VERSION, "^(\\d+)\\.(\\d).*", "$1-$2")
}

variable "TORCH_VERSION" {
  default = "2.0.1+cu118"
}

variable "TORCH_INDEX" {
  default = "https://download.pytorch.org/whl/cu118"
}

# docker-metadata-action will populate this in GitHub Actions
target "docker-metadata-action" {}

# Shared amongst all containers
target "common" {
  context = "."
  contexts = {
    cuda-devel   = "docker-image://${CUDA_BASE_IMAGE}:${CUDA_DEVEL_TAG}"
    cuda-runtime = "docker-image://${CUDA_BASE_IMAGE}:${CUDA_RUNTIME_TAG}"
  }
  args = {
    CUDA_REPO_URL = "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/"
    CUDA_REPO_KEY = "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub"
    CUDA_VERSION  = CUDA_VERSION
    CUDA_RELEASE  = CUDA_RELEASE

    TORCH_INDEX      = TORCH_INDEX
    TORCH_VERSION    = TORCH_VERSION
    XFORMERS_VERSION = "0.0.18"
    BNB_VERSION      = "0.38.1"
    TRITON_VERSION   = "2.0.0.post1"
  }
  platforms = ["linux/amd64"]
  output = [
    "type=docker",
  ]
}

# python3.10 cuda images
target "base" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/base"
  dockerfile = "Dockerfile"
  target     = "base"
  tags       = ["${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/base:latest"]
  args = {
    BASE_IMAGE = "cuda-devel"
  }

}

# text-generation-webui images
target "textgen-webui" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/textgen-webui"
  dockerfile = "Dockerfile"
  target     = "webui"
  contexts = {
    base = "target:base"
  }
  tags = ["${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/textgen-webui:latest"]
  args = {
    WEBUI_REPO_URL = "https://github.com/oobabooga/text-generation-webui.git"
    WEBUI_REPO_REF = "56f6b7052a54b4a8442552ecf4105404684c7bd9"

    GPTQ4L_REPO_URL = "https://github.com/qwopqwop200/GPTQ-for-LLaMa"
    GPTQ4L_REPO_REF = "triton"

    TRANSFORMERS_VERSION = "git+https://github.com/huggingface/transformers.git@main"
    ACCELERATE_VERSION   = "0.18.0"
    DATASETS_VERSION     = "2.12.0"
    SAFETENSORS_VERSION  = "0.3.1"
  }

}

# saltshaker images
target "saltshaker" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/saltshaker"
  dockerfile = "saltshaker/Dockerfile"
  target     = "trainer"
  contexts = {
    base = "target:base"
  }
  tags = ["${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/saltshaker:latest"]
  args = {
    TRAINER_REPO_URL = "https://github.com/neggles/saltshaker.git"
    TRAINER_REPO_REF = "5e91e22fa7703ef964b8fca5e023d8c0403e9d7c"
  }
}
