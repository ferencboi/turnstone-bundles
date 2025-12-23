#!/bin/bash
# Build Mesa Turnip Vulkan driver for Android arm64
#
# Turnip is Mesa's open-source Vulkan driver for Qualcomm Adreno GPUs
#
# Usage: ./build-turnip.sh [version]
# Example: ./build-turnip.sh 24.1.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

# Configuration
MESA_VERSION="${1:-24.1.0}"
MESA_REPO="https://gitlab.freedesktop.org/mesa/mesa.git"
MESA_TAG="mesa-${MESA_VERSION}"

BUILD_DIR="/build/turnip"
SOURCE_DIR="${BUILD_DIR}/source"
OUTPUT_DIR="/output"

BUNDLE_ID="turnip-${MESA_VERSION}-arm64"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_ID}"

log_info "========================================="
log_info "Building Mesa Turnip ${MESA_VERSION} for Android arm64"
log_info "========================================="

# Check NDK
check_ndk

# Create directories
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"
rm -rf "${BUNDLE_DIR}"
create_bundle_dir "${BUNDLE_DIR}"

# Clone Mesa
log_info "Cloning Mesa ${MESA_TAG}..."
clone_or_update "${MESA_REPO}" "${SOURCE_DIR}" "${MESA_TAG}"

# Apply patches if any
apply_patches "${SOURCE_DIR}" "${SCRIPT_DIR}/patches"

cd "${SOURCE_DIR}"

# Create Meson cross-file for Android
cat > android-aarch64-cross.txt << EOF
[binaries]
c = '${CC}'
cpp = '${CXX}'
ar = '${AR}'
strip = '${STRIP}'
pkgconfig = 'pkg-config'
llvm-config = '/usr/bin/llvm-config'

[built-in options]
c_args = ['-O2', '-fPIC', '-DANDROID']
cpp_args = ['-O2', '-fPIC', '-DANDROID']
c_link_args = ['-fuse-ld=lld']
cpp_link_args = ['-fuse-ld=lld']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[properties]
needs_exe_wrapper = true
EOF

# Configure Mesa for Turnip only
log_info "Configuring Mesa for Turnip..."
rm -rf build
meson setup build \
    --cross-file android-aarch64-cross.txt \
    --buildtype release \
    --strip \
    -Dprefix="${BUILD_DIR}/install" \
    -Dplatforms=android \
    -Dvulkan-drivers=freedreno \
    -Dgallium-drivers= \
    -Dopengl=false \
    -Degl=disabled \
    -Dgbm=disabled \
    -Dglx=disabled \
    -Dllvm=disabled \
    -Dshared-glapi=disabled \
    -Dandroid-stub=true \
    -Dfreedreno-kmds=kgsl

# Build
log_info "Building Mesa Turnip..."
ninja -C build -j$(nproc)

# Install
log_info "Installing Mesa Turnip..."
ninja -C build install

# Copy Vulkan driver to bundle
log_info "Copying files to bundle..."

# The Vulkan ICD JSON and library
mkdir -p "${BUNDLE_DIR}/lib/vulkan"

# Copy the Turnip shared library
find "${BUILD_DIR}/install" -name "libvulkan_freedreno.so" -exec cp -v {} "${BUNDLE_DIR}/lib/" \;
find "${BUILD_DIR}/install" -name "vulkan_freedreno.so" -exec cp -v {} "${BUNDLE_DIR}/lib/" \;

# Create Vulkan ICD JSON
cat > "${BUNDLE_DIR}/lib/vulkan/turnip_icd.aarch64.json" << EOF
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "../libvulkan_freedreno.so",
        "api_version": "1.3"
    }
}
EOF

# Strip binaries
strip_binaries "${BUNDLE_DIR}"

# Generate manifest with Adreno compatibility tags
generate_manifest "${BUNDLE_DIR}" "${BUNDLE_ID}" "turnip" "${MESA_VERSION}" \
    "Mesa Turnip ${MESA_VERSION} - Vulkan driver for Qualcomm Adreno GPUs"

# Update manifest with compatibility tags
sed -i 's/"compatibilityTags": \[\]/"compatibilityTags": ["adreno-600", "adreno-700"]/' \
    "${BUNDLE_DIR}/manifest.json"

# Package
ARCHIVE="${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
SHA256=$(package_bundle "${BUNDLE_DIR}" "${ARCHIVE}")

log_info "========================================="
log_info "Mesa Turnip build complete!"
log_info "Archive: ${ARCHIVE}"
log_info "SHA-256: ${SHA256}"
log_info "========================================="

# Output for CI
echo "BUNDLE_ARCHIVE=${ARCHIVE}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_SHA256=${SHA256}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_ID=${BUNDLE_ID}" >> "${OUTPUT_DIR}/build-info.txt"

