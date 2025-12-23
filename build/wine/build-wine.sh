#!/bin/bash
# Build Wine for Android arm64
#
# Wine requires a two-stage build:
# 1. Build native Wine tools on the host
# 2. Cross-compile Wine for Android using those tools
#
# Usage: ./build-wine.sh [version]
# Example: ./build-wine.sh 9.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

# Configuration
WINE_VERSION="${1:-9.0}"
WINE_REPO="https://gitlab.winehq.org/wine/wine.git"
WINE_TAG="wine-${WINE_VERSION}"

BUILD_DIR="/build/wine"
SOURCE_DIR="${BUILD_DIR}/source"
HOST_BUILD_DIR="${BUILD_DIR}/build-host"
ANDROID_BUILD_DIR="${BUILD_DIR}/build-android"
INSTALL_DIR="${BUILD_DIR}/install"
OUTPUT_DIR="/output"

BUNDLE_ID="wine-${WINE_VERSION}-arm64"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_ID}"

log_info "========================================="
log_info "Building Wine ${WINE_VERSION} for Android arm64"
log_info "========================================="

# Check NDK
check_ndk

# Create directories
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${HOST_BUILD_DIR}" "${ANDROID_BUILD_DIR}"
rm -rf "${BUNDLE_DIR}"
create_bundle_dir "${BUNDLE_DIR}"

# Clone Wine
log_info "Cloning Wine ${WINE_TAG}..."
clone_or_update "${WINE_REPO}" "${SOURCE_DIR}" "${WINE_TAG}"

# Apply patches if any
apply_patches "${SOURCE_DIR}" "${SCRIPT_DIR}/patches"

# Stage 1: Build native Wine tools
log_info "Stage 1: Building native Wine tools..."
cd "${HOST_BUILD_DIR}"

"${SOURCE_DIR}/configure" \
    --enable-win64 \
    --without-x \
    --without-freetype \
    --disable-tests

make -j$(nproc) __tooldeps__

# Stage 2: Cross-compile Wine for Android
log_info "Stage 2: Cross-compiling Wine for Android..."
cd "${ANDROID_BUILD_DIR}"

# Set up cross-compilation environment
export HOST_CC=gcc
export HOST_CXX=g++

# Configure for Android arm64
"${SOURCE_DIR}/configure" \
    --host=aarch64-linux-android \
    --with-wine-tools="${HOST_BUILD_DIR}" \
    --prefix="${INSTALL_DIR}" \
    --enable-win64 \
    --without-x \
    --without-freetype \
    --without-pulse \
    --without-alsa \
    --without-oss \
    --without-cups \
    --without-dbus \
    --without-fontconfig \
    --without-gphoto \
    --without-gnutls \
    --without-gsm \
    --without-gstreamer \
    --without-krb5 \
    --without-ldap \
    --without-netapi \
    --without-opencl \
    --without-pcap \
    --without-sane \
    --without-sdl \
    --without-udev \
    --without-usb \
    --without-v4l2 \
    --without-vulkan \
    --disable-tests \
    CC="${CC}" \
    CXX="${CXX}" \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CXXFLAGS}" \
    LDFLAGS="${LDFLAGS}"

# Build
log_info "Building Wine..."
make -j$(nproc)

# Install
log_info "Installing Wine..."
make install DESTDIR="${INSTALL_DIR}"

# Copy to bundle directory
log_info "Copying files to bundle..."

# Copy bin directory
cp -rv "${INSTALL_DIR}/bin/"* "${BUNDLE_DIR}/bin/" 2>/dev/null || true

# Copy lib directory
if [ -d "${INSTALL_DIR}/lib" ]; then
    cp -rv "${INSTALL_DIR}/lib/"* "${BUNDLE_DIR}/lib/"
fi
if [ -d "${INSTALL_DIR}/lib64" ]; then
    cp -rv "${INSTALL_DIR}/lib64/"* "${BUNDLE_DIR}/lib/"
fi

# Copy share directory (for Wine data files)
if [ -d "${INSTALL_DIR}/share/wine" ]; then
    cp -rv "${INSTALL_DIR}/share/wine" "${BUNDLE_DIR}/share/"
fi

# Strip binaries
strip_binaries "${BUNDLE_DIR}"

# Generate manifest
generate_manifest "${BUNDLE_DIR}" "${BUNDLE_ID}" "wine" "${WINE_VERSION}" \
    "Wine ${WINE_VERSION} - Windows compatibility layer for Android"

# Package
ARCHIVE="${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
SHA256=$(package_bundle "${BUNDLE_DIR}" "${ARCHIVE}")

log_info "========================================="
log_info "Wine build complete!"
log_info "Archive: ${ARCHIVE}"
log_info "SHA-256: ${SHA256}"
log_info "========================================="

# Output for CI
echo "BUNDLE_ARCHIVE=${ARCHIVE}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_SHA256=${SHA256}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_ID=${BUNDLE_ID}" >> "${OUTPUT_DIR}/build-info.txt"

