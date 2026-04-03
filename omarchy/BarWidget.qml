import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isActive: pluginApi?.pluginSettings?.active === true
  readonly property bool isAvailable: pluginMain?.available === true
  readonly property bool isLoading: pluginMain?.operationInProgress === true

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)

  readonly property string iconName: {
    if (isLoading)
      return "refresh"
    if (!isActive)
      return "palette-off"
    if (!isAvailable)
      return "alert-circle"
    return "palette"
  }

  readonly property string tooltipText: {
    if (isLoading)
      return pluginApi?.tr("status.applying")
    if (!isActive)
      return pluginApi?.tr("tooltips.inactive")
    if (!isAvailable)
      return pluginApi?.tr("tooltips.not-available")
    return pluginApi?.tr("tooltips.active", { "theme": pluginMain?.themeDisplayName || "" })
  }

  implicitWidth: isBarVertical ? capsuleHeight : button.implicitWidth
  implicitHeight: capsuleHeight

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("tooltips.random-theme"),
        "action": "random",
        "icon": "dice-3"
      },
      {
        "label": pluginApi?.tr("tooltips.widget-settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "random") {
        selectRandomTheme()
      } else if (action === "settings") {
        openPluginSettings()
      }
    }
  }

  NIconButton {
    id: button

    anchors.centerIn: parent
    implicitWidth: capsuleHeight
    implicitHeight: capsuleHeight
    icon: iconName
    colorFg: (!isActive || !isAvailable) ? Color.mOnSurface : Color.mPrimary
    tooltipText: root.tooltipText

    onClicked: {
      TooltipService.hide()
      pluginApi?.togglePanel(root.screen, button)
    }

  }

  MouseArea {
    anchors.fill: button
    acceptedButtons: Qt.RightButton | Qt.MiddleButton
    hoverEnabled: false
    onClicked: mouse => {
      TooltipService.hide()
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, button, screen)
      } else if (mouse.button === Qt.MiddleButton) {
        selectRandomTheme()
      }
    }
  }

  function openPluginSettings() {
    if (!pluginApi || !root.screen)
      return

    BarService.openPluginSettings(root.screen, pluginApi.manifest)
  }

  function selectRandomTheme() {
    if (!pluginMain || !isAvailable || !isActive || isLoading)
      return

    pluginMain.randomTheme()
  }
}
