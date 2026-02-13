import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.minimumWidth: Math.round(520 * Style.uiScaleRatio)
  Layout.preferredWidth: Layout.minimumWidth

  readonly property var defaultSettings: (pluginApi && pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings) || ({})
  readonly property var pluginMain: pluginApi && pluginApi.mainInstance

  // Local state
  property int gridRows: 2
  property int gridColumns: 5
  property real gridScale: 0.16
  property bool hideEmptyRows: true
  property string overviewPosition: "top"

  function getSetting(key, fallback) {
    if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings[key] !== undefined) {
      return pluginApi.pluginSettings[key]
    }
    if (defaultSettings && defaultSettings[key] !== undefined) {
      return defaultSettings[key]
    }
    return fallback
  }

  function syncFromPlugin() {
    if (!pluginApi)
      return
    gridRows = parseInt(getSetting("rows", 2)) || 2
    gridColumns = parseInt(getSetting("columns", 5)) || 5
    gridScale = parseFloat(getSetting("scale", 0.16)) || 0.16
    hideEmptyRows = !!getSetting("hideEmptyRows", true)
    overviewPosition = getSetting("position", "top") || "top"
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  function saveSettings() {
    if (!pluginApi)
      return

    var settings = pluginApi.pluginSettings || {}

    settings.rows = gridRows
    settings.columns = gridColumns
    settings.scale = gridScale
    settings.hideEmptyRows = hideEmptyRows
    settings.position = overviewPosition

    pluginApi.pluginSettings = settings
    pluginApi.saveSettings()

    pluginMain && pluginMain.refresh()
  }

  // Description
  NText {
    text: pluginApi && pluginApi.tr("plugin.description") || "Visual workspace overview with live window previews for Hyprland"
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NDivider {
    Layout.fillWidth: true
  }

  // === Workspace Grid ===
  NHeader {
    label: pluginApi && pluginApi.tr("settings.grid.title") || "Workspace Grid"
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NSpinBox {
      Layout.fillWidth: true
      label: pluginApi && pluginApi.tr("settings.grid.rows.label") || "Rows"
      description: pluginApi && pluginApi.tr("settings.grid.rows.description") || "Number of workspace rows"
      from: 1
      to: 10
      value: root.gridRows
      onValueChanged: {
        if (root.gridRows !== value) {
          root.gridRows = value
          root.saveSettings()
        }
      }
    }

    NSpinBox {
      Layout.fillWidth: true
      label: pluginApi && pluginApi.tr("settings.grid.columns.label") || "Columns"
      description: pluginApi && pluginApi.tr("settings.grid.columns.description") || "Number of workspace columns"
      from: 1
      to: 20
      value: root.gridColumns
      onValueChanged: {
        if (root.gridColumns !== value) {
          root.gridColumns = value
          root.saveSettings()
        }
      }
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi && pluginApi.tr("settings.grid.scale.label") || "Scale"
    description: pluginApi && pluginApi.tr("settings.grid.scale.description") || "Overview scale factor"
    from: 0.05
    to: 0.50
    stepSize: 0.01
    value: root.gridScale
    text: value.toFixed(2)
    onMoved: value => {
      if (Math.abs(root.gridScale - value) > 0.001) {
        root.gridScale = value
        root.saveSettings()
      }
    }
  }

  NText {
    text: {
      var total = root.gridRows * root.gridColumns
      return total + " total workspaces"
    }
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NDivider {
    Layout.fillWidth: true
  }

  // === Behavior ===
  NHeader {
    label: pluginApi && pluginApi.tr("settings.behavior.title") || "Behavior"
  }

  NToggle {
    label: pluginApi && pluginApi.tr("settings.behavior.hide-empty-rows.label") || "Hide empty rows"
    description: pluginApi && pluginApi.tr("settings.behavior.hide-empty-rows.description") || "Automatically hide workspace rows with no windows"
    checked: root.hideEmptyRows
    onToggled: checked => {
      root.hideEmptyRows = checked
      root.saveSettings()
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // === Layout ===
  NHeader {
    label: pluginApi && pluginApi.tr("settings.layout.title") || "Layout"
  }



  NComboBox {
    Layout.fillWidth: true
    label: pluginApi && pluginApi.tr("settings.layout.position.label") || "Position"
    description: pluginApi && pluginApi.tr("settings.layout.position.description") || "Where the overview appears on screen"
    model: [
      { "key": "top", "name": pluginApi && pluginApi.tr("settings.layout.position.top") || "Top" },
      { "key": "center", "name": pluginApi && pluginApi.tr("settings.layout.position.center") || "Center" },
      { "key": "bottom", "name": pluginApi && pluginApi.tr("settings.layout.position.bottom") || "Bottom" }
    ]
    currentKey: root.overviewPosition
    onSelected: key => {
      root.overviewPosition = key
      root.saveSettings()
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
