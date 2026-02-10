import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isActive: pluginApi?.pluginSettings?.active || false
  readonly property bool isAvailable: pluginMain?.available || false

  readonly property string pluginTitle: pluginApi?.tr("title") || "Omarchy"
  readonly property string unavailableLabel: pluginApi?.tr("status.not-available") || "Omarchy not found"

  readonly property string labelText: {
    if (!isActive)
      return pluginTitle;
    if (!isAvailable)
      return unavailableLabel;
    const name = pluginMain?.themeDisplayName || "";
    return name !== "" ? name : pluginTitle;
  }

  readonly property bool showThemeName: pluginApi?.pluginSettings?.showThemeName !== false
  readonly property string pillText: (isBarVertical || !showThemeName) ? "" : labelText
  readonly property string iconName: {
    if (!isActive)
      return "palette-off";
    if (!isAvailable)
      return "alert-circle";
    return "palette";
  }
  readonly property bool isLoading: pluginMain?.operationInProgress || false

  readonly property string tooltipText: {
    if (isLoading)
      return "Applying theme...";
    if (!isActive)
      return pluginApi?.tr("tooltips.inactive") || "Omarchy (inactive)\nClick to open settings";
    if (!isAvailable)
      return pluginApi?.tr("tooltips.not-available") || "Omarchy not available\nInstall omarchy and configure themes";
    const currentTheme = pluginMain?.themeDisplayName || "";
    return pluginApi?.tr("tooltips.active", { "theme": currentTheme }) || ("Theme: " + currentTheme);
  }

  readonly property color pillBackgroundColor: {
    if (!isActive)
      return Color.mSurfaceVariant;
    if (!isAvailable)
      return Color.mSurfaceVariant;
    return Qt.rgba(0, 0, 0, 0);
  }
  readonly property color pillTextIconColor: (!isActive || !isAvailable) ? Color.mOnSurface : Qt.rgba(0, 0, 0, 0)

  implicitWidth: pill.width
  implicitHeight: pill.height

  function popupWindow() {
    if (!screen)
      return null;
    return PanelService.getPopupMenuWindow(screen);
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("tooltips.random-theme") || "Random theme",
        "action": "random",
        "icon": "dice-3"
      },
      {
        "label": pluginApi?.tr("tooltips.widget-settings") || "Widget settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
                   var popupMenuWindow = popupWindow();
                   if (popupMenuWindow) {
                     popupMenuWindow.close();
                   }
                   if (action === "random") {
                     selectRandomTheme();
                   } else if (action === "settings") {
                     openPluginSettings();
                   }
                 }
  }

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: isLoading ? "refresh" : iconName
    text: pillText
    tooltipText: root.tooltipText
    forceOpen: !isBarVertical && isActive && isAvailable && pillText !== ""
    forceClose: !isActive || (!isAvailable && pillText === "")
    customBackgroundColor: isLoading ? Color.mPrimary : pillBackgroundColor
    customTextIconColor: pillTextIconColor

    onClicked: {
      TooltipService.hide();
      pluginApi?.togglePanel(root.screen, pill);
    }
    onRightClicked: {
      TooltipService.hide();
      var popupMenuWindow = popupWindow();
      if (popupMenuWindow) {
        popupMenuWindow.showContextMenu(contextMenu);
        contextMenu.openAtItem(pill, screen);
      }
    }
    onMiddleClicked: {
      TooltipService.hide();
      if (!isLoading) {
        selectRandomTheme();
      }
    }
  }

  function openPluginSettings() {
    if (!pluginApi || !root.screen)
      return;
    BarService.openPluginSettings(root.screen, pluginApi.manifest);
  }

  function selectRandomTheme() {
    if (!pluginMain || !isAvailable || !isActive)
      return;
    pluginMain.randomTheme();
  }
}
