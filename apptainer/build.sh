#!/bin/bash
# Build Apptainer SIF images from the existing Docker images.
#
# Prerequisites:
#   - Docker with the images already built (make build-dev and/or make build-casa)
#   - Apptainer installed and on PATH
#
# Output:
#   apptainer/pipeline-dev.sif   — development environment (Ubuntu 24.04 + Pixi)
#   apptainer/runtime.sif        — CASA runtime environment (AlmaLinux 8 + CASA)
#
# Typical usage (build both, then rsync to HPC):
#   ./apptainer/build.sh --all
#   rsync -av apptainer/*.sif hpc-host:~/alma/apptainer/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

DEV_IMAGE="pipeline-dev"
CASA_IMAGE="pipeline-casa"
DEV_SIF="${SCRIPT_DIR}/pipeline-dev.sif"
CASA_SIF="${SCRIPT_DIR}/pipeline-casa.sif"

BUILD_DEV=false
BUILD_CASA=false

usage() {
    echo "Usage: $0 [--dev] [--casa] [--all]"
    echo "  --dev    Build the dev SIF image (pipeline-dev)"
    echo "  --casa   Build the CASA runtime SIF image (pipeline-casa)"
    echo "  --all    Build both"
    exit 1
}

[ $# -eq 0 ] && usage

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)  BUILD_DEV=true ;;
        --casa) BUILD_CASA=true ;;
        --all)  BUILD_DEV=true; BUILD_CASA=true ;;
        *)      usage ;;
    esac
    shift
done

# --- dependency checks -------------------------------------------------------

if ! command -v apptainer &>/dev/null; then
    echo "Error: apptainer is not installed or not on PATH." >&2
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "Error: docker is not installed or not on PATH." >&2
    exit 1
fi

# --- helper ------------------------------------------------------------------

build_sif() {
    local docker_image="$1"
    local sif_path="$2"

    if ! docker image inspect "${docker_image}" &>/dev/null; then
        echo "Error: Docker image '${docker_image}' not found." >&2
        echo "       Build it first with 'make build-dev' or 'make build-casa'." >&2
        exit 1
    fi

    echo "Building ${sif_path} from docker-daemon://${docker_image} ..."
    apptainer build --force "${sif_path}" "docker-daemon://${docker_image}"
    echo "Done: ${sif_path}"
}

# --- build -------------------------------------------------------------------

if $BUILD_DEV; then
    build_sif "${DEV_IMAGE}" "${DEV_SIF}"
fi

if $BUILD_CASA; then
    build_sif "${CASA_IMAGE}" "${CASA_SIF}"
fi

echo
echo "SIF files are in ${SCRIPT_DIR}/"
echo "Transfer them to your HPC system before running apptainer/run-dev.sh or apptainer/run-casa.sh."
