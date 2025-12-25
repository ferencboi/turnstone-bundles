# Turnstone Bundles - Build Status and Lessons Learned

Last Updated: 2025-12-24

## Bundle Status Overview

| Component | Version | Build Status | Release Status | Notes |
|-----------|---------|--------------|----------------|-------|
| box64 | 0.3.8 | ✅ Built | ✅ Released | Fully functional |
| DXVK | 2.5.3 | ✅ Built | ✅ Released | Fully functional |
| Turnip | 25.3.2 | ✅ Built | ✅ Released | Linux WSI + KGSL build |
| Wine | 9.22 | ✅ Built | ✅ Released | Linux x86_64 for Box64 (218 MB) |

## Current Build: Wine 9.22

**Status:** ✅ Successfully built and released!

**Architecture Notes:**
- Wine is **NOT cross-compiled for Android ARM64**
- Built as Linux x86_64 binary to run under Box64 emulation
- Same approach used by Winlator and Termux
- WoW64 mode enables 32-bit + 64-bit Windows app support

**Build Configuration:**
```bash
./configure \
    --enable-win64 \
    --enable-archs=i386,x86_64 \
    --without-oss \
    --disable-tests \
    --disable-winemenubuilder
```

**Release Details:**
- Build Date: 2025-12-24
- SHA-256: `837212693737ae33ef45c7ea9440e2e17fff433042378129f9230787cf7cd6ba`
- Size: 228,493,083 bytes (218 MB compressed)
- Release URL: https://github.com/ferencboi/turnstone-bundles/releases/tag/wine-9.22
- Output: `wine-9.22-x86_64.tar.zst`

## Completed Tasks

### box64 0.3.8
- Build Date: 2025-12-23
- Status: Successfully built and released
- SHA-256: 550bfe8c5afacdd14bbf27c9abd212044a887ba83e434ecbae67b383cad01ed2
- Size: 3466940 bytes
- Release URL: https://github.com/ferencboi/turnstone-bundles/releases/tag/box64-0.3.8

### DXVK 2.5.3
- Build Date: 2025-12-23
- Status: Successfully built and released
- SHA-256: 48a93ca9e52a2da82e13bd2fc6f1de4dbb53bb52febe4aa77727a55f1355a023
- Size: 4186091 bytes
- Release URL: https://github.com/ferencboi/turnstone-bundles/releases/tag/dxvk-2.5.3

### Turnip (Mesa freedreno Vulkan ICD) 25.3.2
- Build Date: 2025-12-24
- Status: Successfully built and released
- SHA-256: fb8bed77facb1a7215fa2fe3483915874fb5552f742ea0ef3852a36b1388c009
- Size: 1715942 bytes
- Release URL: https://github.com/ferencboi/turnstone-bundles/releases/tag/turnip-25.3.2
- Notes: Built with Android NDK toolchain, but using Mesa's Linux path with KGSL backend.

## Lessons Learned (Turnip)

- The Android NDK toolchain defines __ANDROID__, which can trigger Mesa Android-only codepaths.
  For a Linux WSI + KGSL style build, disable Android OS detection in Mesa.
- Meson fallback subprojects can pull optional dependencies during cross builds (for example libarchive).
  If the dependency is optional for freedreno, remove the corresponding wrap to prevent fallback.
- Android NDK sysroot does not ship libelf. Mesa freedreno links against -lelf.
  Build and link a static libelf.a for the target.
- Make Meson install prefix match the staging directory used for packaging.

## Lessons Learned (Wine)

- **Wine is NOT cross-compiled for Android ARM64.** It runs under Box64 as a Linux x86_64 binary.
- Build environment is Ubuntu 22.04 (glibc), NOT Android NDK.
- WoW64 mode (Wine 9.x+) eliminates need for separate 32-bit Wine build.
- Output directory permissions must be set before container run (SELinux `:Z` flag helps).

## Future Plans

### Gaming-Optimized Wine Builds
The current Wine build is a **full build** (~500MB) for testing. Production gaming builds will:
- Strip non-gaming components (printing, scanning, mshtml/Gecko)
- Include wine-staging patches (Esync, Fsync)
- Target size: ~150-200MB

See [GAMING_ARCHITECTURE.md](.github/GAMING_ARCHITECTURE.md) for the full strategy.

### Target Wine Versions
- **Wine 9.22** - Stable development (current build)
- **Wine 10.20** - Development branch (planned)
- **Wine-staging** - Gaming patches (planned)
