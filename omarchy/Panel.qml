import QtQuick
import QtQuick.Layouts
import "PluginUi.js" as PluginUi
import "ThemeIdentity.js" as ThemeIdentity
import "components"
import qs.Commons

Item {
  id: root

  property var pluginApi: null
  readonly property var screen: pluginApi?.panelOpenScreen || null

  readonly property bool allowAttach: settingsGroupValue("ui", "panelsAttachedToBar", false) === true
  readonly property string barPosition: settingsGroupValue("bar", "position", "")

  // Panel positioning (passed to PluginPanelSlot)
  // When not attached, default to top-centered to prevent resizing from jumping vertically
  readonly property bool panelAnchorHorizontalCenter: true
  readonly property bool panelAnchorVerticalCenter: allowAttach ? (barPosition === "left" || barPosition === "right") : false
  readonly property bool panelAnchorTop: allowAttach ? (barPosition === "top") : true
  readonly property bool panelAnchorBottom: allowAttach && (barPosition === "bottom")
  readonly property bool panelAnchorLeft: allowAttach && (barPosition === "left")
  readonly property bool panelAnchorRight: allowAttach && (barPosition === "right")

  readonly property int contentPreferredWidth: Math.round(340 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: mainColumn.implicitHeight + (Style.marginL * 2)
  readonly property real maxListHeight: 300 * Style.uiScaleRatio

  readonly property var pluginMain: pluginApi?.mainInstance

  function trOrDefault(key, fallback) {
    return PluginUi.tr(pluginApi, key, fallback);
  }

  function settingsGroupValue(groupName, key, fallback) {
    const group = Settings.data[groupName];
    if (!group)
      return fallback;
    const value = group[key];
    return (value === undefined || value === null) ? fallback : value;
  }

  readonly property string titleText: trOrDefault("title", "Omarchy")
  readonly property string settingsHintText: trOrDefault("panel.settings-hint", "Configure Omarchy paths from Settings → Plugins → Omarchy.")
  readonly property string noThemesText: trOrDefault("errors.no-themes", "No themes found")
  readonly property string inactiveTitleText: trOrDefault("panel.inactive-title", "Omarchy sync is off")
  readonly property string inactiveDescriptionText: trOrDefault("panel.inactive-description", "Activate the plugin to apply Omarchy themes from this panel.")

  readonly property bool isActive: pluginApi?.pluginSettings?.active || false
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool showSearchInput: pluginApi?.pluginSettings?.showSearchInput !== false
  readonly property bool isLoading: pluginMain?.isBusy || false
  readonly property string loadingThemeName: pluginMain?.operationThemeName || ""

  onVisibleChanged: {
    if (visible) {
      searchQuery = "";
      selectedThemeIndex = -1;
      if (themeSearchBar) {
        themeSearchBar.text = "";
        if (showSearchInput)
          themeSearchBar.focusInput();
      }
    }
  }

  property string themeFilter: "all"
  property string searchQuery: ""
  property int selectedThemeIndex: -1

  readonly property bool selectionEnabled: showSearchInput && themeSearchBar && themeSearchBar.inputActiveFocus && filteredThemes && filteredThemes.length > 0 && searchQuery.trim() !== ""

  function clampSelection() {
    if (!filteredThemes || filteredThemes.length === 0) {
      selectedThemeIndex = -1;
      return;
    }

    if (selectedThemeIndex < 0 || selectedThemeIndex >= filteredThemes.length) {
      selectedThemeIndex = 0;
    }
  }

  function moveSelection(delta) {
    if (!filteredThemes || filteredThemes.length === 0)
      return;
    clampSelection();

    const count = filteredThemes.length;
    selectedThemeIndex = (selectedThemeIndex + delta + count) % count;
  }

  function selectedThemeDirName() {
    if (!filteredThemes || filteredThemes.length === 0)
      return "";

    clampSelection();

    const selected = filteredThemes[selectedThemeIndex];
    return ThemeIdentity.themeEntryDirName(selected);
  }

  function applySelectedTheme() {
    if (!selectionEnabled)
      return;
    const dirName = selectedThemeDirName();
    handleThemeSelection(dirName);
  }

  function activatePlugin() {
    return pluginMain?.activate() ?? false;
  }

  function handleThemeSelection(dirName) {
    if (!dirName)
      return false;

    let started = false;
    if (!isActive)
      started = pluginMain?.activateAndSetTheme(dirName) ?? false;
    else
      started = pluginMain?.setTheme(dirName) ?? false;

    if (started && pluginApi)
      pluginApi.closePanel(root.screen);

    return started;
  }

  readonly property string themeFilterLabel: themeFilter === "dark" ? trOrDefault("filters.dark", "Dark") : (themeFilter === "light" ? trOrDefault("filters.light", "Light") : trOrDefault("filters.all", "All"))

  readonly property var filteredThemes: ThemeIdentity.filterThemes(pluginMain?.availableThemes || [], themeFilter, searchQuery)

  onFilteredThemesChanged: clampSelection()

  function preferredThemeFilter() {
    const hour = new Date().getHours();
    return (hour >= 18 || hour < 6) ? "dark" : "light";
  }

  function cycleThemeFilter() {
    searchQuery = "";
    if (themeSearchBar)
      themeSearchBar.text = "";

    if (themeFilter === "all") {
      themeFilter = preferredThemeFilter();
    } else {
      themeFilter = themeFilter === "light" ? "dark" : "light";
    }
  }

  ColumnLayout {
    id: mainColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.marginL
    spacing: Style.marginM

    ThemePanelHeader {
      panelRoot: root
    }

    InactiveStateCard {
      visible: !root.isActive
      panelRoot: root
    }

    ThemeSearchBar {
      id: themeSearchBar
      visible: root.showSearchInput
      panelRoot: root
    }

    ThemeList {
      panelRoot: root
    }
  }
}
