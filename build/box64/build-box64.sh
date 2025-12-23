#!/bin/bash
# Build box64 for Android arm64
#
# Usage: ./build-box64.sh [version]
# Example: ./build-box64.sh 0.2.8

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# common.sh is mounted at /build/scripts/ in Docker, or relative path for local builds
if [ -f "/build/scripts/common.sh" ]; then
    source "/build/scripts/common.sh"
elif [ -f "${SCRIPT_DIR}/../scripts/common.sh" ]; then
    source "${SCRIPT_DIR}/../scripts/common.sh"
else
    echo "ERROR: common.sh not found"
    exit 1
fi

# Configuration
BOX64_VERSION="${1:-0.2.8}"
BOX64_REPO="https://github.com/ptitSeb/box64.git"
BOX64_TAG="v${BOX64_VERSION}"

BUILD_DIR="/build/box64"
SOURCE_DIR="${BUILD_DIR}/source"
INSTALL_DIR="${BUILD_DIR}/install"
OUTPUT_DIR="/output"

BUNDLE_ID="box64-${BOX64_VERSION}-arm64"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_ID}"

log_info "========================================="
log_info "Building box64 ${BOX64_VERSION} for Android arm64"
log_info "========================================="

# Check NDK
check_ndk

# Create directories
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"
rm -rf "${BUNDLE_DIR}"
create_bundle_dir "${BUNDLE_DIR}"

# Clone box64
log_info "Cloning box64 ${BOX64_TAG}..."
clone_or_update "${BOX64_REPO}" "${SOURCE_DIR}" "${BOX64_TAG}"

# Apply patches if any
apply_patches "${SOURCE_DIR}" "${SCRIPT_DIR}/patches"

# Configure with CMake
log_info "Configuring box64..."
cd "${SOURCE_DIR}"
rm -rf build && mkdir build && cd build

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="${NDK_HOME}/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-${ANDROID_API} \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DARM_DYNAREC=ON \
    -DANDROID=1 \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -G Ninja

# Build
log_info "Building box64..."
ninja -j$(nproc)

# Install
log_info "Installing box64..."
ninja install

# Copy to bundle directory
log_info "Copying files to bundle..."
cp -v "${INSTALL_DIR}/bin/box64" "${BUNDLE_DIR}/bin/"

# Copy libraries if any
if [ -d "${INSTALL_DIR}/lib" ]; then
    cp -rv "${INSTALL_DIR}/lib/"* "${BUNDLE_DIR}/lib/" 2>/dev/null || true
fi

# Strip binaries
strip_binaries "${BUNDLE_DIR}"

# Generate manifest
generate_manifest "${BUNDLE_DIR}" "${BUNDLE_ID}" "box64" "${BOX64_VERSION}" \
    "box64 ${BOX64_VERSION} - x86_64 Linux emulator for ARM64"

# Package
ARCHIVE="${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
SHA256=$(package_bundle "${BUNDLE_DIR}" "${ARCHIVE}")

log_info "========================================="
log_info "box64 build complete!"
log_info "Archive: ${ARCHIVE}"
log_info "SHA-256: ${SHA256}"
log_info "========================================="

# Output for CI
echo "BUNDLE_ARCHIVE=${ARCHIVE}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_SHA256=${SHA256}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_ID=${BUNDLE_ID}" >> "${OUTPUT_DIR}/build-info.txt"

