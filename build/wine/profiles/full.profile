# Wine Full Profile - Maximum Compatibility
# =============================================================================
# Target: ~1.4GB installed
# Use case: Development, testing, maximum compatibility
#
# This is a BUILD-TIME profile only. It controls what gets compiled into Wine.
# Game-specific settings (env vars, registry tweaks) are applied at RUNTIME
# via game profiles in the Turnstone app.
#
# See: .github/WINE_RUNTIME_PROFILES_PLAN.md for architecture details
# =============================================================================

PROFILE_NAME="Wine Full"
PROFILE_TARGET_SIZE="1.4GB"
PROFILE_DESCRIPTION="Full Wine build with all features - for development and maximum compatibility"

# =============================================================================
# CAPABILITIES
# =============================================================================
# Full build has all capabilities

CAPABILITIES=(
    "wow64"         # 32-bit + 64-bit Windows app support
    "esync"         # eventfd-based synchronization
    "fsync"         # futex-based synchronization (kernel dependent)
    "vulkan"        # Vulkan graphics support
    "opengl"        # OpenGL graphics support
    "pulse-audio"   # PulseAudio support
    "alsa"          # ALSA audio support
    "gnutls"        # TLS/SSL support
    "gstreamer"     # DirectShow/media support
    "x11"           # X11 windowing
    "freetype"      # Font rendering
    "cups"          # Printing support
    "sane"          # Scanner support
    "v4l2"          # Video capture
    "ldap"          # Directory services
    "krb5"          # Kerberos authentication
    "opencl"        # GPU compute
    "usb"           # USB device support
)

# =============================================================================
# CONFIGURE FLAGS
# =============================================================================

CONFIGURE_FLAGS=(
    "--enable-win64"
    "--enable-archs=i386,x86_64"
    "--disable-tests"
)

# Compiler flags
PROFILE_CFLAGS="-O2 -march=x86-64 -mtune=generic"
PROFILE_LDFLAGS=""

# =============================================================================
# REMOVAL PATTERNS
# =============================================================================
# Full build - remove nothing except dev tools

REMOVE_PATTERNS=(
    # Only remove development tools
    "bin/widl"
    "bin/winebuild"
    "bin/wrc"
    "bin/wmc"
    "bin/winegcc"
    "bin/winecpp"
    "bin/wineg++"
    "bin/winedump"
    "bin/function_grep.pl"
    "include/*"
    "lib/wine/*.a"
    "lib/wine/*.def"
)

# =============================================================================
# STRIP LEVEL
# =============================================================================

STRIP_LEVEL="debug"
