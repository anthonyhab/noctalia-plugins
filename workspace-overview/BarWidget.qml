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

  // Widget properties passed from Bar.qml
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isOverviewOpen: pluginMain?.overviewOpen || false

  readonly property string tooltipText: pluginApi?.tr("barWidget.tooltip") || "Workspace Overview"

  readonly property string iconName: isOverviewOpen ? "layout-dashboard" : "layout-grid"

  implicitWidth: pill.width
  implicitHeight: pill.height

  function popupWindow() {
    if (!screen)
      return null
    return PanelService.getPopupMenuWindow(screen)
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("actions.settings") || "Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      var popupMenuWindow = popupWindow()
      if (popupMenuWindow) {
        popupMenuWindow.close()
      }

      if (action === "settings") {
        openPluginSettings()
      }
    }
  }

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.iconName
    tooltipText: root.tooltipText

    onClicked: {
      TooltipService.hide()
      pluginMain?.toggle()
    }

    onRightClicked: {
      TooltipService.hide()
      var popupMenuWindow = popupWindow()
      if (popupMenuWindow) {
        popupMenuWindow.showContextMenu(contextMenu)
        contextMenu.openAtItem(pill, screen)
      }
    }
  }

  function openPluginSettings() {
    if (!pluginApi || !root.screen)
      return

    var popupMenuWindow = popupWindow()
    if (popupMenuWindow) {
      popupMenuWindow.close()
    }

    BarService.openPluginSettings(root.screen, pluginApi.manifest)
  }
}
