import QtQuick
import QtQuick.Layouts
import "PluginUi.js" as PluginUi
import "components"
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
    font.family: root.uiSetting("fontDefault", "")
    font.pointSize: Style.fontSizeM
  }

  readonly property int basePreferredWidth: Math.round(520 * Style.uiScaleRatio)
  readonly property int fontSafePreferredWidth: Math.round(appFontMetrics.averageCharacterWidth * 56 + Style.marginL * 2)
  Layout.preferredWidth: Math.max(basePreferredWidth, fontSafePreferredWidth)

  property string themeSetCommand: ""
  property string configDir: ""
  property bool showThemeName: true
  property bool showSearchInput: true
  property bool timeBasedThemeFiltering: false
  property string themeFilteringMode: "random-only"
  property bool debugLogging: false
  property bool isLoading: false
  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  function uiSetting(key, fallback) {
    const ui = Settings.data.ui;
    if (!ui)
      return fallback;
    const value = ui[key];
    return (value === undefined || value === null) ? fallback : value;
  }

  function tr(key, fallback) {
    return PluginUi.tr(pluginApi, key, fallback);
  }

  readonly property string refreshText: tr("actions.refresh", "Refresh")
  readonly property string applyText: tr("actions.apply", "Apply current theme")
  readonly property string activateText: tr("actions.activate", "Activate")
  readonly property string deactivateText: tr("actions.deactivate", "Deactivate")
  readonly property string applyingText: tr("status.applying", "Applying…")
  readonly property string availableText: tr("status.available", "Omarchy detected")
  readonly property string notAvailableText: tr("status.not-available", "Omarchy not found or not executable")
  readonly property string activeStatusText: tr("status.active", "Active")
  readonly property string inactiveStatusText: tr("status.inactive", "Inactive")

  readonly property bool isApplying: pluginMain?.isBusy || false
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool isActive: pluginApi?.pluginSettings?.active || false

  readonly property string statusText: isApplying ? applyingText : (isAvailable ? availableText : notAvailableText)

  function getSetting(key, fallback) {
    if (!pluginApi)
      return fallback;

    var val = undefined;
    if (pluginApi.getSetting)
      val = pluginApi.getSetting(key);
    else if (pluginApi.pluginSettings)
      val = pluginApi.pluginSettings[key];

    if (val === undefined || val === null)
      val = defaultSettings ? defaultSettings[key] : undefined;

    return (val === undefined || val === null) ? fallback : val;
  }

  function colorSchemeSetting(key, fallback) {
    const colorSchemes = Settings.data.colorSchemes;
    if (!colorSchemes)
      return fallback;
    const value = colorSchemes[key];
    return (value === undefined || value === null) ? fallback : value;
  }

  function syncFromPlugin() {
    if (!pluginApi)
      return;
    isLoading = true;
    themeSetCommand = getSetting("themeSetCommand", "") || "";
    configDir = getSetting("omarchyConfigDir", "") || "";
    showThemeName = getSetting("showThemeName", true) !== false;
    showSearchInput = getSetting("showSearchInput", true) !== false;
    timeBasedThemeFiltering = getSetting("timeBasedThemeFiltering", false) === true;
    themeFilteringMode = getSetting("themeFilteringMode", "random-only") || "random-only";
    debugLogging = getSetting("debugLogging", false) === true;
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
    var changed = false;
    var refreshNeeded = false;

    var trimmedCommand = themeSetCommand.trim();
    if ((settings.themeSetCommand || "") !== trimmedCommand) {
      settings.themeSetCommand = trimmedCommand;
      changed = true;
    }

    var normalizedDir = configDir.trim();
    if ((settings.omarchyConfigDir || "") !== normalizedDir) {
      settings.omarchyConfigDir = normalizedDir;
      refreshNeeded = true;
      changed = true;
    }

    if (settings.showThemeName !== showThemeName) {
      settings.showThemeName = showThemeName;
      changed = true;
    }

    if (settings.showSearchInput !== showSearchInput) {
      settings.showSearchInput = showSearchInput;
      changed = true;
    }

    if (settings.timeBasedThemeFiltering !== timeBasedThemeFiltering) {
      settings.timeBasedThemeFiltering = timeBasedThemeFiltering;
      changed = true;
    }

    if (settings.themeFilteringMode !== themeFilteringMode) {
      settings.themeFilteringMode = themeFilteringMode;
      changed = true;
    }

    if (settings.debugLogging !== debugLogging) {
      settings.debugLogging = debugLogging;
      changed = true;
    }

    if (!changed)
      return;

    // Re-assign to trigger bindings and save
    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();

    if (refreshNeeded) {
      pluginApi.mainInstance?.refresh();
    }
  }

  function scheduleSave() {
    saveDebounce.restart();
  }

  Timer {
    id: saveDebounce
    interval: 350
    repeat: false
    onTriggered: root.saveSettings()
  }

  // Tab Bar
  NTabBar {
    id: tabBar
    Layout.fillWidth: true
    currentIndex: 0
    distributeEvenly: true

    NTabButton {
      text: tr("settings.tabs.general", "General")
      tabIndex: 0
      checked: tabBar.currentIndex === 0
    }

    NTabButton {
      text: tr("settings.tabs.configuration", "Configuration")
      tabIndex: 1
      checked: tabBar.currentIndex === 1
    }
  }

  // Tab Content
  StackLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    currentIndex: tabBar.currentIndex

    GeneralSettingsTab {
      settingsRoot: root
    }

    ConfigurationSettingsTab {
      settingsRoot: root
    }
  }
}
