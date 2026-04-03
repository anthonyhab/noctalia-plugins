import Quickshell
import qs.Commons
import qs.Widgets

NIconButtonHot {
    id: root

    property ShellScreen screen
    property var pluginApi: null

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
    colorFg: {
        if (!agentAvailable || !providerRegistered)
            return Color.mError
        if (providerActivityKnown && !providerActive)
            return Color.mTertiary
        return Color.mPrimary
    }

    onClicked: {
        pluginApi?.togglePanel(screen, root)
    }
}
