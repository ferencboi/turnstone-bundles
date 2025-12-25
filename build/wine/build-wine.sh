#!/bin/bash
# Build Wine for Linux x86_64 (runs under box64 on Android ARM64)
#
# Wine is NOT cross-compiled for Android. Instead we build a native Linux x86_64
# Wine which is then executed by box64 (x86_64 emulator) on the Android device.
# This is the same approach used by Winlator and Termux.
#
# The WoW64 mode (Wine 9.x+) allows a single 64-bit Wine build to run both
# 32-bit and 64-bit Windows applications without needing a separate 32-bit build.
#
# Usage: ./build-wine.sh [version]
# Example: ./build-wine.sh 9.22

set -e

# Configuration
WINE_VERSION="${1:-9.22}"
WINE_URL_BASE="https://dl.winehq.org/wine/source"
BUILD_DIR="/build/wine-build"
SOURCE_DIR="${BUILD_DIR}/wine-${WINE_VERSION}"
BUILD_64_DIR="${BUILD_DIR}/build64"
INSTALL_DIR="${BUILD_DIR}/install"
OUTPUT_DIR="/output"

# Determine Wine source URL (stable vs development)
# Stable versions have .0 in second position (9.0, 10.0)
# Development versions have other numbers (9.1, 9.2, 9.22)
MAJOR_VERSION=$(echo "$WINE_VERSION" | cut -d. -f1)
MINOR_VERSION=$(echo "$WINE_VERSION" | cut -d. -f2)
if [ "$MINOR_VERSION" = "0" ]; then
    WINE_URL="${WINE_URL_BASE}/${MAJOR_VERSION}.0/wine-${WINE_VERSION}.tar.xz"
else
    WINE_URL="${WINE_URL_BASE}/${MAJOR_VERSION}.x/wine-${WINE_VERSION}.tar.xz"
fi

BUNDLE_ID="wine-${WINE_VERSION}-x86_64"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_ID}"

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_info "========================================="
log_info "Building Wine ${WINE_VERSION} for Linux x86_64"
log_info "========================================="
log_info "This build is designed to run under box64 on Android ARM64"
log_info ""

# Create directories
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${BUILD_64_DIR}" "${INSTALL_DIR}"
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/bin" "${BUNDLE_DIR}/lib" "${BUNDLE_DIR}/share"

# Download Wine source
log_info "Downloading Wine ${WINE_VERSION}..."
cd "${BUILD_DIR}"
if [ ! -f "wine-${WINE_VERSION}.tar.xz" ]; then
    wget -q --show-progress "${WINE_URL}" || {
        log_error "Failed to download Wine. Check if version ${WINE_VERSION} exists."
        log_error "URL: ${WINE_URL}"
        exit 1
    }
fi

# Extract
log_info "Extracting Wine source..."
tar xf "wine-${WINE_VERSION}.tar.xz"

# Apply patches if any
PATCH_DIR="/build/patches"
if [ -d "${PATCH_DIR}" ] && [ "$(ls -A ${PATCH_DIR}/*.patch 2>/dev/null)" ]; then
    log_info "Applying patches..."
    cd "${SOURCE_DIR}"
    for patch in "${PATCH_DIR}"/*.patch; do
        log_info "  Applying $(basename $patch)..."
        patch -p1 < "$patch"
    done
fi

# Regenerate build files after patching
cd "${SOURCE_DIR}"
log_info "Regenerating build files..."
./tools/make_requests || true
./tools/make_specfiles || true
autoreconf -f 2>/dev/null || true

# Build Wine 64-bit with WoW64 mode
log_info "Configuring Wine 64-bit (WoW64 mode)..."
cd "${BUILD_64_DIR}"

# Configure options:
# --enable-win64: Build 64-bit Wine
# --enable-archs=i386,x86_64: Enable WoW64 for 32-bit app support
# --without-oss: OSS not typically available
# --disable-tests: Skip tests
# --disable-winemenubuilder: Not needed for headless/embedded use

"${SOURCE_DIR}/configure" \
    --prefix="${INSTALL_DIR}" \
    --enable-win64 \
    --enable-archs=i386,x86_64 \
    --without-oss \
    --disable-tests \
    --disable-winemenubuilder \
    CFLAGS="-O2 -march=x86-64 -mtune=generic" \
    CXXFLAGS="-O2 -march=x86-64 -mtune=generic"

# Build
log_info "Building Wine (this may take a while)..."
make -j$(nproc)

# Install
log_info "Installing Wine..."
make install

# Copy to bundle directory
log_info "Creating bundle..."

# Copy bin directory
cp -rv "${INSTALL_DIR}/bin/"* "${BUNDLE_DIR}/bin/"

# Copy lib directory (Wine libraries and DLLs)
if [ -d "${INSTALL_DIR}/lib" ]; then
    cp -rv "${INSTALL_DIR}/lib/"* "${BUNDLE_DIR}/lib/"
fi
if [ -d "${INSTALL_DIR}/lib64" ]; then
    cp -rv "${INSTALL_DIR}/lib64/"* "${BUNDLE_DIR}/lib/"
fi

# Copy share directory (Wine data files)
if [ -d "${INSTALL_DIR}/share/wine" ]; then
    cp -rv "${INSTALL_DIR}/share/wine" "${BUNDLE_DIR}/share/"
fi

# Strip binaries to reduce size
log_info "Stripping binaries..."
find "${BUNDLE_DIR}/bin" -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true
find "${BUNDLE_DIR}/lib" -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true

# Create manifest
log_info "Creating manifest..."
cat > "${BUNDLE_DIR}/manifest.json" << EOF
{
  "id": "${BUNDLE_ID}",
  "type": "wine",
  "version": "${WINE_VERSION}",
  "arch": "x86_64",
  "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "description": "Wine ${WINE_VERSION} for Linux x86_64 (runs under box64)",
  "notes": "WoW64 mode enabled - supports both 32-bit and 64-bit Windows applications"
}
EOF

# Package
log_info "Packaging bundle..."
cd "${BUILD_DIR}"
ARCHIVE="${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
tar -I 'zstd -19 -T0' -cvf "${ARCHIVE}" "${BUNDLE_ID}"

# Calculate SHA-256
SHA256=$(sha256sum "${ARCHIVE}" | cut -d' ' -f1)
echo "${SHA256}  ${BUNDLE_ID}.tar.zst" > "${ARCHIVE}.sha256"

# Get file size
SIZE=$(stat -c%s "${ARCHIVE}")

log_info "========================================="
log_info "Wine build complete!"
log_info "Archive: ${ARCHIVE}"
log_info "Size: ${SIZE} bytes"
log_info "SHA-256: ${SHA256}"
log_info "========================================="

# Output for CI
cat > "${OUTPUT_DIR}/build-info.txt" << EOF
BUNDLE_ARCHIVE=${ARCHIVE}
BUNDLE_SHA256=${SHA256}
BUNDLE_SIZE=${SIZE}
BUNDLE_ID=${BUNDLE_ID}
WINE_VERSION=${WINE_VERSION}
EOF

