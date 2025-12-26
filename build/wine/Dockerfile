# Build Wine for Linux x86_64 (runs under box64 on Android ARM64)
#
# Wine is NOT cross-compiled for Android. Instead we build a native Linux x86_64
# Wine which is then executed by box64 (x86_64 emulator) on the Android device.
# This is the same approach used by Winlator and Termux.
#
# Build: docker build -t turnstone-wine-builder -f Dockerfile .
#
# Usage (do NOT use --rm, clean up manually after success):
#   docker run --name wine-build -v $(pwd)/output:/output turnstone-wine-builder [version] [profile]
#   docker rm wine-build  # Only after successful build!
#
# Examples:
#   docker run --name wine-build -v $(pwd)/../output:/output turnstone-wine-builder 9.22
#   docker run --name wine-build -v $(pwd)/../output:/output turnstone-wine-builder 9.22 gaming
#   docker rm wine-build  # Clean up after success
#
# On build failure, container is preserved for debugging:
#   docker start -ai wine-build     # Resume/retry
#   docker cp wine-build:/build/wine-build ./  # Extract build artifacts
#   docker rm wine-build             # Clean up when done
#
# Available profiles: full, gaming, guild-wars (see profiles/ directory)

FROM ubuntu:22.04

LABEL description="Build environment for Wine x86_64 bundle (for box64)"
LABEL maintainer="Turnstone Project"

ENV DEBIAN_FRONTEND=noninteractive

# Install Wine build dependencies
# All dependencies installed regardless of profile - configure flags control what gets built
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    git \
    wget \
    curl \
    ca-certificates \
    pkg-config \
    autoconf \
    automake \
    libtool \
    flex \
    bison \
    gettext \
    # MinGW for PE DLLs (required for WoW64)
    gcc-mingw-w64 \
    g++-mingw-w64 \
    mingw-w64-tools \
    # Wine dependencies - X11
    libx11-dev \
    libxext-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxi-dev \
    libxrender-dev \
    libxfixes-dev \
    libxcomposite-dev \
    libxinerama-dev \
    # Wine dependencies - Graphics
    libfreetype-dev \
    libfontconfig1-dev \
    libpng-dev \
    libjpeg-dev \
    libvulkan-dev \
    libsdl2-dev \
    # Wine dependencies - Audio
    libopenal-dev \
    libpulse-dev \
    libasound2-dev \
    # Wine dependencies - Network/Security (CRITICAL for gaming)
    libgnutls28-dev \
    libkrb5-dev \
    # Wine dependencies - Media
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    # Wine dependencies - Other
    libxml2-dev \
    libxslt1-dev \
    libcups2-dev \
    libdbus-1-dev \
    libusb-1.0-0-dev \
    libgphoto2-dev \
    libsane-dev \
    libv4l-dev \
    liblcms2-dev \
    libpcap-dev \
    libudev-dev \
    unixodbc-dev \
    # Compression
    zstd \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy build scripts and profiles
COPY build-wine.sh /build/
COPY patches/ /build/patches/
COPY profiles/ /build/profiles/

RUN chmod +x /build/build-wine.sh

WORKDIR /build

ENTRYPOINT ["/build/build-wine.sh"]
CMD ["9.22", "full"]

