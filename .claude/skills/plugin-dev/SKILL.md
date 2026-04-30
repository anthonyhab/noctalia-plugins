---
name: plugin-dev
description: Master reference for Noctalia Shell plugin architecture, file layout, and implementation patterns. Use when starting a new plugin or making cross-entry-point structural changes.
---

# Noctalia Plugin Development Guide

Master reference for developing Noctalia Shell plugins.

## Quick Start

```
my-plugin/
├── manifest.json           # Plugin metadata (required)
├── Main.qml                # Backend logic, IPC, state
├── BarWidget.qml           # Bar widget UI
├── Panel.qml               # Panel UI
├── Settings.qml            # Settings UI
├── ControlCenterWidget.qml # Control center button
├── i18n/
│   └── en.json            # Translations
└── README.md              # Documentation
```

## Entry Points

| Entry Point | File | Purpose |
|-------------|------|---------|
| `main` | Main.qml | State management, IPC handlers, background logic |
| `barWidget` | BarWidget.qml | Status bar widget |
| `panel` | Panel.qml | Full-screen overlay panel |
| `settings` | Settings.qml | Configuration UI |
| `controlCenterWidget` | ControlCenterWidget.qml | Control center button |
| `desktopWidget` | DesktopWidget.qml | Desktop widget |

## Manifest.json

```json
{
  "id": "unique-plugin-id",
  "name": "Plugin Name",
  "version": "0.1.0",
  "minNoctaliaVersion": "3.6.0",
  "entryPoints": {
    "main": "Main.qml",
    "barWidget": "BarWidget.qml",
    "panel": "Panel.qml",
    "settings": "Settings.qml"
  },
  "metadata": {
    "defaultSettings": {
      "enabled": true,
      "refreshInterval": 5000
    }
  }
}
```

## Architecture Pattern

```
┌─────────────────┐     ┌─────────────────┐
│   BarWidget.qml │────→│                 │
│   (UI - thin)   │     │   Main.qml      │
└─────────────────┘     │  (state owner)  │
                        │                 │
┌─────────────────┐     │  • State        │
│   Panel.qml     │────→│  • Polling      │
│   (UI - thin)   │     │  • IPC          │
└─────────────────┘     │  • Helpers      │
                        │                 │
┌─────────────────┐     │  • Persistence  │
│   Settings.qml  │←────│                 │
│   (config UI)   │     └─────────────────┘
└─────────────────┘              ↑
                                 │
                        ┌─────────────────┐
                        │   manifest.json   │
                        │  • entryPoints    │
                        │  • defaults       │
                        └─────────────────┘
```

## Component Guidelines

### Main.qml (State Owner)
- Owns all state and data
- Handles IPC commands
- Manages timers/polling
- Wraps helper processes
- Provides `refresh()` method

### BarWidget.qml (Thin UI)
- Reads state from `mainInstance`
- No local business logic
- Declares: `property var pluginApi: null`
- Uses per-screen properties

### Panel.qml (Interactive UI)
- Reads state from `mainInstance`
- Calls methods on `mainInstance`
- Uses `geometryPlaceholder` property
- Provides keyboard shortcuts

### Settings.qml (Configuration)
- Local edit state
- `saveSettings()` function
- Fallback to manifest defaults
- Triggers main refresh on save

## pluginApi Reference

```qml
// Properties
pluginApi.pluginId           // Plugin ID
pluginApi.pluginDir        // Plugin directory
pluginApi.pluginSettings   // Read/write settings
pluginApi.manifest         // Manifest object
pluginApi.currentLanguage  // Locale code
pluginApi.mainInstance     // Main.qml reference

// Methods
pluginApi.saveSettings()           // Persist settings
pluginApi.openPanel(screen, item)  // Open panel
pluginApi.closePanel(screen)       // Close panel
pluginApi.togglePanel(screen, item)// Toggle panel
pluginApi.tr("key")                // Translate
pluginApi.trp("key", count, ...)   // Pluralize
```

## Common Imports

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io       // For Process, IpcHandler
import qs.Commons          // Style, Color, Logger, I18n, Settings
import qs.Widgets          // NText, NButton, NIcon, etc.
import qs.Services.UI      // ToastService, PanelService, BarService
```

## Essential Patterns

### Settings with Fallback

```qml
readonly property string value:
  pluginApi?.pluginSettings?.key ??
  pluginApi?.manifest?.metadata?.defaultSettings?.key ??
  "fallback"
```

### Access Main Instance

```qml
readonly property var main: pluginApi?.mainInstance
readonly property bool connected: main?.connected ?? false
```

### IPC Handler

```qml
import Quickshell.Io

IpcHandler {
  target: "plugin:your-plugin-id"
  function refresh() {
    root.fetchData()
  }
}
```

### React to Settings Changes

```qml
Connections {
  target: pluginApi
  function onPluginSettingsChanged() {
    initialize()
  }
}
```

### Save Settings

```qml
function saveSettings() {
  pluginApi.pluginSettings.key = editValue
  pluginApi.saveSettings()
  pluginApi.mainInstance?.refresh()
}
```

## Anti-Patterns

1. **Don't store state in UI components** - Keep it in Main.qml
2. **Don't use `var` for settings** - Use `property type name`
3. **Don't compute menu positions** - Use `PanelService.showContextMenu()`
4. **Don't use global Settings** - Use per-screen helpers
5. **Don't skip null checks** - Always guard `pluginApi?.`

## Testing Checklist

- [ ] Plugin loads without errors
- [ ] Settings save and persist
- [ ] Bar widget displays correctly
- [ ] Bar widget context menu works
- [ ] Panel opens and closes
- [ ] Panel reacts to state changes
- [ ] Settings UI edits and saves
- [ ] IPC commands work
- [ ] Translations load
- [ ] Multi-monitor support
