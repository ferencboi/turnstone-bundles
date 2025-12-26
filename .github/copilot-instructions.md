# turnstone-bundles - AI Coding Instructions

> **Repository:** turnstone-bundles (Public)  
> **Type:** Build System + Distribution  
> **Purpose:** Build and distribute runtime bundles for the Turnstone Android app

---

## Non negotiable rule:
Do not use symbols, icons, emojis, or any non-standard Unicode symbols in code, comments, documentation, or chat responses. All content must use only standard alphanumeric characters, punctuation, and symbols appropriate to the programming language. This applies to source code, inline and block comments, markdown, API docs, and all generated communication.
Retroactively remove any such symbols from existing code or documentation when making changes.

---

## 🎮 Project Focus: Gaming on Android ARM64

**Turnstone is a Winlator-style app** for running Windows games on Android ARM64 devices with Qualcomm Adreno GPUs. This is NOT a general-purpose Windows compatibility project.

**Key Design Principles:**
- Optimize for gaming performance over broad compatibility
- Target Adreno 6xx/7xx GPUs specifically
- Modular architecture (swap components independently)
- Strip unnecessary features to reduce bundle size

**See Also:** [GAMING_ARCHITECTURE.md](GAMING_ARCHITECTURE.md) for the full technical strategy.

---

## 🚀 Quick Context

This repo builds and publishes the runtime components that the Turnstone Android app downloads:
- **Wine** - Windows compatibility layer (Linux x86_64 binary for Box64)
- **box64** - x86_64 → ARM64 JIT translator (native ARM64)
- **DXVK** - DirectX 9/10/11 → Vulkan translation (Windows DLLs via MinGW)
- **Mesa Turnip** - High-performance Vulkan driver for Adreno GPUs (ARM64)

Bundles are distributed via **GitHub Releases** as `.tar.zst` archives.

### Critical Architecture Note

**Wine is NOT cross-compiled for Android.** It is built as a Linux x86_64 binary that runs under Box64's JIT translation. This is the same approach used by Winlator and Termux.

```
┌─────────────────────────────────────────────────────────────┐
│  Windows Game (.exe)                                         │
├─────────────────────────────────────────────────────────────┤
│  DXVK (DirectX→Vulkan)  │  Wine (Win32→Linux, x86_64)      │
├─────────────────────────────────────────────────────────────┤
│  Box64 (x86_64 JIT → ARM64 native)                          │
├─────────────────────────────────────────────────────────────┤
│  Turnip (Vulkan ICD for Adreno)                             │
├─────────────────────────────────────────────────────────────┤
│  Android ARM64 + KGSL kernel driver                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Release Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Releases                              │
│  ├── wine-9.22/wine-9.22-x86_64.tar.zst    (Linux x86_64)      │
│  ├── box64-0.3.8/box64-0.3.8-arm64.tar.zst (ARM64 native)      │
│  ├── dxvk-2.5.3/dxvk-2.5.3-arm64.tar.zst   (Windows DLLs)      │
│  ├── turnip-25.3.2/turnip-25.3.2-arm64.tar.zst (ARM64)         │
│  └── index-latest/bundle-index.json, compatibility-matrix.json │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Published by CI / scripts
┌─────────────────────────────────────────────────────────────────┐
│                      Build System                                │
│  build/                                                          │
│  ├── docker/Dockerfile.base    (Android NDK base image)         │
│  ├── wine/                     (Wine x86_64 Linux build)        │
│  ├── box64/                    (box64 ARM64 build)              │
│  ├── dxvk/                     (DXVK MinGW build)               │
│  ├── turnip/                   (Mesa Turnip ARM64 build)        │
│  └── build-all.sh              (Orchestrator)                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Directory Structure

```
turnstone-bundles/
├── bundle-index.json           # Master index of all bundles
├── compatibility-matrix.json   # Known-good version combinations
├── README.md
│
├── build/                      # Build system
│   ├── docker/
│   │   └── Dockerfile.base     # Base image with Android NDK
│   ├── scripts/
│   │   └── common.sh           # Shared shell functions
│   ├── wine/
│   │   ├── Dockerfile
│   │   ├── build-wine.sh
│   │   └── patches/            # Wine patches for Android
│   ├── box64/
│   │   ├── Dockerfile
│   │   ├── build-box64.sh
│   │   └── patches/
│   ├── dxvk/
│   │   ├── Dockerfile
│   │   ├── build-dxvk.sh
│   │   └── patches/
│   ├── turnip/
│   │   ├── Dockerfile
│   │   ├── build-turnip.sh
│   │   └── patches/
│   ├── toolchains/             # Cached toolchains (gitignored)
│   └── build-all.sh            # Build all bundles
│
├── scripts/
│   ├── create-release.sh       # Helper for GitHub Releases
│   └── update-index.sh         # Update bundle-index.json
│
├── templates/
│   └── manifest-template.json  # Template for bundle manifests
│
├── dev/
│   └── mock-bundle-index.json  # For local app testing
│
└── test-bundles/               # Small test bundles for CI
    ├── wine-9.0-arm64.tar.zst
    ├── box64-0.2.8-arm64.tar.zst
    ├── dxvk-2.4-arm64.tar.zst
    └── turnip-24.1-arm64.tar.zst
```

---

## 📊 JSON Schemas

### bundle-index.json

The master index that the Turnstone app fetches to discover available bundles.

```json
{
  "schemaVersion": 1,
  "updatedAt": "2025-06-22T00:00:00Z",
  "bundles": [
    {
      "id": "wine-9.0-arm64",           // Unique ID
      "type": "wine",                    // wine | box64 | dxvk | turnip
      "version": "9.0",                  // Semantic version
      "abi": "arm64-v8a",               // Android ABI
      "sha256": "7a1ad456c8ae...",      // SHA-256 of archive
      "downloadUrl": "https://github.com/ferencboi/turnstone-bundles/releases/download/wine-9.0/wine-9.0-arm64.tar.zst",
      "sizeBytes": 123456789,
      "compatibilityTags": ["adreno-600", "adreno-700"],
      "requiredVulkanExtensions": [],
      "minAndroidSdk": 29,
      "releaseNotes": "Wine 9.0 stable release for arm64"
    }
  ]
}
```

#### Bundle Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✅ | Unique identifier (e.g., `wine-9.5-arm64`) |
| `type` | enum | ✅ | `wine`, `box64`, `dxvk`, `turnip` |
| `version` | string | ✅ | Version string |
| `abi` | string | ✅ | Android ABI (`arm64-v8a`) |
| `sha256` | string | ✅ | SHA-256 hash of the archive |
| `downloadUrl` | string | ✅ | HTTPS URL to download |
| `sizeBytes` | number | ✅ | Archive size in bytes |
| `compatibilityTags` | array | ❌ | GPU/device hints |
| `requiredVulkanExtensions` | array | ❌ | Required Vulkan extensions |
| `minAndroidSdk` | number | ❌ | Minimum Android SDK level |
| `releaseNotes` | string | ❌ | Human-readable notes |

### compatibility-matrix.json

Lists known-good combinations of bundle versions.

```json
{
  "schemaVersion": 1,
  "updatedAt": "2025-06-22T00:00:00Z",
  "compatibilitySets": [
    {
      "id": "stable-adreno-2025-06",
      "label": "stable",                 // stable | experimental | legacy
      "displayName": "Stable - June 2025 (Adreno)",
      "deviceHints": ["adreno-600", "adreno-700"],
      "bundles": {
        "wine": "9.0",
        "box64": "0.2.8",
        "dxvk": "2.4",
        "turnip": "24.1"
      },
      "notes": "Recommended stable configuration for Adreno GPUs"
    }
  ]
}
```

#### Compatibility Labels

| Label | Description |
|-------|-------------|
| `stable` | Tested, recommended for general use |
| `experimental` | Latest versions, may have issues |
| `legacy` | Older versions kept for compatibility |
| `minimal` | Basic configuration for any device |

---

## 🔨 Build System

### Prerequisites

- Docker or Podman
- ~20GB disk space
- Internet connection

### Quick Start

```bash
# Build all bundles with default versions
cd build
./build-all.sh

# Or build individual bundles
docker build -t turnstone-build-base -f docker/Dockerfile.base docker/
docker build -t turnstone-wine-builder -f wine/Dockerfile wine/
docker run --rm -v $(pwd)/output:/output turnstone-wine-builder 9.0
```

### Environment Variables

```bash
export WINE_VERSION=9.5
export BOX64_VERSION=0.2.8
export DXVK_VERSION=2.4
export TURNIP_VERSION=24.1.0
./build-all.sh
```

### Build Output

Builds produce:
```
output/
├── wine-9.5-arm64.tar.zst
├── wine-9.5-arm64.sha256
├── box64-0.2.8-arm64.tar.zst
├── box64-0.2.8-arm64.sha256
└── ...
```

---

## 📦 Bundle Archive Format

Bundles are `.tar.zst` (tar + Zstandard compression) archives.

### Internal Structure

```
wine-9.0-arm64.tar.zst
└── wine-9.0-arm64/
    ├── manifest.json       # Bundle metadata
    ├── bin/                # Executables
    │   ├── wine
    │   ├── wine64
    │   └── wineserver
    └── lib/                # Libraries
        ├── wine/
        └── ...
```

### manifest.json (inside archive)

```json
{
  "id": "wine-9.0-arm64",
  "type": "wine",
  "version": "9.0",
  "abi": "arm64-v8a",
  "buildDate": "2025-06-22T00:00:00Z",
  "sourceCommit": "abc123..."
}
```

---

## 🚀 Release Workflow

### 1. Build Bundle
```bash
cd build
./wine/build-wine.sh 9.5
```

### 2. Create GitHub Release
```bash
./scripts/create-release.sh wine 9.5 output/wine-9.5-arm64.tar.zst
```

This creates:
- Tag: `wine-9.5`
- Release: `Wine 9.5`
- Asset: `wine-9.5-arm64.tar.zst`

### 3. Update Index
```bash
./scripts/update-index.sh
```

This regenerates `bundle-index.json` from all releases and publishes to `index-latest`.

---

## 📝 Common Tasks

### Adding a New Bundle Version

1. **Build:**
   ```bash
   cd build && ./wine/build-wine.sh 10.0
   ```

2. **Release:**
   ```bash
   ./scripts/create-release.sh wine 10.0 output/wine-10.0-arm64.tar.zst
   ```

3. **Update index:**
   ```bash
   ./scripts/update-index.sh
   ```

### Adding a Patch

1. Create patch file in `build/{component}/patches/`
2. Name format: `{number}-{description}.patch` (e.g., `001-fix-android-build.patch`)
3. Patches are applied in numeric order

### Adding a New Component Type

1. Create `build/{component}/`:
   - `Dockerfile`
   - `build-{component}.sh`
   - `patches/` (if needed)
2. Update `build-all.sh`
3. Add type to `bundle-index.json` schema documentation

### Testing Locally with Turnstone App

1. Use `dev/mock-bundle-index.json` for local testing
2. Or use `test-bundles/` small archives
3. Point Turnstone app to local server or mock URL

---

## ⚠️ Constraints & Rules

### MUST
- ✅ Cross-compile for `arm64-v8a` (Android)
- ✅ Use Zstandard compression (`.tar.zst`)
- ✅ Generate SHA-256 hashes for all archives
- ✅ Include `manifest.json` inside archives
- ✅ Keep bundles reproducible (same inputs → same output)

### MUST NOT
- ❌ Include debug symbols in release bundles (strip them)
- ❌ Hardcode absolute paths
- ❌ Include test data in release archives
- ❌ Break backward compatibility in JSON schemas without version bump

### PREFER
- 🔹 Docker over Podman (for CI compatibility)
- 🔹 Staged builds for smaller images
- 🔹 Semantic versioning for bundle versions
- 🔹 Descriptive patch names

---

## 🔧 Component Build Notes

### Wine
- Source: `https://gitlab.winehq.org/wine/wine`
- **Architecture:** Linux x86_64 (NOT Android)
- Build environment: Ubuntu 22.04 container with MinGW
- WoW64 mode enables 32-bit + 64-bit support in single binary
- Output: `wine-{version}-x86_64.tar.zst`

### box64
- Source: `https://github.com/ptitSeb/box64`
- **Architecture:** Native Android ARM64
- Built with CMake + Android NDK
- ARM64 dynarec enabled for gaming performance
- Output: `box64-{version}-arm64.tar.zst`

### DXVK
- Source: `https://github.com/doitsujin/dxvk`
- **Architecture:** Windows DLLs (x86 + x64)
- Cross-compiled with MinGW (produces Windows DLLs)
- Output DLLs: `d3d9.dll`, `d3d10core.dll`, `d3d11.dll`, `dxgi.dll`
- Output: `dxvk-{version}-arm64.tar.zst` (contains Windows DLLs)

### Mesa Turnip
- Source: `https://gitlab.freedesktop.org/mesa/mesa`
- **Architecture:** Android ARM64 shared library
- Built with Meson + Android NDK, KGSL backend
- Output: `libvulkan_freedreno.so` (Vulkan ICD for Adreno)
- Output: `turnip-{version}-arm64.tar.zst`

---

## 🔗 Related

- **Turnstone** repo: The Android app that consumes these bundles
- **GAMING_ARCHITECTURE.md**: Full technical strategy document
- Published to: `https://github.com/ferencboi/turnstone-bundles/releases`
- Index URL: `https://github.com/ferencboi/turnstone-bundles/releases/download/index-latest/bundle-index.json`
