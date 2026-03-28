import QtQuick
import qs.Commons

Rectangle {
    id: root

    property var pluginMain: null
    property int workspaceId: 1
    property var monitorId: null
    property real workspaceWidth: 240
    property real workspaceHeight: 140
    property bool isActive: false
    property bool showLabel: true

    width: workspaceWidth
    height: workspaceHeight
    radius: Style.radiusS
    color: isActive ? Qt.alpha(Color.mSecondary, 0.16) : Qt.alpha(Color.mSurface, 0.58)
    border.width: isActive ? Style.borderM : Style.borderS
    border.color: isActive ? Color.mSecondary : Qt.alpha(Color.mOutline, 0.85)

    Rectangle {
        anchors.fill: parent
        anchors.margins: Style.marginXS
        radius: Math.max(0, root.radius - 2)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Color.mOutline, 0.35)
    }

    Rectangle {
        visible: pluginMain && pluginMain.draggingWindowAddress !== "" && pluginMain.draggingToWorkspace === workspaceId
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Color.mSecondary, 0.24)
        border.width: Style.borderM
        border.color: Color.mSecondary
    }

    Rectangle {
        id: occupancyDot

        width: 7
        height: 7
        radius: 4
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Style.marginS
        visible: pluginMain ? pluginMain.workspaceHasWindows(workspaceId, monitorId) : false
        color: isActive ? Color.mSecondary : Qt.alpha(Color.mOnSurfaceVariant, 0.7)
    }

    Text {
        visible: showLabel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: Style.marginS
        text: "Workspace " + workspaceId
        color: isActive ? Color.mOnSurface : Color.mOnSurfaceVariant
        font.pixelSize: Style.fontSizeS
        font.weight: Style.fontWeightMedium
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            if (pluginMain && pluginMain.draggingWindowAddress !== "")
                pluginMain.setDragTarget(workspaceId);

        }
        onClicked: {
            if (pluginMain && pluginMain.draggingWindowAddress === "") {
                pluginMain.switchToWorkspace(workspaceId);
                pluginMain.close();
            }
        }
        onReleased: {
            if (pluginMain && pluginMain.draggingWindowAddress !== "")
                pluginMain.finishWindowDrag();

        }
    }

}
