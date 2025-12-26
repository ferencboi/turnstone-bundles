# Building a gaming-focused Wine distribution

> **Document status**: Draft
> **Last updated**: 2025-12-25
> **Author:** GitHub Copilot - Gemini 3 Pro

This document provides a comprehensive engineering specification for a production-grade, gaming-optimized Wine distribution targeting Android container runtimes (via Box64). It incorporates the new requirements for security, reliability, and automated testing.

## Specification Document

```markdown name=WINE_GAMING_SPEC_V2.md
# Wine Gaming Build Specification v2.0

> **Target Architecture:** Android (AArch64) via Box64  
> **Wine Architecture:** Pure WoW64 (x86_64 Host / i386 + x86_64 PE)  
> **Goal:** High-performance, secure, minimized runtime for DirectX 9-11 games.  
> **Last Updated:** 2025-12-25

---

## 1. Architecture & Packaging Design

### 1.1 The "Pure WoW64" Container Model
To minimize dependencies on Android (which lacks 32-bit Linux libraries), we strictly utilize the **"New WoW64"** (Pure WoW64) architecture.

*   **Host Layer (Android/Termux):** 64-bit only (AArch64).
*   **Emulation Layer (Box64):** Translates x86_64 Linux syscalls to AArch64.
*   **Wine Layer:** compiled as **x86_64**.
    *   Unix libraries (`.so`) are 64-bit **only**.
    *   PE libraries (`.dll`) are both 32-bit and 64-bit.
    *   Wine internally thunks 32-bit Windows API calls to 64-bit Unix syscalls.
*   **Benefit:** Zero dependency on 32-bit host libraries (libc, alsa, freetype). This is critical for modern Android.

### 1.2 Directory Layout
We separate immutable assets (artifacts) from mutable state (configs/prefixes).

```text
/opt/wine-gaming/              # Immutable Installation (Read-Only)
├── bin/                       # wine, wineserver (x86_64)
├── lib/
│   └── wine/
│       ├── x86_64-unix/       # .so files (Unix system calls)
│       ├── x86_64-windows/    # .dll files (64-bit Windows libs)
│       └── i386-windows/      # .dll files (32-bit Windows libs)
├── share/
│   ├── wine/fonts/            # Minimal font set (Tahoma, Arial)
│   └── wine/wine.inf          # Default registry setup
└── dxvk/                      # Decoupled DXVK artifacts
    ├── x64/
    └── x32/
```

### 1.3 Universal Build Strategy
Do not build per-device. Build **one** generic artifact.
*   **Runtime Adaptation:** Use a launch script (`wine-launch.sh`) to detect device capabilities (e.g., Adreno 6xx vs 7xx) and inject environment variables (Turnip quirks) at runtime.
*   **Feature Gating:** Disable features via `WINEDLLOVERRIDES` rather than excluding files, preventing load-time link errors.

---

## 2. Build Strategy

### 2.1 Justification: Pure WoW64
**Decision:** Enable `--enable-archs=i386,x86_64` but **without** multilib 32-bit Linux libraries.
**Why:**
1.  **Android Reality:** Modern Android devices dropped 32-bit support in hardware (Cortex-X4) or userspace.
2.  **Box64 Synergy:** Box64 excels at 64-bit translation. Adding Box86 (32-bit) adds massive complexity and overhead. Pure WoW64 keeps the Unix side purely 64-bit.

### 2.2 Configure Flags (Minimal Gaming Profile)
Recommended configuration for the build environment (Docker container):

```bash
./configure \
    --prefix=/opt/wine-gaming \
    --enable-win64 \
    --enable-archs=i386,x86_64 \
    \
    # 1. Dependency Minimization (Force System Libs where possible, disable optional)
    --without-cups \
    --without-sane \
    --without-gphoto \
    --without-v4l2 \
    --without-ldap \
    --without-krb5 \
    --without-pcap \
    --without-opencl \
    --without-oss \
    --without-coreaudio \
    --without-netapi \
    \
    # 2. Graphics & Audio (Essential)
    --with-x \
    --with-vulkan \
    --with-opengl \
    --with-pulse \
    --with-alsa \
    \
    # 3. Size/Perf Optimization
    --disable-tests \
    --disable-winemenubuilder \
    --with-mingw  # Use MinGW for PE builds (cleaner separation)
```

---

## 3. Graphics Stack

### 3.1 DXVK Integration
**Do not bake DXVK into System32.**
*   **Install:** Copy `d3d9.dll`, `dxgi.dll`, etc., from `/opt/wine-gaming/dxvk/` to the `$WINEPREFIX/drive_c/windows/system32` during prefix creation.
*   **Overrides:**
    ```bash
    export WINEDLLOVERRIDES="d3d9,d3d10core,d3d11,dxgi=n,b"
    ```
    *Note: `n,b` = Native (DXVK) first, Builtin (Wine OpenGL) fallback.*

### 3.2 Vulkan & Turnip (Adreno)
Running DXVK on Adreno (Turnip driver) requires specific environment tuning to prevent crashes in heavy shaders.

**Common Failure Mode:** "Device Lost" or Shader Compilation Stalls.
**Mitigation (in `wine-launch.sh`):**
```bash
# Force Turnip to be compliant
export TU_DEBUG=noconform
# Optimize descriptor usage
export ZINK_DESCRIPTORS=lazy 
# Fix swapchain issues on Android surfaces
export MESA_VK_WSI_PRESENT_MODE=mailbox
```

### 3.3 Fallback Strategy
If Vulkan fails (old device or bad driver), fall back to **WineD3D** (OpenGL).
1.  Check for `/dev/kgsl` or `/dev/dri/renderD128`.
2.  If Vulkan ICD is missing, unset `WINEDLLOVERRIDES` to revert to built-in `d3d9.dll` (OpenGL path).

---

## 4. Audio & Input

### 4.1 Audio Backend
**Choice:** PulseAudio (`winepulse.drv`).
**Rationale:** On Android containers (Termux/Proot), direct ALSA access is often blocked or requires root to touch `/dev/snd`. PulseAudio provides a user-space socket that easily bridges to Android's `AAudio` via `pulseaudio-module-aaudio`.

**Configuration:**
```registry
[HKCU\Software\Wine\Drivers]
"Audio"="pulse"
```

### 4.2 Input Pitfalls
*   **Cursor Clipping:** Android's touch interface doesn't "capture" the mouse like a PC.
    *   *Fix:* Patch `winex11.drv` or use `UseTakeFocus="N"` in registry to prevent Wine from fighting the Android Window Manager.
*   **Touchscreen Mapping:** Ensure the container (Winlator/Termux-X11) maps touch gestures to standard X11 mouse events (Button 1/2/3). Wine receives these as standard X11 events.

---

## 5. Media Playback

### 5.1 DirectShow Strategy
Games like *Guild Wars* use DirectShow for cutscenes.
*   **Keep:** `quartz.dll`, `devenum.dll`.
*   **Remove:** `amstream.dll` (rarely used).

### 5.2 GStreamer Strategy
Wine uses GStreamer (`winegstreamer.dll`) to decode video formats it doesn't natively support (MP4, VP8).
*   **Problem:** Installing full GStreamer adds ~300MB.
*   **Solution:** Compile a **minimal GStreamer** build containing only:
    *   `core`: core, base
    *   `video`: videoconvert, videoscale
    *   `audio`: audioconvert, audioresample
    *   `codecs`: libav (stripped to h264/aac only) or vp8/vp9/mp3.
*   **Test:** Validate playback of the *Guild Wars* login screen background (often a video loop).

---

## 6. Size Reduction

### 6.1 Safe Stripping
The safest way to strip without breaking functionality:
```bash
# DLLs: Strip debug symbols only (safe for anti-cheat/debugging)
find . -name "*.dll" -exec strip --strip-debug {} \;

# SOs: Strip unneeded symbols (safe for Unix libs)
find . -name "*.so" -exec strip --strip-unneeded {} \;
```

### 6.2 The "Delete List"
Files to remove post-install:
1.  **Development:** `include/`, `lib/*.a`, `bin/widl`, `bin/winegcc`.
2.  **Printing:** `winspool.drv`, `wineps.drv`, `localspl.dll`.
3.  **Scanners:** `sane.ds`, `twain_32.dll`.
4.  **Browsers:** `mshtml.dll` (Warning: See note below), `ieframe.dll`.
    *   *Note:* Replace `mshtml.dll` with a 0-byte stub or a custom "fake" DLL if the game launcher crashes on load.
5.  **UI Automation:** `uiautomationcore.dll` (Very large, rarely used by games).

### 6.3 Do NOT Delete
*   `wbemprox.dll`: Required for hardware capability detection.
*   `nls/*.nls`: Required for text rendering. Deleting these causes "Box" characters.
*   `mpr.dll`: Networking provider, needed for some login flows.

---

## 7. Security & Reliability

### 7.1 Sandbox & Least Privilege
*   **User Context:** Never run Wine as root. Run as a dedicated user (e.g., `u0_a123`).
*   **Drive Z: Isolation:** By default, `Z:` maps to `/`. This exposes the entire Android rootfs.
    *   *Fix:* In `winecfg` or registry, restrict `Z:` to the container's sandbox directory only.
    *   Remove `Z:` drive mapping entirely if possible and map specific folders (e.g., `D:` -> `/sdcard/Games`).
*   **Process Isolation:** Ensure the container runtime (Box64) forbids `ptrace` on processes outside the container group.

### 7.2 Logging Strategy
*   **Structured Logs:** Wine produces unstructured text. Wrap stderr/stdout.
*   **Sanitization:** Wine logs *will* dump environment variables (including tokens) in crash dumps.
    *   *Policy:* Set `WINEDEBUG=-all` for production builds.
    *   *Debug Mode:* If debugging is enabled by user, display a prominent warning "LOGS MAY CONTAIN SENSITIVE DATA".

### 7.3 Update Strategy
*   **Immutable Core:** The `/opt/wine-gaming` folder should be read-only at runtime.
*   **Atomic Swaps:** Updates should replace the entire folder path (e.g., `/opt/wine-gaming-v2`) and update the symlink `/opt/wine-current`.

---

## 8. Testing & CI

### 8.1 Automated Smoke Tests (GitHub Actions)
Run these checks inside the build container before publishing artifacts.

1.  **Headless Boot:**
    ```bash
    # Verify wineboot initializes without crashing
    WINEDEBUG=-all wine cmd /c "echo Success" | grep "Success"
    ```
2.  **Architecture Check:**
    ```bash
    # Ensure 32-bit PE support is active
    file lib/wine/i386-windows/kernel32.dll | grep "PE32 executable"
    ```
3.  **Registry Check:**
    ```bash
    # Ensure critical keys exist
    wine reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion"
    ```

### 8.2 Game Portfolio (Manual/Semi-Auto)
Verification matrix for release:

| Game | DirectX | Feature Test | Success Criteria |
|:-----|:--------|:-------------|:-----------------|
| **Guild Wars** | DX9 | Login, Town Load | >30 FPS, Audio OK |
| **Skyrim (2011)** | DX9 | Intro Cart | Audio sync, No crash |
| **Warcraft III** | DX8/9 | Custom Game | Mouse Lock OK |

### 8.3 Regression Metrics
Track the following in CI artifacts:
*   **Bundle Size:** Fail build if `> 220MB`.
*   **DLL Count:** Alert if critical DLLs (e.g., `dsound.dll`) vanish.
*   **Startup Time:** Measure time from `wine cmd` to exit.

---

## References & Standards
1.  **Pure WoW64:** *Julliard, A. (2021). "The new WoW64 architecture." WineHQ.*
2.  **Box64:** *PtitSeb. "Box64: Linux Userspace x86_64 Emulator with a twist."*
3.  **Security:** *OWASP. "Least Privilege."*
```