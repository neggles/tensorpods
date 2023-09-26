# docker-bake.hcl for tensorpod builds
group "default" {
  targets = ["xformers"]
}

variable "IMAGE_REGISTRY" {
  default = "ghcr.io"
}

variable IMAGE_NAMESPACE {
  default = "neggles/tensorpods"
}

variable TORCH_CUDA_ARCH_LIST {
  # sorry pascal users but your cards are no good here
  # n.b. in GH builds volta is not available due to compile timeouts
  default = "7.0;7.5;8.0;8.6;8.9;9.0"
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
  params          = [cudaVer, cudaType]
  variadic_params = extraVals
  result = join(":", [
    "nvidia/cuda",
    join("-", [cudaVer], extraVals, [cudaType, "ubuntu22.04"])
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
  result = regex_replace(version, "^(\\d+)\\.(\\d+)\\.(\\d+).*", "torch$1$2$3")
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

target "xformers" {
  name     = stripName("xformers-${xformers.version}-${base.type}${base.version}")
  inherits = ["common", "docker-metadata-action"]
  context  = "docker/xformers"
  target   = "xformers"
  contexts = {
    base-ngc   = "docker-image://nvcr.io/nvidia/pytorch:${base.version}-py3"
    base-torch = "docker-image://${repoImage("base", cudaName(base.cuda), base.type, base.version)}"
  }
  matrix = {
    base = [
      {
        type    = "ngc"
        version = "23.08"
        cuda    = "12.2.1"
      },
      {
        type    = "ngc"
        version = "23.07"
        cuda    = "12.1.1"
      },
    ],
    xformers = [
      {
        version   = "v0.0.21",
        repo      = "https://github.com/neggles/xformers.git"
        ref       = "tensorpods-v0.0.21"
        buildtype = "release"
      },
      {
        version   = "dev"
        repo      = "https://github.com/neggles/xformers.git"
        ref       = "tensorpods"
        buildtype = "release"
      }
    ]
  }
  args = {
    BASE_IMAGE = "base-${base.type}"

    XFORMERS_REPO       = xformers.repo
    XFORMERS_REF        = xformers.ref
    XFORMERS_BUILD_TYPE = xformers.buildtype
  }
}

target local {
  inherits = ["xformers-v0021-ngc2308"]
  tags = [
    repoImage("xformers", "v0.0.21", "ngc23.08")
  ]
}
