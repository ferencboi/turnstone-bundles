#!/bin/bash
# Common functions for Turnstone bundle builds
# Source this file in other build scripts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions (output to stderr to not interfere with function return values)
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Android NDK paths
export NDK_HOME="${ANDROID_NDK_HOME:-/opt/android-ndk}"
export ANDROID_API="${ANDROID_API:-29}"
export TOOLCHAIN="${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"

# Cross-compilation variables
export TARGET_TRIPLE="aarch64-linux-android"
export CC="${TOOLCHAIN}/bin/${TARGET_TRIPLE}${ANDROID_API}-clang"
export CXX="${TOOLCHAIN}/bin/${TARGET_TRIPLE}${ANDROID_API}-clang++"
export AR="${TOOLCHAIN}/bin/llvm-ar"
export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
export STRIP="${TOOLCHAIN}/bin/llvm-strip"
export LD="${TOOLCHAIN}/bin/ld.lld"

# Common flags
export CFLAGS="-O2 -fPIC"
export CXXFLAGS="-O2 -fPIC"
export LDFLAGS="-fuse-ld=lld"

# Verify NDK is available
check_ndk() {
    if [ ! -d "${NDK_HOME}" ]; then
        log_error "Android NDK not found at ${NDK_HOME}"
        exit 1
    fi
    if [ ! -f "${CC}" ]; then
        log_error "Clang not found at ${CC}"
        exit 1
    fi
    log_info "Using Android NDK at ${NDK_HOME}"
    log_info "Target: ${TARGET_TRIPLE}, API: ${ANDROID_API}"
}

# Create bundle directory structure
create_bundle_dir() {
    local bundle_dir="$1"
    mkdir -p "${bundle_dir}/bin"
    mkdir -p "${bundle_dir}/lib"
    mkdir -p "${bundle_dir}/share"
    log_info "Created bundle directory: ${bundle_dir}"
}

# Generate manifest.json for a bundle
generate_manifest() {
    local bundle_dir="$1"
    local bundle_id="$2"
    local bundle_type="$3"
    local version="$4"
    local release_notes="$5"

    local archive_name="${bundle_id}.tar.zst"
    local download_url="https://github.com/ferencboi/turnstone-bundles/releases/download/${bundle_type}-${version}/${archive_name}"

    cat > "${bundle_dir}/manifest.json" << EOF
{
  "id": "${bundle_id}",
  "type": "${bundle_type}",
  "version": "${version}",
  "abi": "arm64-v8a",
  "sha256": "PLACEHOLDER",
  "downloadUrl": "${download_url}",
  "sizeBytes": 0,
  "compatibilityTags": [],
  "requiredVulkanExtensions": [],
  "minAndroidSdk": ${ANDROID_API},
  "releaseNotes": "${release_notes}"
}
EOF
    log_info "Generated manifest.json"
}

# Package bundle as tar.zst
package_bundle() {
    local bundle_dir="$1"
    local output_file="$2"

    log_info "Packaging bundle: ${output_file}"

    # Create tarball with zstd compression (redirect verbose to stderr)
    tar -I 'zstd -19' -cvf "${output_file}" -C "$(dirname ${bundle_dir})" "$(basename ${bundle_dir})" >&2

    # Calculate SHA-256
    local sha256=$(sha256sum "${output_file}" | cut -d' ' -f1)
    local size=$(stat -c%s "${output_file}")

    log_info "SHA-256: ${sha256}"
    log_info "Size: ${size} bytes"

    # Update manifest with hash and size
    if [ -f "${bundle_dir}/manifest.json" ]; then
        sed -i "s/\"sha256\": \"PLACEHOLDER\"/\"sha256\": \"${sha256}\"/" "${bundle_dir}/manifest.json"
        sed -i "s/\"sizeBytes\": 0/\"sizeBytes\": ${size}/" "${bundle_dir}/manifest.json"
    fi

    # Return only the SHA256 (to stdout)
    echo "${sha256}"
}

# Strip debug symbols from binaries
strip_binaries() {
    local dir="$1"
    log_info "Stripping debug symbols from ${dir}"

    find "${dir}" -type f \( -name "*.so" -o -name "*.so.*" \) -exec ${STRIP} --strip-unneeded {} \; 2>/dev/null || true
    find "${dir}/bin" -type f -executable -exec ${STRIP} --strip-unneeded {} \; 2>/dev/null || true
}

# Clone or update a git repository
clone_or_update() {
    local repo_url="$1"
    local target_dir="$2"
    local ref="$3"  # branch, tag, or commit

    if [ -d "${target_dir}/.git" ]; then
        log_info "Updating ${target_dir}"
        cd "${target_dir}"
        git fetch --all --tags
        git checkout "${ref}"
        git pull origin "${ref}" 2>/dev/null || true
    else
        log_info "Cloning ${repo_url} to ${target_dir}"
        git clone --depth 1 --branch "${ref}" "${repo_url}" "${target_dir}"
    fi
}

# Apply patches from a directory
apply_patches() {
    local source_dir="$1"
    local patches_dir="$2"

    if [ -d "${patches_dir}" ]; then
        log_info "Applying patches from ${patches_dir}"
        for patch in "${patches_dir}"/*.patch; do
            if [ -f "${patch}" ]; then
                log_info "Applying: $(basename ${patch})"
                cd "${source_dir}"
                patch -p1 < "${patch}"
            fi
        done
    fi
}

log_info "Common build functions loaded"

