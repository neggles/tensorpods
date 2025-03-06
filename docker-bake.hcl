# docker-bake.hcl for tensorpod builds
group "default" {
  targets = ["local-torchrelease"]
}

group torchrc {
  targets = ["local-torchrc", "xformers-wheel"]
}

variable "IMAGE_REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAMESPACE" {
  default = "neggles/tensorpods"
}

variable TORCH_CUDA_ARCH_LIST {
  # sorry pascal users but your cards are no good here
  default = "8.0;8.6;8.9;9.0"
}

variable MAX_JOBS {
  default = "8"
}

variable "NVCC_THREADS" {
  default = "1"
}

# removes characters not valid in a target name, useful for other things too
function stripName {
  params = [name]
  result = regex_replace(name, "[^a-zA-Z0-9_-]+", "")
}

# convert a CUDA version number and container dev type etc. into an image URI
function cudaImage {
  params          = [cudaVer, cudaType, distro]
  variadic_params = extraVals
  result = join(":", [
    "nvidia/cuda",
    join("-", [cudaVer], extraVals, [cudaType, distro])
  ])
}

# convert a CUDA version number into a shortname (e.g. 11.2.1 -> cu112)
function cudaName {
  params = [version]
  result = regex_replace(version, "^(\\d+)\\.(\\d).*", "cu$1$2")
}

# convert a CUDA version number into a release number (e.g. 11.2.1 -> 11-2)
function cudaRelease {
  params = [version]
  result = regex_replace(version, "^(\\d+)\\.(\\d).*", "$1-$2")
}

# torch version to torch name
function torchName {
  params = [version]
  # this is cursed, but if i try to do torch$1$20 it will interpret "$2 0" as $20
  result = join("", [regex_replace(version, "^(\\d+)\\.(\\d+)\\.(\\d+).*", "torch$1$2"), "0"])
}
# torch version to torch name
function torchSpec {
  params = [version]
  result = regex_replace(version, "^(\\d+)\\.(\\d+)\\.(\\d+).*", "torch==$1.$2.$3")
}

# build a tag for an image from this repo
function repoImage {
  params          = [imageName]
  variadic_params = extraVals
  result = join(":", [
    join("/", [IMAGE_REGISTRY, IMAGE_NAMESPACE, imageName]),
    join("-", extraVals)
  ])
}

# cursed override for torch2.0.1 & CUDA 12, and torch2.1.0 & CUDA 11.8
function torchIndex {
  params = [index, version, cuda]
  result = (
    and(equal(version, "2.5.1"), equal(cuda, "12.4.1"))
    ? "https://pypi.org/simple"
    : "${index}/${cudaName(cuda)}"
  )
}

function cudnnTag {
  params = [cudaVersion]
  result = (
    and(split(".", cudaVersion)[0] >= 12, split(".", cudaVersion)[1] > 1)
    ? "cudnn"
    : "cudnn8"
  )
}

# set to "true" by github actions, used to disable auto-tag
variable "CI" { default = "" }

# docker-metadata-action will populate this in GitHub Actions
target "docker-metadata-action" {}

# Shared amongst all containers
target "common" {
  context    = "."
  dockerfile = "Dockerfile"
  args = {
    TORCH_CUDA_ARCH_LIST = TORCH_CUDA_ARCH_LIST
    MAX_JOBS             = MAX_JOBS
    NVCC_THREADS         = NVCC_THREADS
  }
  platforms = ["linux/amd64"]
  output = [
    "type=docker",
  ]
}

target "base" {
  name     = stripName("base-${cuda.name}-${torchName(torch.version)}")
  inherits = ["common", "docker-metadata-action"]
  context  = "docker/base"
  target   = equal(torch.xformers, "") ? "base" : "xformers-binary"
  contexts = {
    base-cuda = "docker-image://${cudaImage(cuda.version, "devel", cuda.distro, cudnnTag(cuda.version))}"
  }
  matrix = {
    torch = [
      {
        version  = "2.4.0"
        index    = "https://download.pytorch.org/whl"
        xformers = "xformers>=0.0.28"
      },
      {
        version  = "2.5.1"
        index    = "https://download.pytorch.org/whl"
        xformers = "xformers>=0.0.29.post1"
      },
      {
        version  = "2.6.0"
        index    = "https://download.pytorch.org/whl"
        xformers = "xformers>=0.0.29.post2"
      }
    ],
    cuda = [
      {
        name    = "cu121"
        version = "12.1.1"
        distro  = "ubuntu22.04"
      },
      {
        name    = "cu124"
        version = "12.4.1"
        distro  = "ubuntu22.04"
      },
      {
        name    = "cu126"
        version = "12.6.3"
        distro  = "ubuntu24.04"
      }
    ]
  }
  args = {
    BASE_IMAGE   = "base-cuda"
    CUDA_VERSION = cuda.version
    CUDA_RELEASE = cudaRelease(cuda.version)

    TORCH_INDEX      = torchIndex(torch.index, torch.version, cuda.version)
    TORCH_PACKAGE    = torchSpec(torch.version)
    XFORMERS_PACKAGE = torch.xformers
  }
}

target xformers-wheel {
  inherits = ["base-cu124-torch250"]
  target   = "xformers-wheel"
  tags = [
    repoImage("xformers", "v0.0.29.post1", cudaName("12.4.1"), torchName("2.5.1"))
  ]
  args = {
    XFORMERS_REPO = "https://github.com/neggles/xformers.git"
    XFORMERS_REF  = "tensorpods-v0.0.29.post1"
  }
}

target local-torchrelease {
  inherits = ["base-cu124-torch260"]
  target   = "xformers-binary"
  tags = [
    repoImage("base", cudaName("12.4.1"), torchName("2.6.0")),
    repoImage("base", "latest"),
  ]
  args = {}
}

target local-cu121 {
  inherits = ["base-cu121-torch250"]
  target   = "xformers-binary"
  tags = [
    repoImage("base", cudaName("12.1.1"), torchName("2.5.1")),
    repoImage("base", "latest"),
  ]
  args = {}
}
