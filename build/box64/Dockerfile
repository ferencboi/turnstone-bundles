# Docker image for building box64 for Android
#
# Build: docker build -t turnstone-box64-builder -f Dockerfile .
#
# Usage (do NOT use --rm, clean up manually after success):
#   docker run --name box64-build -v $(pwd)/output:/output turnstone-box64-builder [version]
#   docker rm box64-build  # Only after successful build!
#
# On failure, container is preserved - extract artifacts with:
#   docker cp box64-build:/build/ ./recovered-build/

FROM turnstone-build-base

LABEL description="Build environment for box64 Android bundle"

# box64 has minimal dependencies, base image is sufficient

# Copy build scripts
COPY build-box64.sh /build/
COPY patches/ /build/patches/

# Create scripts directory - common.sh will be mounted at runtime
RUN mkdir -p /build/scripts

RUN chmod +x /build/build-box64.sh

WORKDIR /build

ENTRYPOINT ["/build/build-box64.sh"]
CMD ["0.3.8"]

