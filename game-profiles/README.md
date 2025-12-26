# Game Profiles

Official game profiles for Turnstone. These define runtime configuration for specific games.

## What Are Game Profiles?

Game profiles are JSON files that tell Turnstone how to configure Wine, DXVK, Turnip, and Box64 for a specific game. They are applied at **runtime**, not build time.

## Available Profiles

| Profile | Game | DirectX | Status |
|---------|------|---------|--------|
| [guild-wars.json](guild-wars.json) | Guild Wars (All Campaigns) | DX9 | Gold |
| [generic-dx9.json](generic-dx9.json) | Generic DirectX 9 games | DX9 | - |
| [generic-dx11.json](generic-dx11.json) | Generic DirectX 11 games | DX11 | - |

## Using Profiles

Turnstone app automatically fetches these profiles. Users can:
1. Select an official profile for their game
2. Clone and customize a profile
3. Create a new profile from scratch

## Profile Structure

```json
{
  "id": "game-name",
  "name": "Game Title",
  "version": "1.0.0",
  "gameInfo": { ... },
  "requiredCapabilities": ["wow64", "gnutls"],
  "environment": { ... },
  "registry": [ ... ],
  "dllOverrides": { ... },
  "notes": "..."
}
```

See [game-profile-schema.json](../templates/game-profile-schema.json) for full schema.

## Contributing

To add a new game profile:

1. Copy `generic-dx9.json` or `generic-dx11.json` as a starting point
2. Fill in game-specific information
3. Test the configuration
4. Submit a pull request

### Profile Naming

- Use kebab-case: `game-name.json`
- For games with subtitles: `game-name-subtitle.json`
- For sequels: `game-name-2.json`

### Testing Status

Use ProtonDB-style ratings:
- **platinum** - Perfect, runs flawlessly
- **gold** - Minor issues that do not affect gameplay
- **silver** - Playable with some tweaks or issues
- **bronze** - Runs but has significant issues
- **broken** - Does not work

## Schema Version

Current schema version: **1**

Profiles must be compatible with the schema version. The Turnstone app validates profiles against the schema.
