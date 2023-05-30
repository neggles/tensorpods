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
  params = [version, type, cudnn]
  result = notequal("false", cudnn) ? "${version}-${cudnn}-${type}-ubuntu22.04" : "${version}-${type}-ubuntu22.04"
}

function "cudarelease" {
  params = [version]
  result = regex_replace(version, "^(\\d+)\\.(\\d).*", "$1-$2")
}

variable "TORCH_VERSION" {
  default = "torch==2.0.1+cu118"
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
    cuda-11-8 = "docker-image://${CUDA_BASE_IMAGE}:${cudatag("11.8.0", "devel", "cudnn8")}"
    cuda-12-1 = "docker-image://${CUDA_BASE_IMAGE}:${cudatag("12.1.1", "devel", "cudnn8")}"
  }
  args = {
    CUDA_REPO_URL = "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/"
    CUDA_REPO_KEY = "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub"

    TORCH_INDEX      = TORCH_INDEX
    TORCH_VERSION    = TORCH_VERSION
    XFORMERS_VERSION = "xformers==0.0.18"
    BNB_VERSION      = "bitsandbytes==0.38.1"
    TRITON_VERSION   = "triton~=2.0.0"
  }
  platforms = ["linux/amd64"]
  output = [
    "type=docker",
  ]
}

# python3.10 cuda 12.1 torch 2.0.1+cu118
target "base" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/base"
  dockerfile = "Dockerfile"
  target     = "base"
  tags = [
    "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/base:latest",
    "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/base:latest-cu121"
  ]
  args = {
    BASE_IMAGE   = "cuda-12-1"
    CUDA_VERSION = CUDA_VERSION
    CUDA_RELEASE = cudarelease(CUDA_VERSION)

    TORCH_INDEX   = "https://download.pytorch.org/whl/cu118"
    TORCH_VERSION = TORCH_VERSION
  }
}

# python3.10 cuda12.1 torch nightly (2.1.0)
target "base-edge" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/base"
  dockerfile = "Dockerfile"
  target     = "base"
  tags = [
    "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/base:edge",
    "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/base:edge-cu121"
  ]
  args = {
    BASE_IMAGE   = "cuda-12-1"
    CUDA_VERSION = "12.1.1"
    CUDA_RELEASE = cudarelease(CUDA_VERSION)

    EXTRA_PIP_ARGS = "--pre"
    TORCH_INDEX    = "https://download.pytorch.org/whl/nightly/cu121"
    TORCH_VERSION  = "torch"
    TRITON_VERSION = "git+https://github.com/openai/triton.git#subdirectory=python"
  }
}

# py3.10 cuda 11.8 torch 2.0.1+cu118
target "base-cu118" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/base"
  dockerfile = "Dockerfile"
  target     = "base"
  tags = [
    "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/base:latest-cu118"
  ]
  args = {
    BASE_IMAGE   = "cuda-11-8"
    CUDA_VERSION = "11.8.0"
    CUDA_RELEASE = cudarelease(CUDA_VERSION)

    TORCH_INDEX   = "https://download.pytorch.org/whl/cu118"
    TORCH_VERSION = TORCH_VERSION
  }
}

# text-generation-webui images
target "textgen-webui" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/textgen-webui"
  dockerfile = "Dockerfile"
  target     = "webui"
  contexts = {
    base = "target:base-cu118"
  }
  tags = [
    "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/textgen-webui:latest"
  ]
  args = {
    WEBUI_REPO_URL = "https://github.com/oobabooga/text-generation-webui.git"
    WEBUI_REPO_REF = "main"

    GPTQ4L_REPO_URL = "https://github.com/qwopqwop200/GPTQ-for-LLaMa"
    GPTQ4L_REPO_REF = "05781593c818d4dc8adc2d32c975e83d17d2b9a8"

    TRANSFORMERS_VERSION = "git+https://github.com/huggingface/transformers.git@main"
    ACCELERATE_VERSION   = "accelerate==0.18.0"
    DATASETS_VERSION     = "datasets==2.12.0"
    SAFETENSORS_VERSION  = "safetensors==0.3.1"

    TORCH_CUDA_ARCH_LIST = "7.0 7.5 8.0 8.6+PTX"
  }
}

target "textgen-webui-edge" {
  inherits   = ["common", "docker-metadata-action"]
  context    = "./docker/textgen-webui"
  dockerfile = "Dockerfile"
  target     = "webui"
  contexts = {
    base = "target:base-edge"
  }
  tags = [
    "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/textgen-webui:edge"
  ]
  args = {
    WEBUI_REPO_URL = "https://github.com/oobabooga/text-generation-webui.git"
    WEBUI_REPO_REF = "0db4e191bd9e4e1024c3cb0872096890ed16df25"

    GPTQ4L_REPO_URL = "https://github.com/qwopqwop200/GPTQ-for-LLaMa"
    GPTQ4L_REPO_REF = "triton"

    TRANSFORMERS_VERSION = "git+https://github.com/huggingface/transformers.git@main"
    ACCELERATE_VERSION   = "accelerate==0.18.0"
    DATASETS_VERSION     = "datasets==2.12.0"
    SAFETENSORS_VERSION  = "safetensors==0.3.1"

    TORCH_CUDA_ARCH_LIST = "7.0 7.5 8.0 8.6+PTX"
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
