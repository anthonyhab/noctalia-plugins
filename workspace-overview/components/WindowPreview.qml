import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons

Item {
    id: root
    property var pluginMain
    property var toplevel
    property var windowData
    property var monitorData
    property var scale: 1.0
    property var availableWorkspaceWidth: 100
    property var availableWorkspaceHeight: 100
    property bool restrictToWorkspace: true
    property bool overviewOpen: false

    property real initX: Math.max((((windowData && windowData.at[0]) || 0) - ((monitorData && monitorData.x) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[0]) || 0)) * root.scale, 0) + xOffset
    property real initY: Math.max((((windowData && windowData.at[1]) || 0) - ((monitorData && monitorData.y) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[1]) || 0)) * root.scale, 0) + yOffset
    property real xOffset: 0
    property real yOffset: 0
    property int widgetMonitorId: 0

    property var targetWindowWidth: ((windowData && windowData.size[0]) || 100) * scale
    property var targetWindowHeight: ((windowData && windowData.size[1]) || 100) * scale
    property bool hovered: false
    property bool pressed: false

    property real iconToWindowRatio: 0.25
    property real iconToWindowRatioCompact: 0.45
    property var entry: DesktopEntries.heuristicLookup(windowData && windowData.class)
    property var iconPath: Quickshell.iconPath((entry && entry.icon) || (windowData && windowData.class) || "application-x-executable", "image-missing")
    property bool compactMode: 48 > targetWindowHeight || 48 > targetWindowWidth

    x: initX
    y: initY
    width: Math.min(((windowData && windowData.size[0]) || 100) * root.scale, availableWorkspaceWidth)
    height: Math.min(((windowData && windowData.size[1]) || 100) * root.scale, availableWorkspaceHeight)
    opacity: ((windowData && windowData.monitor) || -1) == widgetMonitorId ? 1 : 0.4

    clip: true

    Behavior on x {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: root.overviewOpen ? root.toplevel : null
        live: true

        // Window overlay (hover/press states + border)
        Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Style.screenRadius * root.scale)
            color: root.pressed
                ? Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.5)
                : root.hovered
                    ? Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.3)
                    : "transparent"
            border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.3)
            border.width: Style.borderS
        }

        // App icon
        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            Image {
                id: windowIcon
                property real iconSize: {
                    return Math.min(root.targetWindowWidth, root.targetWindowHeight) *
                        (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) /
                        ((root.monitorData && root.monitorData.scale) || 1)
                }
                Layout.alignment: Qt.AlignHCenter
                source: root.iconPath
                width: iconSize
                height: iconSize
                sourceSize: Qt.size(iconSize, iconSize)

                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
