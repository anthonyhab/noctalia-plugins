---
name: plugin-manifest
description: Specification guide for Noctalia plugin manifest metadata, entry points, and defaults. Use when creating or updating manifest.json fields, IDs, versions, and dependency declarations.
---

# Noctalia Plugin Manifest

Defines the plugin metadata and entry points required for all Noctalia plugins.

## File: `manifest.json`

```json
{
  "id": "unique-plugin-id",
  "name": "Human Readable Name",
  "version": "0.1.0",
  "minNoctaliaVersion": "3.6.0",
  "author": "your-name",
  "license": "MIT",
  "repository": "https://github.com/your/repo",
  "description": "Brief description of what the plugin does",
  "tags": ["Bar", "Panel", "Productivity"],
  "entryPoints": {
    "main": "Main.qml",
    "panel": "Panel.qml",
    "barWidget": "BarWidget.qml",
    "settings": "Settings.qml",
    "controlCenterWidget": "ControlCenterWidget.qml"
  },
  "dependencies": {
    "plugins": []
  },
  "metadata": {
    "defaultSettings": {
      "key": "value"
    }
  }
}
```

## Required Fields

| Field | Description |
|-------|-------------|
| `id` | Globally unique identifier (kebab-case) |
| `name` | Human-readable display name |
| `version` | SemVer version string |
| `minNoctaliaVersion` | Minimum compatible Noctalia version |

## Entry Points

All entry points are optional but must exist if referenced:

- **`main`**: Background logic with IPC handlers, state management
- **`panel`**: Full-screen overlay panel UI
- **`barWidget`**: Status bar widget
- **`settings`**: Settings configuration UI
- **`controlCenterWidget`**: Quick action button in Control Center
- **`desktopWidget`**: Desktop background widget
- **`launcherProvider`**: Launcher search provider

## Default Settings Pattern

```json
"metadata": {
  "defaultSettings": {
    "apiUrl": "",
    "apiToken": "",
    "refreshInterval": 5000,
    "enabled": true
  }
}
```

## Plugin Directory Structure

```
my-plugin/
├── manifest.json           # Required
├── Main.qml                # Backend/state (if entryPoints.main)
├── Panel.qml               # Panel UI (if entryPoints.panel)
├── BarWidget.qml           # Bar widget (if entryPoints.barWidget)
├── Settings.qml            # Settings UI (if entryPoints.settings)
├── ControlCenterWidget.qml # Control center button (if entryPoints.controlCenterWidget)
├── i18n/
│   └── en.json            # Translations (recommended)
└── README.md              # User documentation
```

## Best Practices

1. **Always use kebab-case for plugin IDs** (`my-plugin`, not `myPlugin`)
2. **Keep defaultSettings comprehensive** - every configurable option should have a default
3. **Document dependencies** in README.md
4. **Use semantic versioning** - bump version on every change
5. **Test minNoctaliaVersion** against actual API requirements
