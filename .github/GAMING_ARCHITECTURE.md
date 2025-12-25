# Turnstone Gaming Architecture Plan

> **Document Status:** Planning Draft  
> **Last Updated:** 2025-12-24  
> **Purpose:** Define the optimized architecture for running Windows games on Android ARM64 devices

---

## Executive Summary

Turnstone aims to be a **Winlator-style Android app** for gaming. This requires a fundamentally different approach than vanilla Wine. The architecture is modular ("Frankenstein build"), optimizing each layer for **gaming performance on Qualcomm Adreno GPUs**.

This document synthesizes:
- Practical findings from our build process
- Technical spec from Gemini analysis (see `gemini2cents.md`)
- Industry approaches (Winlator, Termux, Proton)

---

## 🎯 Target Environment

| Aspect | Specification |
|--------|--------------|
| **Host OS** | Android 10+ (API 29+) |
| **Host Architecture** | ARM64 (aarch64) |
| **Target GPUs** | Qualcomm Adreno 6xx, 7xx series |
| **Target Apps** | Windows x86/x64 games (DirectX 9-12) |
| **Performance Goal** | Playable framerates (30+ FPS) on mid-range devices |

---

## 🏗️ Layered Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Windows Game (.exe)                          │
├─────────────────────────────────────────────────────────────────┤
│ Layer D: Graphics Stack                                          │
│   ├── DXVK: DirectX 9/10/11 → Vulkan                            │
│   ├── VKD3D-Proton: DirectX 12 → Vulkan (future)                │
│   └── Turnip (Mesa freedreno): Vulkan ICD for Adreno            │
├─────────────────────────────────────────────────────────────────┤
│ Layer C: Wine Core                                               │
│   ├── Wine-Staging or Wine-TKG (gaming patches)                 │
│   ├── WoW64 mode (32-bit + 64-bit in single binary)             │
│   └── Esync/Fsync for synchronization                           │
├─────────────────────────────────────────────────────────────────┤
│ Layer B: CPU Translation                                         │
│   ├── Box64: x86_64 → ARM64 JIT                                 │
│   └── (Box86 legacy support if needed)                          │
├─────────────────────────────────────────────────────────────────┤
│ Layer A: Execution Container                                     │
│   ├── Glibc-based proot/chroot (NOT Android bionic)             │
│   └── Linux filesystem layout expected by Wine/Box64            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Android System                               │
│   ├── Kernel (KGSL for GPU access)                              │
│   └── Native ARM64 execution                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer Details

### Layer A: Execution Container

**Choice: Glibc-based proot/chroot** (NOT native Android bionic)

**Rationale:**
- Wine and most Linux desktop tools expect glibc, not Android's bionic
- Enables use of upstream Mesa/Turnip builds without patching
- Simplifies library compatibility (X11, Wayland emulation, audio)

**Implementation Options:**
| Option | Pros | Cons |
|--------|------|------|
| **proot** | No root required, easy setup | Performance overhead (~5-15%) |
| **chroot** | Near-native performance | Requires root |
| **termux-proot** | Well-tested on Android | Limited to Termux ecosystem |

**Container Base:** Ubuntu 22.04 or Debian 12 (ARM64 userland, but hosting x86_64 Wine)

**Key Directories:**
```
/opt/turnstone/
├── container/        # Glibc rootfs (Ubuntu/Debian ARM64)
│   ├── usr/
│   ├── lib/
│   └── opt/wine/     # Wine installation (x86_64)
├── box64/            # Box64 binary (ARM64 native)
├── turnip/           # Mesa Turnip ICD
└── dxvk/             # DXVK DLLs
```

---

### Layer B: CPU Translation (Box64)

**Choice: Box64** for x86_64 → ARM64 translation

**Why Box64:**
- Mature JIT with ARM64 dynarec
- Active development, gaming-focused optimizations
- Native Android ARM64 support

**Optimization Environment Variables:**
```bash
# Aggressive gaming optimizations
export BOX64_DYNAREC=1
export BOX64_DYNAREC_BIGBLOCK=1       # Larger JIT blocks
export BOX64_DYNAREC_STRONGMEM=0      # Relaxed memory model
export BOX64_DYNAREC_FASTNAN=1        # Skip NaN handling
export BOX64_DYNAREC_FASTROUND=1      # Fast FP rounding
export BOX64_DYNAREC_SAFEFLAGS=0      # Aggressive flag optimization

# Wine-specific
export BOX64_LD_LIBRARY_PATH=/opt/wine/lib:/opt/wine/lib/wine/x86_64-unix
export BOX64_PATH=/opt/wine/bin
```

**WoW64 Strategy:**
- Wine 9.x+ WoW64 mode: Single 64-bit Wine binary handles both 32-bit and 64-bit apps
- Box64 translates x86_64 Wine → ARM64
- No need for separate Box86 + 32-bit Wine build

---

### Layer C: Wine Core

**Wine Build Profiles:**

| Profile | Use Case | Size (Est.) | Features |
|---------|----------|-------------|----------|
| **wine-full** | Development/Testing | ~500MB | Everything |
| **wine-gaming** | Production gaming | ~150-200MB | Gaming-only |
| **wine-minimal** | Lightweight/Launchers | ~80-100MB | Basic Windows compat |

**wine-gaming Profile (Primary Target):**

**KEEP (Gaming-Essential):**
```
DLLs:
  - d3d9.dll, d3d10*.dll, d3d11.dll, d3d12.dll (Direct3D)
  - ddraw.dll (Legacy DirectDraw)
  - dsound.dll, xaudio2_*.dll (DirectSound, XAudio)
  - dinput*.dll, xinput*.dll (Input)
  - dwrite.dll, gdi32.dll (Rendering)
  - user32.dll, kernel32.dll, ntdll.dll (Core)
  - ws2_32.dll, iphlpapi.dll (Networking)
  - ucrtbase.dll, vcruntime*.dll (C Runtime)
  
Binaries:
  - wine, wine64, wineserver
  - wineboot (prefix setup)
  - reg.exe, regedit.exe (registry)
```

**REMOVE (Bloat for Gaming):**
```
DLLs:
  - mshtml.dll (Gecko/HTML rendering - LARGE!)
  - winemenubuilder.exe
  - sane.ds (Scanner)
  - cups* (Printing)
  - wineps.drv (PostScript)
  - gphoto* (Camera)
  - twain* (Scanner API)
  
Binaries:
  - widl, wmc, wrc, winegcc (dev tools)
  - notepad.exe, wordpad.exe (apps)
  - iexplore.exe (Internet Explorer)
```

**Recommended Wine Source:**

| Source | Patches | Best For |
|--------|---------|----------|
| **wine-staging** | Community gaming patches | Stable gaming |
| **wine-tkg** | Proton-derived patches | Bleeding edge |
| **wine-ge** | Proton + Glorious Eggroll fixes | Steam-like compat |
| **wine-vanilla** | None | Baseline testing |

**Critical Gaming Patches:**
- **Esync** (eventfd sync): Reduces CPU overhead on sync primitives
- **Fsync** (futex sync): Even better if kernel supports `FUTEX_WAIT_MULTIPLE`
- **LAA** (Large Address Aware): Prevents OOM in 32-bit titles
- **CSMT** (Command Stream Multi-Threading): Offloads GL/Vulkan work

**Configure Flags (Gaming Build):**
```bash
./configure \
    --enable-win64 \
    --enable-archs=i386,x86_64 \
    --without-oss \
    --without-sane \
    --without-cups \
    --without-gphoto \
    --without-v4l2 \
    --without-capi \
    --without-netapi \
    --without-ldap \
    --disable-tests \
    --disable-winemenubuilder
```

---

### Layer D: Graphics Stack

**Vulkan Driver: Mesa Turnip (freedreno)**

**Status:** ✅ Released (turnip-25.3.2)

**GPU Support:**
| GPU Series | Support Level | Notes |
|------------|---------------|-------|
| Adreno 6xx | Good | Stable, widely tested |
| Adreno 7xx | Experimental | Needs git-main builds |

**Driver Injection:**
```bash
# Point Vulkan loader to Turnip
export VK_ICD_FILENAMES=/opt/turnstone/turnip/share/vulkan/icd.d/freedreno_icd.aarch64.json
export VK_DRIVER_FILES=/opt/turnstone/turnip/share/vulkan/icd.d/freedreno_icd.aarch64.json
```

**DirectX Translation: DXVK**

**Status:** ✅ Released (dxvk-2.5.3)

**DXVK Version Strategy:**
| Version | Use Case |
|---------|----------|
| DXVK 1.10.3 | Legacy fallback, maximum compatibility |
| DXVK 2.x | Modern titles, requires Vulkan 1.3 |

**Installation:**
```bash
# Copy DLLs to Wine prefix
cp dxvk/*.dll ~/.wine/drive_c/windows/system32/
cp dxvk/*32.dll ~/.wine/drive_c/windows/syswow64/  # For 32-bit
```

**Runtime Configuration:**
```bash
export DXVK_ASYNC=1          # Async shader compilation
export DXVK_HUD=fps          # Show FPS overlay
export DXVK_STATE_CACHE=1    # Enable state cache
```

---

## 📦 Bundle Strategy

### Current Bundles (Full/Development)

| Bundle | Arch | Purpose |
|--------|------|---------|
| wine-X.XX-x86_64.tar.zst | x86_64 | Full Wine for box64 |
| box64-X.X.X-arm64.tar.zst | ARM64 | Native translator |
| dxvk-X.X.X-arm64.tar.zst | x86_64 DLLs | DirectX translation |
| turnip-XX.X.X-arm64.tar.zst | ARM64 | Vulkan ICD |

### Future Gaming-Optimized Bundles

| Bundle | Arch | Size Target |
|--------|------|-------------|
| wine-gaming-X.XX-x86_64.tar.zst | x86_64 | ~150-200MB |
| wine-staging-X.XX-x86_64.tar.zst | x86_64 | ~300MB |
| container-base-arm64.tar.zst | ARM64 | ~200MB (glibc rootfs) |

---

## 🎮 Runtime Configuration Profile

**Standard Gaming Profile (env vars):**
```bash
# === Wine Configuration ===
export WINEPREFIX=/data/data/com.turnstone/files/wine
export WINEDEBUG=-all
export WINEDLLOVERRIDES="winemenubuilder.exe=d"

# === Synchronization ===
export WINEESYNC=1
export WINEFSYNC=1  # If kernel supports

# === Box64 Optimization ===
export BOX64_DYNAREC=1
export BOX64_DYNAREC_BIGBLOCK=1
export BOX64_DYNAREC_FASTNAN=1
export BOX64_DYNAREC_FASTROUND=1
export BOX64_DYNAREC_SAFEFLAGS=0
export BOX64_DYNAREC_STRONGMEM=0

# === Graphics ===
export VK_ICD_FILENAMES=/opt/turnstone/turnip/icd.json
export DXVK_ASYNC=1
export DXVK_STATE_CACHE_PATH=/data/data/com.turnstone/cache/dxvk

# === Mesa/Turnip Tweaks ===
export MESA_LOADER_DRIVER_OVERRIDE=zink  # Only for debugging
export mesa_glthread=true
export MESA_NO_ERROR=1  # Skip GL error checking

# === Compatibility Hacks ===
export MESA_EXTENSION_MAX_YEAR=2003  # Legacy GL version checks
export __GL_THREADED_OPTIMIZATIONS=1
```

---

## 📋 Implementation Roadmap

### Phase 1: Foundation (Current)
- [x] Build box64 for Android ARM64
- [x] Build DXVK (MinGW cross-compile)
- [x] Build Turnip (Mesa) for Android ARM64
- [ ] Build Wine (Linux x86_64 for box64) ← **In Progress**

### Phase 2: Gaming Optimization
- [ ] Create wine-gaming profile (stripped build)
- [ ] Add wine-staging patches
- [ ] Test Esync/Fsync on Android kernels
- [ ] Create container-base bundle (glibc rootfs)

### Phase 3: Distribution
- [ ] Add bundle profiles to bundle-index.json
- [ ] Create compatibility-matrix.json presets
- [ ] Document app integration API

### Phase 4: Advanced
- [ ] VKD3D-Proton for DirectX 12
- [ ] Audio backend optimization (PulseAudio vs OpenSL ES)
- [ ] Per-game configuration profiles
- [ ] Adreno 7xx specific optimizations

---

## 🔗 References

- [Winlator](https://github.com/brunodev85/winlator) - Reference implementation
- [Box64](https://github.com/ptitSeb/box64) - x86_64 emulator
- [DXVK](https://github.com/doitsujin/dxvk) - DirectX to Vulkan
- [Wine-Staging](https://github.com/wine-staging/wine-staging) - Gaming patches
- [Wine-TKG](https://github.com/Frogging-Family/wine-tkg-git) - Proton-derived
- [Mesa Turnip](https://gitlab.freedesktop.org/mesa/mesa) - Adreno Vulkan

---

## ⚠️ Known Limitations

1. **Kernel Fsync Support**: Not all Android kernels support `FUTEX_WAIT_MULTIPLE`
2. **GPU Memory**: Adreno has limited VRAM, affects large texture games
3. **Thermal Throttling**: Mobile SoCs throttle under sustained load
4. **32-bit Apps**: WoW64 mode may have edge cases vs native 32-bit Wine
5. **Root Requirement**: chroot for best perf, proot otherwise

---

## 📝 Notes

This document will be updated as we validate the architecture through builds and testing.
Current Wine build (9.22) is a **full build** for testing. Gaming-optimized builds will follow.
