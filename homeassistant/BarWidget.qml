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
  readonly property bool isConnected: pluginMain?.connected || false
  readonly property bool isConnecting: pluginMain?.connecting || false
  readonly property bool isPlaying: pluginMain?.isPlaying || false
  readonly property bool isPaused: pluginMain?.isPaused || false
  property bool hasEverConnected: false

  onIsConnectedChanged: {
    if (isConnected)
      hasEverConnected = true;
  }

  readonly property string mediaTitle: pluginMain?.mediaTitle || ""
  readonly property string mediaArtist: pluginMain?.mediaArtist || ""
  readonly property string friendlyName: pluginMain?.friendlyName || ""

  readonly property string labelText: {
    if (!isConnected)
      return pluginApi?.tr("title") || "Home Assistant";
    if (mediaTitle)
      return mediaTitle;
    return friendlyName || (pluginApi?.tr("title") || "Home Assistant");
  }

  readonly property string pillText: isBarVertical ? "" : labelText

  readonly property string iconName: {
    if (isConnecting)
      return "home-search";
    if (!isConnected)
      return "home-off";
    if (isPlaying)
      return "player-play";
    if (isPaused)
      return "player-pause";
    return "home";
  }

  readonly property string tooltipText: {
    if (isConnecting)
      return pluginApi?.tr("status.connecting") || "Connecting...";
    if (!isConnected)
      return pluginApi?.tr("tooltips.disconnected") || "Home Assistant (disconnected)\nClick to configure";
    if (isPlaying && mediaTitle) {
      let tooltip = mediaTitle;
      if (mediaArtist)
        tooltip += "\n" + mediaArtist;
      tooltip += "\n" + (pluginApi?.tr("tooltips.click-hint") || "Click to control");
      return tooltip;
    }
    return pluginApi?.tr("tooltips.connected", {
                           count: pluginMain?.mediaPlayers?.length || 0
                         }) || "Home Assistant\n" + (pluginMain?.mediaPlayers?.length || 0) + " devices available";
  }

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string scrollingMode: pluginApi?.pluginSettings?.barWidgetScrollingMode || defaultSettings.barWidgetScrollingMode || "hover"

  readonly property bool forceOpen: !isBarVertical && scrollingMode === "always" && pillText !== ""
  readonly property bool forceClose: isBarVertical || scrollingMode === "never" || pillText === ""

  readonly property color customBgColor: {
    if (!isConnected && hasEverConnected)
      return Color.mSurfaceVariant;
    return Qt.rgba(0, 0, 0, 0);
  }

  readonly property color customFgColor: {
    if (!isConnected && hasEverConnected)
      return Color.mOnSurface;
    return Qt.rgba(0, 0, 0, 0);
  }

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
        label: isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play"),
        action: "play-pause",
        icon: isPlaying ? "player-pause" : "player-play",
        enabled: isConnected
      },
      {
        label: pluginApi?.tr("actions.next") || "Next",
        action: "next",
        icon: "player-track-next",
        enabled: isConnected
      },
      {
        label: pluginApi?.tr("actions.previous") || "Previous",
        action: "previous",
        icon: "player-track-prev",
        enabled: isConnected
      },
      {
        label: pluginApi?.tr("actions.refresh") || "Refresh",
        action: "refresh",
        icon: "refresh"
      },
      {
        label: pluginApi?.tr("tooltips.widget-settings") || "Widget settings",
        action: "settings",
        icon: "settings"
      }
    ]

    onTriggered: action => {
                   PanelService.closeContextMenu(screen);
                   if (action === "play-pause") {
                     pluginMain?.mediaPlayPause();
                   } else if (action === "next") {
                     pluginMain?.mediaNext();
                   } else if (action === "previous") {
                     pluginMain?.mediaPrevious();
                   } else if (action === "refresh") {
                     pluginMain?.refresh();
                   } else if (action === "settings") {
                     openPluginSettings();
                   }
                 }
  }

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: iconName
    text: pillText
    tooltipText: root.tooltipText
    autoHide: false
    forceOpen: root.forceOpen
    forceClose: root.forceClose
    customBackgroundColor: customBgColor
    customTextIconColor: customFgColor

    onClicked: {
      pluginApi?.togglePanel(root.screen, pill);
    }
    onRightClicked: {
      PanelService.showContextMenu(contextMenu, pill, screen);
    }
    onMiddleClicked: {
      pluginMain?.mediaPlayPause();
    }
    onWheel: delta => {
               if (!isConnected)
               return;
               if (delta > 0) {
                 pluginMain?.volumeUp();
               } else {
                 pluginMain?.volumeDown();
               }
             }
  }

  function openPluginSettings() {
    if (!pluginApi || !root.screen)
      return;
    PanelService.closeContextMenu(screen);
    BarService.openPluginSettings(root.screen, pluginApi.manifest);
  }
}
