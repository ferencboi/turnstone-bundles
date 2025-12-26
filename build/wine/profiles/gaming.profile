# Wine Gaming Profile - Build Configuration
# =============================================================================
# Target: ~150-200MB installed
# Use case: General gaming - covers most games
#
# This is a BUILD-TIME profile only. It controls what gets compiled into Wine.
# Game-specific settings (env vars, registry tweaks) are applied at RUNTIME
# via game profiles in the Turnstone app.
#
# See: .github/WINE_RUNTIME_PROFILES_PLAN.md for architecture details
# =============================================================================

PROFILE_NAME="gaming"
PROFILE_TARGET_SIZE="150-200MB"
PROFILE_DESCRIPTION="Gaming-optimized Wine build with non-gaming components removed"

# =============================================================================
# CAPABILITIES
# =============================================================================
# These are declared in the bundle manifest so Turnstone app knows what
# features this build supports. Game profiles can require specific capabilities.

CAPABILITIES=(
    "wow64"         # 32-bit + 64-bit Windows app support
    "esync"         # eventfd-based synchronization
    "fsync"         # futex-based synchronization (kernel dependent)
    "vulkan"        # Vulkan graphics support
    "opengl"        # OpenGL graphics support
    "pulse-audio"   # PulseAudio support
    "alsa"          # ALSA audio support
    "gnutls"        # TLS/SSL support (required for online games)
    "gstreamer"     # DirectShow/media support
    "x11"           # X11 windowing
    "freetype"      # Font rendering
    "usb"           # USB device support (controllers)
    "udev"          # Device hotplug detection
    "dbus"          # D-Bus support (Bluetooth controllers)
)

# =============================================================================
# CONFIGURE FLAGS
# =============================================================================
# Based on consolidated spec from multiple AI models
# See: .github/WINE_BUILD_SPEC_CONSOLIDATED.md

CONFIGURE_FLAGS=(
    # Architecture: Pure WoW64 (unanimous AI consensus)
    "--enable-win64"
    "--enable-archs=i386,x86_64"
    
    # === KEEP (Gaming Essential) ===
    "--with-x"
    "--with-vulkan"
    "--with-opengl"
    "--with-pulse"
    "--with-alsa"
    "--with-freetype"
    "--with-fontconfig"
    "--with-gnutls"             # CRITICAL: Required for TLS/game login
    "--with-gstreamer"          # DirectShow for video cutscenes
    "--with-usb"                # USB HID devices (controllers)
    "--with-udev"               # Device hotplug (controller connect/disconnect)
    "--with-dbus"               # D-Bus (Bluetooth controller support)
    
    # === REMOVE (Bloat) ===
    "--without-cups"            # Printing (-20MB)
    "--without-sane"            # Scanning (-10MB)
    "--without-gphoto"          # Camera (-8MB)
    "--without-v4l2"            # Video capture (-5MB)
    "--without-ldap"            # Directory services (-12MB)
    "--without-krb5"            # Kerberos (-8MB)
    "--without-netapi"          # SMB networking (-15MB)
    "--without-pcap"            # Packet capture (-6MB)
    "--without-opencl"          # GPU compute (-18MB)
    "--without-oss"             # OSS audio (use ALSA/Pulse)
    "--without-coreaudio"       # macOS only
    "--without-osmesa"          # Software OpenGL (-25MB)
    "--without-capi"            # ISDN (-5MB)
    "--without-unwind"          # Stack unwinding
    "--without-inotify"         # File watching
    
    # === BUILD OPTIONS ===
    "--disable-tests"
    "--disable-winemenubuilder"
)

# Compiler flags - optimize for size and performance
PROFILE_CFLAGS="-O2 -ffunction-sections -fdata-sections -march=x86-64 -mtune=generic"
PROFILE_LDFLAGS="-Wl,--gc-sections"

# =============================================================================
# REMOVAL PATTERNS
# =============================================================================
# Glob patterns for files/directories to remove after build
# These are components that no game needs

REMOVE_PATTERNS=(
    # Development tools (never needed at runtime)
    "bin/widl"
    "bin/winebuild"
    "bin/wrc"
    "bin/wmc"
    "bin/winegcc"
    "bin/winecpp"
    "bin/wineg++"
    "bin/winedump"
    "bin/function_grep.pl"
    
    # Development files
    "include/*"
    "lib/wine/*.a"
    "lib/wine/*.def"
    
    # Gecko/Mono (massive, games do not need browser engine)
    "share/wine/gecko"
    "share/wine/mono"
    
    # Browser engine (80-120MB savings)
    "lib/wine/*/mshtml.dll"
    "lib/wine/*/ieframe.dll"
    "lib/wine/*/jscript.dll"
    "lib/wine/*/vbscript.dll"
    "lib/wine/*/msscript.ocx"
    
    # Printing subsystem (already disabled via --without-cups)
    "lib/wine/*/winspool.drv"
    "lib/wine/*/wineps.drv"
    "lib/wine/*/localspl.dll"
    "lib/wine/*/spoolss.dll"
    
    # Scanner (already disabled via --without-sane)
    "lib/wine/*/sane.ds"
    "lib/wine/*/twain_32.dll"
    "lib/wine/*/gphoto2.ds"
    
    # Windows apps not needed for gaming
    "lib/wine/*/notepad.exe"
    "lib/wine/*/wordpad.exe"
    "lib/wine/*/write.exe"
    "lib/wine/*/iexplore.exe"
    "lib/wine/*/winefile.exe"
    "lib/wine/*/winemine.exe"
    "lib/wine/*/winhlp32.exe"
    "lib/wine/*/progman.exe"
    "lib/wine/*/clock.exe"
    "lib/wine/*/taskmgr.exe"
    "lib/wine/*/wineconsole.exe"
    "bin/msiexec"
    
    # Accessibility
    "lib/wine/*/oleacc.dll"
    "lib/wine/*/uiautomationcore.dll"
    
    # .NET interop (games use native code)
    "lib/wine/*/mscoree.dll"
    "lib/wine/*/fusion.dll"
    "lib/wine/*/clr.dll"
    
    # Box64 specific: preloader not needed when invoking via box64
    "bin/wine64-preloader"
    "bin/wine-preloader"
)

# =============================================================================
# STRIP LEVEL
# =============================================================================
# none: No stripping
# debug: Strip debug symbols only (--strip-debug) - RECOMMENDED
# full: Strip everything (--strip-unneeded) - May break anti-cheat

STRIP_LEVEL="debug"
