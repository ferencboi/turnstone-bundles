#!/bin/bash
# Build all Turnstone bundles
#
# Usage: ./build-all.sh [--push]
#   --push: Push built bundles to GitHub releases
#
# Environment variables:
#   WINE_VERSION: Wine version to build (default: 9.0)
#   BOX64_VERSION: box64 version to build (default: 0.2.8)
#   DXVK_VERSION: DXVK version to build (default: 2.4)
#   TURNIP_VERSION: Mesa Turnip version to build (default: 24.1.0)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}"
OUTPUT_DIR="${SCRIPT_DIR}/output"

# Default versions
WINE_VERSION="${WINE_VERSION:-9.0}"
BOX64_VERSION="${BOX64_VERSION:-0.3.8}"
DXVK_VERSION="${DXVK_VERSION:-2.4}"
TURNIP_VERSION="${TURNIP_VERSION:-24.1.0}"

PUSH_RELEASES=false
if [ "$1" = "--push" ]; then
    PUSH_RELEASES=true
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Build base Docker image first
log_info "Building base Docker image..."
docker build -t turnstone-build-base -f "${BUILD_DIR}/docker/Dockerfile.base" "${BUILD_DIR}/docker"

# Function to build a bundle
build_bundle() {
    local name="$1"
    local version="$2"
    local profile="${3:-}"
    local build_dir="${BUILD_DIR}/${name}"
    local container_name="turnstone-${name}-build-$$"

    log_info "========================================="
    log_info "Building ${name} ${version}${profile:+ (profile: $profile)}"
    log_info "========================================="

    # Build the Docker image for this bundle
    docker build -t "turnstone-${name}-builder" \
        --build-arg SCRIPTS_DIR="${BUILD_DIR}/scripts" \
        -f "${build_dir}/Dockerfile" \
        "${build_dir}"

    # Run the build (NO --rm flag - keep container on failure for debugging)
    # Container will be cleaned up after successful packaging
    local build_args=("${version}")
    [ -n "${profile}" ] && build_args+=("${profile}")

    docker run \
        --name "${container_name}" \
        -v "${OUTPUT_DIR}:/output" \
        -v "${BUILD_DIR}/scripts:/build/scripts:ro" \
        "turnstone-${name}-builder" \
        "${build_args[@]}"

    # Build succeeded - clean up container
    log_info "Build succeeded, cleaning up container..."
    docker rm "${container_name}" >/dev/null 2>&1 || true

    log_info "${name} ${version} build complete!"
}

# Build all bundles
log_info "Starting Turnstone bundle builds..."
log_info "Versions: Wine=${WINE_VERSION}, box64=${BOX64_VERSION}, DXVK=${DXVK_VERSION}, Turnip=${TURNIP_VERSION}"

# box64 (simplest, start here)
build_bundle "box64" "${BOX64_VERSION}"

# DXVK
build_bundle "dxvk" "${DXVK_VERSION}"

# Turnip
build_bundle "turnip" "${TURNIP_VERSION}"

# Wine (most complex, do last)
build_bundle "wine" "${WINE_VERSION}"

# Generate updated bundle-index.json
log_info "Generating bundle-index.json..."

cat > "${OUTPUT_DIR}/bundle-index.json" << EOF
{
  "schemaVersion": 1,
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "bundles": [
EOF

# Read build info and generate bundle entries
first=true
for info_file in "${OUTPUT_DIR}/"*-build-info.txt; do
    if [ -f "${info_file}" ]; then
        source "${info_file}"

        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "${OUTPUT_DIR}/bundle-index.json"
        fi

        # This is a simplified version - in practice, read from manifest.json
        cat >> "${OUTPUT_DIR}/bundle-index.json" << ENTRY
    {
      "id": "${BUNDLE_ID}",
      "sha256": "${BUNDLE_SHA256}",
      "sizeBytes": $(stat -c%s "${BUNDLE_ARCHIVE}")
    }
ENTRY
    fi
done

cat >> "${OUTPUT_DIR}/bundle-index.json" << EOF

  ]
}
EOF

log_info "========================================="
log_info "All builds complete!"
log_info "Output directory: ${OUTPUT_DIR}"
log_info "========================================="

ls -la "${OUTPUT_DIR}"

# Push to GitHub releases if requested
if [ "$PUSH_RELEASES" = true ]; then
    log_info "Pushing to GitHub releases..."

    # This would use gh CLI to create releases
    # For now, just print instructions
    log_warn "Automatic push not yet implemented"
    log_info "To manually upload:"
    log_info "  gh release create wine-${WINE_VERSION} ${OUTPUT_DIR}/wine-${WINE_VERSION}-arm64.tar.zst"
    log_info "  gh release create box64-${BOX64_VERSION} ${OUTPUT_DIR}/box64-${BOX64_VERSION}-arm64.tar.zst"
    log_info "  gh release create dxvk-${DXVK_VERSION} ${OUTPUT_DIR}/dxvk-${DXVK_VERSION}-arm64.tar.zst"
    log_info "  gh release create turnip-${TURNIP_VERSION} ${OUTPUT_DIR}/turnip-${TURNIP_VERSION}-arm64.tar.zst"
fi

