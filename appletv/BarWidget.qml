import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
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

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool connected: pluginMain?.connected || false
  readonly property bool connecting: pluginMain?.connecting || false

  readonly property string pillText: {
    if (isBarVertical)
      return "";
    if (!connected)
      return pluginApi?.tr("title") || "Apple TV";
    const title = pluginMain?.displayTitle || "";
    if (title)
      return title;
    return pluginMain?.deviceLabel || (pluginApi?.tr("title") || "Apple TV");
  }

  readonly property string iconName: {
    if (connecting)
      return "device-tv-off";
    if (!connected)
      return "device-tv-off";
    return pluginMain?.isPlaying ? "player-play" : "player-stop";
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        "label": pluginMain?.isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play"),
        "icon": pluginMain?.isPlaying ? "player-pause" : "player-play",
        "action": "play"
      },
      {
        "label": pluginApi?.tr("actions.next") || "Next",
        "icon": "player-track-next",
        "action": "next"
      },
      {
        "label": pluginApi?.tr("actions.previous") || "Previous",
        "icon": "player-track-prev",
        "action": "previous"
      },
      {
        "label": pluginApi?.tr("actions.refresh") || "Refresh",
        "icon": "refresh",
        "action": "refresh"
      },
      {
        "label": pluginApi?.tr("tooltips.widget-settings") || "Widget settings",
        "icon": "settings",
        "action": "settings"
      }
    ]

    onTriggered: action => {
                   contextMenu.close();
                   if (!pluginMain)
                   return;
                   if (action === "play") {
                     pluginMain.togglePlayPause();
                   } else if (action === "next") {
                     pluginMain.nextTrack();
                   } else if (action === "previous") {
                     pluginMain.previousTrack();
                   } else if (action === "refresh") {
                     pluginMain.refresh();
                   } else if (action === "settings") {
                     openPluginSettings();
                   }
                 }
  }

  function openPluginSettings() {
    if (!pluginApi)
      return;
    PluginSettingsDialog.open(pluginApi);
  }

  function openPanel() {
    if (!pluginApi)
      return;
    pluginApi.withCurrentScreen(scr => {
                                  pluginApi.openPanel(scr, pill);
                                });
  }

  function popupWindow() {
    if (screen) {
      var window = PanelService.getPopupMenuWindow(screen);
      if (window)
        return window;
    }
    if (Quickshell.screens.length > 0)
      return PanelService.getPopupMenuWindow(Quickshell.screens[0]);
    return null;
  }

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill
    screen: root.screen
    density: Settings.data.bar.density
    oppositeDirection: BarService.getPillDirection(root)
    icon: iconName
    text: pillText
    tooltipText: connected ? pillText : (pluginApi?.tr("status.disconnected") || "Not connected")
    forceOpen: !isBarVertical && connected && pillText !== ""
    forceClose: isBarVertical || pillText === ""
    onClicked: openPanel()
    onMiddleClicked: pluginMain?.togglePlayPause()
    onRightClicked: {
      const popup = popupWindow();
      if (popup) {
        popup.showContextMenu(contextMenu);
        const pos = BarService.getContextMenuPosition(pill, contextMenu.implicitWidth, contextMenu.implicitHeight);
        contextMenu.openAtItem(pill, pos.x, pos.y);
      } else {
        openPluginSettings();
      }
    }
  }
}
