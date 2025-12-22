# Turnstone Bundles

Private repository for Turnstone runtime bundles distribution.

## Overview

This repository hosts the runtime bundles (Wine, box64, DXVK, Mesa Turnip) for the Turnstone Android app.
Bundles are distributed via GitHub Releases.

## Repository Structure

```
turnstone-bundles/
    README.md
    bundle-index.json           # Index of all available bundles
    compatibility-matrix.json   # Known-good bundle combinations
    scripts/
        build-wine.sh           # Build scripts for each component
        build-box64.sh
        build-dxvk.sh
        build-turnip.sh
        create-release.sh       # Script to create a new release
    templates/
        manifest-template.json  # Template for bundle manifests
```

## Bundle Index

The `bundle-index.json` file lists all available bundles with their metadata:
- Download URLs (pointing to GitHub Releases)
- SHA-256 hashes for integrity verification
- Compatibility tags (device/GPU hints)
- Size information

## Releases

Each bundle is released as a separate GitHub Release with:
- Tag format: `{component}-{version}` (e.g., `wine-9.5`, `dxvk-2.4`)
- Asset: `{component}-{version}-arm64.tar.zst`
- The bundle-index.json is updated with each release

## Security

- All bundles require SHA-256 verification before installation
- Only HTTPS download URLs are allowed
- Bundles are signed (future: GPG signatures)

## Building Bundles

See individual build scripts in `scripts/` directory.
Bundles are cross-compiled for arm64-v8a Android target.

## Usage

The Turnstone app fetches:
1. `bundle-index.json` from the latest release
2. Selected bundle archives from their respective releases
3. Verifies SHA-256 hash before extraction

## Private Repository

This repository is private. Access is restricted to authorized developers.
Do not share bundle URLs or hashes publicly.

