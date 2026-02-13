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

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var pluginMain: pluginApi?.mainInstance

  // Local state
  property int gridRows: 2
  property int gridColumns: 5
  property real gridScale: 0.16
  property bool hideEmptyRows: true
  property string overviewPosition: "top"

  function getSetting(key, fallback) {
    if (pluginApi?.pluginSettings && pluginApi.pluginSettings[key] !== undefined) {
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

    pluginMain?.refresh()
  }

  // Description
  NText {
    text: pluginApi?.tr("plugin.description") || "Visual workspace overview with live window previews for Hyprland"
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NDivider {
    Layout.fillWidth: true
  }

  // === Workspace Grid ===
  NText {
    text: pluginApi?.tr("settings.grid.title") || "Workspace Grid"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.grid.rows.label") || "Rows"
      description: pluginApi?.tr("settings.grid.rows.description") || "Number of workspace rows"
      placeholderText: "2"
      text: root.gridRows.toString()
      inputItem.inputMethodHints: Qt.ImhDigitsOnly
      onTextChanged: {
        var val = parseInt(text)
        if (val >= 1 && val <= 5) root.gridRows = val
      }
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.grid.columns.label") || "Columns"
      description: pluginApi?.tr("settings.grid.columns.description") || "Number of workspace columns"
      placeholderText: "5"
      text: root.gridColumns.toString()
      inputItem.inputMethodHints: Qt.ImhDigitsOnly
      onTextChanged: {
        var val = parseInt(text)
        if (val >= 1 && val <= 10) root.gridColumns = val
      }
    }
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.grid.scale.label") || "Scale"
    description: pluginApi?.tr("settings.grid.scale.description") || "Overview scale factor (smaller = more compact)"
    placeholderText: "0.16"
    text: root.gridScale.toFixed(2)
    inputItem.inputMethodHints: Qt.ImhFormattedNumbersOnly
    onTextChanged: {
      var val = parseFloat(text)
      if (val >= 0.08 && val <= 0.30) root.gridScale = val
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
  NText {
    text: pluginApi?.tr("settings.behavior.title") || "Behavior"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    label: pluginApi?.tr("settings.behavior.hide-empty-rows.label") || "Hide empty rows"
    description: pluginApi?.tr("settings.behavior.hide-empty-rows.description") || "Automatically hide workspace rows with no windows"
    checked: root.hideEmptyRows
    onToggled: checked => root.hideEmptyRows = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  // === Layout ===
  NText {
    text: pluginApi?.tr("settings.layout.title") || "Layout"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }



  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.layout.position.label") || "Position"
    description: pluginApi?.tr("settings.layout.position.description") || "Where the overview appears on screen"
    model: [
      { "key": "top", "name": pluginApi?.tr("settings.layout.position.top") || "Top" },
      { "key": "center", "name": pluginApi?.tr("settings.layout.position.center") || "Center" },
      { "key": "bottom", "name": pluginApi?.tr("settings.layout.position.bottom") || "Bottom" }
    ]
    currentKey: root.overviewPosition
    onSelected: key => root.overviewPosition = key
  }

  Item {
    Layout.fillHeight: true
  }
}
