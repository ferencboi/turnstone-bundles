# Docker image for building Mesa Turnip for Android
#
# Build: docker build -t turnstone-turnip-builder -f Dockerfile .
# Run: docker run --rm -v $(pwd)/output:/output turnstone-turnip-builder [version]

FROM turnstone-build-base

LABEL description="Build environment for Mesa Turnip Android bundle"

# Install Mesa build dependencies
RUN apt-get update && apt-get install -y \
    # Mesa specific
    libdrm-dev \
    libxcb1-dev \
    libx11-xcb-dev \
    libxcb-dri2-0-dev \
    libxcb-dri3-dev \
    libxcb-present-dev \
    libxcb-randr0-dev \
    libxcb-shm0-dev \
    libxcb-sync-dev \
    libxcb-xfixes0-dev \
    libxshmfence-dev \
    libxrandr-dev \
    # Shader compilers
    glslang-tools \
    # Python deps
    python3-mako \
    python3-ply \
    python3-yaml \
    # LLVM (for some Mesa components)
    libllvm-dev \
    llvm-dev \
    && rm -rf /var/lib/apt/lists/*

# Install additional Python packages
RUN pip3 install --no-cache-dir mako PyYAML

# Copy build scripts
COPY build-turnip.sh /build/
COPY patches/ /build/patches/
COPY --from=scripts /build/scripts/common.sh /build/scripts/

RUN chmod +x /build/build-turnip.sh

WORKDIR /build

ENTRYPOINT ["/build/build-turnip.sh"]
CMD ["24.1.0"]

