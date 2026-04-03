import Quickshell
import qs.Commons
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

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property bool agentAvailable: mainInstance?.agentAvailable ?? false
    readonly property bool providerRegistered: mainInstance?.providerRegistered ?? false
    readonly property bool providerActivityKnown: mainInstance?.providerActivityKnown ?? false
    readonly property bool providerActive: mainInstance?.providerActive ?? false

    icon: "shield"
    tooltipText: {
        if (!agentAvailable || !providerRegistered)
            return pluginApi?.tr("widget.tooltip-unavailable")
        if (providerActivityKnown && !providerActive)
            return pluginApi?.tr("widget.tooltip-standby")
        return pluginApi?.tr("widget.tooltip-ready")
    }
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL

    colorBg: Style.capsuleColor
    colorFg: {
        if (!agentAvailable || !providerRegistered)
            return Color.mError
        if (providerActivityKnown && !providerActive)
            return Color.mTertiary
        return Color.mPrimary
    }
    colorBgHover: Color.mHover
    colorFgHover: Color.mOnHover
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: {
        pluginApi?.togglePanel(screen, root)
    }
}
