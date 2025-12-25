# Turnstone Bundles

Runtime bundles for **Turnstone**, a Winlator-style Android app for running Windows games on ARM64 devices with Qualcomm Adreno GPUs.

> **🎮 Gaming-Focused:** This project optimizes for gaming performance, not general Windows compatibility.  
> See [GAMING_ARCHITECTURE.md](.github/GAMING_ARCHITECTURE.md) for the technical strategy.

## Project Goal

Run Windows x86/x64 games on Android ARM64 through a modular stack:
- **Box64**: x86_64 → ARM64 CPU translation
- **Wine**: Windows compatibility layer (runs under Box64)
- **DXVK**: DirectX → Vulkan translation
- **Mesa Turnip**: High-performance Vulkan driver for Adreno GPUs

## Current Status (2025-12-24)

| Bundle | Version | Status | Notes |
|--------|---------|--------|-------|
| box64 | 0.3.8 | ✅ Released | Native ARM64 dynarec |
| DXVK | 2.5.3 | ✅ Released | DX9/10/11 → Vulkan |
| Turnip | 25.3.2 | ✅ Released | Adreno 6xx/7xx Vulkan |
| Wine | 9.22 | ✅ Released | Linux x86_64 for Box64 (218 MB) |

**Build Status:** See [BUILD_STATUS.md](BUILD_STATUS.md) for detailed progress and lessons learned.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows Game (.exe)                       │
├─────────────────────────────────────────────────────────────┤
│  DXVK (DirectX → Vulkan)  │  Wine (Windows API → Linux)    │
├─────────────────────────────────────────────────────────────┤
│              Box64 (x86_64 → ARM64 JIT)                     │
├─────────────────────────────────────────────────────────────┤
│              Turnip (Vulkan for Adreno)                     │
├─────────────────────────────────────────────────────────────┤
│                    Android ARM64                             │
└─────────────────────────────────────────────────────────────┘
```

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
Windows compatibility layer. **Built for Linux x86_64** and executed under Box64.
- Source: https://gitlab.winehq.org/wine/wine
- **Architecture:** Linux x86_64 binary (NOT cross-compiled for Android)
- Uses WoW64 mode (Wine 9.x+) for 32-bit and 64-bit Windows app support
- Future: Gaming-optimized builds with stripped non-gaming components

> ⚠️ **Note:** Wine runs as a Linux x86_64 process translated by Box64. This is the same approach used by Winlator and Termux Wine.

### box64
x86_64 → ARM64 dynamic binary translator (JIT). The foundation that makes Wine run on ARM.
- Source: https://github.com/ptitSeb/box64
- **Architecture:** Native ARM64 binary
- Features: Dynarec with aggressive gaming optimizations
- Translates x86_64 Wine into ARM64 instructions at runtime

### DXVK
DirectX 9/10/11 to Vulkan translation layer. Enables DirectX games to run on Vulkan.
- Source: https://github.com/doitsujin/dxvk
- **Architecture:** Windows DLLs (x86/x64) - MinGW cross-compiled
- Replaces Wine's DirectX implementation with high-performance Vulkan calls
- Async shader compilation reduces stutter

### Mesa Turnip
Open-source Vulkan driver for Qualcomm Adreno GPUs. Better performance than stock drivers.
- Source: https://gitlab.freedesktop.org/mesa/mesa
- **Architecture:** ARM64 shared library
- Supports Adreno 6xx and 7xx (experimental) GPU series
- Built with KGSL backend for Android kernel compatibility

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

