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
  Layout.minimumWidth: Math.round(360 * Style.uiScaleRatio)

  FontMetrics {
    id: appFontMetrics
    font: Qt.application.font
  }

  readonly property int basePreferredWidth: Math.round(520 * Style.uiScaleRatio)
  readonly property int fontSafePreferredWidth: Math.round(appFontMetrics.averageCharacterWidth * 56 + Style.marginL * 2)
  Layout.preferredWidth: Math.max(basePreferredWidth, fontSafePreferredWidth)

  property string themeSetCommand: ""
  property string configDir: ""
  property bool showThemeName: true
  property bool showSearchInput: true
  property bool isLoading: false
  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  function tr(key, fallback) {
    if (!pluginApi || !pluginApi.tr)
      return fallback

    var translated = pluginApi.tr(key)
    if (!translated)
      return fallback

    if (typeof translated === "string"
        && translated.length >= 4
        && translated.slice(0, 2) === "!!"
        && translated.slice(translated.length - 2) === "!!") {
      return fallback
    }

    return translated
  }

  readonly property string refreshText: tr("actions.refresh", "Refresh")
  readonly property string applyText: tr("actions.apply", "Apply current theme")
  readonly property string activateText: tr("actions.activate", "Activate")
  readonly property string deactivateText: tr("actions.deactivate", "Deactivate")
  readonly property string applyingText: tr("status.applying", "Applying…")
  readonly property string availableText: tr("status.available", "Omarchy detected")
  readonly property string notAvailableText: tr("status.not-available", "Omarchy not found")
  readonly property string activeStatusText: tr("status.active", "Active")
  readonly property string inactiveStatusText: tr("status.inactive", "Inactive")

  readonly property bool isApplying: pluginMain?.applying || false
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool isActive: pluginApi?.pluginSettings?.active || false

  readonly property string statusText: isApplying ? applyingText : (isAvailable ? availableText : notAvailableText)

  function getSetting(key, fallback) {
    if (!pluginApi)
      return fallback

    var val = undefined
    if (pluginApi.getSetting)
      val = pluginApi.getSetting(key)
    else if (pluginApi.pluginSettings)
      val = pluginApi.pluginSettings[key]

    if (val === undefined || val === null)
      val = defaultSettings ? defaultSettings[key] : undefined

    return (val === undefined || val === null) ? fallback : val
  }

  function syncFromPlugin() {
    if (!pluginApi)
      return

    isLoading = true
    themeSetCommand = getSetting("themeSetCommand", "") || ""
    configDir = getSetting("omarchyConfigDir", "") || ""
    showThemeName = getSetting("showThemeName", true) !== false
    showSearchInput = getSetting("showSearchInput", true) !== false
    isLoading = false
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      syncFromPlugin()
    }
  }

  function saveSettings() {
    if (!pluginApi)
      return

    var settings = pluginApi.pluginSettings || {}
    var changed = false
    var refreshNeeded = false

    var trimmedCommand = themeSetCommand.trim()
    if ((settings.themeSetCommand || "") !== trimmedCommand) {
      settings.themeSetCommand = trimmedCommand
      changed = true
    }

    var normalizedDir = configDir.trim()
    if ((settings.omarchyConfigDir || "") !== normalizedDir) {
      settings.omarchyConfigDir = normalizedDir
      refreshNeeded = true
      changed = true
    }

    if (settings.showThemeName !== showThemeName) {
      settings.showThemeName = showThemeName
      changed = true
    }

    if (settings.showSearchInput !== showSearchInput) {
      settings.showSearchInput = showSearchInput
      changed = true
    }

    if (!changed)
      return

    // Re-assign to trigger bindings and save
    pluginApi.pluginSettings = settings
    pluginApi.saveSettings()

    if (refreshNeeded) {
      pluginApi.mainInstance?.refresh()
    }
  }

  Timer {
    id: saveDebounce
    interval: 350
    repeat: false
    onTriggered: root.saveSettings()
  }

  NText {
    text: tr("settings.description", "Configure Omarchy integration.")
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NText {
    text: tr("settings.paths-hint", "Set the executable and config directory Omarchy should use.")
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    Layout.fillWidth: true
  }

  NTextInput {
    label: tr("fields.theme-set-command", "Theme-set command")
    placeholderText: "~/.local/share/omarchy/bin/omarchy-theme-set"
    text: root.themeSetCommand
    Layout.fillWidth: true
    onTextChanged: {
      if (root.isLoading)
        return
      if (root.themeSetCommand !== text) {
        root.themeSetCommand = text
        saveDebounce.restart()
      }
    }
  }

  NTextInput {
    label: tr("fields.config-dir", "Omarchy config dir")
    placeholderText: "~/.config/omarchy/"
    text: root.configDir
    Layout.fillWidth: true
    onTextChanged: {
      if (root.isLoading)
        return
      if (root.configDir !== text) {
        root.configDir = text
        saveDebounce.restart()
      }
    }
  }

  NToggle {
    label: tr("fields.show-theme-name.label", "Show theme name in bar widget")
    description: tr("fields.show-theme-name.desc", "Disable to hide the current theme label next to the Omarchy icon.")
    checked: root.showThemeName
    Layout.fillWidth: true
    onToggled: function(checked) {
      if (root.isLoading)
        return
      root.showThemeName = checked
      root.saveSettings()
    }
  }

  NToggle {
    label: tr("fields.show-search-input.label", "Show search input in panel")
    description: tr("fields.show-search-input.desc", "Enable fuzzy search for themes in the Omarchy panel.")
    checked: root.showSearchInput
    Layout.fillWidth: true
    onToggled: function(checked) {
      if (root.isLoading)
        return
      root.showSearchInput = checked
      root.saveSettings()
    }
  }

  NToggle {
    label: tr("fields.debug-logging.label", "Enable debug logging")
    description: tr("fields.debug-logging.desc", "Logs extra diagnostics to help troubleshoot theme parsing and scheme application.")
    checked: getSetting("debugLogging", false) === true
    Layout.fillWidth: true
    onToggled: function(checked) {
      if (root.isLoading)
        return
      if (!pluginApi)
        return
      var settings = pluginApi.pluginSettings || {}
      if (settings.debugLogging === checked)
        return
      settings.debugLogging = checked
      pluginApi.pluginSettings = settings
      pluginApi.saveSettings()
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: tr("settings.controls.title", "Plugin controls")
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      text: statusText + " · " + (isActive ? activeStatusText : inactiveStatusText)
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        Layout.fillWidth: true
        text: refreshText
        enabled: !!pluginMain
        onClicked: pluginMain?.refresh()
      }

      NButton {
        Layout.fillWidth: true
        text: isActive ? deactivateText : activateText
        enabled: !!pluginMain
        onClicked: {
          if (!pluginApi)
            return
          if (isActive)
            pluginMain?.deactivate()
          else
            pluginMain?.activate()
        }
      }

      NButton {
        Layout.fillWidth: true
        text: applyText
        enabled: !!pluginMain && isAvailable && !isApplying
        onClicked: pluginMain?.applyCurrentTheme()
      }
    }
  }
}
