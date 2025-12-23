# Docker image for building Wine for Android
#
# Wine requires a two-stage build process:
# 1. Build native tools on the host
# 2. Cross-compile for Android using those tools
#
# Build: docker build -t turnstone-wine-builder -f Dockerfile .
# Run: docker run --rm -v $(pwd)/output:/output turnstone-wine-builder [version]

FROM turnstone-build-base

LABEL description="Build environment for Wine Android bundle"

# Install Wine build dependencies
RUN apt-get update && apt-get install -y \
    # Required for Wine configure/build
    flex \
    bison \
    gettext \
    # For native tools build
    gcc \
    g++ \
    # Wine optional deps (some may be needed even for minimal build)
    libfreetype-dev \
    libpng-dev \
    libjpeg-dev \
    libxml2-dev \
    libxslt1-dev \
    # Perl for some Wine scripts
    perl \
    && rm -rf /var/lib/apt/lists/*

# Copy build scripts
COPY build-wine.sh /build/
COPY patches/ /build/patches/
COPY --from=scripts /build/scripts/common.sh /build/scripts/

RUN chmod +x /build/build-wine.sh

WORKDIR /build

ENTRYPOINT ["/build/build-wine.sh"]
CMD ["9.0"]

