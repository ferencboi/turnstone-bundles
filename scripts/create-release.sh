#!/bin/bash
# Create a new bundle release
# Usage: ./create-release.sh <component> <version> <archive-path>
#
# Example: ./create-release.sh wine 9.0 /path/to/wine-9.0-arm64.tar.zst

set -e

COMPONENT="$1"
VERSION="$2"
ARCHIVE="$3"

if [ -z "$COMPONENT" ] || [ -z "$VERSION" ] || [ -z "$ARCHIVE" ]; then
    echo "Usage: $0 <component> <version> <archive-path>"
    echo "Example: $0 wine 9.0 /path/to/wine-9.0-arm64.tar.zst"
    exit 1
fi

if [ ! -f "$ARCHIVE" ]; then
    echo "Error: Archive not found: $ARCHIVE"
    exit 1
fi

# Calculate SHA-256
SHA256=$(sha256sum "$ARCHIVE" | cut -d' ' -f1)
SIZE=$(stat -c%s "$ARCHIVE")

echo "Component: $COMPONENT"
echo "Version: $VERSION"
echo "Archive: $ARCHIVE"
echo "SHA-256: $SHA256"
echo "Size: $SIZE bytes"

# Generate manifest entry
cat << EOF

Add this entry to bundle-index.json:

{
  "id": "${COMPONENT}-${VERSION}-arm64",
  "type": "${COMPONENT}",
  "version": "${VERSION}",
  "abi": "arm64-v8a",
  "sha256": "${SHA256}",
  "downloadUrl": "https://github.com/ferencboi/turnstone-bundles/releases/download/${COMPONENT}-${VERSION}/${COMPONENT}-${VERSION}-arm64.tar.zst",
  "sizeBytes": ${SIZE},
  "compatibilityTags": [],
  "requiredVulkanExtensions": [],
  "minAndroidSdk": 29,
  "releaseNotes": "${COMPONENT} ${VERSION} release"
}

To create the GitHub release:
1. Create a new release with tag: ${COMPONENT}-${VERSION}
2. Upload the archive: $ARCHIVE
3. Update bundle-index.json with the entry above
4. Commit and push bundle-index.json
5. Re-upload bundle-index.json to the 'index' release (or latest)

EOF

