#!/bin/bash
# Build Mesa Turnip Vulkan driver for Android arm64
#
# Turnip is Mesa's open-source Vulkan driver for Qualcomm Adreno GPUs
#
# Usage: ./build-turnip.sh [version]
# Example: ./build-turnip.sh 25.3.2
#
# ============================================================================
# BUILD APPROACH: Linux WSI + KGSL (Termux/Winlator method)
# ============================================================================
# This uses the same approach as Termux's mesa-vulkan-icd-freedreno package:
#   - Build Mesa for Linux (NOT Android platform)
#   - Use KGSL kernel backend for Qualcomm GPU access
#   - The resulting libvulkan_freedreno.so works in Proot/Wine environments
#
# Key insight: The GPU communication happens via KGSL kernel driver,
# which is the same on Android. We just use Linux WSI code path.
#
# Reference: https://github.com/termux/termux-packages/blob/main/packages/mesa/build.sh
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Inline logging functions
log_info() { echo -e "\033[0;32m[INFO]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; }

# Configuration
MESA_VERSION="${1:-25.3.2}"
MESA_REPO="https://gitlab.freedesktop.org/mesa/mesa.git"
MESA_TAG="mesa-${MESA_VERSION}"

BUILD_DIR="/build/turnip-build"
SOURCE_DIR="${BUILD_DIR}/source"
OUTPUT_DIR="/output"

BUNDLE_ID="turnip-${MESA_VERSION}-arm64"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_ID}"

# Android NDK setup
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-/opt/android-ndk}"
export ANDROID_API="${ANDROID_API:-29}"
NDK_TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"

log_info "========================================="
log_info "Building Mesa Turnip ${MESA_VERSION} for Android arm64"
log_info "========================================="
log_info "NDK: ${ANDROID_NDK_HOME}"
log_info "API Level: ${ANDROID_API}"

# Check NDK
if [ ! -d "${ANDROID_NDK_HOME}" ]; then
    log_error "Android NDK not found at ${ANDROID_NDK_HOME}"
    exit 1
fi

# Create directories
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/bin" "${BUNDLE_DIR}/lib" "${BUNDLE_DIR}/share"

# =============================================================================
# Cross-compile libelf for Android
# =============================================================================
# Mesa's freedreno Vulkan driver links against -lelf.
# The NDK sysroot does not provide libelf, so we build it.
#
# elfutils' configure requires argp_parse. Android/Bionic doesn't provide argp,
# but Mesa only needs libelf, not elfutils programs. To keep this deterministic
# and avoid pulling extra dependencies, we provide a tiny libargp stub that
# exports argp_parse to satisfy configure and (potential) link steps.
# =============================================================================
ELFUTILS_VERSION="0.191"
ELFUTILS_DIR="${BUILD_DIR}/elfutils-${ELFUTILS_VERSION}"
LIBELF_PREFIX="${BUILD_DIR}/libelf-android"
ARGP_PREFIX="${BUILD_DIR}/argp-android"
OBSTACK_PREFIX="${BUILD_DIR}/obstack-android"
INTL_PREFIX="${BUILD_DIR}/intl-android"

if [ ! -f "${LIBELF_PREFIX}/lib/libelf.a" ]; then
    log_info "Building libelf (elfutils ${ELFUTILS_VERSION}) for Android..."
    cd "${BUILD_DIR}"

    # Build a minimal libargp.a (only what elfutils' configure probes for).
    if [ ! -f "${ARGP_PREFIX}/lib/libargp.a" ]; then
        log_info "Building minimal libargp stub for Android..."
        rm -rf "${BUILD_DIR}/argp_stub"
        mkdir -p "${BUILD_DIR}/argp_stub/include" "${ARGP_PREFIX}/lib" "${ARGP_PREFIX}/include"

        cat > "${BUILD_DIR}/argp_stub/include/argp.h" << 'EOF'
#ifndef ARGP_H
#define ARGP_H
typedef int error_t;
struct argp;
struct argp_state;
error_t argp_parse(const struct argp *argp, int argc, char **argv, unsigned flags, int *arg_index, void *input);
#endif
EOF

        cat > "${BUILD_DIR}/argp_stub/argp.c" << 'EOF'
#include <argp.h>
error_t argp_parse(const struct argp *argp, int argc, char **argv, unsigned flags, int *arg_index, void *input) {
    (void)argp;
    (void)argc;
    (void)argv;
    (void)flags;
    (void)arg_index;
    (void)input;
    return 0;
}
EOF

        "${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API}-clang" \
            -I"${BUILD_DIR}/argp_stub/include" -fPIC -O2 -c "${BUILD_DIR}/argp_stub/argp.c" -o "${BUILD_DIR}/argp_stub/argp.o"
        "${NDK_TOOLCHAIN}/bin/llvm-ar" rcs "${ARGP_PREFIX}/lib/libargp.a" "${BUILD_DIR}/argp_stub/argp.o"
        cp -f "${BUILD_DIR}/argp_stub/include/argp.h" "${ARGP_PREFIX}/include/argp.h"
        log_info "libargp stub built"
    fi

    # Build a minimal libobstack.a (elfutils' configure probes for _obstack_free).
    # Android/Bionic doesn't provide glibc obstacks; we only need the symbol to
    # satisfy configure so we can build libelf.
    if [ ! -f "${OBSTACK_PREFIX}/lib/libobstack.a" ]; then
        log_info "Building minimal libobstack stub for Android..."
        rm -rf "${BUILD_DIR}/obstack_stub"
        mkdir -p "${BUILD_DIR}/obstack_stub/include" "${OBSTACK_PREFIX}/lib" "${OBSTACK_PREFIX}/include"

        cat > "${BUILD_DIR}/obstack_stub/include/obstack.h" << 'EOF'
#ifndef OBSTACK_H
#define OBSTACK_H
struct obstack {
    int dummy;
};
void _obstack_free(struct obstack *h, void *obj);
#endif
EOF

        cat > "${BUILD_DIR}/obstack_stub/obstack.c" << 'EOF'
#include <obstack.h>
void _obstack_free(struct obstack *h, void *obj) {
    (void)h;
    (void)obj;
}
EOF

        "${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API}-clang" \
            -I"${BUILD_DIR}/obstack_stub/include" -fPIC -O2 -c "${BUILD_DIR}/obstack_stub/obstack.c" -o "${BUILD_DIR}/obstack_stub/obstack.o"
        "${NDK_TOOLCHAIN}/bin/llvm-ar" rcs "${OBSTACK_PREFIX}/lib/libobstack.a" "${BUILD_DIR}/obstack_stub/obstack.o"
        cp -f "${BUILD_DIR}/obstack_stub/include/obstack.h" "${OBSTACK_PREFIX}/include/obstack.h"
        log_info "libobstack stub built"
    fi

    # Provide a minimal libintl.h stub.
    # elfutils disables NLS with --disable-nls, but its headers may still
    # include libintl.h depending on configure results.
    if [ ! -f "${INTL_PREFIX}/include/libintl.h" ]; then
        log_info "Creating minimal libintl.h stub..."
        mkdir -p "${INTL_PREFIX}/include"
        cat > "${INTL_PREFIX}/include/libintl.h" << 'EOF'
#ifndef LIBINTL_H
#define LIBINTL_H
static inline const char *gettext(const char *msgid) { return msgid; }
static inline const char *dgettext(const char *domain, const char *msgid) { (void)domain; return msgid; }
static inline const char *dcgettext(const char *domain, const char *msgid, int category) { (void)domain; (void)category; return msgid; }
static inline const char *textdomain(const char *domain) { return domain; }
static inline const char *bindtextdomain(const char *domain, const char *dir) { (void)dir; return domain; }
static inline const char *bind_textdomain_codeset(const char *domain, const char *codeset) { (void)codeset; return domain; }
#endif
EOF
        log_info "libintl.h stub created"
    fi

    if [ ! -d "${ELFUTILS_DIR}" ]; then
        log_info "Downloading elfutils ${ELFUTILS_VERSION}..."
        curl -L -f "https://sourceware.org/elfutils/ftp/${ELFUTILS_VERSION}/elfutils-${ELFUTILS_VERSION}.tar.bz2" -o "elfutils-${ELFUTILS_VERSION}.tar.bz2"
        tar xjf "elfutils-${ELFUTILS_VERSION}.tar.bz2"
    fi

    cd "${ELFUTILS_DIR}"

    # Configure for Android cross-compilation.
    # We only build/install libelf; the libargp stub is to satisfy configure.
    export CPPFLAGS="-I${INTL_PREFIX}/include -I${ARGP_PREFIX}/include -I${OBSTACK_PREFIX}/include"
    export LDFLAGS="-L${ARGP_PREFIX}/lib -L${OBSTACK_PREFIX}/lib"
    export LIBS="-largp -lobstack"

    CC="${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API}-clang" \
    AR="${NDK_TOOLCHAIN}/bin/llvm-ar" \
    RANLIB="${NDK_TOOLCHAIN}/bin/llvm-ranlib" \
    CFLAGS="-fPIC -O2" \
    ./configure \
        --host=aarch64-linux-android \
        --prefix="${LIBELF_PREFIX}" \
        --disable-nls \
        --disable-shared \
        --enable-static \
        --disable-debuginfod \
        --disable-libdebuginfod \
        --disable-demangler

    # Build ONLY the static archive. Building the shared libelf.so pulls in
    # ../lib/libeu.a (and more), which we don't need for Mesa's -lelf link.
    make -C libelf -j"$(nproc)" libelf.a

    # Install libelf.a and public headers manually (avoid install rules that
    # may try to build/install libelf.so).
    mkdir -p "${LIBELF_PREFIX}/lib" "${LIBELF_PREFIX}/include"
    cp -f "${ELFUTILS_DIR}/libelf/libelf.a" "${LIBELF_PREFIX}/lib/"
    cp -f "${ELFUTILS_DIR}/libelf/libelf.h" "${LIBELF_PREFIX}/include/"
    cp -f "${ELFUTILS_DIR}/libelf/gelf.h" "${LIBELF_PREFIX}/include/"
    if [ -f "${ELFUTILS_DIR}/libelf/nlist.h" ]; then
        cp -f "${ELFUTILS_DIR}/libelf/nlist.h" "${LIBELF_PREFIX}/include/"
    fi

    # Ensure pkg-config metadata exists (Mesa prefers pkg-config when available).
    if [ ! -f "${LIBELF_PREFIX}/lib/pkgconfig/libelf.pc" ]; then
        mkdir -p "${LIBELF_PREFIX}/lib/pkgconfig"
        cat > "${LIBELF_PREFIX}/lib/pkgconfig/libelf.pc" << EOF
prefix=${LIBELF_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libelf
Description: ELF object file access library
Version: ${ELFUTILS_VERSION}
Libs: -L\${libdir} -lelf
Cflags: -I\${includedir}
EOF
    fi

    log_info "libelf built successfully"
else
    log_info "Using cached libelf build"
fi

# Export libelf paths for Mesa build
export CFLAGS="-I${LIBELF_PREFIX}/include ${CFLAGS:-}"
export LDFLAGS="-L${LIBELF_PREFIX}/lib ${LDFLAGS:-}"
export PKG_CONFIG_PATH="${LIBELF_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Clone Mesa
log_info "Cloning Mesa ${MESA_TAG}..."
if [ -d "${SOURCE_DIR}" ]; then
    cd "${SOURCE_DIR}"
    git fetch --tags
    git checkout "${MESA_TAG}"
else
    git clone --depth 1 --branch "${MESA_TAG}" "${MESA_REPO}" "${SOURCE_DIR}"
fi

cd "${SOURCE_DIR}"

# Apply patches if any
if [ -d "${SCRIPT_DIR}/patches" ] && [ "$(ls -A ${SCRIPT_DIR}/patches/*.patch 2>/dev/null)" ]; then
    log_info "Applying patches..."
    for patch in "${SCRIPT_DIR}/patches"/*.patch; do
        if [ -f "$patch" ]; then
            log_info "Applying: $(basename $patch)"
            git apply "$patch" || log_warn "Patch may already be applied: $(basename $patch)"
        fi
    done
fi

# =============================================================================
# Remove problematic subproject wraps
# =============================================================================
# libarchive has cross-compilation issues (needs libxml2 -> ICU).
# Since freedreno uses it with required: false, we can safely remove it.
# =============================================================================
log_info "Removing problematic subproject wraps..."
rm -f subprojects/libarchive.wrap
log_info "Removed libarchive.wrap - will be skipped (optional dependency)"

# =============================================================================
# Critical fix: Disable Android OS detection in Mesa
# =============================================================================
# Problem: The Android NDK compiler always defines __ANDROID__, which causes
# Mesa's detect_os.h to set DETECT_OS_ANDROID=1. This triggers Android-specific
# code paths that require headers like <cutils/trace.h> and <log/log.h> which
# don't exist in the NDK.
#
# Solution: Patch detect_os.h to never define DETECT_OS_ANDROID as 1.
# This makes Mesa treat the build as pure Linux with KGSL backend.
# This is the same approach Termux uses for their mesa-vulkan-icd-freedreno.
# =============================================================================
log_info "Applying source modifications for Linux build..."

# Patch detect_os.h to disable Android detection entirely
# Change: #if defined(__ANDROID__)  #define DETECT_OS_ANDROID 1
# To:     #if 0  #define DETECT_OS_ANDROID 1 (never triggers)
sed -i 's/^#if defined(__ANDROID__)$/#if 0 \/* __ANDROID__ - disabled for Linux build *\//' \
    src/util/detect_os.h || log_warn "Failed to modify detect_os.h"

# Verify the change was applied
if grep -q "#if 0 /\* __ANDROID__ - disabled for Linux build \*/" src/util/detect_os.h; then
    log_info "Successfully disabled DETECT_OS_ANDROID in detect_os.h"
else
    log_error "Failed to disable Android detection - checking file content..."
    grep -n "ANDROID" src/util/detect_os.h | head -5
fi

# Patch vk_android_native_buffer.h to not require cutils/native_handle.h
# The header has: #if defined(__ANDROID__) || defined(ANDROID)
# We change it to: #if 0 /* disabled for Linux build */
# This makes it use the simple "typedef void *buffer_handle_t" fallback
sed -i 's/^#if defined(__ANDROID__) || defined(ANDROID)$/#if 0 \/* __ANDROID__ disabled for Linux build *\//' \
    include/vulkan/vk_android_native_buffer.h || log_warn "Failed to modify vk_android_native_buffer.h"

if grep -q "#if 0 /\* __ANDROID__ disabled for Linux build \*/" include/vulkan/vk_android_native_buffer.h; then
    log_info "Successfully patched vk_android_native_buffer.h"
else
    log_warn "vk_android_native_buffer.h patch may not have applied correctly"
fi

# =============================================================================
# Create stub headers for Android system headers
# =============================================================================
# The Vulkan Android extension headers (vk_android_native_buffer.h) include
# Android system headers like cutils/native_handle.h which don't exist in NDK.
# We create minimal stub headers to satisfy the compiler.
# =============================================================================
log_info "Creating stub Android system headers..."
STUB_INCLUDE_DIR="${SOURCE_DIR}/android_stubs"
mkdir -p "${STUB_INCLUDE_DIR}/cutils"
mkdir -p "${STUB_INCLUDE_DIR}/log"

# Copy zstd headers from host for libarchive cross-compilation
# libarchive subproject needs zstd.h but NDK doesn't include it
if [ -f /usr/include/zstd.h ]; then
    cp /usr/include/zstd.h "${STUB_INCLUDE_DIR}/"
    log_info "Copied zstd.h to stub headers"
fi

# Create stub android_lf.h (libarchive large file support for Android)
# This is needed because libarchive detects Android and includes android_lf.h
cat > "${STUB_INCLUDE_DIR}/android_lf.h" << 'STUBHEADER'
#ifndef ANDROID_LF_H
#define ANDROID_LF_H
/* Stub android_lf.h for NDK cross-compilation
 * Libarchive uses this for large file support on Android.
 * On modern Android (API 21+), 64-bit off_t is standard, so this is just a stub.
 */
#include <sys/types.h>
#include <unistd.h>
/* No special definitions needed - NDK has 64-bit off_t by default for API 21+ */
#endif /* ANDROID_LF_H */
STUBHEADER

# Create stub cutils/native_handle.h
cat > "${STUB_INCLUDE_DIR}/cutils/native_handle.h" << 'STUBHEADER'
#ifndef ANDROID_NATIVE_HANDLE_H
#define ANDROID_NATIVE_HANDLE_H
/* Stub header for non-Android builds */
typedef struct native_handle {
    int version;
    int numFds;
    int numInts;
    int data[0];
} native_handle_t;
#endif /* ANDROID_NATIVE_HANDLE_H */
STUBHEADER

# Create stub log/log.h (in case anything still tries to include it)
cat > "${STUB_INCLUDE_DIR}/log/log.h" << 'STUBHEADER'
#ifndef ANDROID_LOG_H
#define ANDROID_LOG_H
/* Stub header for non-Android builds */
#define ANDROID_LOG_DEBUG 3
#define ANDROID_LOG_INFO 4
#define ANDROID_LOG_WARN 5
#define ANDROID_LOG_ERROR 6
#define LOG_TAG "MESA"
#define LOG_PRI(priority, tag, fmt, ...) ((void)0)
#define ALOGD(...) ((void)0)
#define ALOGI(...) ((void)0)
#define ALOGW(...) ((void)0)
#define ALOGE(...) ((void)0)
#endif /* ANDROID_LOG_H */
STUBHEADER

# Create stub cutils/properties.h
cat > "${STUB_INCLUDE_DIR}/cutils/properties.h" << 'STUBHEADER'
#ifndef ANDROID_CUTILS_PROPERTIES_H
#define ANDROID_CUTILS_PROPERTIES_H
/* Stub header for non-Android builds */
#define PROPERTY_VALUE_MAX 92
static inline int property_get(const char *key, char *value, const char *default_value) {
    if (default_value) {
        int len = 0;
        while (default_value[len] && len < PROPERTY_VALUE_MAX - 1) {
            value[len] = default_value[len];
            len++;
        }
        value[len] = '\0';
        return len;
    }
    value[0] = '\0';
    return 0;
}
#endif /* ANDROID_CUTILS_PROPERTIES_H */
STUBHEADER

# Create stub cutils/trace.h
cat > "${STUB_INCLUDE_DIR}/cutils/trace.h" << 'STUBHEADER'
#ifndef ANDROID_CUTILS_TRACE_H
#define ANDROID_CUTILS_TRACE_H
/* Stub header for non-Android builds */
#define ATRACE_TAG_GRAPHICS 0
#define ATRACE_ENABLED() 0
#define ATRACE_BEGIN(name) ((void)0)
#define ATRACE_END() ((void)0)
#define ATRACE_INT(name, value) ((void)0)
#define atrace_begin_body(name) ((void)0)
#define atrace_end_body() ((void)0)
#define atrace_init() ((void)0)
#endif /* ANDROID_CUTILS_TRACE_H */
STUBHEADER

log_info "Stub headers created in ${STUB_INCLUDE_DIR}"

# Create a pkg-config wrapper that blocks host-only libraries
log_info "Creating pkg-config wrapper..."
cat > /tmp/pkg-config-android << 'WRAPPER'
#!/bin/bash
# Wrapper to prevent finding host-only libraries during cross-compilation
# Block libraries that would cause linker errors or have cross-compile issues
BLOCKED_PACKAGES="spirv-tools SPIRV-Tools libarchive"
for blocked in $BLOCKED_PACKAGES; do
    if [[ "$*" == *"$blocked"* ]]; then
        exit 1
    fi
done
exec /usr/bin/pkg-config "$@"
WRAPPER
chmod +x /tmp/pkg-config-android

# Create Meson cross-file for Android aarch64 (but targeting Linux environment)
# This is the Termux approach: build for Linux, use KGSL for GPU access
# NOTE: We undefine __ANDROID__ to prevent Mesa from using Android-specific code
# paths that require cutils/trace.h and other Android system headers.
# The NDK compiler defines __ANDROID__ by default which we must override.
log_info "Creating Meson cross-file..."
cat > android-aarch64-cross.txt << EOF
[binaries]
c = '${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API}-clang'
cpp = '${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API}-clang++'
ar = '${NDK_TOOLCHAIN}/bin/llvm-ar'
strip = '${NDK_TOOLCHAIN}/bin/llvm-strip'
c_ld = '${NDK_TOOLCHAIN}/bin/ld.lld'
cpp_ld = '${NDK_TOOLCHAIN}/bin/ld.lld'
pkgconfig = '/tmp/pkg-config-android'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[built-in options]
# Standard flags for cross-compilation
# Include android_stubs directory for stub headers like android_lf.h
# Include libelf headers from our cross-compiled build
c_args = ['-D__USE_GNU', '-I${SOURCE_DIR}/android_stubs', '-I${LIBELF_PREFIX}/include']
cpp_args = ['-D__USE_GNU', '-I${SOURCE_DIR}/android_stubs', '-I${LIBELF_PREFIX}/include']
c_link_args = ['-L${LIBELF_PREFIX}/lib']
cpp_link_args = ['-L${LIBELF_PREFIX}/lib']
EOF

# Create native file for build machine
cat > native.txt << EOF
[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'llvm-ar'
strip = 'llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'

[build_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF

# Configure Mesa for Turnip only (Termux approach: Linux WSI + KGSL)
log_info "Configuring Mesa for Turnip..."
rm -rf build
rm -rf "${BUILD_DIR}/install"

# Meson options based on Termux's working configuration
# Key: Use Linux platforms (not android) but with KGSL kernel backend
MESON_OPTIONS=(
    --cross-file android-aarch64-cross.txt
    --native-file native.txt
    --prefix "${BUILD_DIR}/install"
    --buildtype release
    # Linux platforms - NOT android! This is the key insight from Termux
    -Dplatforms=
    # Vulkan only, no OpenGL/EGL
    -Dgallium-drivers=
    -Dvulkan-drivers=freedreno
    # KGSL backend for Qualcomm Adreno GPUs (works on Android kernel)
    -Dfreedreno-kmds=kgsl
    # Disable features we don't need
    -Degl=disabled
    -Dgles1=disabled
    -Dgles2=disabled
    -Dglx=disabled
    -Dopengl=false
    -Dllvm=disabled
    -Dshared-glapi=disabled
    -Dgbm=disabled
    # Disable zstd - headers not available in NDK sysroot
    -Dzstd=disabled
    # Disable xmlconfig - requires expat which is not in NDK sysroot
    -Dxmlconfig=disabled
    # Build options
    -Db_lto=false
    -Dstrip=true
)

meson setup build "${MESON_OPTIONS[@]}"

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

# Find and copy the Turnip shared library
TURNIP_LIB=$(find "${BUILD_DIR}/install" -name "libvulkan_freedreno.so" | head -1)
if [ -z "${TURNIP_LIB}" ]; then
    TURNIP_LIB=$(find "${BUILD_DIR}/install" -name "vulkan_freedreno.so" | head -1)
fi

if [ -n "${TURNIP_LIB}" ]; then
    cp -v "${TURNIP_LIB}" "${BUNDLE_DIR}/lib/libvulkan_freedreno.so"
else
    log_error "Could not find Turnip library!"
    find "${BUILD_DIR}/install" -name "*.so" -type f
    exit 1
fi

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
log_info "Stripping binaries..."
find "${BUNDLE_DIR}" -type f -name "*.so" -exec "${NDK_TOOLCHAIN}/bin/llvm-strip" --strip-unneeded {} \;

# Generate manifest
log_info "Generating manifest..."
cat > "${BUNDLE_DIR}/manifest.json" << EOF
{
  "id": "${BUNDLE_ID}",
  "type": "turnip",
  "version": "${MESA_VERSION}",
  "abi": "arm64-v8a",
  "sha256": "PLACEHOLDER",
  "downloadUrl": "https://github.com/ferencboi/turnstone-bundles/releases/download/turnip-${MESA_VERSION}/${BUNDLE_ID}.tar.zst",
  "sizeBytes": 0,
  "compatibilityTags": ["adreno-600", "adreno-700"],
  "requiredVulkanExtensions": [],
  "minAndroidSdk": 29,
  "releaseNotes": "Mesa Turnip ${MESA_VERSION} - Vulkan driver for Qualcomm Adreno GPUs"
}
EOF

# Package
log_info "Packaging bundle..."
ARCHIVE="${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
cd "${BUILD_DIR}"
tar -I 'zstd -19' -cvf "${ARCHIVE}" "${BUNDLE_ID}"
SHA256=$(sha256sum "${ARCHIVE}" | awk '{print $1}')

log_info "========================================="
log_info "Mesa Turnip build complete!"
log_info "Archive: ${ARCHIVE}"
log_info "SHA-256: ${SHA256}"
log_info "========================================="

# Output for CI
echo "BUNDLE_ARCHIVE=${ARCHIVE}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_SHA256=${SHA256}" >> "${OUTPUT_DIR}/build-info.txt"
echo "BUNDLE_ID=${BUNDLE_ID}" >> "${OUTPUT_DIR}/build-info.txt"

