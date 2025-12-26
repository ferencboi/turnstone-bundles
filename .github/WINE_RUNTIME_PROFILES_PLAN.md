# Wine Runtime Profiles Architecture Plan

> **Status:** APPROVED - Ready for implementation  
> **Created:** 2025-12-26  
> **Decision Makers:** User + AI collaboration  
> **Reference Game:** Guild Wars: Factions

---

## Executive Summary

Separate **build-time optimization** from **runtime configuration**. Wine bundles become self-describing, declaring their capabilities. Game-specific settings move to runtime profiles that Turnstone app applies at launch.

---

## Key Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Build profiles | Only `full` and `gaming` | Simpler maintenance, covers all games |
| Game-specific config | Runtime profiles (not build-time) | Non-destructive, user-adjustable |
| Bundle metadata | Self-describing with capabilities | App does not need updates for new Wine settings |
| Schema versioning | Yes, include `settingsSchemaVersion` | Forward compatibility |
| Official profiles location | This repo (`game-profiles/`) | Community-maintained, curated |
| Custom profiles | Turnstone app manages | Users can clone/edit official profiles |
| Capabilities | Explicitly declared in bundle | Clear contract, no inference needed |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TURNSTONE-BUNDLES REPO                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  templates/                                                                 │
│    wine-settings-schema.json    <-- Master schema of ALL Wine settings     │
│    game-profile-schema.json     <-- Schema for game profile JSON files     │
│                                                                             │
│  game-profiles/                                                             │
│    guild-wars.json              <-- Official Guild Wars profile            │
│    generic-dx9.json             <-- Generic DirectX 9 games                │
│    generic-dx11.json            <-- Generic DirectX 11 games               │
│                                                                             │
│  build/wine/profiles/                                                       │
│    full.profile                 <-- Build everything (dev/testing)         │
│    gaming.profile               <-- Stripped for gaming (production)       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ Published via GitHub Releases
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WINE BUNDLE (tar.zst)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  wine-9.22-gaming-x86_64/                                                   │
│    manifest.json                <-- Extended with capabilities + settings  │
│    bin/                                                                     │
│    lib/                                                                     │
│    share/                                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ Downloaded by app
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TURNSTONE APP (Android)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. Reads manifest.json from bundle                                         │
│  2. Discovers capabilities and configurable settings                        │
│  3. Fetches official game profiles from repo (or uses cached)              │
│  4. User selects/customizes profile                                         │
│  5. At launch: applies env vars, registry tweaks, args                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## File Specifications

### 1. Wine Settings Schema (`templates/wine-settings-schema.json`)

Master definition of ALL configurable Wine settings. Turnstone app uses this to render UI.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "settingsSchemaVersion": 1,
  "title": "Wine Runtime Settings Schema",
  "description": "Defines all configurable Wine settings for Turnstone",
  
  "settings": {
    "environment": {
      "WINEDEBUG": {
        "type": "string",
        "default": "-all",
        "description": "Wine debug output channels",
        "category": "debugging",
        "examples": ["-all", "+loaddll", "+err,+warn"]
      },
      "WINEESYNC": {
        "type": "boolean",
        "default": true,
        "description": "Enable eventfd-based synchronization (faster)",
        "category": "performance",
        "requires": ["esync"]
      },
      "WINEFSYNC": {
        "type": "boolean",
        "default": true,
        "description": "Enable futex-based synchronization (fastest, kernel 5.16+)",
        "category": "performance",
        "requires": ["fsync"]
      },
      "WINE_LARGE_ADDRESS_AWARE": {
        "type": "boolean",
        "default": true,
        "description": "Allow 32-bit apps to use more memory",
        "category": "compatibility"
      },
      "WINEDLLOVERRIDES": {
        "type": "string",
        "default": "",
        "description": "DLL load order overrides",
        "category": "compatibility",
        "examples": ["d3d9=n,b", "d3d11,dxgi=n,b"]
      }
    },
    
    "registry": {
      "wine.direct3d.MaxShaderModelVS": {
        "path": "HKCU\\Software\\Wine\\Direct3D",
        "value": "MaxShaderModelVS",
        "type": "string",
        "default": null,
        "description": "Limit vertex shader model (e.g., 3.0)",
        "category": "graphics"
      },
      "wine.direct3d.MaxShaderModelPS": {
        "path": "HKCU\\Software\\Wine\\Direct3D",
        "value": "MaxShaderModelPS",
        "type": "string",
        "default": null,
        "description": "Limit pixel shader model (e.g., 3.0)",
        "category": "graphics"
      },
      "wine.direct3d.csmt": {
        "path": "HKCU\\Software\\Wine\\Direct3D",
        "value": "csmt",
        "type": "dword",
        "default": 3,
        "description": "Command stream multi-threading mode",
        "category": "performance"
      },
      "wine.x11.UseTakeFocus": {
        "path": "HKCU\\Software\\Wine\\X11 Driver",
        "value": "UseTakeFocus",
        "type": "string",
        "default": "Y",
        "description": "Window focus handling (N for Android)",
        "category": "display"
      },
      "wine.x11.GrabPointer": {
        "path": "HKCU\\Software\\Wine\\X11 Driver",
        "value": "GrabPointer",
        "type": "string",
        "default": "N",
        "description": "Capture mouse pointer in window",
        "category": "input"
      },
      "wine.x11.GrabFullscreen": {
        "path": "HKCU\\Software\\Wine\\X11 Driver",
        "value": "GrabFullscreen",
        "type": "string",
        "default": "N",
        "description": "Grab input in fullscreen mode",
        "category": "input"
      }
    },
    
    "dxvk": {
      "DXVK_ASYNC": {
        "type": "boolean",
        "default": true,
        "description": "Async shader compilation (reduces stutter)",
        "category": "performance"
      },
      "DXVK_STATE_CACHE": {
        "type": "boolean",
        "default": true,
        "description": "Cache pipeline state (faster subsequent loads)",
        "category": "performance"
      },
      "DXVK_LOG_LEVEL": {
        "type": "enum",
        "values": ["none", "error", "warn", "info", "debug"],
        "default": "none",
        "description": "DXVK logging verbosity",
        "category": "debugging"
      },
      "DXVK_HUD": {
        "type": "string",
        "default": "",
        "description": "DXVK overlay elements",
        "category": "debugging",
        "examples": ["fps", "fps,memory", "full"]
      }
    },
    
    "turnip": {
      "TU_DEBUG": {
        "type": "string",
        "default": "",
        "description": "Turnip debug flags",
        "category": "debugging",
        "examples": ["noconform", "norobust"]
      },
      "mesa_glthread": {
        "type": "boolean",
        "default": true,
        "description": "Enable threaded GL optimization",
        "category": "performance"
      },
      "MESA_NO_ERROR": {
        "type": "boolean",
        "default": false,
        "description": "Skip OpenGL error checking (faster but unsafe)",
        "category": "performance"
      }
    },
    
    "box64": {
      "BOX64_DYNAREC": {
        "type": "boolean",
        "default": true,
        "description": "Enable dynamic recompilation",
        "category": "performance"
      },
      "BOX64_DYNAREC_BIGBLOCK": {
        "type": "boolean",
        "default": true,
        "description": "Use larger JIT blocks",
        "category": "performance"
      },
      "BOX64_DYNAREC_STRONGMEM": {
        "type": "enum",
        "values": ["0", "1", "2"],
        "default": "0",
        "description": "Memory model strictness (0=relaxed, faster)",
        "category": "compatibility"
      },
      "BOX64_DYNAREC_FASTNAN": {
        "type": "boolean",
        "default": true,
        "description": "Fast NaN handling (may break some games)",
        "category": "performance"
      },
      "BOX64_DYNAREC_FASTROUND": {
        "type": "boolean",
        "default": true,
        "description": "Fast FP rounding (may break some games)",
        "category": "performance"
      }
    }
  },
  
  "categories": {
    "performance": { "label": "Performance", "icon": "speed" },
    "compatibility": { "label": "Compatibility", "icon": "tune" },
    "graphics": { "label": "Graphics", "icon": "display" },
    "input": { "label": "Input", "icon": "gamepad" },
    "display": { "label": "Display", "icon": "monitor" },
    "debugging": { "label": "Debugging", "icon": "bug" }
  }
}
```

### 2. Bundle Manifest Extension (`manifest.json` inside bundle)

Wine bundles declare their capabilities and which settings apply.

```json
{
  "id": "wine-9.22-gaming-x86_64",
  "type": "wine",
  "version": "9.22",
  "profile": "gaming",
  "arch": "x86_64",
  "buildDate": "2025-12-26T00:00:00Z",
  "installedSizeBytes": 157286400,
  
  "settingsSchemaVersion": 1,
  
  "capabilities": [
    "wow64",
    "esync",
    "fsync",
    "vulkan",
    "opengl",
    "pulse-audio",
    "alsa",
    "gnutls",
    "x11"
  ],
  
  "buildFlags": {
    "included": [
      "--with-vulkan",
      "--with-opengl",
      "--with-pulse",
      "--with-alsa",
      "--with-gnutls",
      "--with-x"
    ],
    "excluded": [
      "--without-cups",
      "--without-sane",
      "--without-gphoto",
      "--without-v4l2",
      "--without-ldap",
      "--without-gstreamer"
    ]
  },
  
  "configurableSettings": [
    "environment.WINEDEBUG",
    "environment.WINEESYNC",
    "environment.WINEFSYNC",
    "environment.WINE_LARGE_ADDRESS_AWARE",
    "environment.WINEDLLOVERRIDES",
    "registry.wine.direct3d.*",
    "registry.wine.x11.*",
    "dxvk.*",
    "turnip.*",
    "box64.*"
  ],
  
  "notes": "Gaming-optimized build. WoW64 mode for 32/64-bit. No printing/scanning/camera."
}
```

### 3. Game Profile Schema (`templates/game-profile-schema.json`)

Defines the structure of game-specific profile files.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "gameProfileSchemaVersion": 1,
  "title": "Turnstone Game Profile Schema",
  
  "type": "object",
  "required": ["id", "name", "version"],
  
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique profile identifier (kebab-case)",
      "pattern": "^[a-z0-9-]+$"
    },
    "name": {
      "type": "string",
      "description": "Human-readable profile name"
    },
    "version": {
      "type": "string",
      "description": "Profile version (semver)"
    },
    "gameInfo": {
      "type": "object",
      "properties": {
        "title": { "type": "string" },
        "developer": { "type": "string" },
        "releaseYear": { "type": "integer" },
        "directXVersion": { "type": "string" },
        "executable": { "type": "string" },
        "steamAppId": { "type": "integer" },
        "gogId": { "type": "string" }
      }
    },
    "minimumWineVersion": {
      "type": "string",
      "description": "Minimum Wine version required"
    },
    "requiredCapabilities": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Capabilities the Wine bundle must have"
    },
    "environment": {
      "type": "object",
      "additionalProperties": { "type": "string" },
      "description": "Environment variables to set"
    },
    "registry": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "path": { "type": "string" },
          "value": { "type": "string" },
          "data": { "type": ["string", "integer"] },
          "type": { "enum": ["REG_SZ", "REG_DWORD"] }
        }
      },
      "description": "Registry entries to apply"
    },
    "dllOverrides": {
      "type": "object",
      "additionalProperties": { 
        "enum": ["native", "builtin", "native,builtin", "builtin,native", "disabled", ""]
      },
      "description": "DLL override settings"
    },
    "gameArguments": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Command-line arguments for the game"
    },
    "wineArguments": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Command-line arguments for Wine itself"
    },
    "notes": {
      "type": "string",
      "description": "Usage notes and known issues"
    },
    "testedWith": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "wineVersion": { "type": "string" },
          "dxvkVersion": { "type": "string" },
          "turnipVersion": { "type": "string" },
          "status": { "enum": ["platinum", "gold", "silver", "bronze", "broken"] }
        }
      }
    }
  }
}
```

### 4. Example Game Profile (`game-profiles/guild-wars.json`)

```json
{
  "id": "guild-wars",
  "name": "Guild Wars (All Campaigns)",
  "version": "1.0.0",
  
  "gameInfo": {
    "title": "Guild Wars: Factions",
    "developer": "ArenaNet",
    "releaseYear": 2006,
    "directXVersion": "9.0c",
    "executable": "Gw.exe"
  },
  
  "minimumWineVersion": "9.0",
  
  "requiredCapabilities": [
    "wow64",
    "gnutls",
    "pulse-audio"
  ],
  
  "environment": {
    "WINEDEBUG": "-all",
    "WINEESYNC": "1",
    "WINEFSYNC": "1",
    "WINE_LARGE_ADDRESS_AWARE": "1",
    "DXVK_ASYNC": "1",
    "DXVK_STATE_CACHE": "1",
    "DXVK_LOG_LEVEL": "none",
    "TU_DEBUG": "noconform",
    "mesa_glthread": "true",
    "BOX64_DYNAREC": "1",
    "BOX64_DYNAREC_BIGBLOCK": "1",
    "BOX64_DYNAREC_STRONGMEM": "0",
    "BOX64_DYNAREC_FASTNAN": "1",
    "BOX64_DYNAREC_FASTROUND": "1"
  },
  
  "dllOverrides": {
    "d3d9": "native,builtin"
  },
  
  "registry": [
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides",
      "value": "d3d9",
      "data": "native",
      "type": "REG_SZ"
    },
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D",
      "value": "MaxShaderModelVS",
      "data": "3.0",
      "type": "REG_SZ"
    },
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D",
      "value": "MaxShaderModelPS",
      "data": "3.0",
      "type": "REG_SZ"
    },
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D",
      "value": "csmt",
      "data": 3,
      "type": "REG_DWORD"
    },
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver",
      "value": "UseTakeFocus",
      "data": "N",
      "type": "REG_SZ"
    },
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver",
      "value": "GrabPointer",
      "data": "Y",
      "type": "REG_SZ"
    },
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver",
      "value": "GrabFullscreen",
      "data": "Y",
      "type": "REG_SZ"
    },
    {
      "path": "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\Spooler",
      "value": "Start",
      "data": 4,
      "type": "REG_DWORD"
    },
    {
      "path": "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\wuauserv",
      "value": "Start",
      "data": 4,
      "type": "REG_DWORD"
    },
    {
      "path": "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides",
      "value": "winemenubuilder.exe",
      "data": "disabled",
      "type": "REG_SZ"
    }
  ],
  
  "gameArguments": [
    "-bmp"
  ],
  
  "wineArguments": [],
  
  "notes": "Guild Wars 1 (Prophecies, Factions, Nightfall, Eye of the North). Requires working TLS for login (gnutls). Uses DirectX 9, works well with DXVK. May show launcher news incorrectly without mshtml, but gameplay unaffected.",
  
  "testedWith": [
    {
      "wineVersion": "9.22",
      "dxvkVersion": "2.5.3",
      "turnipVersion": "25.3.2",
      "status": "gold"
    }
  ]
}
```

---

## UI Rendering Contract

This section defines how the Turnstone app should interpret bundle manifests and settings schemas to dynamically render configuration UI. This is the contract between turnstone-bundles and the Turnstone Android app.

### Data Flow

```
┌───────────────────────────────────────────────────────────────────────────────┐
│  1. App downloads bundle -> extracts manifest.json                            │
│  2. App fetches wine-settings-schema.json (cached, versioned)                 │
│  3. App filters schema by manifest.configurableSettings                       │
│  4. App filters settings by manifest.capabilities (disable unsupported)       │
│  5. App renders UI grouped by category                                        │
│  6. User edits -> stored as game profile JSON                                 │
│  7. At launch: profile values merged with defaults, applied as env/registry   │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Type-to-Widget Mapping

The `type` field in the settings schema determines which UI widget to render:

| Schema Type | Widget | Notes |
|-------------|--------|-------|
| `boolean` | Toggle/Switch | On/Off states |
| `string` | TextField | Free-form text input |
| `string` + `enum` | Dropdown/Spinner | Constrained to enum values |
| `string` + `examples` | TextField + Suggestions | Show autocomplete from examples |
| `integer` / `dword` | NumberPicker or Slider | Use `min`/`max` if present |
| `integer` + `min` + `max` | Slider | When range is reasonable (e.g., 0-10) |
| `array` of `string` | Chip list / Tag editor | Add/remove items |

**Example rendering logic (pseudocode):**

```kotlin
fun renderSetting(key: String, schema: SettingSchema): Widget {
    // Check if setting is available for this bundle
    if (schema.requires != null && !bundle.capabilities.containsAll(schema.requires)) {
        return DisabledWidget(reason = "Requires: ${schema.requires.joinToString()}")
    }
    
    // Check if setting is app-managed
    if (schema.managed == true) {
        return null  // Do not render, app controls this
    }
    
    return when (schema.type) {
        "boolean" -> ToggleWidget(
            label = key,
            description = schema.description,
            default = schema.default as Boolean
        )
        "string" -> {
            if (schema.enum != null) {
                DropdownWidget(options = schema.enum, default = schema.default)
            } else {
                TextFieldWidget(
                    hints = schema.examples,
                    default = schema.default as String?
                )
            }
        }
        "integer", "dword" -> {
            if (schema.min != null && schema.max != null && (schema.max - schema.min) <= 20) {
                SliderWidget(min = schema.min, max = schema.max, default = schema.default)
            } else {
                NumberPickerWidget(min = schema.min, max = schema.max, default = schema.default)
            }
        }
        else -> TextFieldWidget(default = schema.default?.toString())
    }
}
```

### Special Field Behaviors

| Field | Behavior |
|-------|----------|
| `requires: ["capability"]` | Gray out / disable if bundle lacks capability. Show tooltip explaining why. |
| `managed: true` | Do not render. App controls this value (e.g., WINEPREFIX). |
| `default: value` | Pre-populate widget. Show "Reset to default" option if user changes it. |
| `description: "..."` | Show as subtitle or info icon tooltip. |
| `examples: [...]` | For string fields: show as autocomplete suggestions or quick-pick chips. |
| `category: "..."` | Group settings under category headers in UI. |
| `min` / `max` | Validate input. Show error if out of range. |
| `pattern: "regex"` | Validate string input against regex. |

### Capability-Based Filtering

Settings with a `requires` array should check against the bundle's `capabilities`:

```kotlin
// manifest.json from bundle
val bundleCapabilities = setOf("wow64", "esync", "vulkan", "pulse-audio", ...)

// From wine-settings-schema.json
val fsyncSetting = schema.settings.environment["WINEFSYNC"]
// fsyncSetting.requires = ["fsync"]

if (!bundleCapabilities.containsAll(fsyncSetting.requires)) {
    // Render as disabled with explanation
    showDisabledToggle(
        label = "WINEFSYNC",
        reason = "This bundle was not built with fsync support"
    )
}
```

### Wildcard Expansion in configurableSettings

The manifest's `configurableSettings` array may contain wildcards:

```json
{
  "configurableSettings": [
    "environment.WINEDEBUG",
    "environment.WINEESYNC",
    "registry.wine.direct3d.*",   // Wildcard
    "dxvk.*",                      // Wildcard
    "box64.*"                      // Wildcard
  ]
}
```

**Expansion algorithm:**

```kotlin
fun expandConfigurableSettings(
    patterns: List<String>,
    schema: SettingsSchema
): Set<String> {
    val result = mutableSetOf<String>()
    
    for (pattern in patterns) {
        if (pattern.endsWith(".*")) {
            // Wildcard: match all keys starting with prefix
            val prefix = pattern.dropLast(2)  // Remove ".*"
            val section = schema.getSection(prefix)  // e.g., "dxvk" -> schema.settings.dxvk
            section?.keys?.forEach { key ->
                result.add("$prefix.$key")
            }
        } else {
            // Exact match
            result.add(pattern)
        }
    }
    
    return result
}
```

### Category Grouping and Order

Settings should be grouped by `category` field. Display order:

1. **performance** - Most impactful settings first
2. **graphics** - Visual quality settings
3. **compatibility** - Workarounds and fixes
4. **display** - Window/resolution settings
5. **input** - Controller/keyboard settings
6. **debugging** - Developer/troubleshooting (collapsed by default)

**Category metadata from schema:**

```json
"categories": {
  "performance": { "label": "Performance", "icon": "speed" },
  "compatibility": { "label": "Compatibility", "icon": "tune" },
  "graphics": { "label": "Graphics", "icon": "display" },
  "input": { "label": "Input", "icon": "gamepad" },
  "display": { "label": "Display", "icon": "monitor" },
  "debugging": { "label": "Debugging", "icon": "bug" }
}
```

**Icon mapping (Material Icons recommended):**

| Icon Name | Material Icon |
|-----------|---------------|
| `speed` | `speed` or `bolt` |
| `tune` | `tune` |
| `display` | `display_settings` |
| `gamepad` | `sports_esports` |
| `monitor` | `monitor` |
| `bug` | `bug_report` |

### Settings Namespaces

Settings are organized by namespace prefix:

| Prefix | Applied As | Example |
|--------|------------|---------|
| `environment.*` | Environment variable | `WINEESYNC=1` |
| `registry.*` | Wine registry key | `wine reg add "HKCU\..."` |
| `dxvk.*` | DXVK environment variable | `DXVK_ASYNC=1` |
| `turnip.*` | Mesa/Turnip environment variable | `TU_DEBUG=...` |
| `box64.*` | Box64 environment variable | `BOX64_DYNAREC=1` |

### Value Serialization

When applying settings at runtime:

| Schema Type | Serialization |
|-------------|---------------|
| `boolean` (env var) | `"1"` or `"0"` |
| `boolean` (registry DWORD) | `1` or `0` |
| `string` | As-is |
| `integer` / `dword` | String representation for env, numeric for registry |

**Example:**

```kotlin
fun serializeForEnvironment(key: String, value: Any, schema: SettingSchema): String {
    return when (schema.type) {
        "boolean" -> if (value as Boolean) "1" else "0"
        else -> value.toString()
    }
}

// WINEESYNC=true -> export WINEESYNC=1
// DXVK_HUD="fps,devinfo" -> export DXVK_HUD="fps,devinfo"
```

### Schema Versioning

The `settingsSchemaVersion` field ensures compatibility:

```kotlin
val bundleSchemaVersion = manifest.settingsSchemaVersion  // e.g., 1
val appSchemaVersion = 1  // Hardcoded in app

when {
    bundleSchemaVersion == appSchemaVersion -> {
        // Perfect match, render all settings
    }
    bundleSchemaVersion < appSchemaVersion -> {
        // Bundle is older, app knows more settings than bundle declares
        // Only render settings from bundle's configurableSettings
    }
    bundleSchemaVersion > appSchemaVersion -> {
        // Bundle is newer, may have settings app does not understand
        // Render known settings, warn user to update app
        showWarning("Update Turnstone app for full settings support")
    }
}
```

### Complete UI Rendering Example

```kotlin
fun renderSettingsScreen(bundle: BundleManifest, schema: SettingsSchema) {
    // 1. Expand wildcards
    val availableSettings = expandConfigurableSettings(
        bundle.configurableSettings, 
        schema
    )
    
    // 2. Group by category
    val grouped = availableSettings
        .mapNotNull { key -> schema.getSetting(key)?.let { key to it } }
        .groupBy { (_, setting) -> setting.category }
    
    // 3. Render in category order
    val categoryOrder = listOf("performance", "graphics", "compatibility", 
                               "display", "input", "debugging")
    
    for (category in categoryOrder) {
        val settings = grouped[category] ?: continue
        val categoryMeta = schema.categories[category]
        
        // Render category header
        renderCategoryHeader(
            label = categoryMeta?.label ?: category.capitalize(),
            icon = categoryMeta?.icon,
            collapsed = (category == "debugging")  // Debugging collapsed by default
        )
        
        // Render each setting
        for ((key, setting) in settings) {
            val widget = renderSetting(key, setting)
            if (widget != null) {
                addWidget(widget)
            }
        }
    }
}
```

---

## Implementation Checklist

### Phase 1: Build System Simplification
- [x] Delete `build/wine/profiles/guild-wars.profile`
- [x] Simplify `build/wine/profiles/gaming.profile` (build-time only)
- [x] Update `build/wine/build-wine.sh` to support two profiles
- [x] Add capability detection based on configure flags
- [x] Generate extended manifest.json with capabilities

### Phase 2: Schema Creation
- [x] Create `templates/wine-settings-schema.json`
- [x] Create `templates/game-profile-schema.json`
- [ ] Add JSON Schema validation to CI (optional)

### Phase 3: Game Profiles
- [x] Create `game-profiles/` directory
- [x] Add `guild-wars.json`
- [x] Add `generic-dx9.json`
- [x] Add `generic-dx11.json`
- [x] Update README with profile documentation

### Phase 4: Bundle Index Updates
- [ ] Add `settingsSchemaVersion` to bundle entries
- [ ] Add `capabilities` array to bundle entries
- [ ] Document new fields in copilot-instructions.md

### Phase 5: Documentation
- [ ] Update GAMING_ARCHITECTURE.md with runtime profile concept
- [ ] Add game profile contribution guide
- [ ] Document Turnstone app integration requirements

---

## API Contract: Turnstone App Integration

The Turnstone Android app should:

1. **On bundle download:**
   - Read `manifest.json` from bundle
   - Cache `capabilities` and `configurableSettings`
   - Check `settingsSchemaVersion` for compatibility

2. **On profile fetch:**
   - Fetch game profiles from `https://raw.githubusercontent.com/ferencboi/turnstone-bundles/main/game-profiles/{id}.json`
   - Cache locally
   - Allow user to duplicate and edit

3. **On game launch:**
   - Verify `requiredCapabilities` against bundle capabilities
   - Warn if mismatch
   - Apply environment variables
   - Apply registry entries (via `wine reg add` or direct prefix edit)
   - Launch with combined arguments

4. **Profile precedence:**
   ```
   User custom profile > Official game profile > Generic profile > Bundle defaults
   ```

---

## Schema Versioning Policy

- `settingsSchemaVersion`: Integer, starts at 1
- `gameProfileSchemaVersion`: Integer, starts at 1

**Rules:**
- Additive changes (new settings): No version bump required
- Backward-compatible changes: Minor bump consideration
- Breaking changes (removed/renamed settings): Major bump, Turnstone must handle

**Compatibility matrix in app:**
```
App supports schema v1 → Can use bundles with settingsSchemaVersion 1
App supports schema v2 → Can use bundles with settingsSchemaVersion 1 or 2
```

---

## Recovery Instructions

If context is lost, start here:

1. Read this document
2. Check `build/wine/profiles/` for current build profiles
3. Check `templates/` for schemas
4. Check `game-profiles/` for runtime profiles
5. Resume from the unchecked items in Implementation Checklist

---

## References

- [WINE_BUILD_SPEC_CONSOLIDATED.md](.github/WINE_BUILD_SPEC_CONSOLIDATED.md) - Build optimization details
- [GAMING_ARCHITECTURE.md](.github/GAMING_ARCHITECTURE.md) - Overall architecture
- [copilot-instructions.md](.github/copilot-instructions.md) - Repo conventions
