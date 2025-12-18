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
    const name = pluginMain?.themeName || "";
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
  readonly property string tooltipText: {
    if (!isActive)
      return pluginApi?.tr("tooltips.inactive") || "Omarchy (inactive)\nClick to open settings";
    if (!isAvailable)
      return pluginApi?.tr("tooltips.not-available") || "Omarchy not available\nInstall omarchy and configure themes";
    const currentTheme = pluginMain?.themeName || "";
    return pluginApi?.tr("tooltips.active", { "theme": currentTheme }) || ("Theme: " + currentTheme);
  }
  readonly property var palette: typeof Color !== "undefined" ? Color : null
  readonly property color fallbackSurfaceLow: "#1f1f1f"
  readonly property color fallbackSurfaceHigh: "#262626"
  readonly property color fallbackOnSurface: "#f0f0f0"

  readonly property color pillBackgroundColor: {
    if (!isActive)
      return palette?.mSurfaceContainerLow ?? fallbackSurfaceLow;
    if (!isAvailable)
      return palette?.mSurfaceContainerHigh ?? fallbackSurfaceHigh;
    return Qt.rgba(0, 0, 0, 0);
  }
  readonly property color pillTextIconColor: (!isActive || !isAvailable) ? (palette?.mOnSurface ?? fallbackOnSurface) : Qt.rgba(0, 0, 0, 0)
  property var settingsPopupComponent: null

  implicitWidth: pill.width
  implicitHeight: pill.height

  function popupWindow() {
    if (screen) {
      var window = PanelService.getPopupMenuWindow(screen);
      if (window)
        return window;
    }
    if (Quickshell.screens.length > 0) {
      return PanelService.getPopupMenuWindow(Quickshell.screens[0]);
    }
    return null;
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
                   contextMenu.close();
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
    density: Settings.data.bar.density
    oppositeDirection: BarService.getPillDirection(root)
    icon: iconName
    text: pillText
    tooltipText: tooltipText
    forceOpen: !isBarVertical && isActive && isAvailable && pillText !== ""
    forceClose: !isActive || (!isAvailable && pillText === "")
    customBackgroundColor: pillBackgroundColor
    customTextIconColor: pillTextIconColor
    onClicked: openPanel()
    onRightClicked: {
      var popupMenuWindow = popupWindow();
      if (popupMenuWindow) {
        popupMenuWindow.showContextMenu(contextMenu);
        const pos = BarService.getContextMenuPosition(pill, contextMenu.implicitWidth, contextMenu.implicitHeight);
        contextMenu.openAtItem(pill, pos.x, pos.y);
      } else {
        openPluginSettings();
      }
    }
    onMiddleClicked: selectRandomTheme()
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

  function anchorPanel(screen) {
    Qt.callLater(() => {
                   var panel = pluginPanelForScreen(screen);
                   if (panel && panel.isPanelOpen) {
                     panel.open(pill);
                   }
                 });
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
                                  if (pluginApi.openPanel(screen)) {
                                    anchorPanel(screen);
                                  }
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
        Logger.e("OmarchyWidget", "Failed to instantiate plugin settings dialog:", component.errorString());
        return;
      }

      dialog.openPluginSettings(pluginApi.manifest);

      if (popupMenuWindow) {
        popupMenuWindow.hasDialog = true;
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
          Logger.e("OmarchyWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
          settingsPopupComponent.statusChanged.disconnect(handler);
          settingsPopupComponent = null;
        }
      };
      settingsPopupComponent.statusChanged.connect(handler);
    } else {
      Logger.e("OmarchyWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
      settingsPopupComponent = null;
    }
  }

  function selectRandomTheme() {
    if (!pluginMain || !isAvailable || !isActive)
      return;
    const themes = pluginMain.availableThemes;
    if (themes.length === 0) {
      Logger.w("OmarchyWidget", "No themes available");
      return;
    }

    const randomIndex = Math.floor(Math.random() * themes.length);
    const randomTheme = themes[randomIndex];
    const randomName = typeof randomTheme === 'string' ? randomTheme : randomTheme.name;

    Logger.d("OmarchyWidget", "Random theme:", randomName);
    pluginMain.setTheme(randomName);
  }
}
