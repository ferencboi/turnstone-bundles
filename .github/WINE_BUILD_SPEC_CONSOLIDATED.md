# Wine Build Spec - Consolidated Insights

> **Purpose:** Synthesized key findings from AI supplement documents  
> **Source:** WINE_BUILD_SPEC_supplement_1.md through supplement_security_posture.md  
> **Created:** 2025-12-25

---

## Executive Summary

Eight supplementary documents from various AI models (Claude Opus 4.5, Claude Sonnet 4, GPT-5.2, Gemini 3 Pro) have been analyzed. This document consolidates the **high-value, actionable insights** that should be incorporated into the Wine build process.

---

## 1. Critical Architecture Decisions

### 1.1 Pure WoW64 is the Correct Choice

**Unanimous consensus across all supplements:**

- Build Wine as **pure WoW64** (64-bit Unix host, 32-bit + 64-bit PE DLLs)
- Avoids dependency on 32-bit Linux libraries (critical for Android)
- Box64 only needs to translate x86_64 syscalls, not maintain dual box86/box64
- Arch Linux has officially transitioned to this model (2024)

**Configure flags:**
```bash
--enable-win64 \
--enable-archs=i386,x86_64
```

### 1.2 Do NOT Delete DirectX Stubs

**Critical warning from Gemini 3 Pro (supplement_4.md):**

> "Keep the `d3d*.dll` files in the build. Even when using DXVK, the Wine loader often initializes dependencies via the system directory first before applying the dlloverride."

**Correct approach:**
- Keep Wine's d3d9.dll, d3d11.dll, dxgi.dll stubs
- Use `WINEDLLOVERRIDES="d3d9,d3d10core,d3d11,dxgi=n,b"` at runtime
- This provides DXVK as primary, wined3d as fallback

### 1.3 DLLs That MUST NOT Be Removed

| DLL | Reason | Source |
|-----|--------|--------|
| `wbemprox.dll` | WMI queries for system specs - games silently exit if missing | Gemini 3 Pro |
| `quartz.dll` | DirectShow - games hang at black screen without it | Gemini 3 Pro |
| `mmdevapi.dll` | Audio device enumeration | Multiple |
| `schannel.dll` | TLS/SSL - Guild Wars login fails without it | All |
| All `*.nls` files | Locale/text - text renders as squares if missing | Gemini 3 Pro |

---

## 2. Optimized Configure Flags

### 2.1 Consensus Configure Command

Synthesizing all supplements, here is the recommended configure:

```bash
./configure \
    --prefix=/opt/wine-gaming \
    --enable-win64 \
    --enable-archs=i386,x86_64 \
    \
    # === KEEP (Gaming Essential) ===
    --with-x \
    --with-vulkan \
    --with-opengl \
    --with-pulse \
    --with-alsa \
    --with-freetype \
    --with-fontconfig \
    --with-gnutls \         # CRITICAL: Required for TLS/login
    \
    # === REMOVE (Bloat) ===
    --without-cups \        # Printing (-20MB)
    --without-sane \        # Scanning (-10MB)
    --without-gphoto \      # Camera (-8MB)
    --without-v4l2 \        # Video capture (-5MB)
    --without-ldap \        # Directory services (-12MB)
    --without-krb5 \        # Kerberos (-8MB)
    --without-netapi \      # SMB networking (-15MB)
    --without-pcap \        # Packet capture (-6MB)
    --without-opencl \      # GPU compute (-18MB)
    --without-oss \         # OSS audio (-4MB)
    --without-coreaudio \   # macOS only
    --without-osmesa \      # Software OpenGL (-25MB)
    \
    # === CONDITIONAL ===
    # --without-gstreamer \ # Saves 50-80MB but breaks video cutscenes
    # --with-gstreamer \    # Keep if games need DirectShow video
    \
    # === BUILD OPTIONS ===
    --disable-tests \
    --disable-winemenubuilder \
    \
    # === COMPILER OPTIMIZATIONS ===
    CFLAGS="-O2 -ffunction-sections -fdata-sections" \
    LDFLAGS="-Wl,--gc-sections"
```

### 2.2 GStreamer Decision

**Split opinion:**
- Gemini: `--without-gstreamer` (saves 50-80MB, most games use Bink)
- GPT-5.2: `--with-gstreamer` (DirectShow needed for older games)

**Recommendation:** Create two profiles:
- `wine-gaming-lite`: Without GStreamer (~120MB)
- `wine-gaming`: With GStreamer (~180MB)

---

## 3. Environment Variables for Production

### 3.1 Core Gaming Environment

```bash
# === Wine Debug/Performance ===
export WINEDEBUG=-all
export WINEESYNC=1
export WINEFSYNC=1                    # If kernel supports FUTEX2
export WINE_LARGE_ADDRESS_AWARE=1

# === DXVK ===
export WINEDLLOVERRIDES="d3d9,d3d10core,d3d11,dxgi=n,b"
export DXVK_LOG_LEVEL=none
export DXVK_STATE_CACHE=1
export DXVK_ASYNC=1

# === Turnip/Mesa (Android) ===
export TU_DEBUG=noconform
export ZINK_DESCRIPTORS=lazy
export MESA_VK_WSI_PRESENT_MODE=mailbox
export mesa_glthread=true
```

### 3.2 Audio Configuration

```bash
# PulseAudio is the only viable option on Android containers
export PULSE_LATENCY_MSEC=60          # Reduce latency
```

---

## 4. Post-Build Processing

### 4.1 Safe Stripping Command

From Gemini 3 Pro - use `--strip-debug` not `--strip-unneeded` for DLLs:

```bash
# DLLs: strip-debug (safer with anti-cheat)
find "$WINE_PREFIX" -name "*.dll" -exec strip --strip-debug {} \;
find "$WINE_PREFIX" -name "*.exe" -exec strip --strip-debug {} \;

# Unix libs: strip-unneeded is fine
find "$WINE_PREFIX" -name "*.so" -exec strip --strip-unneeded {} \;
```

### 4.2 Safe Removals (Unanimous)

```bash
# Development tools (always safe)
rm -f bin/{widl,winebuild,wrc,wmc,winegcc,winecpp,winedump,function_grep.pl}
rm -rf include/
rm -rf lib/wine/*.a
rm -rf lib/wine/*.def

# Gecko/Mono (if not needed)
rm -rf share/wine/gecko
rm -rf share/wine/mono

# mshtml (browser engine - 80-120MB)
rm -f lib/wine/*/mshtml.dll
rm -f lib/wine/*/ieframe.dll
rm -f lib/wine/*/jscript.dll
rm -f lib/wine/*/vbscript.dll

# Printing
rm -f lib/wine/*/winspool.drv
rm -f lib/wine/*/wineps.drv
rm -f lib/wine/*/localspl.dll
```

### 4.3 Box64-Specific Removals

```bash
# wine64-preloader not needed when invoking via box64 directly
rm -f bin/wine64-preloader
```

---

## 5. Registry Tweaks for Gaming

### 5.1 Service Disablement

```reg
; Disable non-gaming services
[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Spooler]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\wuauserv]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\BITS]
"Start"=dword:00000004
```

### 5.2 DXVK Overrides

```reg
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"d3d9"="native"
"d3d10"="native"
"d3d10_1"="native"
"d3d10core"="native"
"d3d11"="native"
"dxgi"="native"
```

### 5.3 Turnip/Android Specific

```reg
; Limit shader complexity for Turnip stability
[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"MaxShaderModelVS"="3.0"

; Prevent window manager fights on Android
[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"UseTakeFocus"="N"
```

---

## 6. Synchronization: Esync/Fsync/NTsync

### 6.1 Technology Comparison

| Tech | Performance | Kernel Req | Android Status |
|------|-------------|------------|----------------|
| Wineserver | Baseline | None | Works |
| Esync | +15-30% | eventfd | Works |
| Fsync | +20-40% | futex2 (5.16+) | Kernel dependent |
| NTsync | Best | 6.x+ | Future |

### 6.2 Esync Requirements

```bash
# File descriptor limits (check on Android container)
ulimit -Hn  # Should be >= 524288
```

---

## 7. Security Posture (from supplement_security_posture.md)

### 7.1 Critical Security Gap

> "A sha256 in a manifest protects against corruption, not a malicious mirror or compromised index. Require a signature chain you control."

**Action items:**
1. Sign bundle-index.json with offline key
2. Ship public key in app
3. Verify signature before trusting index
4. Implement rollback protection

### 7.2 Bundle Integrity Chain

```
[Offline Root Key] -> [Signing Key] -> bundle-index.json (signed)
                                    -> manifest.json (per bundle, signed)
                                    -> *.tar.zst (sha256 verified)
```

### 7.3 Android Permissions

**Required stance:**
- No dangerous permissions unless justified
- Scoped storage only (no broad EXTERNAL_STORAGE)
- Per-container network toggle
- No secrets in logs

---

## 8. Testing Checklist (Enhanced)

### 8.1 Loader/Prefix Tests
```
[ ] wineboot -u completes successfully
[ ] Registry operations work (reg.exe)
[ ] Prefix creates without errors
[ ] TLS fetch works (winhttp test)
```

### 8.2 Graphics Tests
```
[ ] DXVK injection works
[ ] Vulkan ICD loads (vulkaninfo)
[ ] Fallback to wined3d works if Vulkan fails
```

### 8.3 Android/Box64 Specific
```
[ ] No mmap allocation failures (WINEDEBUG=+virtual)
[ ] Cursor clipping works (ClipCursor)
[ ] Keyboard scancode mapping correct
[ ] Audio plays via PulseAudio
```

### 8.4 Guild Wars Specific
```
[ ] Launcher loads (may need mshtml stub)
[ ] Login succeeds (TLS/gnutls required)
[ ] Game world loads
[ ] Audio and input work
```

---

## 9. Layered Bundle Architecture (Future)

From supplement_1.md - consider splitting Wine into layers:

```
Layer 0: wine-core       (~50 MB)  - Core executables, ntdll, kernel32
Layer 1: wine-gaming     (~40 MB)  - DirectX stubs, audio, input
Layer 2: wine-network    (~20 MB)  - Networking DLLs
Layer 3: wine-fonts      (~10 MB)  - Essential fonts only
Layer 4: wine-media      (~30 MB)  - GStreamer/DirectShow (optional)

Total: ~120-150 MB (can update layers independently)
```

---

## 10. Key References from Supplements

| Source | Key Contribution |
|--------|------------------|
| Kron4ek Wine-Builds | Portable build practices |
| Wine-TKG | Modular patches, stripping |
| Winlator | Android container patterns |
| Arch Wiki | WoW64 transition guide |
| ProtonDB | Game compatibility data |

---

## Summary of Changes to WINE_BUILD_SPEC.md

Based on this analysis, the following updates should be made to the main spec:

1. **Add wbemprox.dll and quartz.dll to KEEP list**
2. **Add --with-gnutls to required configure flags**
3. **Change stripping from --strip-unneeded to --strip-debug for DLLs**
4. **Add registry tweaks section**
5. **Add Box64-specific optimizations (remove wine64-preloader)**
6. **Add security requirements for bundle signing**
7. **Expand environment variables section**
8. **Add Turnip-specific registry tweaks**
