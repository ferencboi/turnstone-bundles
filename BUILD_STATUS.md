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

Rationale:
- No root required (Path B's Chroot needs root)
- Best performance (no Proot ptrace overhead)
- Easy version swapping (just replace .so files)
- Matches Turnstone's BundleManager design
- Proven by Winlator (15.9k GitHub stars)

Mesa Turnip build approaches:

| Approach | Description | Complexity | Used By |
|----------|-------------|------------|---------|
| **Linux WSI + KGSL** | `-Dplatforms=x11,wayland` | Medium | Winlator, Termux |
| **Full Android WSI** | `-Dplatforms=android` | Very High | AOSP builds |

**Native Android approach** (`-Dplatforms=android`):
- Requires Android gralloc/ANB (Android Native Buffer) implementation
- The `-Dandroid-stub=true` flag only provides HEADERS, not implementations
- Undefined symbols like `vk_android_get_anb_layout` indicate missing ANB code
- Needs either: full AOSP build environment, OR patches from working projects

**Linux Container approach** (`-Dplatforms=x11,wayland`):
- Uses standard Linux WSI code path (X11/Wayland)
- KGSL backend (`-Dfreedreno-kmds=kgsl`) talks to Android GPU kernel driver
- Much easier to build - standard Linux Mesa build
- Requires container infrastructure (Proot/Chroot) in the Android app

**Key insight from [lfdevs/mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container):**
> "Mesa drivers compiled in arm64 chroot containers across multiple popular Linux
> distributions offer better compatibility"

Their build uses `-Dplatforms=x11,wayland` NOT `-Dplatforms=android`!

**Technical blockers with `-Dplatforms=android`:**
1. `vk_android.c` needs working gralloc HAL (not just stubs)
2. `wsi_common_android.c` requires Android-specific buffer handling
3. `__ANDROID_API__` macro conflicts between NDK and meson
4. libelf not in NDK sysroot (use `-Dallow-fallback-for=libelf`)

---

## 🔗 References

### Key Resources Discovered
- **[lfdevs/mesa-for-android-container](https://github.com/lfdevs/mesa-for-android-container)** - Working Mesa builds for Android containers
  - Uses Linux WSI + KGSL backend (NOT Android WSI)
  - Provides prebuilt packages for Debian/Ubuntu/Arch
  - MIT licensed, can reference their approach
- **Mesa Official docs/android.rst** - Official cross-compilation docs
  - Shows proper cross-file format
  - Confirms `-Dandroid-stub=true` is for compilation only
- **Winlator** - Uses native Android approach with custom patches

### Successful External Builds
- **lfdevs Mesa:** Linux container approach with KGSL backend
- **Winlator Turnip:** Native Android with custom patches (needs investigation)
- **Termux Mesa:** Different approach (Linux userspace, not Android app)

---

## 🎯 Recommended Next Steps

### Immediate Decision: Architecture Choice

**Before proceeding with Turnip, decide between:**

| Option | Approach | Pros | Cons |
|--------|----------|------|------|
| **A** | Native Android Turnip | Simpler app architecture, direct Vulkan | Harder build, needs patches |
| **B** | Linux Container + Turnip | Easier build, proven working | Complex app, needs container runtime |
| **C** | Hybrid/Winlator approach | Study what works, adapt | Reverse engineering needed |

### If Option A (Native Android):
1. Study Winlator's exact Mesa patches and build config
2. May need to build within AOSP tree (not standalone NDK)
3. Reference: https://github.com/nicman23/AUR-Packages-nicman23 (if accessible)
4. Key: provide working ANB/gralloc implementation

### If Option B (Linux Container):
1. Consider using lfdevs prebuilt Turnip directly
2. Add Proot or similar container support to Turnstone
3. Much simpler Mesa build (standard Linux arm64)
4. Trade-off: more complex app runtime

### If Option C (Hybrid/Study):
1. Investigate how Winlator actually builds Turnip
2. Look for their patches that make `-Dplatforms=android` work
3. Key files to find: Android gralloc/ANB bridge code

### After Turnip is Resolved:
1. Complete Wine cross-compilation setup
2. Test full stack: box64 -> Wine -> DXVK -> Turnip
3. Create compatibility-matrix.json with tested combinations

### Infrastructure:
- Consider CI/CD (GitHub Actions) for automated builds
- Add build caching to reduce iteration time
- Document which approach was chosen and why

