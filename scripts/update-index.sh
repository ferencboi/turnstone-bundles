#!/bin/bash
# Update bundle-index.json in the GitHub release
# This script updates the index release with the latest bundle-index.json
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Repository set up as origin remote

set -e

REPO="ferencboi/turnstone-bundles"
INDEX_TAG="index-latest"

echo "Updating bundle-index.json in release $INDEX_TAG..."

# Check if release exists, create if not
if ! gh release view "$INDEX_TAG" --repo "$REPO" > /dev/null 2>&1; then
    echo "Creating index release..."
    gh release create "$INDEX_TAG" \
        --repo "$REPO" \
        --title "Bundle Index" \
        --notes "Latest bundle index and compatibility matrix. Auto-updated with each bundle release."
fi

# Upload/update files
echo "Uploading bundle-index.json..."
gh release upload "$INDEX_TAG" \
    --repo "$REPO" \
    --clobber \
    bundle-index.json

echo "Uploading compatibility-matrix.json..."
gh release upload "$INDEX_TAG" \
    --repo "$REPO" \
    --clobber \
    compatibility-matrix.json

echo "Done! Index updated at:"
echo "https://github.com/$REPO/releases/download/$INDEX_TAG/bundle-index.json"
echo "https://github.com/$REPO/releases/download/$INDEX_TAG/compatibility-matrix.json"

