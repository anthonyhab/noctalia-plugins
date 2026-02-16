import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var screen: null
    readonly property var pluginMain: (pluginApi && pluginApi.mainInstance) || null
    readonly property string panelMode: (pluginMain && pluginMain.settingsPanelMode) || "centered"
    readonly property bool attachToBar: panelMode === "attached"
    readonly property string barPosition: Settings.data.bar.position
    // Panel positioning properties (passed through by PluginPanelSlot)
    readonly property bool allowAttach: attachToBar
    readonly property bool panelAnchorHorizontalCenter: attachToBar ? (barPosition === "top" || barPosition === "bottom") : true
    readonly property bool panelAnchorVerticalCenter: attachToBar ? (barPosition === "left" || barPosition === "right") : true
    readonly property bool panelAnchorTop: attachToBar && barPosition === "top"
    readonly property bool panelAnchorBottom: attachToBar && barPosition === "bottom"
    readonly property bool panelAnchorLeft: attachToBar && barPosition === "left"
    readonly property bool panelAnchorRight: attachToBar && barPosition === "right"
    readonly property int contentPreferredWidth: Math.round(360 * Style.uiScaleRatio)
    readonly property int contentPreferredHeight: authContent.implicitHeight

    AuthContent {
        id: authContent

        anchors.fill: parent
        pluginMain: root.pluginMain
        incomingSession: (pluginMain && pluginMain.currentSession) || null
        busy: (pluginMain && pluginMain.sessionState === "verifying") || (pluginMain && pluginMain.sessionState === "submitting")
        agentAvailable: (pluginMain && pluginMain.agentAvailable) || true
        statusText: (pluginMain && pluginMain.agentStatus) || ""
        errorText: (pluginMain && pluginMain.lastError) || ""
        colorizeIcons: (pluginMain && pluginMain.colorizeIcons) !== false
        onCloseRequested: pluginMain && pluginMain.requestClose()
    }

}
