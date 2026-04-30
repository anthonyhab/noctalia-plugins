---
name: plugin-desktop-widget
description: Development guide for Noctalia desktop widgets rendered on the desktop background. Use when building or debugging DesktopWidget.qml layout, sizing, and background-safe interactions.
---

# Noctalia Desktop Widget Development

Desktop widgets provide at-a-glance information on the desktop background.

## Required Imports

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
```

## Base Structure

```qml
Rectangle {
  id: root

  // Required: Plugin API injection
  property var pluginApi: null

  // Desktop widget properties (injected by shell)
  property ShellScreen screen
  property real widgetScale: 1.0
  property bool editMode: false

  // Size configuration
  implicitWidth: 200 * widgetScale * Style.uiScaleRatio
  implicitHeight: 150 * widgetScale * Style.uiScaleRatio

  // Visual styling
  color: Color.mSurface
  radius: Style.radiusL
  border.color: Color.mOutline
  border.width: Style.borderS

  // Content area
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM * widgetScale
    spacing: Style.marginS * widgetScale

    // Widget content...
  }
}
```

## Scale-Aware Sizing

```qml
// Base sizes (unscaled)
readonly property real baseWidth: 200
readonly property real baseHeight: 150

// Scaled sizes
implicitWidth: baseWidth * widgetScale * Style.uiScaleRatio
implicitHeight: baseHeight * widgetScale * Style.uiScaleRatio

// Scaled margins
anchors.margins: Style.marginM * widgetScale

// Scaled fonts
pointSize: Style.fontSizeM * widgetScale
```

## Edit Mode Indicator

```qml
Rectangle {
  anchors.fill: parent
  color: "transparent"
  border.color: editMode ? Color.mPrimary : "transparent"
  border.width: editMode ? 2 : 0

  // Drag handle or resize indicator
  NIcon {
    visible: editMode
    anchors.top: parent.top
    anchors.right: parent.right
    icon: "arrows-move"
    color: Color.mPrimary
  }
}
```

## State Access

```qml
readonly property var mainInstance: pluginApi?.mainInstance
readonly property var items: mainInstance?.items || []
readonly property string status: mainInstance?.status || "unknown"
```

## Refresh on Visibility

```qml
onVisibleChanged: {
  if (visible && mainInstance) {
    mainInstance.refresh()
  }
}

Timer {
  id: refreshTimer
  interval: 60000
  running: visible
  repeat: true
  onTriggered: mainInstance?.refresh()
}
```

## Minimal Widget Example

```qml
Rectangle {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property real widgetScale: 1.0
  property bool editMode: false

  implicitWidth: 120 * widgetScale * Style.uiScaleRatio
  implicitHeight: 60 * widgetScale * Style.uiScaleRatio

  color: Color.mSurface
  radius: Style.radiusL

  NText {
    anchors.centerIn: parent
    text: root.pluginApi?.mainInstance?.value || "--"
    pointSize: Style.fontSizeL * widgetScale
    color: Color.mOnSurface
  }
}
```

## Complex Widget with Header

```qml
Rectangle {
  id: root
  property var pluginApi: null
  property ShellScreen screen
  property real widgetScale: 1.0
  property bool editMode: false

  implicitWidth: 240 * widgetScale
  implicitHeight: 180 * widgetScale

  color: Color.mSurface
  radius: Style.radiusL

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM * widgetScale
    spacing: Style.marginS * widgetScale

    // Header
    RowLayout {
      Layout.fillWidth: true
      NIcon {
        icon: "clock"
        color: Color.mPrimary
        pointSize: Style.fontSizeM * widgetScale
      }
      NText {
        text: "Clock"
        font.weight: Font.Medium
        color: Color.mOnSurface
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    NDivider {
      Layout.fillWidth: true
    }

    // Content
    NText {
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: root.pluginApi?.mainInstance?.timeString || "--:--"
      pointSize: Style.fontSizeXL * widgetScale
      color: Color.mOnSurface
    }
  }
}
```

## Manifest Entry

```json
{
  "entryPoints": {
    "desktopWidget": "DesktopWidget.qml"
  }
}
```

## Differences from Bar Widgets

| Aspect | Bar Widget | Desktop Widget |
|--------|-----------|----------------|
| Base | `Item` with capsule | `Rectangle` or `NBox` |
| Scaling | Per-screen | `widgetScale` property |
| Position | Bar sections | User-positioned on desktop |
| Edit mode | N/A | `editMode` property |
| Size | Constrained by bar | User-resizable |

## Best Practices

1. **Use `widgetScale`** - Respect user scale preference
2. **Scale fonts** - `pointSize: baseSize * widgetScale`
3. **Scale margins** - `anchors.margins: Style.marginM * widgetScale`
4. **Handle `editMode`** - Show visual indicator
5. **Refresh on visibility** - Update when shown
6. **Keep it compact** - Desktop space is limited
7. **Use high contrast** - Desktop may have varying backgrounds
