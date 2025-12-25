# Build Wine for Linux x86_64 (runs under box64 on Android ARM64)
#
# Wine is NOT cross-compiled for Android. Instead we build a native Linux x86_64
# Wine which is then executed by box64 (x86_64 emulator) on the Android device.
# This is the same approach used by Winlator and Termux.
#
# Build: docker build -t turnstone-wine-builder -f Dockerfile .
# Run: docker run --rm -v $(pwd)/output:/output turnstone-wine-builder [version]

FROM ubuntu:22.04

LABEL description="Build environment for Wine x86_64 bundle (for box64)"

ENV DEBIAN_FRONTEND=noninteractive

# Install Wine build dependencies
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
    # MinGW for PE DLLs
    gcc-mingw-w64 \
    g++-mingw-w64 \
    mingw-w64-tools \
    # Wine dependencies (64-bit)
    libx11-dev \
    libxext-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxi-dev \
    libxrender-dev \
    libxfixes-dev \
    libxcomposite-dev \
    libfreetype-dev \
    libfontconfig1-dev \
    libpng-dev \
    libjpeg-dev \
    libxml2-dev \
    libxslt1-dev \
    libgnutls28-dev \
    libvulkan-dev \
    libsdl2-dev \
    libopenal-dev \
    libpulse-dev \
    libasound2-dev \
    libcups2-dev \
    libdbus-1-dev \
    libusb-1.0-0-dev \
    libgphoto2-dev \
    libsane-dev \
    libv4l-dev \
    libkrb5-dev \
    liblcms2-dev \
    libpcap-dev \
    libudev-dev \
    unixodbc-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    # Compression
    zstd \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy build scripts
COPY build-wine.sh /build/
COPY patches/ /build/patches/

RUN chmod +x /build/build-wine.sh

WORKDIR /build

ENTRYPOINT ["/build/build-wine.sh"]
CMD ["9.22"]

