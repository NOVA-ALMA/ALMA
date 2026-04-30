# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG USER_NAME=pipeline
ARG USER_HOME=/home/${USER_NAME}
ARG PIXI_VERSION=latest

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIXI_HOME=/opt/pixi \
    PIXI_ENV_PREFIX=/opt/pixi/default-env \
    PYTHONNOUSERSITE=1 \
    DISPLAY=:0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y --no-install-recommends \
    bzip2 \
    curl \
    ca-certificates \
    git \
    less \
    xvfb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupmod -n "${USER_NAME}" ubuntu \
    && usermod -l "${USER_NAME}" -d "${USER_HOME}" -m ubuntu \
    && mkdir -p "${PIXI_HOME}" "${USER_HOME}/.casa/data" \
    && chown -R "${USER_NAME}:${USER_NAME}" "${PIXI_HOME}" "${USER_HOME}"

USER "${USER_NAME}"
WORKDIR "${USER_HOME}/pipeline"

ENV PATH="${PIXI_HOME}/bin:${PIXI_ENV_PREFIX}/bin:${PATH}" \
    CONDA_PREFIX="${PIXI_ENV_PREFIX}" \
    CONDA_DEFAULT_ENV=default

RUN curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION="${PIXI_VERSION}" bash \
    && pixi config set --global detached-environments /opt/pixi/envs

# Copy the Pixi project into the image so the default environment can be
# installed at build time. docker-compose bind-mounts the same path at runtime.
COPY --chown="${USER_NAME}:${USER_NAME}" pipeline/ ./

RUN rm -f .git \
    && pixi install --environment default

RUN python_bin="$(find "${PIXI_HOME}/envs" -path '*/envs/default/bin/python' -print -quit)" \
    && ln -s "$(dirname "$(dirname "${python_bin}")")" "${PIXI_ENV_PREFIX}" \
    && git config --global --add safe.directory "${USER_HOME}/pipeline" \
    && { \
        echo ''; \
        echo '# Activate the baked Pixi default environment for interactive shells.'; \
        echo "export PIXI_HOME=${PIXI_HOME}"; \
        echo "export CONDA_PREFIX=${PIXI_ENV_PREFIX}"; \
        echo 'export CONDA_DEFAULT_ENV=default'; \
        echo "export PATH=${PIXI_HOME}/bin:${PIXI_ENV_PREFIX}/bin:\$PATH"; \
      } >> "${USER_HOME}/.bashrc" \
    && rm -rf "${USER_HOME}/.cache/rattler" "${USER_HOME}/.cache/pixi" "${USER_HOME}/.cache/uv"

WORKDIR "${USER_HOME}"

CMD ["bash"]
