---
name: plugin-bar-widget
description: Development guide for Noctalia bar widgets that run in top, bottom, left, or right bar sections. Use when building or debugging BarWidget.qml structure, sizing, interactions, and context menus.
---

# Noctalia Bar Widget Development

Bar widgets extend the Noctalia status bar (top, bottom, left, or right) with custom functionality.

## Required Imports

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
```

## Base Structure (Standard Pattern)

```qml
Item {
  id: root

  // Required: Plugin API injection
  property var pluginApi: null

  // Required: Bar widget properties (injected by shell)
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""           // "left", "center", or "right"
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Per-screen properties (required for multi-monitor support)
  readonly property string screenName: screen?.name ?? ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  // Content dimensions (visual capsule)
  readonly property real contentWidth: content.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: capsuleHeight

  // Widget dimensions
  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Visual capsule - centered with extended click area
  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight

    // Required styling
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // Widget content
    RowLayout {
      id: content
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "your-icon"
        color: Color.mPrimary
      }

      NText {
        text: "Status"
        color: Color.mOnSurface
        pointSize: barFontSize
      }
    }
  }

  // MouseArea at root for extended click area
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      pluginApi?.togglePanel(root.screen, root)
    }
  }
}
```

## Using NIconButton (Simpler Alternative)

For icon-only widgets, extend `NIconButton`:

```qml
NIconButton {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  icon: "layout-dashboard"
  tooltipText: pluginApi?.tr("widget.tooltip")
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL

  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: pluginApi?.togglePanel(screen, this)
}
```

## Context Menu (Right-Click)

```qml
import qs.Widgets
import qs.Services.UI

NPopupContextMenu {
  id: contextMenu
  model: [
    { "label": pluginApi?.tr("menu.refresh") || "Refresh", "action": "refresh", "icon": "refresh" },
    { "label": pluginApi?.tr("menu.settings") || "Settings", "action": "settings", "icon": "settings" }
  ]
  onTriggered: action => {
    contextMenu.close()
    PanelService.closeContextMenu(screen)
    if (action === "refresh") {
      pluginApi?.mainInstance?.refresh()
    } else if (action === "settings") {
      BarService.openPluginSettings(screen, pluginApi.manifest)
    }
  }
}

MouseArea {
  id: mouseArea
  anchors.fill: parent
  hoverEnabled: true
  acceptedButtons: Qt.LeftButton | Qt.RightButton
  onClicked: (mouse) => {
    if (mouse.button === Qt.LeftButton) {
      pluginApi?.togglePanel(root.screen, root)
    } else if (mouse.button === Qt.RightButton) {
      PanelService.showContextMenu(contextMenu, root, screen)
    }
  }
}
```

## Accessing Main Instance State

```qml
readonly property var mainInstance: pluginApi?.mainInstance
readonly property bool isConnected: mainInstance?.connected || false
readonly property string status: mainInstance?.status || "unknown"

// React to state changes
icon: isConnected ? "check" : "x"
colorFg: isConnected ? Color.mPrimary : Color.mError
```

## Vertical Bar Support

```qml
readonly property real contentWidth: isBarVertical ? capsuleHeight : layout.implicitWidth + Style.marginM * 2
readonly property real contentHeight: isBarVertical ? layout.implicitHeight + Style.marginM * 2 : capsuleHeight

// Use ColumnLayout instead of RowLayout for vertical
ColumnLayout {
  id: layout
  visible: isBarVertical
  // ...
}
RowLayout {
  id: layout
  visible: !isBarVertical
  // ...
}
```

## Styling Constants

| Constant | Use For |
|----------|---------|
| `Style.capsuleColor` | Widget background |
| `Color.mHover` | Hover state background |
| `Color.mPrimary` | Accent/icon color |
| `Color.mOnSurface` | Primary text |
| `Color.mOnSurfaceVariant` | Secondary text |
| `Style.marginS` | Small spacing (6px base) |
| `Style.marginM` | Medium spacing (9px base) |
| `Style.radiusL` | Capsule corner radius |
| `Style.fontSizeM` | Standard text size |

## Common Patterns

### State-Driven Icons

```qml
icon: {
  if (isConnecting) return "loader"
  if (!isConnected) return "wifi-off"
  if (isPlaying) return "player-play"
  return "check"
}
```

```qml
tooltipText: {
  if (!isConnected) return pluginApi?.tr("tooltips.offline")
  return pluginApi?.tr("tooltips.online", { count: deviceCount })
}
```

### Settings Access

```qml
readonly property bool showLabels: pluginApi?.pluginSettings?.showLabels ?? true
readonly property int maxWidth: pluginApi?.pluginSettings?.maxWidth ?? defaultSettings.maxWidth
```

## Anti-Patterns to Avoid

1. **Don't hardcode sizes** - Always use `Style.uiScaleRatio` for scaling
2. **Don't use global Settings** - Use per-screen `getBarPositionForScreen()` etc.
3. **Don't store state locally** - Keep state in `Main.qml`, access via `mainInstance`
4. **Don't compute menu positions** - Use `PanelService.showContextMenu()`
5. **Don't use onEntered/onExited for hover** - Use property binding: `color: mouseArea.containsMouse ? ...`

## Testing Checklist

- [ ] Works on top bar position
- [ ] Works on bottom bar position
- [ ] Works on left bar position (vertical)
- [ ] Works on right bar position (vertical)
- [ ] Context menu appears correctly
- [ ] Panel opens near widget
- [ ] Tooltip displays correctly
- [ ] Hover effects work
- [ ] Multi-monitor support works
