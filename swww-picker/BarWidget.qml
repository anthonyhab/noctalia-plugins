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

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool isApplying: pluginMain?.applying || false
  readonly property bool autoCycleEnabled: pluginMain?.autoCycleEnabled || false
  readonly property bool shuffleMode: pluginMain?.shuffleMode || false
  readonly property int wallpaperCount: pluginMain?.wallpaperList?.length || 0

  readonly property string currentWallpaperName: {
    if (!pluginMain?.currentWallpaper)
      return "";
    const path = pluginMain.currentWallpaper;
    return path.split("/").pop() || "";
  }

  readonly property bool showWallpaperName: pluginApi?.pluginSettings?.showWallpaperName !== false

  readonly property string pillText: {
    if (isBarVertical)
      return "";
    if (!isAvailable)
      return pluginApi?.tr("title") || "Wallpaper";
    if (!showWallpaperName)
      return "";
    return currentWallpaperName;
  }

  readonly property string iconName: {
    if (!isAvailable)
      return "photo-off";
    if (isApplying)
      return "loader-2";
    if (autoCycleEnabled)
      return "player-play";
    return "photo";
  }

  readonly property string tooltipText: {
    if (!isAvailable)
      return pluginApi?.tr("tooltips.unavailable") || "swww daemon not available\nRun: swww-daemon";

    let text = currentWallpaperName || (pluginApi?.tr("tooltips.no-wallpaper") || "No wallpaper set");

    if (autoCycleEnabled) {
      const interval = pluginApi?.pluginSettings?.autoCycleInterval || 30;
      text += "\n" + (pluginApi?.tr("tooltips.auto-cycle", { "interval": interval }) || ("Auto-cycling every " + interval + " min"));
    }

    if (shuffleMode) {
      text += "\n" + (pluginApi?.tr("tooltips.shuffle-on") || "Shuffle mode enabled");
    }

    text += "\n" + wallpaperCount + " wallpapers";

    return text;
  }

  property var settingsPopupComponent: null

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
        "label": pluginApi?.tr("actions.next") || "Next",
        "action": "next",
        "icon": "arrow-right",
        "enabled": isAvailable && wallpaperCount > 0
      },
      {
        "label": pluginApi?.tr("actions.previous") || "Previous",
        "action": "previous",
        "icon": "arrow-left",
        "enabled": isAvailable && wallpaperCount > 0
      },
      {
        "label": pluginApi?.tr("actions.random") || "Random",
        "action": "random",
        "icon": "dice-3",
        "enabled": isAvailable && wallpaperCount > 0
      },
      {
        "label": autoCycleEnabled
          ? (pluginApi?.tr("actions.disable-auto") || "Disable auto-cycle")
          : (pluginApi?.tr("actions.enable-auto") || "Enable auto-cycle"),
        "action": "toggle-auto",
        "icon": autoCycleEnabled ? "player-pause" : "player-play",
        "enabled": isAvailable
      },
      {
        "label": pluginApi?.tr("actions.settings") || "Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      var popupMenuWindow = popupWindow();
      if (popupMenuWindow) {
        popupMenuWindow.close();
      }

      if (action === "next") {
        pluginMain?.next();
      } else if (action === "previous") {
        pluginMain?.previous();
      } else if (action === "random") {
        pluginMain?.random();
      } else if (action === "toggle-auto") {
        pluginMain?.toggleAutoCycle();
      } else if (action === "settings") {
        openPluginSettings();
      }
    }
  }

  BarPill {
    id: pill

    screen: root.screen
    density: Settings.data.bar.density
    oppositeDirection: BarService.getPillDirection(root)
    icon: iconName
    text: pillText
    tooltipText: root.tooltipText
    forceOpen: !isBarVertical && isAvailable && showWallpaperName && pillText !== ""
    forceClose: !isAvailable

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
      pluginMain?.random();
    }
  }

  function pluginPanelForScreen(screen) {
    if (!pluginApi || !screen)
      return null;
    const slots = ["pluginPanel1", "pluginPanel2"];
    for (var i = 0; i < slots.length; i++) {
      var panel = PanelService.getPanel(slots[i], screen);
      if (panel && panel.currentPluginId === pluginApi.pluginId) {
        return panel;
      }
    }
    return null;
  }

  function openPanel() {
    if (!pluginApi)
      return;
    pluginApi.withCurrentScreen(screen => {
      var panel = pluginPanelForScreen(screen);
      if (panel && panel.isPanelOpen) {
        panel.toggle(pill);
        return;
      }
      pluginApi.openPanel(screen, pill);
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
        Logger.e("SwwwPickerWidget", "Failed to instantiate plugin settings dialog:", component.errorString());
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
          Logger.e("SwwwPickerWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
          settingsPopupComponent.statusChanged.disconnect(handler);
          settingsPopupComponent = null;
        }
      };
      settingsPopupComponent.statusChanged.connect(handler);
    } else {
      Logger.e("SwwwPickerWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
      settingsPopupComponent = null;
    }
  }
}
