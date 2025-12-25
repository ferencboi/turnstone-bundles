# Wine Gaming Build Specification

> **Document Status:** Draft v1.0  
> **Last Updated:** 2025-12-25  
> **Target Game:** Guild Wars: Factions (DX9 MMORPG)  
> **Goal:** Reduce Wine from 1.4 GB → ~150-200 MB while maintaining gaming functionality

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Reference Game Analysis](#reference-game-analysis)
3. [Prior Art & Research](#prior-art--research)
4. [Build Profiles](#build-profiles)
5. [Component Classification](#component-classification)
6. [Configure Options](#configure-options)
7. [Post-Build Stripping](#post-build-stripping)
8. [Testing Checklist](#testing-checklist)
9. [Implementation Plan](#implementation-plan)

---

## Executive Summary

The Wine 9.22 "full" build produces a **1.4 GB** installed bundle. For a mobile gaming app, this is unacceptable. Our goal is to create a **wine-gaming** profile that:

- Supports DirectX 9/10/11 games (via DXVK)
- Includes networking (Winsock) for online games
- Supports keyboard and mouse input
- Includes audio (DirectSound, XAudio2)
- Excludes non-gaming features (printing, scanning, HTML rendering, etc.)

**Target size:** 150-200 MB installed (~20-30 MB compressed)

---

## Reference Game Analysis

### Guild Wars: Factions Requirements

**Game Profile:**
| Attribute | Value |
|-----------|-------|
| **Genre** | MMORPG |
| **DirectX** | DirectX 9.0c |
| **Year** | 2006 |
| **32-bit/64-bit** | 32-bit |
| **Online** | Always-online, TCP/IP networking |
| **Anti-cheat** | None (server-side validation) |

**Wine AppDB:** [Gold rating](https://appdb.winehq.org/objectManager.php?sClass=application&iId=1648)  
**ProtonDB:** Platinum (works out of box)

### Required Wine Components for Guild Wars

```
┌─────────────────────────────────────────────────────────────────┐
│                    Guild Wars Requirements                       │
├─────────────────────────────────────────────────────────────────┤
│ Graphics (DXVK handles):                                         │
│   • d3d9.dll (DirectX 9) - replaced by DXVK                     │
│   • ddraw.dll (DirectDraw for 2D fallback)                      │
│   • dxgi.dll (DXVK)                                             │
├─────────────────────────────────────────────────────────────────┤
│ Audio:                                                           │
│   • dsound.dll (DirectSound - primary audio)                    │
│   • winmm.dll (Multimedia timers)                               │
├─────────────────────────────────────────────────────────────────┤
│ Input:                                                           │
│   • dinput.dll, dinput8.dll (DirectInput)                       │
│   • user32.dll (keyboard/mouse via Windows messages)            │
├─────────────────────────────────────────────────────────────────┤
│ Networking:                                                      │
│   • ws2_32.dll (Winsock 2)                                      │
│   • iphlpapi.dll (IP Helper API)                                │
│   • winhttp.dll (HTTP client for login/patching)                │
│   • secur32.dll (SSPI for TLS)                                  │
│   • crypt32.dll (Certificate validation)                        │
├─────────────────────────────────────────────────────────────────┤
│ Core Windows:                                                    │
│   • kernel32.dll, ntdll.dll (Core APIs)                         │
│   • user32.dll (Window management)                              │
│   • gdi32.dll (GDI rendering, fonts)                            │
│   • advapi32.dll (Registry, services)                           │
│   • shell32.dll (Shell APIs)                                    │
│   • ole32.dll, oleaut32.dll (COM)                               │
├─────────────────────────────────────────────────────────────────┤
│ C Runtime:                                                       │
│   • msvcrt.dll, ucrtbase.dll                                    │
│   • vcruntime140.dll (if needed)                                │
├─────────────────────────────────────────────────────────────────┤
│ Fonts:                                                           │
│   • Core fonts (Tahoma, Arial) for UI                           │
└─────────────────────────────────────────────────────────────────┘
```

### Components NOT Required for Guild Wars

```
❌ mshtml.dll (Gecko) - No embedded browser
❌ mono (Wine Mono) - No .NET
❌ gecko (Wine Gecko) - No HTML rendering
❌ cups* - No printing
❌ sane* - No scanning
❌ gphoto* - No camera
❌ v4l2 - No video capture
❌ ldap - No directory services
❌ netapi - No Windows networking (SMB)
❌ opencl - No GPU compute
❌ pcap - No packet capture
❌ winemenubuilder - No desktop integration
❌ wordpad, notepad - No bundled apps
❌ iexplore - No Internet Explorer
```

---

## Prior Art & Research

### Winlator Approach

Winlator (brunodev85) uses a curated Wine build with:

- **Default components:** `direct3d=1,directsound=1,directmusic=0,directshow=0,directplay=0,vcrun2010=1,wmdecoder=1`
- **Pre-built container pattern** with common DLLs
- **Runtime DLL overrides** via registry
- **WoW64 mode** enabled by default

**Key files from Winlator:**
```java
// Container.java
DEFAULT_WINCOMPONENTS = "direct3d=1,directsound=1,directmusic=0,directshow=0,directplay=0,vcrun2010=1,wmdecoder=1"
DEFAULT_ENV_VARS = "ZINK_DESCRIPTORS=lazy MESA_SHADER_CACHE_DISABLE=false mesa_glthread=true WINEESYNC=1"
```

### Wine-TKG Approach

Wine-TKG provides customization via cfg files:

```bash
# Disable non-gaming features
_MIME_NOPE="true"           # Disable MIME type registration
_FOAS_NOPE="true"           # Disable file associations
_pkg_strip="true"           # Strip debug symbols

# Strip command
strip --strip-unneeded *.dll *.so *.exe
```

### Proton Approach

Proton disables many components at runtime:

```python
# proton conf/proton
self.env.setdefault("WINEDEBUG", "-all")
self.env["PROTON_NVAPI_DISABLE"] = "1"
self.env["PROTON_WINEDBG_DISABLE"] = "1"
self.env["PROTON_CONHOST_DISABLE"] = "1"
self.dlloverrides["winemenubuilder.exe"] = "d"  # disable
```

---

## Build Profiles

### Profile Comparison

| Profile | Size | Use Case | Features |
|---------|------|----------|----------|
| **wine-full** | ~1.4 GB | Development | Everything |
| **wine-gaming** | ~150-200 MB | Production | Gaming-essential only |
| **wine-minimal** | ~80-100 MB | Launchers | Basic Windows compat |

### wine-gaming Profile (Primary Target)

**Target applications:**
- DirectX 9/10/11 games
- Online/multiplayer games
- Games requiring audio and input
- 32-bit and 64-bit Windows games (via WoW64)

**NOT supported:**
- DirectX 12 games (future: VKD3D-Proton)
- .NET applications (no Mono)
- HTML/Web content (no Gecko)
- Office applications
- Printing/scanning

---

## Component Classification

### 🟢 KEEP - Gaming Essential

#### Core DLLs (system32 / syswow64)

```
# Core Windows APIs
kernel32.dll          # Windows kernel API
kernelbase.dll        # Low-level kernel functions  
ntdll.dll             # NT layer
user32.dll            # User interface, input
gdi32.dll             # Graphics Device Interface
win32u.dll            # Win32 user subsystem

# COM/OLE
ole32.dll             # COM runtime
oleaut32.dll          # OLE automation
rpcrt4.dll            # RPC runtime
combase.dll           # COM base

# Registry & Services
advapi32.dll          # Advanced Windows APIs

# Shell
shell32.dll           # Shell APIs (file dialogs)
shlwapi.dll           # Shell lightweight utilities

# DirectX (stubs - DXVK replaces these)
d3d9.dll              # Direct3D 9 (DXVK override)
d3d10.dll             # Direct3D 10 (DXVK override)
d3d10_1.dll           # Direct3D 10.1 (DXVK override)
d3d10core.dll         # D3D10 core (DXVK override)
d3d11.dll             # Direct3D 11 (DXVK override)
dxgi.dll              # DXGI (DXVK override)
ddraw.dll             # DirectDraw (legacy 2D)

# Audio
dsound.dll            # DirectSound
winmm.dll             # Windows Multimedia
mmdevapi.dll          # MM Device API
xaudio2_0.dll - xaudio2_9.dll  # XAudio2

# Input
dinput.dll            # DirectInput (legacy)
dinput8.dll           # DirectInput 8
xinput1_1.dll - xinput1_4.dll  # XInput (gamepad)
xinput9_1_0.dll       # XInput compat
hid.dll               # HID support

# Networking (CRITICAL for Guild Wars)
ws2_32.dll            # Winsock 2
iphlpapi.dll          # IP Helper
winhttp.dll           # HTTP client
wininet.dll           # Internet functions
urlmon.dll            # URL monikers
mswsock.dll           # Winsock extensions
dnsapi.dll            # DNS client

# Security (for TLS/HTTPS)
secur32.dll           # SSPI
crypt32.dll           # Crypto API
bcrypt.dll            # BCrypt primitives
ncrypt.dll            # NCrypt
schannel.dll          # TLS/SSL channel
rsaenh.dll            # RSA provider

# C Runtime
msvcrt.dll            # C runtime
ucrtbase.dll          # Universal CRT
vcruntime140.dll      # VC++ 2015+ runtime
msvcp140.dll          # C++ runtime

# Threading/Sync
kernelbase.dll        # (included above)
ntdll.dll             # (included above)
synchronization.dll   # Sync primitives

# Version info
version.dll           # Version info API

# Misc required
imm32.dll             # Input Method Manager
usp10.dll             # Uniscribe (text)
setupapi.dll          # Setup API
cfgmgr32.dll          # Config Manager
```

#### Core Executables (bin)

```
wine                  # Main Wine executable
wine64                # 64-bit Wine
wineserver            # Wine server process
wineboot              # Prefix initialization
```

#### Essential Wine Tools

```
reg.exe               # Registry tool
regedit.exe           # Registry editor (debugging)
winecfg.exe           # Wine configuration (optional)
```

#### Unix Libraries (lib/wine/x86_64-unix)

```
# Driver modules
winex11.drv.so        # X11 display driver
winewayland.drv.so    # Wayland driver (future)
winevulkan.so         # Vulkan ICD loader integration

# Audio backends
winealsa.drv.so       # ALSA audio
winepulse.drv.so      # PulseAudio

# OpenGL/Vulkan
opengl32.so           # OpenGL (wined3d fallback)
vulkan-1.so           # Vulkan loader
```

### 🔴 REMOVE - Non-Gaming Bloat

#### Large Components to Remove

```
# HTML Rendering (HUGE - ~100MB+)
mshtml.dll            # Trident engine
ieframe.dll           # IE frame
jscript.dll           # JavaScript (in mshtml)
vbscript.dll          # VBScript

# Printing (~20MB)
winspool.drv          # Print spooler
localspl.dll          # Local print provider
cups*                 # CUPS integration
wineps.drv            # PostScript driver

# Scanning (~10MB)
sane.ds               # SANE scanner
twain*                # TWAIN API
gphoto2.ds            # Camera

# Development Tools (~50MB)
widl.exe              # IDL compiler
wmc.exe               # Message compiler
wrc.exe               # Resource compiler
winegcc               # Wine GCC wrapper
winebuild             # PE builder
winedump              # PE dump utility

# Bundled Applications (~30MB)
notepad.exe           # Notepad
wordpad.exe           # WordPad
write.exe             # Write
iexplore.exe          # Internet Explorer stub
explorer.exe          # Windows Explorer (keep minimal stub)
taskmgr.exe           # Task Manager

# Media Codecs (let external handle)
wmvcore.dll           # WMV codec
wmp.dll               # Windows Media Player
quartz.dll            # DirectShow (unless needed)
winegstreamer.dll     # GStreamer (unless needed)

# .NET / Mono Support
mscoree.dll           # .NET runtime loader
fusion.dll            # .NET assembly
mscorwks.dll          # .NET execution engine

# Network Services (not needed for client games)
netapi32.dll          # Windows Networking
wkscli.dll            # Workstation service
srvcli.dll            # Server service
samcli.dll            # SAM client
```

#### Services to Disable

```
# Via registry (HKLM\System\CurrentControlSet\Services\)
PlugPlay=3            # Disabled (3=manual)
Spooler=3             # Print spooler disabled
wuauserv=3            # Windows Update disabled
BITS=3                # Background transfer disabled
```

### 🟡 CONDITIONAL - Game-Dependent

```
# DirectShow (some games need video playback)
quartz.dll            # DirectShow core
devenum.dll           # Device enumerator
amstream.dll          # AM stream

# DirectMusic (older games)
dmime.dll             # DM implementation
dmloader.dll          # DM loader
dmsynth.dll           # DM synthesizer

# DirectPlay (LAN multiplayer)
dplayx.dll            # DirectPlay
dpnet.dll             # DirectPlay Network
```

---

## Configure Options

### Recommended ./configure for wine-gaming

```bash
./configure \
    --prefix=/opt/wine \
    \
    # Architecture
    --enable-win64 \
    --enable-archs=i386,x86_64 \
    \
    # Disable non-gaming features
    --without-cups \          # No printing
    --without-sane \          # No scanning  
    --without-gphoto \        # No camera
    --without-v4l2 \          # No video capture
    --without-capi \          # No ISDN
    --without-netapi \        # No Windows networking
    --without-ldap \          # No LDAP
    --without-opencl \        # No OpenCL
    --without-pcap \          # No packet capture
    --without-oss \           # Use ALSA instead
    --without-coreaudio \     # Linux only
    --without-osmesa \        # No software GL
    \
    # Keep gaming features
    --with-alsa \             # Audio (ALSA)
    --with-pulse \            # Audio (PulseAudio)  
    --with-vulkan \           # Vulkan support
    --with-x \                # X11 support
    --with-freetype \         # Font rendering
    --with-fontconfig \       # Font config
    --with-opengl \           # OpenGL (wined3d fallback)
    \
    # Disable unnecessary
    --disable-tests \         # No test suite
    --disable-winemenubuilder # No desktop integration
```

### MinGW Cross-Compile Flags

```bash
# For PE DLL building
export CROSSCFLAGS="-O2 -march=x86-64 -mtune=generic"
export CROSSLDFLAGS="-Wl,--file-alignment,4096"
```

---

## Post-Build Stripping

### Strip Debug Symbols

```bash
# Strip all executables and libraries
find /opt/wine -type f \( \
    -name "*.dll" -o \
    -name "*.so" -o \
    -name "*.exe" -o \
    -name "*.drv" -o \
    -name "*.sys" \
\) -exec strip --strip-unneeded {} \;
```

### Remove Development Files

```bash
# Remove headers and import libraries
rm -rf /opt/wine/include
rm -rf /opt/wine/lib/wine/*.a
rm -rf /opt/wine/lib/wine/*.def

# Remove development tools
rm -f /opt/wine/bin/widl
rm -f /opt/wine/bin/wmc  
rm -f /opt/wine/bin/wrc
rm -f /opt/wine/bin/winegcc
rm -f /opt/wine/bin/wineg++
rm -f /opt/wine/bin/winebuild
rm -f /opt/wine/bin/winedump
rm -f /opt/wine/bin/winecpp
rm -f /opt/wine/bin/function_grep.pl
rm -f /opt/wine/bin/winedbg
```

### Remove Bloat DLLs

```bash
# Create removal script
cat > strip-wine-gaming.sh << 'EOF'
#!/bin/bash
WINE_PREFIX="$1"

# Large non-gaming DLLs to remove
REMOVE_DLLS=(
    # HTML/Browser
    "mshtml.dll" "ieframe.dll" "jscript.dll" "vbscript.dll"
    "mshtml.tlb" "ieframe.tlb"
    
    # Printing
    "winspool.drv" "localspl.dll" "wineps.drv" "spoolsv.exe"
    
    # Scanning
    "sane.ds" "twain_32.dll" "gphoto2.ds"
    
    # .NET
    "mscoree.dll" "fusion.dll" "mscorwks.dll"
    
    # Apps
    "notepad.exe" "wordpad.exe" "write.exe"
    "iexplore.exe"
    
    # Media (if not needed)
    "wmvcore.dll" "wmp.dll" "wmplayer.exe"
)

for dll in "${REMOVE_DLLS[@]}"; do
    find "$WINE_PREFIX" -name "$dll" -delete
done

# Remove Gecko/Mono placeholders
rm -rf "$WINE_PREFIX/share/wine/gecko"
rm -rf "$WINE_PREFIX/share/wine/mono"
EOF
```

### Size Estimation After Stripping

| Component | Full Size | After Strip |
|-----------|-----------|-------------|
| PE DLLs (x86_64-windows) | ~600 MB | ~150 MB |
| PE DLLs (i386-windows) | ~400 MB | ~100 MB |
| Unix libs (x86_64-unix) | ~200 MB | ~50 MB |
| Binaries | ~50 MB | ~20 MB |
| Fonts | ~20 MB | ~10 MB |
| **Total** | ~1.4 GB | ~150-200 MB |

---

## Testing Checklist

### Guild Wars Functionality Test

```
[ ] Game launches without crash
[ ] Login screen displays correctly
[ ] Can connect to login server (networking)
[ ] Can authenticate (TLS/HTTPS)
[ ] Audio plays (music, sound effects)
[ ] Keyboard input works (WASD, chat)
[ ] Mouse input works (camera, clicking)
[ ] Game graphics render correctly (via DXVK)
[ ] Can enter game world
[ ] No performance regression vs full Wine
```

### Generic Gaming Test Suite

```
[ ] DXVK injection works (d3d9 → Vulkan)
[ ] WoW64 mode works (32-bit on 64-bit Wine)
[ ] Winsock networking functional
[ ] DirectSound audio plays
[ ] DirectInput recognizes keyboard/mouse
[ ] XInput recognizes gamepad (if present)
[ ] Font rendering works
[ ] Dialog boxes display correctly
```

### Regression Tests

```
[ ] No missing DLL errors at startup
[ ] No Wine fixme floods (check WINEDEBUG=+err)
[ ] wineboot completes successfully
[ ] Registry operations work (reg.exe)
[ ] File dialogs open (shell32)
```

---

## Implementation Plan

### Phase 1: Configure-Time Reduction

1. Update `build/wine/Dockerfile` with gaming-specific `./configure` flags
2. Disable compile-time features (cups, sane, gphoto, etc.)
3. Build and measure size reduction

**Expected savings:** ~100-200 MB

### Phase 2: Post-Build Stripping

1. Strip debug symbols from all binaries
2. Remove development tools (widl, wmc, wrc, winegcc)
3. Remove headers and import libraries
4. Remove documentation

**Expected savings:** ~200-400 MB

### Phase 3: DLL Surgery

1. Create `strip-wine-gaming.sh` script
2. Remove bloat DLLs (mshtml, printing, scanning)
3. Test with Guild Wars

**Expected savings:** ~500-800 MB

### Phase 4: Validation

1. Run full test suite
2. Verify Guild Wars works end-to-end
3. Test additional games (suggest 2-3 more)
4. Document any issues

### Phase 5: Integration

1. Update build scripts for gaming profile
2. Create bundle-index entry for wine-gaming
3. Update compatibility-matrix.json
4. Document in README

---

## File Structure

Final wine-gaming bundle structure:

```
wine-gaming-9.22-x86_64/
├── manifest.json
├── bin/
│   ├── wine
│   ├── wine64
│   ├── wineserver
│   └── wineboot
├── lib/
│   └── wine/
│       ├── x86_64-unix/
│       │   ├── winex11.drv.so
│       │   ├── winealsa.drv.so
│       │   ├── winepulse.drv.so
│       │   ├── winevulkan.so
│       │   └── [~50 .so files]
│       ├── x86_64-windows/
│       │   └── [~100 essential .dll files]
│       └── i386-windows/
│           └── [~80 essential .dll files for WoW64]
└── share/
    └── wine/
        ├── fonts/
        │   └── [core fonts only]
        └── wine.inf
```

---

## References

- [Winlator Source](https://github.com/brunodev85/winlator) - Reference implementation
- [Wine-TKG](https://github.com/Frogging-Family/wine-tkg-git) - Gaming patches and customization
- [Proton](https://github.com/ValveSoftware/Proton) - Valve's Wine distribution
- [Wine Wiki - Building](https://gitlab.winehq.org/wine/wine/-/wikis/Building-Wine)
- [Guild Wars AppDB](https://appdb.winehq.org/objectManager.php?sClass=application&iId=1648)
- [ProtonDB - Guild Wars](https://www.protondb.com/app/29570)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-25 | Initial specification |

---

## Notes

### Why Not Just Use Winlator's Wine?

Winlator's Wine is tightly coupled to their build system and includes patches specific to their architecture. By creating our own gaming-optimized Wine:

1. We control the patches and can update independently
2. We can optimize specifically for Turnstone's architecture
3. We learn the build system for future improvements
4. We can contribute improvements back to the community

### Mono and Gecko

Some games use .NET or embedded HTML:

- **Without Mono:** `.NET` games won't work
- **Without Gecko:** Games with embedded browsers (launchers) won't work

For Guild Wars specifically, neither is required. For broader compatibility, we may create a `wine-gaming-full` variant that includes these.

### DXVK Integration

This spec assumes DXVK is installed separately (as it is in our current bundle system). The Wine gaming build provides the *stubs* for d3d9/d3d10/d3d11, which DXVK overrides at runtime.
