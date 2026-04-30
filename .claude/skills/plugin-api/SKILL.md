---
name: plugin-api
description: Complete reference for the `pluginApi` object injected into Noctalia plugin components. Use when reading or implementing pluginApi properties, panel controls, settings persistence, or translation calls.
---

# Noctalia Plugin API Reference

Complete reference for the `pluginApi` object injected into all plugin components.

## Core Properties

| Property | Type | Description |
|----------|------|-------------|
| `pluginId` | string | Unique plugin identifier from manifest |
| `pluginDir` | string | Absolute path to plugin folder |
| `pluginSettings` | object | Read/write settings object (persisted) |
| `manifest` | object | Full manifest.json content |
| `currentLanguage` | string | Current UI language code (e.g., "en") |
| `mainInstance` | var | Reference to Main.qml instance |
| `barWidget` | var | Reference to bar widget component |
| `pluginTranslations` | object | Loaded translation strings |

## Core Methods

### Settings Persistence

```qml
// Save settings to disk (required after mutation)
pluginApi.saveSettings()
```

### Panel Control

```qml
// Open panel (optionally anchored to sourceItem)
pluginApi.openPanel(screen)
pluginApi.openPanel(screen, sourceItem)

// Close panel
pluginApi.closePanel(screen)

// Toggle panel
pluginApi.togglePanel(screen, sourceItem)

// Get current screen
pluginApi.withCurrentScreen(callback)
```

### Launcher Control (Provider Plugins)

```qml
pluginApi.openLauncher(screen)
pluginApi.closeLauncher(screen)
pluginApi.toggleLauncher(screen)
```

### Translations

```qml
// Basic translation
pluginApi.tr("key")
pluginApi.tr("key", { param: value })

// Pluralization
pluginApi.trp("key", count, singularDefault, pluralDefault)

// Check exists
pluginApi.hasTranslation("key")
```

## Settings Object

Persisted to `~/.config/noctalia/plugins/{pluginId}.json`.

### Reading with Fallback

```qml
readonly property string value:
  pluginApi?.pluginSettings?.key ??
  pluginApi?.manifest?.metadata?.defaultSettings?.key ??
  "default"
```

### Writing

```qml
pluginApi.pluginSettings.key = newValue
pluginApi.saveSettings()
```

### Reacting to Changes

```qml
Connections {
  target: pluginApi
  function onPluginSettingsChanged() { ... }
}
```

## Noctalia Services

### Toast Notifications

```qml
import qs.Services.UI
ToastService.showNotice("Success")
ToastService.showError("Failed")
```

### Logger

```qml
import qs.Commons
Logger.d("Tag", "Debug", value)
Logger.i("Tag", "Info")
Logger.w("Tag", "Warning")
Logger.e("Tag", "Error", err)
```

### Panel Service

```qml
import qs.Services.UI
PanelService.showContextMenu(menu, item, screen)
PanelService.closeContextMenu(screen)
```

### Bar Service

```qml
import qs.Services.UI
BarService.getTooltipDirection(screenName)
BarService.openPluginSettings(screen, manifest)
BarService.getPillDirection(widget)
```

### Tooltip Service

```qml
TooltipService.show(target, text, direction)
TooltipService.hide()
```

## Styling Constants

### Colors

```qml
Color.mBackground, Color.mSurface, Color.mPrimary
Color.mOnSurface, Color.mOnSurfaceVariant
Color.mOutline, Color.mHover, Color.mError
```

### Spacing (base * uiScaleRatio)

```qml
Style.marginXXS, XS, S, M, L, XL
```

### Radii

```qml
Style.radiusXXS-XL       // Containers
Style.iRadiusXXS-L       // Inputs
```

### Typography

```qml
Style.fontSizeXS, S, M, L, XL, XXL
```

### Bar Widgets

```qml
Style.barHeight
Style.capsuleHeight, capsuleColor, capsuleBorderColor
Style.getCapsuleHeightForScreen(screenName)
Style.getBarFontSizeForScreen(screenName)
```

### Scaling

```qml
Style.uiScaleRatio
```
