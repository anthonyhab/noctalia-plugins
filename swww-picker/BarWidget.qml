import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

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

  readonly property string iconName: {
    if (!isAvailable)
      return "photo-off";
    if (isApplying)
      return "loader-2";
    if (autoCycleEnabled)
      return "player-play";
    return "photo";
  }

  readonly property string tooltipTextValue: {
    if (!isAvailable)
      return pluginApi?.tr("tooltips.unavailable");

    let text = currentWallpaperName || pluginApi?.tr("tooltips.no-wallpaper");

    if (autoCycleEnabled) {
      const interval = pluginApi?.pluginSettings?.autoCycleInterval || 30;
      text += "\n" + pluginApi?.tr("tooltips.auto-cycle", { "interval": interval });
    }

    if (shuffleMode)
      text += "\n" + pluginApi?.tr("tooltips.shuffle-on");

    text += "\n" + wallpaperCount + " " + pluginApi?.tr("status.wallpapers");
    return text;
  }

  readonly property string screenName: screen?.name ?? ""

  icon: iconName
  tooltipText: tooltipTextValue
  tooltipDirection: BarService.getTooltipDirection(screenName)
  baseSize: Style.getCapsuleHeightForScreen(screenName)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: isAvailable ? Color.mOnSurface : Color.mOnSurfaceVariant
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover
  colorBorder: Style.capsuleBorderColor
  colorBorderHover: Style.capsuleBorderColor
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  function popupWindow() {
    if (!screen)
      return null;
    return PanelService.getPopupMenuWindow(screen);
  }

  function openPanel() {
    if (!pluginApi)
      return;
    pluginApi.togglePanel(root.screen, root);
  }

  function openPluginSettings() {
    if (!pluginApi || !root.screen)
      return;

    const popupMenuWindow = popupWindow();
    if (popupMenuWindow)
      popupMenuWindow.close();

    BarService.openPluginSettings(root.screen, pluginApi.manifest);
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("actions.next"),
        "action": "next",
        "icon": "arrow-right",
        "enabled": isAvailable && wallpaperCount > 0
      },
      {
        "label": pluginApi?.tr("actions.previous"),
        "action": "previous",
        "icon": "arrow-left",
        "enabled": isAvailable && wallpaperCount > 0
      },
      {
        "label": pluginApi?.tr("actions.random"),
        "action": "random",
        "icon": "dice-3",
        "enabled": isAvailable && wallpaperCount > 0
      },
      {
        "label": autoCycleEnabled
          ? pluginApi?.tr("actions.disable-auto")
          : pluginApi?.tr("actions.enable-auto"),
        "action": "toggle-auto",
        "icon": autoCycleEnabled ? "player-pause" : "player-play",
        "enabled": isAvailable
      },
      {
        "label": pluginApi?.tr("actions.settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      const popupMenuWindow = popupWindow();
      if (popupMenuWindow)
        popupMenuWindow.close();

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

  onClicked: {
    TooltipService.hide();
    openPanel();
  }

  onRightClicked: {
    TooltipService.hide();
    const popupMenuWindow = popupWindow();
    if (!popupMenuWindow)
      return;

    popupMenuWindow.showContextMenu(contextMenu);
    contextMenu.openAtItem(root, screen);
  }

  onMiddleClicked: {
    TooltipService.hide();
    pluginMain?.random();
  }
}
