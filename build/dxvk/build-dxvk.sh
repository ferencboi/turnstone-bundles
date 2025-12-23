#!/bin/bash
# Build DXVK for use with Wine on Android
#
# DXVK is built as Windows DLLs using MinGW cross-compilation
# These DLLs are used inside Wine to translate DirectX to Vulkan
#
# Usage: ./build-dxvk.sh [version]
# Example: ./build-dxvk.sh 2.4

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

# Configuration
DXVK_VERSION="${1:-2.4}"
DXVK_REPO="https://github.com/doitsujin/dxvk.git"
DXVK_TAG="v${DXVK_VERSION}"

BUILD_DIR="/build/dxvk"
SOURCE_DIR="${BUILD_DIR}/source"
OUTPUT_DIR="/output"

BUNDLE_ID="dxvk-${DXVK_VERSION}-arm64"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_ID}"

log_info "========================================="
log_info "Building DXVK ${DXVK_VERSION}"
log_info "========================================="

# Create directories
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"
rm -rf "${BUNDLE_DIR}"
create_bundle_dir "${BUNDLE_DIR}"

# Clone DXVK
log_info "Cloning DXVK ${DXVK_TAG}..."
clone_or_update "${DXVK_REPO}" "${SOURCE_DIR}" "${DXVK_TAG}"

# Apply patches if any
apply_patches "${SOURCE_DIR}" "${SCRIPT_DIR}/patches"

cd "${SOURCE_DIR}"

# Build 64-bit DLLs
log_info "Building DXVK 64-bit..."
rm -rf build.win64
meson setup \
    --cross-file build-win64.txt \
    --buildtype release \
    --strip \
    --prefix "${BUILD_DIR}/install64" \
    build.win64

ninja -C build.win64 install

# Build 32-bit DLLs
log_info "Building DXVK 32-bit..."
rm -rf build.win32
meson setup \
    --cross-file build-win32.txt \
    --buildtype release \
    --strip \
    --prefix "${BUILD_DIR}/install32" \
    build.win32

ninja -C build.win32 install

# Copy DLLs to bundle
log_info "Copying DLLs to bundle..."

# Create x64 and x86 directories
mkdir -p "${BUNDLE_DIR}/lib/wine/x86_64-windows"
mkdir -p "${BUNDLE_DIR}/lib/wine/i386-windows"

# Copy 64-bit DLLs
cp -v "${BUILD_DIR}/install64/bin/"*.dll "${BUNDLE_DIR}/lib/wine/x86_64-windows/"

# Copy 32-bit DLLs
cp -v "${BUILD_DIR}/install32/bin/"*.dll "${BUNDLE_DIR}/lib/wine/i386-windows/"

# Create setup script for DXVK installation in Wine prefix
cat > "${BUNDLE_DIR}/bin/setup_dxvk.sh" << 'EOF'
#!/bin/bash
# Setup DXVK in a Wine prefix
# Usage: setup_dxvk.sh /path/to/prefix [32|64|both]

PREFIX="$1"
ARCH="${2:-both}"

if [ -z "$PREFIX" ]; then
    echo "Usage: $0 /path/to/prefix [32|64|both]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DXVK_DIR="$(dirname "${SCRIPT_DIR}")"

install_dll() {
    local src="$1"
    local dst="$2"
    cp -v "$src" "$dst"
}

if [ "$ARCH" = "64" ] || [ "$ARCH" = "both" ]; then
    echo "Installing 64-bit DXVK DLLs..."
    DST="${PREFIX}/drive_c/windows/system32"
    mkdir -p "$DST"
    for dll in "${DXVK_DIR}/lib/wine/x86_64-windows/"*.dll; do
        install_dll "$dll" "$DST/"
    done
fi

if [ "$ARCH" = "32" ] || [ "$ARCH" = "both" ]; then
    echo "Installing 32-bit DXVK DLLs..."
    DST="${PREFIX}/drive_c/windows/syswow64"
    mkdir -p "$DST"
    for dll in "${DXVK_DIR}/lib/wine/i386-windows/"*.dll; do
        install_dll "$dll" "$DST/"
    done
fi

echo "DXVK installation complete!"
EOF
chmod +x "${BUNDLE_DIR}/bin/setup_dxvk.sh"

# Generate manifest
generate_manifest "${BUNDLE_DIR}" "${BUNDLE_ID}" "dxvk" "${DXVK_VERSION}" \
    "DXVK ${DXVK_VERSION} - DirectX 9/10/11 to Vulkan translation layer"

# Update manifest with Vulkan requirements
sed -i 's/"requiredVulkanExtensions": \[\]/"requiredVulkanExtensions": ["VK_KHR_maintenance1", "VK_KHR_dedicated_allocation"]/' \
    "${BUNDLE_DIR}/manifest.json"

# Package
ARCHIVE="${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
SHA256=$(package_bundle "${BUNDLE_DIR}" "${ARCHIVE}")

log_info "========================================="
log_info "DXVK build complete!"
log_info "Archive: ${ARCHIVE}"
log_info "SHA-256: ${SHA256}"
log_info "========================================="

# Output for CI
echo "BUNDLE_ARCHIVE=${ARCHIVE}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_SHA256=${SHA256}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_ID=${BUNDLE_ID}" >> "${OUTPUT_DIR}/build-info.txt"

