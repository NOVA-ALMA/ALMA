FROM almalinux:8

# Install required system libraries CASA depends on
RUN dnf install -y epel-release && \
    dnf install -y \
    mesa-libGL \
    glib2 \
    libnsl \
    xorg-x11-server-Xvfb \
    wget \
    which \
    xz \
    perl \
    git \
    ImageMagick \
    && dnf clean all

# Provided at build time from docker/casa/version.env.
ARG CASA_VERSION

# Create a working directory
WORKDIR /casa

# Copy and extract the CASA tarball
COPY docker/casa/casa-${CASA_VERSION}.tar.xz .
RUN tar -xf casa-${CASA_VERSION}.tar.xz && rm casa-${CASA_VERSION}.tar.xz

# Create CASA data directory for measures data
RUN mkdir -p /root/.casa/data

# Add CASA to PATH
ENV PATH="/casa/casa-${CASA_VERSION}/bin:/casa/casa-${CASA_VERSION}/lib/py/bin:$PATH"

# Install the shared runtime requirements plus any CASA-specific overlay.
COPY pipeline/requirements.txt /tmp/pipeline-requirements.txt
COPY docker/casa/requirements-overlay.txt /tmp/casa-requirements-overlay.txt

RUN PYTHONNOUSERSITE=1 python3 -m pip install \
    --disable-pip-version-check --upgrade-strategy=only-if-needed \
    -r /tmp/pipeline-requirements.txt \
    -r /tmp/casa-requirements-overlay.txt && \
    rm /tmp/pipeline-requirements.txt /tmp/casa-requirements-overlay.txt

# Pre-extract the casaplotms AppImage so it runs without FUSE (unavailable in
# Docker containers).  The AppImage is replaced with a thin wrapper script that
# execs the extracted AppRun binary directly.
RUN APPIMAGE="/casa/casa-${CASA_VERSION}/lib/py/lib/python3.12/site-packages/casaplotms/__bin__/casaplotms-x86_64.AppImage" && \
    cd /tmp && "$APPIMAGE" --appimage-extract > /dev/null && \
    mv /tmp/squashfs-root /opt/casaplotms && \
    printf '#!/bin/sh\nexec /opt/casaplotms/AppRun "$@"\n' > "$APPIMAGE" && \
    chmod +x "$APPIMAGE"

# Allow git to operate on the bind-mounted source (owned by host user, not root).
RUN git config --global --add safe.directory /casa/pipeline

COPY docker/casa/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["casa", "--nologger", "--log2term", "--nogui"]
