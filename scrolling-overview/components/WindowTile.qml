import QtQuick
import Quickshell.Wayland
import qs.Commons

Item {
    id: root

    property var pluginMain: null
    property var scene: null
    property var toplevel: null
    property var windowData: null
    property var monitorData: null
    readonly property int workspaceId: (windowData && windowData.workspace && windowData.workspace.id) || -1
    readonly property var workspaceRect: scene ? scene.workspaceRectFor(workspaceId) : ({
        "valid": false
    })
    readonly property real monitorX: (monitorData && monitorData.x) || 0
    readonly property real monitorY: (monitorData && monitorData.y) || 0
    readonly property real monitorLeftInset: (monitorData && monitorData.reserved && monitorData.reserved[0]) || 0
    readonly property real monitorTopInset: (monitorData && monitorData.reserved && monitorData.reserved[1]) || 0
    readonly property real localX: ((windowData && windowData.at && windowData.at[0]) || 0) - monitorX - monitorLeftInset
    readonly property real localY: ((windowData && windowData.at && windowData.at[1]) || 0) - monitorY - monitorTopInset
    readonly property real localWidth: (windowData && windowData.size && windowData.size[0]) || 80
    readonly property real localHeight: (windowData && windowData.size && windowData.size[1]) || 60
    readonly property real posScaleX: scene ? scene.workspaceWidth / scene.availableMonitorWidth : 1
    readonly property real posScaleY: scene ? scene.workspaceHeight / scene.availableMonitorHeight : 1
    readonly property real baseX: workspaceRect.valid ? workspaceRect.x + localX * posScaleX : 0
    readonly property real baseY: workspaceRect.valid ? workspaceRect.y + localY * posScaleY : 0
    readonly property real tileWidth: Math.max(26, localWidth * posScaleX)
    readonly property real tileHeight: Math.max(18, localHeight * posScaleY)
    property bool isDragging: false
    property bool movedDuringPress: false
    property real dragX: baseX
    property real dragY: baseY
    property real pressX: 0
    property real pressY: 0
    readonly property bool isFocused: !!(windowData && (windowData.focused || windowData.focusHistoryID === 0))
    readonly property bool isFloating: !!(windowData && windowData.floating)

    visible: workspaceRect.valid && windowData
    x: isDragging ? dragX : baseX
    y: isDragging ? dragY : baseY
    width: tileWidth
    height: tileHeight
    z: isDragging ? 5000 : 50

    Rectangle {
        anchors.fill: parent
        radius: Math.max(2, Style.radiusXS - 2)
        color: Qt.alpha(Color.mSurfaceVariant, 0.9)
        border.width: isFocused ? Style.borderM : Style.borderS
        border.color: isFocused ? Color.mSecondary : Qt.alpha(Color.mOutline, 0.8)
    }

    ScreencopyView {
        anchors.fill: parent
        anchors.margins: 1
        captureSource: toplevel
        live: pluginMain ? pluginMain.useLivePreviews : true
        visible: pluginMain ? pluginMain.useLivePreviews : true
    }

    Rectangle {
        visible: !(pluginMain ? pluginMain.useLivePreviews : true)
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(2, Style.radiusXS - 3)
        color: Qt.alpha(Color.mSurface, 0.86)
    }

    Rectangle {
        visible: isFloating
        width: 10
        height: 10
        radius: 5
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        color: Qt.alpha(Color.mOnSurfaceVariant, 0.9)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPressed: function(mouse) {
            if (!pluginMain || !windowData)
                return ;

            isDragging = true;
            movedDuringPress = false;
            pressX = mouse.x;
            pressY = mouse.y;
            dragX = baseX;
            dragY = baseY;
            pluginMain.beginWindowDrag(windowData.address, workspaceId);
        }
        onPositionChanged: function(mouse) {
            if (!isDragging)
                return ;

            var deltaX = mouse.x - pressX;
            var deltaY = mouse.y - pressY;
            if (Math.abs(deltaX) + Math.abs(deltaY) > 4)
                movedDuringPress = true;

            dragX = baseX + deltaX;
            dragY = baseY + deltaY;
            if (scene && pluginMain) {
                var centerX = dragX + width / 2;
                var centerY = dragY + height / 2;
                var targetWorkspace = scene.workspaceAt(centerX, centerY);
                if (targetWorkspace > 0)
                    pluginMain.setDragTarget(targetWorkspace);

            }
        }
        onReleased: {
            if (!pluginMain)
                return ;

            if (movedDuringPress) {
                pluginMain.finishWindowDrag();
            } else {
                pluginMain.resetDragState();
                pluginMain.focusWindow(windowData);
            }
            isDragging = false;
            movedDuringPress = false;
            dragX = baseX;
            dragY = baseY;
        }
        onCanceled: {
            if (pluginMain)
                pluginMain.resetDragState();

            isDragging = false;
            movedDuringPress = false;
            dragX = baseX;
            dragY = baseY;
        }
    }

    Behavior on x {
        enabled: !isDragging

        NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutCubic
        }

    }

    Behavior on y {
        enabled: !isDragging

        NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutCubic
        }

    }

}
