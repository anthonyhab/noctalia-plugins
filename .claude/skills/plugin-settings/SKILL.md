---
name: plugin-settings
description: Implementation guide for plugin settings UIs integrated into Noctalia settings panels. Use when building or updating Settings.qml controls, local edit state, and persistence wiring.
---

# Noctalia Settings UI Development

Settings UI provides configuration interface integrated with Noctalia's settings panel.

## Required Imports

```qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
```

## Base Structure

```qml
ColumnLayout {
  id: root

  // Required: Plugin API injection
  property var pluginApi: null

  // Layout properties
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.minimumWidth: Math.round(520 * Style.uiScaleRatio)

  // Local edit state (initialized from settings)
  property string editValue: ""
  property bool editEnabled: true
  property int editCount: 0

  Component.onCompleted: {
    syncFromSettings()
  }

  // Sync local state from plugin settings
  function syncFromSettings() {
    editValue = getSetting("value", "")
    editEnabled = getSetting("enabled", true)
    editCount = getSetting("count", 0)
  }

  // Helper to get setting with fallback
  function getSetting(key, fallback) {
    return pluginApi?.pluginSettings?.[key] ??
           pluginApi?.manifest?.metadata?.defaultSettings?.[key] ??
           fallback
  }

  // REQUIRED: Save function called by settings dialog
  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.value = root.editValue
    pluginApi.pluginSettings.enabled = root.editEnabled
    pluginApi.pluginSettings.count = root.editCount

    pluginApi.saveSettings()

    // Trigger refresh in main instance
    pluginApi.mainInstance?.refresh()
  }

  // Settings controls here...
}
```

## Common Controls

### Text Input

```qml
NTextInput {
  Layout.fillWidth: true
  label: "Display Name"
  description: "Name shown in the widget"
  placeholderText: "Enter name..."
  text: root.editName
  onTextChanged: root.editName = text
}
```

### Toggle/Switch

```qml
NToggle {
  Layout.fillWidth: true
  label: "Enable Feature"
  description: "Turn this feature on or off"
  checked: root.editEnabled
  onToggled: checked => root.editEnabled = checked
}
```

### Checkbox

```qml
NCheckbox {
  text: "Show notifications"
  checked: root.editNotifications
  onCheckedChanged: root.editNotifications = checked
}
```

### Slider with Label

```qml
ColumnLayout {
  Layout.fillWidth: true
  spacing: Style.marginS

  NLabel {
    label: "Opacity"
    description: "Current value: " + Math.round(root.editOpacity)
  }

  NSlider {
    Layout.fillWidth: true
    from: 0
    to: 100
    value: root.editOpacity
    onValueChanged: root.editOpacity = value
  }
}
```

### SpinBox (Numeric)

```qml
ColumnLayout {
  Layout.fillWidth: true
  spacing: Style.marginS

  NLabel {
    label: "Refresh Interval"
    description: "Seconds between updates"
  }

  NSpinBox {
    from: 1
    to: 300
    value: root.editInterval
    onValueChanged: root.editInterval = value
  }
}
```

### ComboBox (Dropdown)

```qml
NComboBox {
  Layout.fillWidth: true
  label: "Display Mode"
  description: "How to show content"
  model: [
    { "key": "compact", "name": "Compact" },
    { "key": "normal", "name": "Normal" },
    { "key": "expanded", "name": "Expanded" }
  ]
  currentKey: root.editMode
  onSelected: key => root.editMode = key
}
```

### Color Picker

```qml
ColumnLayout {
  Layout.fillWidth: true
  spacing: Style.marginS

  NLabel {
    label: "Accent Color"
    description: "Custom highlight color"
  }

  NColorPicker {
    Layout.preferredWidth: Style.sliderWidth
    Layout.preferredHeight: Style.baseWidgetSize
    selectedColor: root.editColor
    onColorSelected: color => root.editColor = color
  }
}
```

## Tabbed Settings

```qml
// Tab bar
NTabBar {
  id: tabBar
  Layout.fillWidth: true
  currentIndex: 0
  distributeEvenly: true

  NTabButton {
    text: "Appearance"
    tabIndex: 0
    checked: tabBar.currentIndex === 0
  }

  NTabButton {
    text: "Connection"
    tabIndex: 1
    checked: tabBar.currentIndex === 1
  }
}

// Tab content
StackLayout {
  Layout.fillWidth: true
  Layout.fillHeight: true
  currentIndex: tabBar.currentIndex

  // Tab 0: Appearance
  ColumnLayout {
    spacing: Style.marginL
    // Appearance controls...
  }

  // Tab 1: Connection
  ColumnLayout {
    spacing: Style.marginL
    // Connection controls...
  }
}
```

## Section Dividers

```qml
NDivider {
  Layout.fillWidth: true
  Layout.topMargin: Style.marginM
  Layout.bottomMargin: Style.marginM
}

NText {
  text: "Section Title"
  pointSize: Style.fontSizeM
  font.weight: Style.fontWeightMedium
  color: Color.mOnSurface
  Layout.fillWidth: true
}

NText {
  text: "Section description goes here"
  wrapMode: Text.WordWrap
  color: Color.mOnSurfaceVariant
  pointSize: Style.fontSizeS
  Layout.fillWidth: true
}
```

## Connection Testing Pattern

```qml
property bool testingConnection: false
property string testResult: ""
property bool testSuccess: true

RowLayout {
  spacing: Style.marginM

  NButton {
    text: testingConnection ? "Testing..." : "Test Connection"
    enabled: !testingConnection && root.editUrl && root.editToken
    onClicked: testConnection()
  }

  NText {
    visible: testResult !== ""
    text: testResult
    color: testSuccess ? Color.mPrimary : Color.mError
  }
}

function testConnection() {
  testingConnection = true
  testResult = ""

  const xhr = new XMLHttpRequest()
  xhr.onreadystatechange = () => {
    if (xhr.readyState === XMLHttpRequest.DONE) {
      testingConnection = false
      if (xhr.status === 200) {
        testResult = "Connected!"
        testSuccess = true
      } else {
        testResult = "Failed: " + xhr.status
        testSuccess = false
      }
    }
  }
  xhr.open("GET", root.editUrl + "/api/")
  xhr.setRequestHeader("Authorization", "Bearer " + root.editToken)
  xhr.send()
}
```

## Settings Access Patterns

### Direct Access with Fallback Chain

```qml
readonly property string value:
  pluginApi?.pluginSettings?.value ??
  pluginApi?.manifest?.metadata?.defaultSettings?.value ??
  ""
```
