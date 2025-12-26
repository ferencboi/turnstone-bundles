# Docker image for building DXVK
#
# DXVK builds Windows DLLs using MinGW cross-compilation
#
# Build: docker build -t turnstone-dxvk-builder -f Dockerfile .
#
# Usage (do NOT use --rm, clean up manually after success):
#   docker run --name dxvk-build -v $(pwd)/output:/output turnstone-dxvk-builder [version]
#   docker rm dxvk-build  # Only after successful build!
#
# On failure, container is preserved - extract artifacts with:
#   docker cp dxvk-build:/build/ ./recovered-build/

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

