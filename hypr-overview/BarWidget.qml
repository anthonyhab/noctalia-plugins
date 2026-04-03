import QtQuick
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
    readonly property var pluginMain: pluginApi && pluginApi.mainInstance
    readonly property bool isOpen: (pluginMain && pluginMain.overviewOpen) || false

    function popupWindow() {
        if (!screen)
            return null;

        return PanelService.getPopupMenuWindow(screen);
    }

    function openPluginSettings() {
        if (!pluginApi || !screen)
            return;

        var popupMenuWindow = popupWindow();
        if (popupMenuWindow)
            popupMenuWindow.close();

        BarService.openPluginSettings(screen, pluginApi.manifest);
    }

    implicitWidth: pill.width
    implicitHeight: pill.height

    NPopupContextMenu {
        id: contextMenu

        model: [{
            "label": (pluginApi && pluginApi.tr("actions.settings")) || "Settings",
            "action": "settings",
            "icon": "settings"
        }]
        onTriggered: function(action) {
            if (action === "settings")
                openPluginSettings();
        }
    }

    BarPill {
        id: pill

        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        icon: "layout-dashboard"
        tooltipText: isOpen ? "Close Hypr Overview" : "Open Hypr Overview"
        onClicked: {
            TooltipService.hide();
            if (pluginMain && pluginMain.toggle)
                pluginMain.toggle();
        }
        onRightClicked: {
            TooltipService.hide();
            var popupMenuWindow = popupWindow();
            if (popupMenuWindow) {
                popupMenuWindow.showContextMenu(contextMenu);
                contextMenu.openAtItem(pill, screen);
            }
        }
    }
}
