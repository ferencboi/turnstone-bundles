# Turnstone Bundles

Runtime bundles (Wine, box64, DXVK, Mesa Turnip) for the Turnstone Android app.

## Repository Structure

```
turnstone-bundles/
    README.md
    bundle-index.json           # Index of all available bundles
    compatibility-matrix.json   # Known-good bundle combinations
    build/
        docker/
            Dockerfile.base     # Base build image with Android NDK
        scripts/
            common.sh           # Shared build functions
        wine/
            Dockerfile
            build-wine.sh
            patches/            # Wine Android patches
        box64/
            Dockerfile
            build-box64.sh
            patches/
        dxvk/
            Dockerfile
            build-dxvk.sh
            patches/
        turnip/
            Dockerfile
            build-turnip.sh
            patches/
        build-all.sh            # Build all bundles
    scripts/
        create-release.sh       # Helper for releases
        update-index.sh         # Update bundle index
```

## Building Bundles

### Prerequisites

- Docker (or Podman)
- ~20GB disk space for build
- Internet connection for downloading sources

### Quick Start

```bash
# Build all bundles with default versions
cd build
./build-all.sh

# Or build individual bundles
docker build -t turnstone-build-base -f docker/Dockerfile.base docker/
docker build -t turnstone-box64-builder -f box64/Dockerfile box64/
docker run --rm -v $(pwd)/output:/output turnstone-box64-builder 0.2.8
```

### Versions

Set environment variables to customize versions:

```bash
export WINE_VERSION=9.0
export BOX64_VERSION=0.2.8
export DXVK_VERSION=2.4
export TURNIP_VERSION=24.1.0
./build-all.sh
```

## Bundle Components

### Wine
Windows compatibility layer. Cross-compiled for Android arm64.
- Source: https://gitlab.winehq.org/wine/wine
- Requires: box64 for x86_64 Windows apps

### box64
x86_64 Linux emulator for ARM64. Enables running x86_64 Wine on ARM devices.
- Source: https://github.com/ptitSeb/box64
- Native Android support via CMake

### DXVK
DirectX 9/10/11 to Vulkan translation layer. Built as Windows DLLs.
- Source: https://github.com/doitsujin/dxvk
- Cross-compiled with MinGW

### Mesa Turnip
Open-source Vulkan driver for Qualcomm Adreno GPUs.
- Source: https://gitlab.freedesktop.org/mesa/mesa
- Provides better Vulkan performance than stock drivers on supported devices

## Releases

Each bundle is released as a separate GitHub Release:
- Tag format: `{component}-{version}` (e.g., `wine-9.0`)
- Asset: `{component}-{version}-arm64.tar.zst`

The `bundle-index.json` is updated with each release and published to `index-latest`.

## Bundle Archive Format

```
{component}-{version}-arm64.tar.zst
    manifest.json       # Bundle metadata with SHA-256
    bin/                # Executables
    lib/                # Shared libraries
    share/              # Data files (optional)
```

## Adding Patches

Place `.patch` files in the component's `patches/` directory:

```bash
# Example: Add Wine Android compatibility patch
cp my-wine-fix.patch build/wine/patches/
```

Patches are applied automatically during build.

## Security

- All downloads use HTTPS
- SHA-256 verification required for all bundles
- Bundles are built from official upstream sources

