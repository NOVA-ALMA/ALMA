#!/bin/bash
# Run the pipeline CASA runtime environment using Apptainer.
#
# Replicates the docker compose casa service: bind mounts, working directory,
# environment variables, and the xvfb-run framebuffer required by CASA tools.
#
# Usage:
#   ./apptainer/run-casa.sh              # open an interactive shell
#   ./apptainer/run-casa.sh python3 -m pytest pipeline/tests/regression/fast/ --nologfile -vv
#
# Prerequisites:
#   - apptainer/pipeline-casa.sif must exist (build with ./apptainer/build.sh --casa)
#   - docker/data/ must be populated (run ./docker/download.sh --data first)
#   - pipeline-testdata/ is required for regression tests; mounted only if present
#   - raw/ is optional; mounted only if present

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CASA_SIF="${SCRIPT_DIR}/pipeline-casa.sif"

# Source the canonical CASA version so PATH is set correctly.
# shellcheck source=../docker/casa/version.env
. "${ROOT_DIR}/docker/casa/version.env"

# --- preflight checks --------------------------------------------------------

if [ ! -f "${CASA_SIF}" ]; then
    echo "Error: ${CASA_SIF} not found." >&2
    echo "       Build it first with: ./apptainer/build.sh --casa" >&2
    exit 1
fi

for required in \
    "${ROOT_DIR}/pipeline" \
    "${ROOT_DIR}/.git/modules/pipeline" \
    "${ROOT_DIR}/docker/data" \
    "${ROOT_DIR}/docker/casa/startup.py"
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
# container's /root/.casa/config.py is never read.
#
# We write an Apptainer-specific config pointing measurespath at
# $HOME/.casa/data, then bind docker/data there.  Because $HOME is owned by
# the running user, casatools' ownership check always passes.

mkdir -p "${HOME}/.casa"
APPTAINER_CASA_CONFIG="${SCRIPT_DIR}/.casa-config.py"
cat > "${APPTAINER_CASA_CONFIG}" <<EOF
measurespath = "${HOME}/.casa/data"
measures_auto_update = False
data_auto_update = False
datapath = ["${HOME}/.casa/data", "/casa/pipeline-testdata"]
EOF
CASA_CONFIG_BIND="${APPTAINER_CASA_CONFIG}:${HOME}/.casa/config.py"

# --- git safe.directory ------------------------------------------------------
#
# On HPC, git uses $HOME/.gitconfig (the real home), not the container's
# /root/.gitconfig.  We write a minimal gitconfig and point GIT_CONFIG_GLOBAL
# at it so that git can operate on the bind-mounted source.

GITCONFIG_FILE="${SCRIPT_DIR}/.gitconfig-casa"
cat > "${GITCONFIG_FILE}" <<'EOF'
[safe]
    directory = /casa/pipeline
EOF

# --- optional mounts ---------------------------------------------------------

OPTIONAL_BINDS=()
if [ -d "${ROOT_DIR}/raw" ]; then
    OPTIONAL_BINDS+=("--bind" "${ROOT_DIR}/raw:/casa/raw")
fi
if [ -d "${ROOT_DIR}/pipeline-testdata" ]; then
    OPTIONAL_BINDS+=("--bind" "${ROOT_DIR}/pipeline-testdata:/casa/pipeline-testdata")
fi

# --- run ---------------------------------------------------------------------
#
# Apptainer does not honour the Docker ENTRYPOINT, so we invoke xvfb-run
# explicitly to provide the virtual framebuffer that CASA tools (e.g. plotms)
# require.

if [ $# -eq 0 ]; then
    # Interactive shell.
    INNER_CMD="exec bash -i"
else
    INNER_CMD="$(printf '%q ' "$@")"
fi

exec apptainer exec \
    --env "PATH=/casa/casa-${CASA_VERSION}/bin:/casa/casa-${CASA_VERSION}/lib/py/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    --env "QT_QPA_PLATFORM=offscreen" \
    --env "LIBGL_ALWAYS_SOFTWARE=1" \
    --env "GIT_CONFIG_GLOBAL=${GITCONFIG_FILE}" \
    --bind "${ROOT_DIR}/pipeline:/casa/pipeline" \
    --bind "${ROOT_DIR}/.git/modules/pipeline:/casa/.git/modules/pipeline:ro" \
    --bind "${ROOT_DIR}/docker/data:${HOME}/.casa/data" \
    --bind "${CASA_CONFIG_BIND}" \
    --bind "${ROOT_DIR}/docker/casa/startup.py:${HOME}/.casa/startup.py" \
    --bind "${ROOT_DIR}:${ROOT_DIR}" \
    "${OPTIONAL_BINDS[@]+"${OPTIONAL_BINDS[@]}"}" \
    --pwd "${ROOT_DIR}" \
    "${CASA_SIF}" \
    bash -c "xvfb-run --auto-servernum ${INNER_CMD}"