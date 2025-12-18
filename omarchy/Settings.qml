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

  property string themeSetCommand: ""
  property string configDir: ""
  property bool useThemeSurface: true
  property bool showThemeName: true
  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string refreshText: pluginApi?.tr("actions.refresh") || "Refresh"
  readonly property string applyText: pluginApi?.tr("actions.apply") || "Apply current theme"
  readonly property string activateText: pluginApi?.tr("actions.activate") || "Activate"
  readonly property string deactivateText: pluginApi?.tr("actions.deactivate") || "Deactivate"
  readonly property string applyingText: pluginApi?.tr("status.applying") || "Applying…"
  readonly property string availableText: pluginApi?.tr("status.available") || "Omarchy detected"
  readonly property string notAvailableText: pluginApi?.tr("status.not-available") || "Omarchy not found"
  readonly property string activeStatusText: pluginApi?.tr("status.active") || "Active"
  readonly property string inactiveStatusText: pluginApi?.tr("status.inactive") || "Inactive"

  readonly property bool isApplying: pluginMain?.applying || false
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool isActive: pluginApi?.pluginSettings?.active || false

  readonly property string statusText: isApplying ? applyingText : (isAvailable ? availableText : notAvailableText)

  function getSetting(key, fallback) {
    if (pluginApi?.pluginSettings && pluginApi.pluginSettings[key] !== undefined) {
      return pluginApi.pluginSettings[key];
    }
    if (defaultSettings && defaultSettings[key] !== undefined) {
      return defaultSettings[key];
    }
    return fallback;
  }

  function syncFromPlugin() {
    if (!pluginApi)
      return;
    themeSetCommand = getSetting("themeSetCommand", "") || "";
    configDir = getSetting("omarchyConfigDir", "") || "";
    useThemeSurface = !!getSetting("useThemeSurface", true);
    showThemeName = getSetting("showThemeName", true) !== false;
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  function saveSettings() {
    if (!pluginApi)
      return;

    var settings = pluginApi.pluginSettings || {};
    var refreshNeeded = false;
    var reapplyNeeded = false;
    var changed = false;

    var trimmedCommand = themeSetCommand.trim();
    if ((settings.themeSetCommand || "") !== trimmedCommand) {
      settings.themeSetCommand = trimmedCommand;
      refreshNeeded = true;
      changed = true;
    }

    var normalizedDir = configDir.trim();
    if ((settings.omarchyConfigDir || "") !== normalizedDir) {
      settings.omarchyConfigDir = normalizedDir;
      refreshNeeded = true;
      changed = true;
    }

    if (!!settings.useThemeSurface !== useThemeSurface) {
      settings.useThemeSurface = useThemeSurface;
      if (settings.active) {
        reapplyNeeded = true;
      }
      changed = true;
    }

    if (!!settings.showThemeName !== showThemeName) {
      settings.showThemeName = showThemeName;
      changed = true;
    }

    if (!changed)
      return;

    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();

    if (refreshNeeded) {
      pluginApi.mainInstance?.refresh();
    }
    if (reapplyNeeded) {
      pluginApi.mainInstance?.applyCurrentTheme();
    }
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Configure Omarchy integration."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.paths-hint") || "Set the executable and config directory Omarchy should use."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    font.pointSize: Style.fontSizeS
  }

  NTextInput {
    label: pluginApi?.tr("fields.theme-set-command") || "Theme-set command"
    placeholderText: "~/.local/share/omarchy/bin/omarchy-theme-set"
    text: root.themeSetCommand
    onTextChanged: {
      if (root.themeSetCommand !== text) {
        root.themeSetCommand = text;
      }
    }
  }

  NTextInput {
    label: pluginApi?.tr("fields.config-dir") || "Omarchy config dir"
    placeholderText: "~/.config/omarchy/"
    text: root.configDir
    onTextChanged: {
      if (root.configDir !== text) {
        root.configDir = text;
      }
    }
  }

  NToggle {
    label: pluginApi?.tr("fields.use-theme-surface.label") || "Use theme background for UI surfaces"
    description: pluginApi?.tr("fields.use-theme-surface.desc") || "If disabled, surfaces stay neutral and theme colors are used as accents."
    checked: root.useThemeSurface
    onToggled: checked => root.useThemeSurface = checked
  }

  NToggle {
    label: pluginApi?.tr("fields.show-theme-name.label") || "Show theme name in bar widget"
    description: pluginApi?.tr("fields.show-theme-name.desc") || "Disable to hide the current theme label next to the Omarchy icon."
    checked: root.showThemeName
    onToggled: checked => root.showThemeName = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: pluginApi?.tr("settings.controls.title") || "Plugin controls"
      font.pointSize: Style.fontSizeM
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
            return;
          if (pluginApi.pluginSettings.active) {
            pluginMain?.deactivate();
          } else {
            pluginMain?.activate();
          }
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
