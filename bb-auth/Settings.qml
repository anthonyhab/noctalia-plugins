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

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property var pluginMain: pluginApi?.mainInstance

  // --- i18n helper (catches !!key!! and ##key## markers) ---
  function tr(key, fallback) {
    if (!pluginApi || !pluginApi.tr)
      return fallback;
    var translated = pluginApi.tr(key);
    if (!translated)
      return fallback;
    if (typeof translated === "string" && translated.length >= 4) {
      var prefix = translated.slice(0, 2);
      var suffix = translated.slice(translated.length - 2);
      if ((prefix === "##" && suffix === "##") || (prefix === "!!" && suffix === "!!"))
        return fallback;
    }
    return translated;
  }

  // --- Settings helpers ---
  function getSetting(key, fallback) {
    if (pluginApi?.pluginSettings && pluginApi.pluginSettings[key] !== undefined)
      return pluginApi.pluginSettings[key];
    if (defaultSettings && defaultSettings[key] !== undefined)
      return defaultSettings[key];
    return fallback;
  }

  // Local state
  property string valueSettingsPanelMode: "centered"
  property bool valueShowDetailsByDefault: false
  property bool valueCloseInstantly: false
  property bool isLoading: false

  function syncFromPlugin() {
    if (!pluginApi)
      return;
    isLoading = true;
    valueSettingsPanelMode = getSetting("settingsPanelMode", "centered") || "centered";
    valueShowDetailsByDefault = getSetting("showDetailsByDefault", false) === true;
    valueCloseInstantly = getSetting("closeInstantly", false) === true;
    isLoading = false;
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      syncFromPlugin();
    }
  }

  function saveSettings() {
    if (!pluginApi)
      return;

    var settings = pluginApi.pluginSettings || {};
    settings.settingsPanelMode = valueSettingsPanelMode;
    settings.showDetailsByDefault = valueShowDetailsByDefault;
    settings.closeInstantly = valueCloseInstantly;

    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();
    pluginMain?.refresh();
  }

  // --- Header ---
  NText {
    text: tr("settings.description", "Polkit and GPG authentication agent for Noctalia.")
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NDivider {
    Layout.fillWidth: true
  }

  // --- Section 1: Dialog Behavior ---
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "Dialog behavior"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      text: "Configure how the authentication dialog appears and behaves."
      wrapMode: Text.WordWrap
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
    }
  }

  NComboBox {
    Layout.fillWidth: true
    label: tr("settings.panel-mode", "Panel mode")
    description: tr("settings.panel-mode-desc", "Choose how the authentication dialog appears.")
    model: [
      { key: "attached", name: tr("settings.panel-mode-attached", "Panel attached to bar") },
      { key: "centered", name: tr("settings.panel-mode-centered", "Centered panel") },
      { key: "window", name: tr("settings.panel-mode-window", "Separate window") }
    ]
    currentKey: root.valueSettingsPanelMode
    onSelected: function(key) {
      if (root.isLoading) return;
      root.valueSettingsPanelMode = key;
      root.saveSettings();
    }
  }

  NToggle {
    label: tr("settings.close-instantly", "Close instantly on success")
    description: tr("settings.close-instantly-desc", "Skip the success animation and close the panel immediately after verification.")
    checked: root.valueCloseInstantly
    Layout.fillWidth: true
    onToggled: function(checked) {
      if (root.isLoading) return;
      root.valueCloseInstantly = checked;
      root.saveSettings();
    }
  }

  NToggle {
    label: tr("settings.show-details", "Show details expander")
    description: tr("settings.show-details-desc", "Show a diagnostics expander with action ID, requestor, and command details.")
    checked: root.valueShowDetailsByDefault
    Layout.fillWidth: true
    onToggled: function(checked) {
      if (root.isLoading) return;
      root.valueShowDetailsByDefault = checked;
      root.saveSettings();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // --- Section 2: Status ---
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "Status"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    // Provider status row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Rectangle {
        width: Math.round(8 * Style.uiScaleRatio)
        height: width
        radius: width / 2
        color: {
          if (!(pluginMain?.providerRegistered ?? false))
            return Color.mError;
          if (!(pluginMain?.providerActivityKnown ?? false))
            return Color.mTertiary;
          return (pluginMain?.providerActive ?? true) ? Color.mPrimary : Color.mOutline;
        }
        Layout.alignment: Qt.AlignVCenter
      }

      NText {
        text: {
          if (!(pluginMain?.providerRegistered ?? false))
            return "Disconnected from auth daemon";
          if (!(pluginMain?.providerActivityKnown ?? false))
            return "Negotiating with auth daemon";
          return (pluginMain?.providerActive ?? true) ? "Active — ready to handle requests" : "Standby — another agent is active";
        }
        color: Color.mOnSurface
        pointSize: Style.fontSizeS
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }
    }

    // Conflict policy
    NText {
      Layout.fillWidth: true
      text: "Conflict policy: " + (pluginMain?.agentConflictMode || "session")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      opacity: 0.7
      wrapMode: Text.WordWrap
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // --- Section 3: About ---
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "About"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      text: (pluginApi?.manifest?.name || "BB Auth") + " v" + (pluginApi?.manifest?.version || "0.0.0")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    NText {
      Layout.fillWidth: true
      text: pluginApi?.manifest?.description || ""
      visible: text !== ""
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
      opacity: 0.7
    }
  }

  Item {
    Layout.fillHeight: true
  }
}
