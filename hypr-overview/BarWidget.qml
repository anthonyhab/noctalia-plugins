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

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)

    implicitWidth: isVertical ? capsuleHeight : button.implicitWidth
    implicitHeight: isVertical ? button.implicitHeight : capsuleHeight

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "settings")
                BarService.openPluginSettings(screen, pluginApi.manifest)
        }
    }

    NIconButton {
        id: button

        icon: "layout-dashboard"
        tooltipText: pluginApi?.tr("widget.tooltip")
        tooltipDirection: BarService.getTooltipDirection(screen?.name)
        baseSize: capsuleHeight
        applyUiScale: false
        customRadius: Style.radiusL
        colorBg: Style.capsuleColor
        colorFg: Color.mOnSurface

        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        onClicked: pluginApi?.togglePanel(screen, this)
        onRightClicked: PanelService.showContextMenu(contextMenu, this, screen)
    }
}
