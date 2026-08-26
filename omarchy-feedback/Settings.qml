import QtQuick
import QtQuick.Layouts
import "PluginUi.js" as PluginUi
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.minimumWidth: Math.round(520 * Style.uiScaleRatio)

  property bool editShowVoxtype: true
  property bool editShowScreenRecording: true
  property bool editShowIdleDisabled: true
  property bool editShowUpdateAvailable: true

  readonly property bool omarchyAvailable: pluginApi?.mainInstance?.omarchyAvailable === true

  function getSetting(key, fallback) {
    return pluginApi?.pluginSettings?.[key] ?? pluginApi?.manifest?.metadata?.defaultSettings?.[key] ?? fallback;
  }

  function tr(key, fallback) {
    return PluginUi.tr(pluginApi, key, fallback);
  }

  function syncFromSettings() {
    editShowVoxtype = getSetting("showVoxtype", true);
    editShowScreenRecording = getSetting("showScreenRecording", true);
    editShowIdleDisabled = getSetting("showIdleDisabled", true);
    editShowUpdateAvailable = getSetting("showUpdateAvailable", true);
  }

  function saveSettings() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.showVoxtype = editShowVoxtype;
    pluginApi.pluginSettings.showScreenRecording = editShowScreenRecording;
    pluginApi.pluginSettings.showIdleDisabled = editShowIdleDisabled;
    pluginApi.pluginSettings.showUpdateAvailable = editShowUpdateAvailable;

    pluginApi.saveSettings();
    pluginApi.mainInstance?.refresh();
  }

  Component.onCompleted: syncFromSettings()
  onPluginApiChanged: syncFromSettings()

  Connections {
    target: pluginApi

    function onPluginSettingsChanged() {
      syncFromSettings();
    }
  }

  NText {
    Layout.fillWidth: true
    text: tr("settings.status-title", "Status")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NText {
    Layout.fillWidth: true
    text: omarchyAvailable ? tr("settings.omarchy-detected", "Omarchy detected") : tr("settings.omarchy-missing", "Omarchy not found via OMARCHY_PATH, ~/.local/share/omarchy, or `omarchy` on PATH")
    color: omarchyAvailable ? Color.mPrimary : Color.mError
    pointSize: Style.fontSizeS
    wrapMode: Text.WordWrap
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: tr("settings.indicators-title", "Indicators")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: tr("settings.show-voxtype", "Show Voxtype indicator")
    checked: editShowVoxtype
    onToggled: checked => {
      editShowVoxtype = checked;
      saveSettings();
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: tr("settings.show-screen-recording", "Show screen recording indicator")
    checked: editShowScreenRecording
    onToggled: checked => {
      editShowScreenRecording = checked;
      saveSettings();
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: tr("settings.show-idle-disabled", "Show idle disabled indicator")
    checked: editShowIdleDisabled
    onToggled: checked => {
      editShowIdleDisabled = checked;
      saveSettings();
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: tr("settings.show-update-available", "Show update available indicator")
    checked: editShowUpdateAvailable
    onToggled: checked => {
      editShowUpdateAvailable = checked;
      saveSettings();
    }
  }
}
