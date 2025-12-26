#!/bin/bash
# =============================================================================
# Wine Build Script for Turnstone
# =============================================================================
#
# Builds Wine for Linux x86_64 (runs under box64 on Android ARM64)
#
# Wine is NOT cross-compiled for Android. Instead we build a native Linux x86_64
# Wine which is then executed by box64 (x86_64 emulator) on the Android device.
# This is the same approach used by Winlator and Termux.
#
# The WoW64 mode (Wine 9.x+) allows a single 64-bit Wine build to run both
# 32-bit and 64-bit Windows applications without needing a separate 32-bit build.
#
# Usage:
#   ./build-wine.sh [version] [profile]
#
# Examples:
#   ./build-wine.sh 9.22           # Build with 'full' profile (default)
#   ./build-wine.sh 9.22 gaming    # Build with 'gaming' profile
#   ./build-wine.sh 9.22 full      # Build with 'full' profile
#
# Profiles:
#   full   - All features, ~1.4GB (development/testing)
#   gaming - Stripped for games, ~150-200MB (production)
#
# See: .github/WINE_RUNTIME_PROFILES_PLAN.md for architecture details
# =============================================================================

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================

WINE_VERSION="${1:-9.22}"
PROFILE_NAME="${2:-full}"

WINE_URL_BASE="https://dl.winehq.org/wine/source"
BUILD_DIR="/build/wine-build"
SOURCE_DIR="${BUILD_DIR}/wine-${WINE_VERSION}"
BUILD_64_DIR="${BUILD_DIR}/build64"
INSTALL_DIR="${BUILD_DIR}/install"
OUTPUT_DIR="/output"
PROFILES_DIR="/build/profiles"

# Settings schema version - increment when schema changes
SETTINGS_SCHEMA_VERSION=1

# =============================================================================
# LOGGING
# =============================================================================

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_section() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

# =============================================================================
# PROFILE LOADING
# =============================================================================

load_profile() {
    local profile_file="${PROFILES_DIR}/${PROFILE_NAME}.profile"
    
    if [ ! -f "$profile_file" ]; then
        log_error "Profile not found: ${PROFILE_NAME}"
        log_info "Available profiles:"
        ls -1 "${PROFILES_DIR}"/*.profile 2>/dev/null | xargs -n1 basename | sed 's/.profile$/  /' || echo "  (none)"
        exit 1
    fi
    
    log_info "Loading profile: ${PROFILE_NAME}"
    
    # Source the profile (defines CONFIGURE_FLAGS, CAPABILITIES, etc.)
    source "$profile_file"
    
    log_info "  Name: ${PROFILE_NAME}"
    log_info "  Target size: ${PROFILE_TARGET_SIZE:-unknown}"
    log_info "  Description: ${PROFILE_DESCRIPTION:-none}"
}

# =============================================================================
# WINE SOURCE URL
# =============================================================================

get_wine_url() {
    # Determine Wine source URL (stable vs development)
    # Stable versions: X.0 (e.g., 9.0, 10.0)
    # Development versions: X.Y where Y != 0 (e.g., 9.1, 9.22)
    local major_version=$(echo "$WINE_VERSION" | cut -d. -f1)
    local minor_version=$(echo "$WINE_VERSION" | cut -d. -f2)
    
    if [ "$minor_version" = "0" ]; then
        echo "${WINE_URL_BASE}/${major_version}.0/wine-${WINE_VERSION}.tar.xz"
    else
        echo "${WINE_URL_BASE}/${major_version}.x/wine-${WINE_VERSION}.tar.xz"
    fi
}

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

download_source() {
    local wine_url=$(get_wine_url)
    
    log_section "Downloading Wine ${WINE_VERSION}"
    log_info "URL: ${wine_url}"
    
    cd "${BUILD_DIR}"
    if [ ! -f "wine-${WINE_VERSION}.tar.xz" ]; then
        wget -q --show-progress "${wine_url}" || {
            log_error "Failed to download Wine. Check if version ${WINE_VERSION} exists."
            log_error "URL: ${wine_url}"
            exit 1
        }
    else
        log_info "Source already downloaded, reusing..."
    fi
    
    log_info "Extracting Wine source..."
    rm -rf "${SOURCE_DIR}"
    tar xf "wine-${WINE_VERSION}.tar.xz"
}

apply_patches() {
    local patch_dir="/build/patches"
    
    if [ -d "${patch_dir}" ] && [ "$(ls -A ${patch_dir}/*.patch 2>/dev/null)" ]; then
        log_section "Applying Patches"
        cd "${SOURCE_DIR}"
        for patch in "${patch_dir}"/*.patch; do
            log_info "  Applying $(basename $patch)..."
            patch -p1 < "$patch"
        done
    fi
}

regenerate_build_files() {
    log_info "Regenerating build files..."
    cd "${SOURCE_DIR}"
    ./tools/make_requests 2>/dev/null || true
    ./tools/make_specfiles 2>/dev/null || true
    autoreconf -f 2>/dev/null || true
}

configure_wine() {
    log_section "Configuring Wine (Profile: ${PROFILE_NAME})"
    
    cd "${BUILD_64_DIR}"
    
    # Build configure command from profile
    local configure_cmd="${SOURCE_DIR}/configure --prefix=${INSTALL_DIR}"
    
    # Add flags from profile
    for flag in "${CONFIGURE_FLAGS[@]}"; do
        configure_cmd="${configure_cmd} ${flag}"
    done
    
    # Add compiler flags
    local cflags="${PROFILE_CFLAGS:--O2 -march=x86-64 -mtune=generic}"
    local ldflags="${PROFILE_LDFLAGS:-}"
    
    configure_cmd="${configure_cmd} CFLAGS=\"${cflags}\""
    configure_cmd="${configure_cmd} CXXFLAGS=\"${cflags}\""
    if [ -n "${ldflags}" ]; then
        configure_cmd="${configure_cmd} LDFLAGS=\"${ldflags}\""
    fi
    
    log_info "Configure flags:"
    for flag in "${CONFIGURE_FLAGS[@]}"; do
        echo "    ${flag}"
    done
    
    # Execute configure
    eval "$configure_cmd"
}

build_wine() {
    log_section "Building Wine"
    log_info "This may take 30-60 minutes depending on hardware..."
    
    cd "${BUILD_64_DIR}"
    make -j$(nproc)
}

install_wine() {
    log_section "Installing Wine"
    
    cd "${BUILD_64_DIR}"
    make install
}

# =============================================================================
# POST-PROCESSING
# =============================================================================

create_bundle_structure() {
    log_section "Creating Bundle Structure"
    
    # Bundle naming: wine-VERSION-PROFILE-ARCH (or wine-VERSION-ARCH for full)
    if [ "$PROFILE_NAME" = "full" ]; then
        BUNDLE_ID="wine-${WINE_VERSION}-x86_64"
    else
        BUNDLE_ID="wine-${WINE_VERSION}-${PROFILE_NAME}-x86_64"
    fi
    
    BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_ID}"
    
    rm -rf "${BUNDLE_DIR}"
    mkdir -p "${BUNDLE_DIR}/bin" "${BUNDLE_DIR}/lib" "${BUNDLE_DIR}/share"
    
    # Copy bin directory
    log_info "Copying binaries..."
    cp -r "${INSTALL_DIR}/bin/"* "${BUNDLE_DIR}/bin/"
    
    # Copy lib directory (Wine libraries and DLLs)
    log_info "Copying libraries..."
    if [ -d "${INSTALL_DIR}/lib" ]; then
        cp -r "${INSTALL_DIR}/lib/"* "${BUNDLE_DIR}/lib/"
    fi
    if [ -d "${INSTALL_DIR}/lib64" ]; then
        cp -r "${INSTALL_DIR}/lib64/"* "${BUNDLE_DIR}/lib/"
    fi
    
    # Copy share directory (Wine data files)
    log_info "Copying data files..."
    if [ -d "${INSTALL_DIR}/share/wine" ]; then
        cp -r "${INSTALL_DIR}/share/wine" "${BUNDLE_DIR}/share/"
    fi
}

apply_removals() {
    if [ ${#REMOVE_PATTERNS[@]} -eq 0 ]; then
        log_info "No removal patterns defined, skipping..."
        return
    fi
    
    log_section "Applying Removal Patterns"
    
    local removed_count=0
    local removed_size=0
    
    for pattern in "${REMOVE_PATTERNS[@]}"; do
        # Handle glob patterns - find matching files
        while IFS= read -r -d '' match; do
            if [ -e "$match" ]; then
                local size=$(du -sb "$match" 2>/dev/null | cut -f1 || echo 0)
                log_info "  Removing: ${match#${BUNDLE_DIR}/}"
                rm -rf "$match"
                removed_count=$((removed_count + 1))
                removed_size=$((removed_size + size))
            fi
        done < <(find "${BUNDLE_DIR}" -path "${BUNDLE_DIR}/${pattern}" -print0 2>/dev/null || true)
    done
    
    if [ $removed_count -gt 0 ]; then
        log_info "Removed ${removed_count} items, saved approximately $(numfmt --to=iec $removed_size 2>/dev/null || echo "${removed_size} bytes")"
    fi
}

strip_binaries() {
    local strip_level="${STRIP_LEVEL:-debug}"
    
    log_section "Stripping Binaries (Level: ${strip_level})"
    
    case "${strip_level}" in
        none)
            log_info "Skipping strip (STRIP_LEVEL=none)"
            ;;
        debug)
            # Strip debug symbols only - safer for DLLs (recommended)
            log_info "Stripping debug symbols (--strip-debug)..."
            find "${BUNDLE_DIR}" -name "*.dll" -exec strip --strip-debug {} \; 2>/dev/null || true
            find "${BUNDLE_DIR}" -name "*.exe" -exec strip --strip-debug {} \; 2>/dev/null || true
            find "${BUNDLE_DIR}" -name "*.so*" -exec strip --strip-debug {} \; 2>/dev/null || true
            find "${BUNDLE_DIR}/bin" -type f -executable -exec strip --strip-debug {} \; 2>/dev/null || true
            ;;
        full)
            # Aggressive strip - may break some anti-cheat
            log_info "Stripping all symbols (--strip-unneeded)..."
            find "${BUNDLE_DIR}" -name "*.dll" -exec strip --strip-unneeded {} \; 2>/dev/null || true
            find "${BUNDLE_DIR}" -name "*.exe" -exec strip --strip-unneeded {} \; 2>/dev/null || true
            find "${BUNDLE_DIR}" -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true
            find "${BUNDLE_DIR}/bin" -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true
            ;;
        *)
            log_warn "Unknown STRIP_LEVEL: ${strip_level}, defaulting to debug"
            find "${BUNDLE_DIR}" -name "*.so*" -exec strip --strip-debug {} \; 2>/dev/null || true
            ;;
    esac
}

generate_capabilities_json() {
    # Generate JSON array of capabilities from CAPABILITIES bash array
    local json="["
    local first=true
    
    for cap in "${CAPABILITIES[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            json="${json},"
        fi
        json="${json}\"${cap}\""
    done
    
    json="${json}]"
    echo "$json"
}

generate_build_flags_json() {
    # Generate JSON object with included/excluded flags
    local included="["
    local excluded="["
    local first_inc=true
    local first_exc=true
    
    for flag in "${CONFIGURE_FLAGS[@]}"; do
        if [[ "$flag" == --with-* ]]; then
            [ "$first_inc" = true ] && first_inc=false || included="${included},"
            included="${included}\"${flag}\""
        elif [[ "$flag" == --without-* ]]; then
            [ "$first_exc" = true ] && first_exc=false || excluded="${excluded},"
            excluded="${excluded}\"${flag}\""
        fi
    done
    
    included="${included}]"
    excluded="${excluded}]"
    
    echo "{\"included\":${included},\"excluded\":${excluded}}"
}

create_manifest() {
    log_section "Creating Manifest"
    
    # Calculate installed size
    local installed_size=$(du -sb "${BUNDLE_DIR}" | cut -f1)
    
    # Generate capabilities and build flags JSON
    local capabilities_json=$(generate_capabilities_json)
    local build_flags_json=$(generate_build_flags_json)
    
    cat > "${BUNDLE_DIR}/manifest.json" << EOF
{
  "id": "${BUNDLE_ID}",
  "type": "wine",
  "version": "${WINE_VERSION}",
  "profile": "${PROFILE_NAME}",
  "arch": "x86_64",
  "buildDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "installedSizeBytes": ${installed_size},
  "settingsSchemaVersion": ${SETTINGS_SCHEMA_VERSION},
  "capabilities": ${capabilities_json},
  "buildFlags": ${build_flags_json},
  "configurableSettings": [
    "environment.WINEDEBUG",
    "environment.WINEESYNC",
    "environment.WINEFSYNC",
    "environment.WINE_LARGE_ADDRESS_AWARE",
    "environment.WINEDLLOVERRIDES",
    "registry.wine.direct3d.*",
    "registry.wine.x11.*",
    "dxvk.*",
    "turnip.*",
    "box64.*"
  ],
  "description": "${PROFILE_DESCRIPTION:-Wine ${WINE_VERSION}}",
  "notes": "WoW64 mode enabled - supports both 32-bit and 64-bit Windows applications. Profile: ${PROFILE_NAME}"
}
EOF
    
    log_info "Manifest created with:"
    log_info "  - ${#CAPABILITIES[@]} capabilities"
    log_info "  - Settings schema version: ${SETTINGS_SCHEMA_VERSION}"
    log_info "  - Installed size: $(numfmt --to=iec ${installed_size} 2>/dev/null || echo "${installed_size} bytes")"
}

package_bundle() {
    log_section "Packaging Bundle"
    
    cd "${BUILD_DIR}"
    
    local archive="${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
    
    log_info "Creating archive: ${BUNDLE_ID}.tar.zst"
    log_info "Compression: zstd level 19 (maximum)"
    
    tar -I 'zstd -19 -T0' -cf "${archive}" "${BUNDLE_ID}"
    
    # Calculate SHA-256
    local sha256=$(sha256sum "${archive}" | cut -d' ' -f1)
    echo "${sha256}  ${BUNDLE_ID}.tar.zst" > "${archive}.sha256"
    
    # Get sizes
    local archive_size=$(stat -c%s "${archive}")
    local installed_size=$(du -sb "${BUNDLE_DIR}" | cut -f1)
    
    log_section "Build Complete!"
    echo ""
    log_info "Bundle ID:       ${BUNDLE_ID}"
    log_info "Profile:         ${PROFILE_NAME}"
    log_info "Wine Version:    ${WINE_VERSION}"
    log_info "Archive:         ${archive}"
    log_info "Archive Size:    $(numfmt --to=iec ${archive_size} 2>/dev/null || echo "${archive_size} bytes")"
    log_info "Installed Size:  $(numfmt --to=iec ${installed_size} 2>/dev/null || echo "${installed_size} bytes")"
    log_info "SHA-256:         ${sha256}"
    log_info "Capabilities:    ${CAPABILITIES[*]}"
    echo ""
    
    # Output for CI/automation
    cat > "${OUTPUT_DIR}/build-info.txt" << EOF
BUNDLE_ARCHIVE=${archive}
BUNDLE_SHA256=${sha256}
BUNDLE_SIZE=${archive_size}
BUNDLE_INSTALLED_SIZE=${installed_size}
BUNDLE_ID=${BUNDLE_ID}
WINE_VERSION=${WINE_VERSION}
PROFILE_NAME=${PROFILE_NAME}
SETTINGS_SCHEMA_VERSION=${SETTINGS_SCHEMA_VERSION}
CAPABILITIES=${CAPABILITIES[*]}
EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_section "Turnstone Wine Build System"
    log_info "Wine Version:    ${WINE_VERSION}"
    log_info "Profile:         ${PROFILE_NAME}"
    log_info "Output:          ${OUTPUT_DIR}"
    log_info "Schema Version:  ${SETTINGS_SCHEMA_VERSION}"
    
    # Create directories
    mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${BUILD_64_DIR}" "${INSTALL_DIR}"
    
    # Load build profile
    load_profile
    
    # Build steps
    download_source
    apply_patches
    regenerate_build_files
    configure_wine
    build_wine
    install_wine
    
    # Post-processing
    create_bundle_structure
    apply_removals
    strip_binaries
    create_manifest
    package_bundle
    
    log_info "Done! Bundle ready at: ${OUTPUT_DIR}/${BUNDLE_ID}.tar.zst"
}

main "$@"

