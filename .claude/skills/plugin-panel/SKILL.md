---
name: plugin-panel
description: Development guide for Noctalia panel entry points used for full-screen or anchored interactive interfaces. Use when implementing or debugging Panel.qml layout, focus, keyboard handling, and close behavior.
---

# Noctalia Panel Development

Panels are full-screen overlay components that provide detailed interfaces and complex interactions.

## Required Imports

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI
```

## Base Structure

```qml
Item {
  id: root

  // Required: Plugin API injection
  property var pluginApi: null

  // Required panel properties (read by PluginPanelSlot loader)
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  // Recommended dimensions (scaled for UI)
  property real contentPreferredWidth: 680 * Style.uiScaleRatio
  property real contentPreferredHeight: 540 * Style.uiScaleRatio

  // Fill the panel slot
  anchors.fill: parent

  // Content container (required for geometryPlaceholder)
  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: Color.mBackground
    radius: Style.radiusL

    // Panel content layout
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header row
      RowLayout {
        Layout.fillWidth: true
        NText {
          text: "Panel Title"
          pointSize: Style.fontSizeL
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }
        NIconButton {
          icon: "x"
          onClicked: pluginApi?.closePanel(pluginApi.panelOpenScreen)
        }
      }

      // Main content area
      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // ... content
      }
    }
  }
}
```

## State Access Pattern

```qml
// Access main instance for shared state
readonly property var mainInstance: pluginApi?.mainInstance
readonly property bool isConnected: mainInstance?.connected || false
readonly property var items: mainInstance?.items || []

// Call methods on main instance
function refresh() {
  mainInstance?.refresh()
}

function performAction(id) {
  mainInstance?.performAction(id)
}
```

## Settings Integration

```qml
// Access settings
readonly property var settings: pluginApi?.pluginSettings || {}
readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || {}

// With fallback chain
readonly property int refreshInterval: settings.refreshInterval ?? defaults.refreshInterval ?? 5000
readonly property bool showPreview: settings.showPreview ?? defaults.showPreview ?? true
```

## Panel Layout Patterns

### Card-Based Layout

```qml
NBox {
  Layout.fillWidth: true
  Layout.preferredHeight: content.implicitHeight + Style.marginM * 2
  color: Color.mSurface
  radius: Style.radiusM

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NText {
      text: "Card Title"
      font.weight: Font.Medium
      color: Color.mOnSurface
    }

    // Card content...
  }
}
```

### Grid Layout

```qml
NGridView {
  Layout.fillWidth: true
  Layout.fillHeight: true
  cellWidth: 120 * Style.uiScaleRatio
  cellHeight: 120 * Style.uiScaleRatio
  model: mainInstance?.items || []

  delegate: NBox {
    // Grid item content
  }
}
```

### List with Items

```qml
ListView {
  Layout.fillWidth: true
  Layout.fillHeight: true
  model: mainInstance?.items || []
  spacing: Style.marginS
  clip: true

  delegate: NBox {
    width: ListView.view.width
    height: 60 * Style.uiScaleRatio
    color: Color.mSurface

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      // Item content...
    }
  }
}
```

## Closing the Panel

```qml
// From a button
NIconButton {
  icon: "x"
  onClicked: pluginApi?.closePanel(pluginApi.panelOpenScreen)
}

// After an action
function onItemSelected(item) {
  mainInstance?.selectItem(item.id)
  pluginApi?.closePanel(pluginApi.panelOpenScreen)
}
```

## Keyboard Shortcuts

```qml
focus: true
Keys.onPressed: (event) => {
  if (event.key === Qt.Key_Escape) {
    pluginApi?.closePanel(pluginApi.panelOpenScreen)
    event.accepted = true
  }
}
```

## Styling Guidelines

- Use `Color.mBackground` for panel background
- Use `Color.mSurface` for cards/sections
- Use `Color.mPrimary` for active/selected states
- Use `Color.mOnSurface` for text on surfaces
- Use `Style.marginL` for panel margins
- Use `Style.marginM` for section spacing
- Use `Style.radiusL` for panel corners
- Use `Style.radiusM` for card corners

## Best Practices

1. **Always declare `geometryPlaceholder`** - Required by panel loader
2. **Use `allowAttach: true`** - Allows panel to attach to bar widgets
3. **Scale with `Style.uiScaleRatio`** - Respect user UI scaling
4. **Access state via `mainInstance`** - Don't duplicate state in panel
5. **Close on Escape key** - Standard UX pattern
6. **Handle null pluginApi** - Guard all API access
