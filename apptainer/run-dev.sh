#!/bin/bash
# Run the pipeline dev environment using Apptainer.
#
# Replicates the docker compose dev service: bind mounts, working directory,
# environment variables, and the startup pip install for version detection.
#
# Usage:
#   ./apptainer/run-dev.sh              # open an interactive shell
#   ./apptainer/run-dev.sh pytest pipeline/pipeline/ --nologfile -q
#
# Prerequisites:
#   - apptainer/pipeline-dev.sif must exist (build with ./apptainer/build.sh --dev)
#   - docker/data/ must be populated (run ./docker/download.sh --data first)
#   - pipeline-testdata/ and raw/ are optional; mounted only if present

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEV_SIF="${SCRIPT_DIR}/pipeline-dev.sif"

# --- preflight checks --------------------------------------------------------

if [ ! -f "${DEV_SIF}" ]; then
    echo "Error: ${DEV_SIF} not found." >&2
    echo "       Build it first with: ./apptainer/build.sh --dev" >&2
    exit 1
fi

for required in \
    "${ROOT_DIR}/pipeline" \
    "${ROOT_DIR}/.git/modules/pipeline" \
    "${ROOT_DIR}/docker/data" \
    "${ROOT_DIR}/docker/dev/config.py"
do
    if [ ! -e "${required}" ]; then
        echo "Error: required path not found: ${required}" >&2
        exit 1
    fi
done

# --- CASA config -------------------------------------------------------------
#
# casatools reads config from $HOME/.casa/config.py.  On HPC, $HOME is the
# user's real home directory (bind-mounted by Apptainer by default), so the
# container's /home/pipeline/.casa/config.py is never read.
#
# We bind our dev config.py over $HOME/.casa/config.py instead.  The config
# points measurespath at /home/pipeline/.casa/data, where we bind the data.
# That path is in the container's own filesystem (not home), so it is always
# owned by the user running the process and passes casatools' ownership check.

mkdir -p "${HOME}/.casa"
CASA_CONFIG_BIND="${ROOT_DIR}/docker/dev/config.py:${HOME}/.casa/config.py"

# --- git safe.directory ------------------------------------------------------
#
# The image bakes a safe.directory entry into /home/pipeline/.gitconfig, but
# on HPC git uses $HOME/.gitconfig (the real home), so it is not read.
# We write a minimal gitconfig and point GIT_CONFIG_GLOBAL at it.
# (Unlike HOME, GIT_CONFIG_GLOBAL is not restricted by HPC Apptainer policy.)

GITCONFIG_FILE="${SCRIPT_DIR}/.gitconfig"
cat > "${GITCONFIG_FILE}" <<'EOF'
[safe]
    directory = /home/pipeline/pipeline
EOF

# --- optional mounts ---------------------------------------------------------

OPTIONAL_BINDS=()
if [ -d "${ROOT_DIR}/raw" ]; then
    OPTIONAL_BINDS+=("--bind" "${ROOT_DIR}/raw:/home/pipeline/raw")
fi
if [ -d "${ROOT_DIR}/pipeline-testdata" ]; then
    OPTIONAL_BINDS+=("--bind" "${ROOT_DIR}/pipeline-testdata:/home/pipeline/pipeline-testdata")
fi

# --- run ---------------------------------------------------------------------

if [ $# -eq 0 ]; then
    # Interactive shell.
    # Do NOT use --login: it would source /etc/profile and reset PATH.
    INNER_CMD="exec bash -i"
else
    INNER_CMD="$(printf '%q ' "$@")"
fi

exec apptainer exec \
    --env "PATH=/opt/conda/envs/pipeline/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    --env "CONDA_PREFIX=/opt/conda/envs/pipeline" \
    --env "CONDA_DEFAULT_ENV=pipeline" \
    --env "GIT_CONFIG_GLOBAL=${GITCONFIG_FILE}" \
    --bind "${ROOT_DIR}/pipeline:/home/pipeline/pipeline" \
    --bind "${ROOT_DIR}/.git/modules/pipeline:/home/pipeline/.git/modules/pipeline:ro" \
    --bind "${ROOT_DIR}/docker/data:/home/pipeline/.casa/data" \
    --bind "${CASA_CONFIG_BIND}" \
    "${OPTIONAL_BINDS[@]+"${OPTIONAL_BINDS[@]}"}" \
    --pwd /home/pipeline \
    "${DEV_SIF}" \
    bash -c "${INNER_CMD}"