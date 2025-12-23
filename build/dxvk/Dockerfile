# Docker image for building DXVK
#
# DXVK builds Windows DLLs using MinGW cross-compilation
#
# Build: docker build -t turnstone-dxvk-builder -f Dockerfile .
# Run: docker run --rm -v $(pwd)/output:/output turnstone-dxvk-builder [version]

FROM turnstone-build-base

LABEL description="Build environment for DXVK bundle"

# Install MinGW for Windows cross-compilation
RUN apt-get update && apt-get install -y \
    mingw-w64 \
    mingw-w64-tools \
    glslang-tools \
    && rm -rf /var/lib/apt/lists/*

# Copy build scripts
COPY build-dxvk.sh /build/
COPY patches/ /build/patches/
COPY --from=scripts /build/scripts/common.sh /build/scripts/

RUN chmod +x /build/build-dxvk.sh

WORKDIR /build

ENTRYPOINT ["/build/build-dxvk.sh"]
CMD ["2.4"]

