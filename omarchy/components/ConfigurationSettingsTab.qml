import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  required property var settingsRoot

  spacing: Style.marginL
  Layout.fillWidth: true

  NText {
    text: root.settingsRoot.tr("settings.description", "Manage Omarchy theme sync and optional command overrides.")
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NText {
    text: root.settingsRoot.tr("settings.paths-hint", "Leave the custom executable blank to use `omarchy theme set`. Set a custom config directory or wrapper only if you need one.")
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    Layout.fillWidth: true
  }

  NTextInput {
    label: root.settingsRoot.tr("fields.theme-set-command", "Custom theme-set executable")
    placeholderText: "~/.local/bin/omarchy-theme-set-fast"
    text: root.settingsRoot.themeSetCommand
    Layout.fillWidth: true
    onTextChanged: {
      if (root.settingsRoot.isLoading)
        return;
      if (root.settingsRoot.themeSetCommand !== text) {
        root.settingsRoot.themeSetCommand = text;
        root.settingsRoot.scheduleSave();
      }
    }
  }

  NTextInput {
    label: root.settingsRoot.tr("fields.config-dir", "Omarchy config dir")
    placeholderText: "~/.config/omarchy/"
    text: root.settingsRoot.configDir
    Layout.fillWidth: true
    onTextChanged: {
      if (root.settingsRoot.isLoading)
        return;
      if (root.settingsRoot.configDir !== text) {
        root.settingsRoot.configDir = text;
        root.settingsRoot.scheduleSave();
      }
    }
  }

  NToggle {
    label: root.settingsRoot.tr("fields.debug-logging.label", "Enable debug logging")
    description: root.settingsRoot.tr("fields.debug-logging.desc", "Logs extra diagnostics to help troubleshoot theme parsing and scheme application.")
    checked: root.settingsRoot.debugLogging
    Layout.fillWidth: true
    onToggled: function (checked) {
      if (root.settingsRoot.isLoading)
        return;
      if (root.settingsRoot.debugLogging !== checked) {
        root.settingsRoot.debugLogging = checked;
        root.settingsRoot.saveSettings();
      }
    }
  }
}
