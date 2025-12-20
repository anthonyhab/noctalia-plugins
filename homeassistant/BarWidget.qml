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

  // Widget properties passed from Bar.qml
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

  readonly property string mediaTitle: pluginMain?.mediaTitle || ""
  readonly property string mediaArtist: pluginMain?.mediaArtist || ""
  readonly property string friendlyName: pluginMain?.friendlyName || ""

  readonly property string labelText: {
    if (!isConnected) {
      return pluginApi?.tr("title") || "Home Assistant";
    }
    if (isPlaying && mediaTitle) {
      return mediaTitle;
    }
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
    return "home";
  }

  readonly property string tooltipText: {
    if (isConnecting) {
      return pluginApi?.tr("status.connecting") || "Connecting...";
    }
    if (!isConnected) {
      return pluginApi?.tr("tooltips.disconnected") || "Home Assistant (disconnected)\nClick to configure";
    }
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

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play"),
        "action": "play-pause",
        "icon": isPlaying ? "player-pause" : "player-play",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.next") || "Next",
        "action": "next",
        "icon": "player-track-next",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.previous") || "Previous",
        "action": "previous",
        "icon": "player-track-prev",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.refresh") || "Refresh",
        "action": "refresh",
        "icon": "refresh"
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

  readonly property var palette: typeof Color !== "undefined" ? Color : null
  readonly property color fallbackSurfaceLow: "#1f1f1f"
  readonly property color fallbackOnSurface: "#f0f0f0"

  readonly property color pillBackgroundColor: {
    if (!isConnected)
      return palette?.mSurfaceContainerLow ?? fallbackSurfaceLow;
    return Qt.rgba(0, 0, 0, 0);
  }
  readonly property color pillTextIconColor: !isConnected ? (palette?.mOnSurface ?? fallbackOnSurface) : Qt.rgba(0, 0, 0, 0)

  property var settingsPopupComponent: null

  implicitWidth: pill.width
  implicitHeight: pill.height

  function popupWindow() {
    if (!screen)
      return null;
    return PanelService.getPopupMenuWindow(screen);
  }

  BarPill {
    id: pill

    screen: root.screen
    density: Settings.data.bar.density
    oppositeDirection: BarService.getPillDirection(root)
    icon: iconName
    text: pillText
    tooltipText: root.tooltipText
    forceOpen: !isBarVertical && isConnected && pillText !== ""
    forceClose: !isConnected && pillText === ""
    customBackgroundColor: pillBackgroundColor
    customTextIconColor: pillTextIconColor
    onClicked: {
      TooltipService.hide();
      openPanel();
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
      pluginMain?.mediaPlayPause();
    }
    onWheel: delta => {
               TooltipService.hide();
               if (!isConnected)
               return;
               // delta > 0 means scroll up (volume up), delta < 0 means scroll down (volume down)
               if (delta > 0) {
                 pluginMain?.volumeUp();
               } else {
                 pluginMain?.volumeDown();
               }
             }
  }

  function openPanel() {
    if (!pluginApi)
      return;
    pluginApi.withCurrentScreen(s => {
                                  pluginApi.openPanel(s, pill);
                                });
  }

  function openPluginSettings() {
    if (!pluginApi)
      return;

    var popupMenuWindow = popupWindow();

    function instantiateDialog(component) {
      var parentItem = popupMenuWindow ? popupMenuWindow.dialogParent : Overlay.overlay;
      var dialog = component.createObject(parentItem, {
                                            "showToastOnSave": true
                                          });
      if (!dialog) {
        Logger.e("HomeAssistantWidget", "Failed to instantiate plugin settings dialog:", component.errorString());
        return;
      }

      dialog.openPluginSettings(pluginApi.manifest);

      if (popupMenuWindow) {
        popupMenuWindow.hasDialog = true;
        popupMenuWindow.open();
        dialog.closed.connect(() => {
                                popupMenuWindow.hasDialog = false;
                                popupMenuWindow.close();
                              });
      }

      dialog.closed.connect(() => dialog.destroy());
    }

    function handleReady(component) {
      instantiateDialog(component);
    }

    if (!settingsPopupComponent) {
      settingsPopupComponent = Qt.createComponent(Quickshell.shellDir + "/Widgets/NPluginSettingsPopup.qml");
    }

    if (settingsPopupComponent.status === Component.Ready) {
      handleReady(settingsPopupComponent);
    } else if (settingsPopupComponent.status === Component.Loading) {
      var handler = function settingsComponentStatusChanged() {
        if (settingsPopupComponent.status === Component.Ready) {
          settingsPopupComponent.statusChanged.disconnect(handler);
          handleReady(settingsPopupComponent);
        } else if (settingsPopupComponent.status === Component.Error) {
          Logger.e("HomeAssistantWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
          settingsPopupComponent.statusChanged.disconnect(handler);
          settingsPopupComponent = null;
        }
      };
      settingsPopupComponent.statusChanged.connect(handler);
    } else {
      Logger.e("HomeAssistantWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
      settingsPopupComponent = null;
    }
  }
}
