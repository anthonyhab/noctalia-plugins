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

  // Settings getter with fallback to manifest defaults and error handling
  function getSetting(key, fallback) {
    // Check if plugin API is available
    if (!pluginApi) {
      Logger.w("PolkitAuthSettings", "Plugin API not available for settings access - using manifest defaults");
      const defaultVal = pluginApi?.manifest?.metadata?.defaultSettings?.[key];
      return defaultVal !== undefined ? defaultVal : fallback;
    }

    // Check if plugin settings are available
    if (!pluginApi.pluginSettings) {
      Logger.w("PolkitAuthSettings", "Plugin settings not available - using manifest defaults");
      const defaultVal = pluginApi?.manifest?.metadata?.defaultSettings?.[key];
      return defaultVal !== undefined ? defaultVal : fallback;
    }

    // Original logic with additional safety checks
    try {
      const userVal = pluginApi?.pluginSettings?.[key];
      if (userVal !== undefined && userVal !== null) return userVal;
      const defaultVal = pluginApi?.manifest?.metadata?.defaultSettings?.[key];
      if (defaultVal !== undefined && defaultVal !== null) return defaultVal;
      return fallback;
    } catch (e) {
      Logger.e("PolkitAuthSettings", "Error accessing plugin settings:", e);
      return fallback;
    }
  }

  property string valueSettingsPanelMode: getSetting("settingsPanelMode", "centered")
  property bool valueShowDetailsByDefault: getSetting("showDetailsByDefault", false)
  property bool valueCloseInstantly: getSetting("closeInstantly", false)

  readonly property var pluginMain: pluginApi?.mainInstance

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("PolkitAuthSettings", "Cannot save settings: plugin API not available");
      ToastService.showError("Polkit Auth", "Settings cannot be saved - plugin not fully loaded");
      return;
    }

    if (!pluginApi.pluginSettings) {
      Logger.e("PolkitAuthSettings", "Cannot save settings: plugin settings not available");
      ToastService.showError("Polkit Auth", "Settings cannot be saved - plugin configuration issue");
      return;
    }

    try {
      pluginApi.pluginSettings.settingsPanelMode = valueSettingsPanelMode;
      pluginApi.pluginSettings.showDetailsByDefault = valueShowDetailsByDefault;
      pluginApi.pluginSettings.closeInstantly = valueCloseInstantly;

      pluginApi.saveSettings();
      pluginMain?.refresh();
      Logger.d("PolkitAuthSettings", "Settings saved successfully");
    } catch (e) {
      Logger.e("PolkitAuthSettings", "Failed to save settings:", e);
      ToastService.showError("Polkit Auth", "Failed to save settings: " + e.toString());
    }
  }

  NText {
    text: pluginApi?.tr("settings.description") ?? "Connect to the Noctalia auth daemon over IPC."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NText {
    text: "Daemon conflict policy: " + (pluginMain?.agentConflictMode || "session")
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
  }

  NText {
    text: {
      if (!(pluginMain?.providerRegistered ?? false)) {
        return "UI provider status: disconnected"
      }
      if (!(pluginMain?.providerActivityKnown ?? false)) {
        return "UI provider status: negotiating"
      }
      return "UI provider status: " + ((pluginMain?.providerActive ?? true) ? "active" : "standby")
    }
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
  }

  NComboBox {
    Layout.fillWidth: true
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

  NToggle {
    label: pluginApi?.tr("settings.show-details") ?? "Show details expander"
    description: pluginApi?.tr("settings.show-details-desc") ?? "Allow the diagnostics details expander in the auth panel."
    checked: root.valueShowDetailsByDefault
    onToggled: checked => root.valueShowDetailsByDefault = checked
  }

  NToggle {
    label: pluginApi?.tr("settings.close-instantly") ?? "Close instantly on success"
    description: pluginApi?.tr("settings.close-instantly-desc") ?? "Skip the success state and close the panel immediately after verification."
    checked: root.valueCloseInstantly
    onToggled: checked => root.valueCloseInstantly = checked
  }
}
