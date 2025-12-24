# Docker image for building Mesa Turnip for Android
#
# Build: docker build -t turnstone-turnip-builder -f Dockerfile .
# Run: docker run --rm -v $(pwd)/output:/output turnstone-turnip-builder [version]
#
# Approach: Build Mesa for Linux (not Android platform) with KGSL backend
# This is the same method used by Termux and Winlator.

FROM ubuntu:24.04

LABEL description="Build environment for Mesa Turnip Android bundle"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Android NDK version
ENV NDK_VERSION=r27c
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV ANDROID_API=29

# Add NDK to PATH
ENV PATH="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}"

# Install base and Mesa build dependencies
RUN apt-get update && apt-get install -y \
    # Basic build tools
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    autoconf \
    automake \
    libtool \
    # Compression
    zstd \
    tar \
    xz-utils \
    # Download tools
    curl \
    wget \
    git \
    # Python (for meson, scripts)
    python3 \
    python3-pip \
    python3-setuptools \
    python3-venv \
    # Shader compilers and SPIRV tools
    glslang-tools \
    spirv-tools \
    # LLVM/Clang for cross-compilation
    llvm \
    clang \
    lld \
    libclang-dev \
    # Mesa dependencies
    libdrm-dev \
    libexpat1-dev \
    libelf-dev \
    libzstd-dev \
    libwayland-dev \
    wayland-protocols \
    libxcb1-dev \
    libxcb-dri2-0-dev \
    libxcb-dri3-dev \
    libxcb-present-dev \
    libxcb-shm0-dev \
    libxcb-sync-dev \
    libxcb-xfixes0-dev \
    libxcb-randr0-dev \
    libxshmfence-dev \
    libx11-xcb-dev \
    libx11-dev \
    libxext-dev \
    libxfixes-dev \
    # Misc
    unzip \
    file \
    patchelf \
    bison \
    flex \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages via pip (use --break-system-packages for Ubuntu 24.04)
RUN pip3 install --no-cache-dir --break-system-packages meson mako PyYAML ply

# Download and extract Android NDK
RUN mkdir -p /opt && \
    cd /opt && \
    curl -L -o ndk.zip "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" && \
    unzip -q ndk.zip && \
    mv android-ndk-${NDK_VERSION} android-ndk && \
    rm ndk.zip

# Create directories
RUN mkdir -p /output /build /build/scripts /build/patches

# Copy build scripts - common.sh needs to be copied during build context
COPY build-turnip.sh /build/
COPY patches/ /build/patches/

RUN chmod +x /build/build-turnip.sh

WORKDIR /build

ENTRYPOINT ["/build/build-turnip.sh"]
CMD ["25.3.2"]

