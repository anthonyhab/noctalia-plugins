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
  property string valueDisplayMode: getSetting("displayMode", "floating")
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
    pluginApi.pluginSettings.displayMode = valueDisplayMode;
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

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.display-mode") ?? "Display mode"
    description: pluginApi?.tr("settings.display-mode-desc") ?? "How the authentication dialog appears"
    model: [
      { key: "floating", name: "Floating window" },
      { key: "panel", name: "Panel (attached to bar)" }
    ]
    currentKey: root.valueDisplayMode
    onSelected: key => root.valueDisplayMode = key
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
