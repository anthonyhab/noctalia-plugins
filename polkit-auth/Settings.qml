import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  implicitWidth: Math.round(520 * Style.uiScaleRatio)
  Layout.minimumWidth: implicitWidth
  Layout.maximumWidth: implicitWidth
  Layout.preferredWidth: implicitWidth

  // Settings getter with fallback to manifest defaults
  function getSetting(key, fallback) {
    const userVal = pluginApi?.pluginSettings?.[key];
    if (userVal !== undefined && userVal !== null) return userVal;
    const defaultVal = pluginApi?.manifest?.metadata?.defaultSettings?.[key];
    if (defaultVal !== undefined && defaultVal !== null) return defaultVal;
    return fallback;
  }

  property string valuePollInterval: getSetting("pollInterval", 100).toString()
  property string valueSettingsPanelMode: getSetting("settingsPanelMode", "centered")
  property bool valueSyncPanelModeWithShell: getSetting("syncPanelModeWithShell", false)
  property bool valueAutoOpenPanel: getSetting("autoOpenPanel", true)
  property bool valueAutoCloseOnSuccess: getSetting("autoCloseOnSuccess", true)
  property bool valueShowSuccessAnimation: getSetting("showSuccessAnimation", true)
  property bool valueAutoCloseOnCancel: getSetting("autoCloseOnCancel", true)
  property string valueSuccessAnimationDuration: getSetting("successAnimationDuration", 300).toString()

  readonly property var pluginMain: pluginApi?.mainInstance

  function saveSettings() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.pollInterval = parseInt(valuePollInterval, 10) || 100;
    pluginApi.pluginSettings.settingsPanelMode = valueSettingsPanelMode;
    pluginApi.pluginSettings.syncPanelModeWithShell = valueSyncPanelModeWithShell;
    pluginApi.pluginSettings.autoOpenPanel = valueAutoOpenPanel;
    pluginApi.pluginSettings.autoCloseOnSuccess = valueAutoCloseOnSuccess;
    pluginApi.pluginSettings.showSuccessAnimation = valueShowSuccessAnimation;
    pluginApi.pluginSettings.autoCloseOnCancel = valueAutoCloseOnCancel;
    pluginApi.pluginSettings.successAnimationDuration = parseInt(valueSuccessAnimationDuration, 10) || 300;

    pluginApi.saveSettings();
    pluginMain?.refresh();
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Connect to the Noctalia polkit agent over IPC."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NTextInput {
    label: pluginApi?.tr("settings.poll-interval") || "Poll interval (ms)"
    description: pluginApi?.tr("settings.poll-interval-desc") || "How frequently the plugin checks for new authentication requests. Lower values are more responsive."
    placeholderText: "100"
    text: root.valuePollInterval
    inputItem.inputMethodHints: Qt.ImhDigitsOnly
    onTextChanged: root.valuePollInterval = text
  }

  NToggle {
    label: pluginApi?.tr("settings.sync-panel-mode") || "Sync panel mode with shell"
    description: pluginApi?.tr("settings.sync-panel-mode-desc") || "Automatically use the same panel mode as the main shell settings."
    checked: root.valueSyncPanelModeWithShell
    onToggled: checked => root.valueSyncPanelModeWithShell = checked
  }

  NComboBox {
    Layout.fillWidth: true
    enabled: !root.valueSyncPanelModeWithShell
    opacity: enabled ? 1.0 : 0.5
    label: pluginApi?.tr("settings.panel-mode") ?? "Panel mode"
    description: pluginApi?.tr("settings.panel-mode-desc") ?? "Choose how the authentication dialog appears (may require reopening)."
    model: [
      { key: "attached", name: pluginApi?.tr("settings.panel-mode-attached") ?? "Panel attached to bar" },
      { key: "centered", name: pluginApi?.tr("settings.panel-mode-centered") ?? "Centered panel" },
      { key: "window", name: pluginApi?.tr("settings.panel-mode-window") ?? "Separate window" }
    ]
    currentKey: root.valueSettingsPanelMode
    onSelected: key => root.valueSettingsPanelMode = key
  }

  NDivider { Layout.fillWidth: true }

  NToggle {
    label: pluginApi?.tr("settings.auto-open") || "Auto-open panel"
    description: pluginApi?.tr("settings.auto-open-desc") || "Show the panel immediately when a request arrives."
    checked: root.valueAutoOpenPanel
    onToggled: checked => root.valueAutoOpenPanel = checked
  }

  NToggle {
    label: pluginApi?.tr("settings.auto-close-success") || "Close on success"
    description: pluginApi?.tr("settings.auto-close-success-desc") || "Close the panel after a successful authentication."
    checked: root.valueAutoCloseOnSuccess
    onToggled: checked => root.valueAutoCloseOnSuccess = checked
  }

  NToggle {
    label: pluginApi?.tr("settings.show-success-animation") || "Show success animation"
    description: pluginApi?.tr("settings.show-success-animation-desc") || "Keep the dialog visible briefly after success."
    checked: root.valueShowSuccessAnimation
    onToggled: checked => root.valueShowSuccessAnimation = checked
  }

  NToggle {
    label: pluginApi?.tr("settings.auto-close-cancel") || "Close on cancel"
    description: pluginApi?.tr("settings.auto-close-cancel-desc") || "Close the panel when a request is cancelled."
    checked: root.valueAutoCloseOnCancel
    onToggled: checked => root.valueAutoCloseOnCancel = checked
  }

  NTextInput {
    label: pluginApi?.tr("settings.success-animation-duration") || "Success animation duration (ms)"
    description: pluginApi?.tr("settings.success-animation-duration-desc") || "How long the success state is shown before closing."
    placeholderText: "300"
    text: root.valueSuccessAnimationDuration
    inputItem.inputMethodHints: Qt.ImhDigitsOnly
    onTextChanged: root.valueSuccessAnimationDuration = text
  }
}
