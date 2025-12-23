# Docker image for building box64 for Android
#
# Build: docker build -t turnstone-box64-builder -f Dockerfile .
# Run: docker run --rm -v $(pwd)/output:/output -v $(pwd)/scripts:/build/scripts:ro turnstone-box64-builder [version]

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

