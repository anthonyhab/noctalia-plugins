---
name: plugin-control-center
description: Implementation reference for Noctalia Control Center widgets and quick action buttons. Use when creating or fixing ControlCenterWidget.qml behavior, state display, and click handling.
---

# Noctalia Control Center Widget Development

Control Center widgets provide quick action buttons in the Control Center panel.

## Required Imports

```qml
import Quickshell
import qs.Widgets
```

## Base Structure

```qml
NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  icon: "your-icon"
  tooltipText: pluginApi?.tr("widget.tooltip")

  onClicked: {
    pluginApi?.togglePanel(screen, this)
  }
}
```

## Full Example

```qml
import Quickshell
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  // Visual properties
  icon: "layout-dashboard"
  tooltipText: pluginApi?.tr("widget.tooltip") || "Open Overview"

  // Click handler - typically opens panel
  onClicked: {
    pluginApi?.togglePanel(screen, this)
  }
}
```

## Using NIconButton Instead

```qml
import Quickshell
import qs.Widgets
import qs.Commons

NIconButton {
  property ShellScreen screen
  property var pluginApi: null

  icon: "settings"
  tooltipText: "Quick Action"

  // Color theming
  colorBg: Color.mSurface
  colorFg: Color.mOnSurface

  onClicked: {
    // Perform action or open panel
    pluginApi?.openPanel(screen, this)
  }
}
```

## Common Patterns

### Toggle Action

```qml
NIconButtonHot {
  property var pluginApi: null
  property ShellScreen screen

  readonly property bool isActive: pluginApi?.mainInstance?.isActive ?? false

  icon: isActive ? "check" : "x"
  tooltipText: isActive ? "Turn Off" : "Turn On"

  onClicked: {
    pluginApi?.mainInstance?.toggleState()
  }
}
```

### State Indicator

```qml
NIconButtonHot {
  property var pluginApi: null
  property ShellScreen screen

  readonly property string status: pluginApi?.mainInstance?.status || "unknown"

  icon: {
    switch (status) {
      case "online": return "wifi"
      case "offline": return "wifi-off"
      case "connecting": return "loader"
      default: return "help"
    }
  }

  tooltipText: "Status: " + status

  onClicked: pluginApi?.togglePanel(screen, this)
}
```

### Direct Action (No Panel)

```qml
NIconButtonHot {
  property var pluginApi: null
  property ShellScreen screen

  icon: "refresh"
  tooltipText: "Refresh Data"

  onClicked: {
    pluginApi?.mainInstance?.refresh()
    ToastService.showNotice("Refreshed")
  }
}
```

## Manifest Entry

```json
{
  "entryPoints": {
    "controlCenterWidget": "ControlCenterWidget.qml"
  }
}
```

## Comparison with Bar Widgets

| Aspect | Bar Widget | Control Center Widget |
|--------|-----------|------------------------|
| Base Component | `Item` with `Rectangle` | `NIconButtonHot` or `NIconButton` |
| Size | Variable (capsule-based) | Fixed (control center grid) |
| Position | Bar (top/bottom/left/right) | Control Center panel |
| Complexity | Can show text + icon | Usually icon-only |
| Context Menu | Yes (optional) | No |

## Best Practices

1. **Keep it simple** - Control center buttons should be icon-only
2. **Use `NIconButtonHot`** - Hot variant provides appropriate styling
3. **Provide tooltip** - Always include tooltipText for accessibility
4. **Handle null pluginApi** - Guard all API access
5. **Use translations** - `pluginApi?.tr("key")` for text
