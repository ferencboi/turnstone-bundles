# Building a gaming-focused Wine distribution

> **Document status**: Draft
> **Last updated**: 2025-12-25
> **Author:** GitHub Copilot - Gemini 3 Pro

This document details the engineering specifications for a **"Pure WoW64"** Wine gaming build optimized for Android container runtimes (Termux/Proot environment leveraging Box64).

## 1. Architecture and Packaging Design

### Container Layer vs. Wine Bundle Layer
To achieve the <200MB target, strict separation of concerns is required between the Android/Linux container (Userland) and the Wine distribution.

*   **Container Layer (The Host):** Provides the ABI boundaries. It must supply:
    *   **Glibc/Musl:** The C standard library.
    *   **Window System:** X11 server (XWayland or Termux-X11) or Wayland compositor.
    *   **Vulkan Loader:** `libvulkan.so` aimed at the Turnip driver.
    *   **Audio Server:** PulseAudio server (standard in Winlator/Mobox).
*   **Wine Bundle Layer (The Guest):**
    *   Must be portable (relocatable RPATH).
    *   Must interface *only* with the Container's 64-bit libraries.

### Universal Build Strategy
We will utilize the **"New WoW64"** architecture introduced in Wine 8.0.

*   **Rationale:** Traditional Wine builds require 32-bit host libraries (i386-linux-gnu) to run 32-bit Windows apps. On Android (aarch64), running 32-bit x86 code requires `box86`. Maintaining a dual `box86`/`box64` stack with split libraries is bloated and unstable.
*   **Implementation:** In "New WoW64", the 32-bit Windows code (PE) makes syscalls into a 64-bit Unix library (via `ntdll`).
    *   **Benefit:** We **only** need `box64` and 64-bit system libraries. 32-bit Windows apps run inside a 64-bit Wine process.

### Directory Layout
Adhere to XDG Base Directory specs where possible, but keep the installation self-contained for the container.

```text
/opt/wine-gaming/
├── bin/                  # Only 64-bit binaries (wine, wine64, wineserver)
├── lib/
│   ├── wine/
│   │   ├── x86_64-unix/  # 64-bit Unix .so files (drivers, thunks)
│   │   ├── x86_64-windows/ # 64-bit PE .dll files
│   │   └── i386-windows/   # 32-bit PE .dll files (WoW64)
├── share/wine/
│   ├── wine.inf          # Minimal INF for prefix creation
│   └── fonts/            # Minimal fonts (Tahoma, Arial)
```

## 2. Build Strategy

### Decision: Pure WoW64 (Recommended)
You should build using the `--enable-archs=i386,x86_64` flag combined with `--enable-win64` to trigger the experimental new WoW64 mode build process, or strictly cross-compile PE files.

**The "New WoW64" Build Sequence:**
Since we are cross-compiling for distribution, we treat the build environment as a cross-compiler.

1.  **Sysroot:** Standard x86_64 Linux sysroot.
2.  **Compiler:** MinGW-w64 (latest).

### Recommended Configure Flags
Based on the `WINE_BUILD_SPEC.md` draft, here are the refined flags for the **150MB target**.

```bash name=configure_flags.sh
# Critical flags for Gaming Minimalist Build
./configure \
    --prefix=/opt/wine-gaming \
    --enable-win64 \
    --enable-archs=i386,x86_64 \
    \
    # ----------------------------
    # GRAPHICS & DISPLAY
    # ----------------------------
    --with-x \
    --with-vulkan \
    --with-opengl \
    --without-osmesa \
    --without-wayland \
    \
    # ----------------------------
    # AUDIO (PulseAudio is King on Android)
    # ----------------------------
    --with-pulse \
    --without-alsa \
    --without-oss \
    --without-coreaudio \
    \
    # ----------------------------
    # INPUT & USB
    # ----------------------------
    --with-sdl \
    --without-udev \
    --without-usb \
    --without-cups \
    --without-sane \
    --without-gphoto \
    \
    # ----------------------------
    # NETWORK & SECURITY
    # ----------------------------
    --with-gnutls \
    --without-ldap \
    --without-krb5 \
    --without-netapi \
    --without-pcap \
    \
    # ----------------------------
    # BLOAT REMOVAL
    # ----------------------------
    --without-gstreamer \
    --without-mingw \
    --disable-tests \
    --disable-winemenubuilder
```

**Justification for Removals:**
*   `--without-gstreamer`: Saves ~50-80MB. *Guild Wars* uses Bink Video (smacker), which uses its own decoder. Most games do not rely on system-installed DirectShow filters for intros anymore.
*   `--without-alsa`: Android HALs sit below PulseAudio/PipeWire. Direct ALSA access often causes blocking issues in containers.
*   `--with-gnutls`: **CRITICAL**. Required for `secur32` and `crypt32`. Without this, *Guild Wars* login will fail (SSL handshake error).

## 3. Graphics Stack

### DXVK Integration
DXVK should **not** be compiled into Wine. It should be a runtime injection.

*   **Deployment:** Place `d3d9.dll`, `dxgi.dll`, etc., into `lib/wine/x86_64-windows/` and `lib/wine/i386-windows/` replacing the Wine built-ins, or use a setup script to copy them to the prefix `system32`/`syswow64`.
*   **Overrides:** The container must set `WINEDLLOVERRIDES` environment variable.
    ```bash
    export WINEDLLOVERRIDES="d3d9,d3d10,d3d11,dxgi=n,b"
    ```
*   **WSI (Window System Integration):** Wine provides the WSI. DXVK talks to Vulkan, which talks to `winevulkan.dll`, which marshals to `winevulkan.so`.

### Vulkan on Android (Turnip)
Turnip (Freedreno) is the Mesa Vulkan driver for Adreno GPUs.

*   **Requirement:** The container must expose `/dev/dri/renderD128` (or similar) and map it correctly.
*   **Common Failure Mode:** `VK_ERROR_INCOMPATIBLE_DRIVER`. This often happens if `winevulkan` cannot find the *host* loader or if the host loader cannot find the Turnip driver (ICD).
*   **Fallback:** If Vulkan fails, Wine falls back to OpenGL (`wined3d`). On Android, this uses `virgl` or Zink, which is significantly slower.
*   **Detection:**
    ```bash
    # Simple check before launching wine
    if ! command -v vulkaninfo >/dev/null; then
        echo "Warning: Host Vulkan tools missing."
    fi
    ```

## 4. Audio and Input

### Audio Backend: PulseAudio
PulseAudio is the only viable production choice for Android containers.

*   **Architecture:** `winepulse.drv.so` (64-bit Unix) talks to `libpulse.so` on the host.
*   **Pitfall:** Latency. Default PulseAudio buffers can be high.
*   **Fix:** In the container environment variables:
    ```bash
    export PULSE_LATENCY_MSEC=60
    ```
    This prevents audio crackling in many DX9 games which rely on tight audio synchronization.

### Input
*   **Mouse/Keyboard:** Handled via X11 driver (`winex11.drv`). This maps standard XInput events from the Android X server (Termux-X11).
*   **Cursor Locking:** *Guild Wars* requires relative mouse movement (mouselook). Ensure the X server supports XWarppointer or XInput2 properly, otherwise, the camera will spin wildly.

## 5. Media Playback

### Strategy: "No Codecs by Default"
For the 150MB target, strip all media frameworks.

*   **Guild Wars Specifics:** Uses Bink (.bik) video. The game ships `binkw32.dll`. It does **not** need Wine GStreamer.
*   **DirectShow:** Keep the core `quartz.dll` and `devenum.dll` because games use them to *enumerate* devices, even if they don't play video.
*   **Plugin Selection:** If you absolutely must support a game with WMV video, compile a separate `wine-extras` package containing `winegstreamer.dll` and the 64-bit Unix GStreamer plugins. Do not bundle this in the base gaming image.

## 6. Size Reduction & Stripping

### Aggressive Stripping Plan

1.  **Strip Unneeded:**
    ```bash
    # Strip symbols from PE files (Windows) and ELF files (Unix)
    find /opt/wine-gaming -name "*.dll" -exec x86_64-w64-mingw32-strip --strip-unneeded {} \;
    find /opt/wine-gaming -name "*.exe" -exec x86_64-w64-mingw32-strip --strip-unneeded {} \;
    find /opt/wine-gaming -name "*.so" -exec strip --strip-unneeded {} \;
    ```

2.  **Delete Development Artifacts (Automated):**
    ```bash name=cleanup.sh
    # Remove static libraries and archives
    rm -rf /opt/wine-gaming/lib/wine/*.a
    rm -rf /opt/wine-gaming/lib/wine/*.def
    
    # Remove headers
    rm -rf /opt/wine-gaming/include
    
    # Remove man pages and docs
    rm -rf /opt/wine-gaming/share/man
    rm -rf /opt/wine-gaming/share/applications
    ```

3.  **What NOT to Delete:**
    *   `mscoree.dll`: Even if you remove Mono, keep the stub. Games check for its existence to decide whether to load .NET paths.
    *   `winebrowser.exe`: Used to open external links (like "Create Account"). Map this to a script that calls `termux-open-url` to launch the Android native browser.

4.  **Debug Build Strategy:**
    *   Do **not** build with `WINEDEBUG=""`.
    *   Build with debug info enabled (`-g`), then use `objcopy --only-keep-debug` to split symbols into `.debug` files, then strip the binary.
    *   Store the `.debug` files in a separate S3 bucket/archive. If a user crashes, they can download the symbol pack for that specific build version.

## References
1.  **New WoW64 Architecture:** *Julliard, A. (2021). "The new WoW64 architecture."* [WineHQ Wiki](https://gitlab.winehq.org/wine/wine/-/wikis/Building-Wine#wow64-build)
2.  **Android Audio Latency:** *Freedesktop PulseAudio Documentation.* [PulseAudio Wiki](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/PerfectSetup/)
3.  **DXVK Async/GPL:** *Doitsujin (2023).* [DXVK GitHub](https://github.com/doitsujin/dxvk) (Reference regarding shader compilation stutter on Turnip).