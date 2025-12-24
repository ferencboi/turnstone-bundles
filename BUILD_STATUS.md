# Turnstone Bundles - Build Status and Lessons Learned

Last Updated: 2025-12-24

## Bundle Status Overview

| Component | Version | Build Status | Release Status | Notes |
|-----------|---------|--------------|----------------|-------|
| box64 | 0.3.8 | Built | Released | Fully functional |
| DXVK | 2.5.3 | Built | Released | Fully functional |
| Turnip | 25.3.2 | Built | Released | Linux WSI + KGSL build |
| Wine | - | Not started | Not released | Pending |

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

## Pending Tasks

### Wine
- Status: Not started
- Notes: Pending, can proceed now that Turnip is available.

