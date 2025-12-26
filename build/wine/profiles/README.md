# Wine Build Profiles

Build-time profiles that control what gets compiled into Wine bundles.

## Important: Build-Time vs Runtime

- **Build profiles** (this directory): Control what features are compiled in
- **Game profiles** (`game-profiles/`): Control runtime behavior (env vars, registry)

See [WINE_RUNTIME_PROFILES_PLAN.md](../../../.github/WINE_RUNTIME_PROFILES_PLAN.md) for architecture.

## Available Build Profiles

| Profile | Target Size | Use Case |
|---------|-------------|----------|
| `full.profile` | ~1.4GB | Development, maximum compatibility |
| `gaming.profile` | ~150-200MB | Production gaming builds |

## Usage

```bash
# Build with full profile (default)
./build-wine.sh 9.22

# Build with gaming profile
./build-wine.sh 9.22 gaming

# Explicitly specify full
./build-wine.sh 9.22 full
```

## Profile Contents

Each profile defines:

| Variable | Description |
|----------|-------------|
| `PROFILE_NAME` | Human-readable name |
| `PROFILE_TARGET_SIZE` | Expected installed size |
| `PROFILE_DESCRIPTION` | Description for manifest |
| `CAPABILITIES` | Features this build supports |
| `CONFIGURE_FLAGS` | Arguments to ./configure |
| `REMOVE_PATTERNS` | Files to delete after build |
| `STRIP_LEVEL` | How aggressively to strip binaries |

## Capabilities

Capabilities are declared in the bundle manifest so Turnstone app knows what features are available:

- `wow64` - 32-bit + 64-bit Windows support
- `esync` - eventfd synchronization
- `fsync` - futex synchronization
- `vulkan` - Vulkan graphics
- `opengl` - OpenGL graphics
- `gnutls` - TLS/SSL (required for online games)
- `gstreamer` - DirectShow/media playback
- `pulse-audio`, `alsa` - Audio backends

Game profiles can require specific capabilities.
