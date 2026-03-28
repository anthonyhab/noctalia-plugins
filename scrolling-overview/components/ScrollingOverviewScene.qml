import "."
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

Item {
    id: scene

    required property var pluginMain
    required property var panelWindow
    readonly property var monitor: panelWindow.monitor
    readonly property var monitorData: findMonitorData()
    readonly property int reservedLeft: (monitorData && monitorData.reserved && monitorData.reserved[0]) || 0
    readonly property int reservedTop: (monitorData && monitorData.reserved && monitorData.reserved[1]) || 0
    readonly property int reservedRight: (monitorData && monitorData.reserved && monitorData.reserved[2]) || 0
    readonly property int reservedBottom: (monitorData && monitorData.reserved && monitorData.reserved[3]) || 0
    readonly property real monitorScale: (monitorData && monitorData.scale) || 1
    readonly property real monitorLogicalWidth: ((monitorData && monitorData.width) || panelWindow.width) / monitorScale
    readonly property real monitorLogicalHeight: ((monitorData && monitorData.height) || panelWindow.height) / monitorScale
    readonly property real availableMonitorWidth: Math.max(1, monitorLogicalWidth - reservedLeft - reservedRight)
    readonly property real availableMonitorHeight: Math.max(1, monitorLogicalHeight - reservedTop - reservedBottom)
    readonly property int workspacesShown: Math.max(1, pluginMain.rows * pluginMain.columns)
    readonly property int groupFirstWorkspaceId: Math.max(1, Math.floor((pluginMain.activeWorkspaceId - 1) / workspacesShown) * workspacesShown + 1)
    readonly property int groupLastWorkspaceId: groupFirstWorkspaceId + workspacesShown - 1
    readonly property real workspaceWidth: availableMonitorWidth * pluginMain.scale
    readonly property real workspaceHeight: availableMonitorHeight * pluginMain.scale
    readonly property real workspaceSpacing: pluginMain.workspaceSpacing
    readonly property real gridWidth: pluginMain.columns * workspaceWidth + (pluginMain.columns - 1) * workspaceSpacing
    readonly property real gridHeight: pluginMain.rows * workspaceHeight + (pluginMain.rows - 1) * workspaceSpacing

    function findMonitorData() {
        if (!monitor)
            return null;

        var list = pluginMain.monitors || [];
        for (var i = 0; i < list.length; ++i) {
            var entry = list[i];
            if (entry && entry.id === monitor.id)
                return entry;

        }
        return null;
    }

    function workspaceIndexFor(workspaceId) {
        return workspaceId - groupFirstWorkspaceId;
    }

    function workspaceRectFor(workspaceId) {
        var index = workspaceIndexFor(workspaceId);
        if (index < 0 || index >= workspacesShown)
            return {
            "valid": false,
            "x": 0,
            "y": 0,
            "w": 0,
            "h": 0,
            "row": -1,
            "column": -1
        };

        var row = Math.floor(index / pluginMain.columns);
        var column = index % pluginMain.columns;
        return {
            "valid": true,
            "x": column * (workspaceWidth + workspaceSpacing),
            "y": row * (workspaceHeight + workspaceSpacing),
            "w": workspaceWidth,
            "h": workspaceHeight,
            "row": row,
            "column": column
        };
    }

    function workspaceAt(x, y) {
        for (var i = 0; i < workspacesShown; ++i) {
            var workspaceId = groupFirstWorkspaceId + i;
            var rect = workspaceRectFor(workspaceId);
            if (!rect.valid)
                continue;

            if (x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h)
                return workspaceId;

        }
        return -1;
    }

    function ensureWorkspaceVisible(workspaceId) {
        var rect = workspaceRectFor(workspaceId);
        if (!rect.valid)
            return ;

        var desiredY = rect.y - ((workspaceFlick.height - rect.h) / 2);
        var maxY = Math.max(0, workspaceFlick.contentHeight - workspaceFlick.height);
        workspaceFlick.contentY = Math.max(0, Math.min(maxY, desiredY));
    }

    Component.onCompleted: {
        ensureWorkspaceVisible(pluginMain.activeWorkspaceId);
    }

    Connections {
        function onActiveWorkspaceIdChanged() {
            scene.ensureWorkspaceVisible(pluginMain.activeWorkspaceId);
        }

        function onRowsChanged() {
            Qt.callLater(function() {
                scene.ensureWorkspaceVisible(pluginMain.activeWorkspaceId);
            });
        }

        function onColumnsChanged() {
            Qt.callLater(function() {
                scene.ensureWorkspaceVisible(pluginMain.activeWorkspaceId);
            });
        }

        target: pluginMain
    }

    NDropShadow {
        source: workspaceShell
        anchors.fill: workspaceShell
    }

    Rectangle {
        id: workspaceShell

        anchors.fill: parent
        anchors.margins: Style.marginM
        radius: Style.radiusM
        color: Qt.alpha(Color.mSurfaceVariant, 0.72)
        border.color: Qt.alpha(Color.mOutline, 0.85)
        border.width: Style.borderS
    }

    Flickable {
        id: workspaceFlick

        anchors.fill: workspaceShell
        anchors.margins: Style.marginL
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: Math.max(stage.width, width)
        contentHeight: Math.max(stage.height, height)

        Item {
            id: stage

            width: gridWidth
            height: gridHeight
            x: Math.round((workspaceFlick.width - width) / 2)

            Repeater {
                model: scene.workspacesShown

                delegate: WorkspaceSlot {
                    property int slotWorkspaceId: scene.groupFirstWorkspaceId + index
                    property var rectData: scene.workspaceRectFor(slotWorkspaceId)

                    x: rectData.x
                    y: rectData.y
                    workspaceWidth: rectData.w
                    workspaceHeight: rectData.h
                    pluginMain: scene.pluginMain
                    workspaceId: slotWorkspaceId
                    monitorId: scene.monitorData ? scene.monitorData.id : null
                    isActive: pluginMain.activeWorkspaceId === slotWorkspaceId
                    showLabel: pluginMain.showWorkspaceLabels
                }

            }

            Repeater {

                model: ScriptModel {
                    values: {
                        if (typeof ToplevelManager === "undefined" || !ToplevelManager.toplevels)
                            return [];

                        return ToplevelManager.toplevels.values.filter(function(toplevel) {
                            if (!toplevel || !toplevel.HyprlandToplevel || toplevel.HyprlandToplevel.address === undefined)
                                return false;

                            var address = "0x" + toplevel.HyprlandToplevel.address;
                            var win = pluginMain.windowByAddress[address];
                            if (!win || !win.workspace)
                                return false;

                            if (!pluginMain.includeSpecialWorkspaces && win.workspace.id < 1)
                                return false;

                            if (win.workspace.id < scene.groupFirstWorkspaceId || win.workspace.id > scene.groupLastWorkspaceId)
                                return false;

                            if (scene.monitorData && win.monitor !== scene.monitorData.id)
                                return false;

                            return true;
                        });
                    }
                }

                delegate: WindowTile {
                    required property var modelData
                    property string address: (modelData && modelData.HyprlandToplevel && modelData.HyprlandToplevel.address !== undefined) ? ("0x" + modelData.HyprlandToplevel.address) : ""

                    pluginMain: scene.pluginMain
                    scene: scene
                    monitorData: scene.monitorData
                    toplevel: modelData
                    windowData: pluginMain.windowByAddress[address]
                }

            }

        }

        Behavior on contentY {
            NumberAnimation {
                duration: Style.animationFast
                easing.type: Easing.OutCubic
            }

        }

    }

}
