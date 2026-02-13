import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Effects
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Services.Power
import qs.Widgets

Item {
    id: root
    required property var pluginMain
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: pluginMain.gridRows * pluginMain.gridColumns
    readonly property int workspaceGroup: Math.floor((((monitor.activeWorkspace && monitor.activeWorkspace.id) || 1) - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) == monitor.name
    property var windows: pluginMain.windowList
    property var windowByAddress: pluginMain.windowByAddress
    property var windowAddresses: pluginMain.addresses
    property var monitorData: pluginMain.monitors.find(function(m) { return m.id === (root.monitor && root.monitor.id) })
    property real scale: pluginMain.gridScale

    // Workspace cell dimensions (accounting for rotated monitors)
    property real workspaceImplicitWidth: (monitorData && monitorData.transform % 2 === 1)
        ? ((monitor.height / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[0]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[2]) || 0)) * root.scale)
        : ((monitor.width / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[0]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[2]) || 0)) * root.scale)
    property real workspaceImplicitHeight: (monitorData && monitorData.transform % 2 === 1)
        ? ((monitor.width / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[1]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[3]) || 0)) * root.scale)
        : ((monitor.height / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[1]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[3]) || 0)) * root.scale)

    // Z-ordering
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    // Drag state
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    // Rows that have windows or contain the active workspace
    property var rowsWithContent: {
        if (!pluginMain.hideEmptyRows) return null

        var rows = new Set()
        var firstWorkspace = root.workspaceGroup * root.workspacesShown + 1
        var lastWorkspace = (root.workspaceGroup + 1) * root.workspacesShown

        // Always show the row with the current workspace
        var currentWorkspace = (monitor.activeWorkspace && monitor.activeWorkspace.id) || 1
        if (currentWorkspace >= firstWorkspace && currentWorkspace <= lastWorkspace) {
            rows.add(Math.floor((currentWorkspace - firstWorkspace) / pluginMain.gridColumns))
        }

        // Add rows that have windows
        for (var addr in windowByAddress) {
            var win = windowByAddress[addr]
            var wsId = win && win.workspace && win.workspace.id
            if (wsId >= firstWorkspace && wsId <= lastWorkspace) {
                var rowIndex = Math.floor((wsId - firstWorkspace) / pluginMain.gridColumns)
                rows.add(rowIndex)
            }
        }

        return rows
    }

    function getVisualYOffset(rowIndex) {
        if (!pluginMain.hideEmptyRows) return rowIndex * (root.workspaceImplicitHeight + root.workspaceSpacing)

        var visualIndex = 0
        for (var i = 0; i < rowIndex; i++) {
            if (root.rowsWithContent && root.rowsWithContent.has(i)) {
                visualIndex++
            }
        }
        return visualIndex * (root.workspaceImplicitHeight + root.workspaceSpacing)
    }

    implicitWidth: overviewBackground.implicitWidth + 20
    implicitHeight: overviewBackground.implicitHeight + 20

    // Background (with Shadow)
    Rectangle {
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: 10

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        // Use standard panel radius
        radius: Style.radiusL
        color: Qt.alpha(Color.mSurface, Settings.data.ui.panelBackgroundOpacity)
        border.width: Style.borderM
        border.color: Color.mOutline

        // Shadow using MultiEffect
        layer.enabled: Settings.data.general.enableShadows && !PowerProfileService.noctaliaPerformanceMode
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: Style.shadowBlurMax
            shadowBlur: Style.shadowBlur * 1.5
            shadowOpacity: Style.shadowOpacity
            shadowColor: "black"
            shadowHorizontalOffset: Settings.data.general.shadowOffsetX
            shadowVerticalOffset: Settings.data.general.shadowOffsetY
        }

        // === WORKSPACE GRID ===
        ColumnLayout {
            id: workspaceColumnLayout
            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing

            Repeater {
                model: pluginMain.gridRows

                delegate: RowLayout {
                    id: row
                    property int rowIndex: index
                    spacing: workspaceSpacing
                    visible: !pluginMain.hideEmptyRows ||
                             (root.rowsWithContent && root.rowsWithContent.has(rowIndex))
                    height: visible ? implicitHeight : 0

                    Repeater {
                        model: pluginMain.gridColumns

                        Rectangle {
                            id: workspace
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * root.workspacesShown + rowIndex * pluginMain.gridColumns + colIndex + 1
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: hoveredWhileDragging
                                ? Qt.lighter(Color.mSurfaceVariant, 1.05)
                                : Color.mSurfaceVariant // Lighter "card" background
                            // Use scaled screen radius for the workspace preview
                            radius: Style.screenRadius * root.scale
                            border.width: Style.borderS
                            border.color: hoveredWhileDragging
                                ? Qt.lighter(Color.mSecondary, 1.1)
                                : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.2)

                            // Workspace number
                            Text {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font.family: Settings.data.ui.fontDefault
                                font.pixelSize: 250 * root.scale * ((monitor && monitor.scale) || 1)
                                font.weight: Style.fontWeightSemiBold
                                color: Qt.rgba(
                                    Color.mOnSurfaceVariant.r,
                                    Color.mOnSurfaceVariant.g,
                                    Color.mOnSurfaceVariant.b,
                                    0.2
                                )
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Click to switch workspace
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        pluginMain.close()
                                        Hyprland.dispatch("workspace " + workspace.workspaceValue)
                                    }
                                }
                            }

                            // Drop target for drag-and-drop
                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return
                                    workspace.hoveredWhileDragging = true
                                }
                                onExited: {
                                    workspace.hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue)
                                        root.draggingTargetWorkspace = -1
                                }
                            }
                        }
                    }
                }
            }
        }

        // === WINDOWS AND ACTIVE WORKSPACE INDICATOR ===
        Item {
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            // Window repeater
            Repeater {
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter(function(toplevel) {
                            var address = "0x" + toplevel.HyprlandToplevel.address
                            var win = root.windowByAddress[address]
                            var inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < (win && win.workspace && win.workspace.id) &&
                                                    (win && win.workspace && win.workspace.id) <= (root.workspaceGroup + 1) * root.workspacesShown)
                            return inWorkspaceGroup
                        }).sort(function(a, b) {
                            var addrA = "0x" + a.HyprlandToplevel.address
                            var addrB = "0x" + b.HyprlandToplevel.address
                            var winA = root.windowByAddress[addrA]
                            var winB = root.windowByAddress[addrB]

                            // Pinned windows always on top
                            if ((winA && winA.pinned) !== (winB && winB.pinned)) {
                                return (winA && winA.pinned) ? 1 : -1
                            }

                            // Floating windows above tiled
                            if ((winA && winA.floating) !== (winB && winB.floating)) {
                                return (winA && winA.floating) ? 1 : -1
                            }

                            // Sort by focus history (lower = more recent = higher)
                            return ((winB && winB.focusHistoryID) || 0) - ((winA && winA.focusHistoryID) || 0)
                        })
                    }
                }

                delegate: WindowPreview {
                    id: windowDelegate
                    required property var modelData
                    required property int index
                    property int monitorId: ((windowData && windowData.monitor) || -1)
                    property var windowMonitor: pluginMain.monitors.find(function(m) { return m.id === monitorId })
                    property var address: "0x" + modelData.HyprlandToplevel.address

                    pluginMain: root.pluginMain
                    windowData: root.windowByAddress[address]
                    toplevel: modelData
                    monitorData: windowMonitor

                    // Scale relative to source monitor
                    property real sourceMonitorWidth: (windowMonitor && windowMonitor.transform % 2 === 1)
                        ? ((windowMonitor && windowMonitor.height) || 1920) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[0]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[2]) || 0)
                        : ((windowMonitor && windowMonitor.width) || 1920) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[0]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[2]) || 0)
                    property real sourceMonitorHeight: (windowMonitor && windowMonitor.transform % 2 === 1)
                        ? ((windowMonitor && windowMonitor.width) || 1080) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[1]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[3]) || 0)
                        : ((windowMonitor && windowMonitor.height) || 1080) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[1]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[3]) || 0)

                    scale: Math.min(
                        root.workspaceImplicitWidth / sourceMonitorWidth,
                        root.workspaceImplicitHeight / sourceMonitorHeight
                    )

                    availableWorkspaceWidth: root.workspaceImplicitWidth
                    availableWorkspaceHeight: root.workspaceImplicitHeight
                    widgetMonitorId: root.monitor.id
                    overviewOpen: root.pluginMain.overviewOpen

                    property bool atInitPosition: (initX == x && initY == y)

                    property int workspaceColIndex: (((windowData && windowData.workspace && windowData.workspace.id) || 1) - 1) % pluginMain.gridColumns
                    property int workspaceRowIndex: Math.floor((((windowData && windowData.workspace && windowData.workspace.id) || 1) - 1) % root.workspacesShown / pluginMain.gridColumns)
                    xOffset: (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColIndex
                    yOffset: root.getVisualYOffset(workspaceRowIndex)

                    Timer {
                        id: updateWindowPosition
                        interval: 150
                        repeat: false
                        running: false
                        onTriggered: {
                            windowDelegate.x = Math.round(Math.max((((windowDelegate.windowData && windowDelegate.windowData.at[0]) || 0) - ((windowDelegate.windowMonitor && windowDelegate.windowMonitor.x) || 0) - ((windowDelegate.monitorData && windowDelegate.monitorData.reserved && windowDelegate.monitorData.reserved[0]) || 0)) * windowDelegate.scale, 0) + windowDelegate.xOffset)
                            windowDelegate.y = Math.round(Math.max((((windowDelegate.windowData && windowDelegate.windowData.at[1]) || 0) - ((windowDelegate.windowMonitor && windowDelegate.windowMonitor.y) || 0) - ((windowDelegate.monitorData && windowDelegate.monitorData.reserved && windowDelegate.monitorData.reserved[1]) || 0)) * windowDelegate.scale, 0) + windowDelegate.yOffset)
                        }
                    }

                    z: atInitPosition ? (root.windowZ + index) : root.windowDraggingZ
                    Drag.hotSpot.x: targetWindowWidth / 2
                    Drag.hotSpot.y: targetWindowHeight / 2

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: windowDelegate.hovered = true
                        onExited: windowDelegate.hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent

                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = ((windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1)
                            windowDelegate.pressed = true
                            windowDelegate.Drag.active = true
                            windowDelegate.Drag.source = windowDelegate
                            windowDelegate.Drag.hotSpot.x = mouse.x
                            windowDelegate.Drag.hotSpot.y = mouse.y
                        }

                        onReleased: {
                            var targetWorkspace = root.draggingTargetWorkspace
                            windowDelegate.pressed = false
                            windowDelegate.Drag.active = false
                            root.draggingFromWorkspace = -1
                            if (targetWorkspace !== -1 && targetWorkspace !== (windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id)) {
                                Hyprland.dispatch("movetoworkspacesilent " + targetWorkspace + ", address:" + (windowDelegate.windowData && windowDelegate.windowData.address))
                                updateWindowPosition.restart()
                            } else {
                                windowDelegate.x = windowDelegate.initX
                                windowDelegate.y = windowDelegate.initY
                            }
                        }

                        onClicked: (event) => {
                            if (!windowDelegate.windowData) return

                            if (event.button === Qt.LeftButton) {
                                root.pluginMain.close()
                                Hyprland.dispatch("focuswindow address:" + windowDelegate.windowData.address)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch("closewindow address:" + windowDelegate.windowData.address)
                                event.accepted = true
                            }
                        }

                        // Tooltip
                        Rectangle {
                            id: windowTooltip
                            visible: dragArea.containsMouse && !windowDelegate.Drag.active
                            x: (parent.width - width) / 2
                            y: parent.height + 4
                            z: 99999
                            width: tooltipText.implicitWidth + 12
                            height: tooltipText.implicitHeight + 8
                            radius: Style.radiusS
                            color: Color.mOnSurface

                            NText {
                                id: tooltipText
                                anchors.centerIn: parent
                                text: ((windowDelegate.windowData && windowDelegate.windowData.title) || (pluginMain.pluginApi && pluginMain.pluginApi.tr("overview.tooltip.unknown") || "Unknown")) +
                                      "\n[" + ((windowDelegate.windowData && windowDelegate.windowData.class) || (pluginMain.pluginApi && pluginMain.pluginApi.tr("overview.tooltip.unknown-class") || "unknown")) + "]" +
                                      (windowDelegate.windowData && windowDelegate.windowData.xwayland ? (" [" + (pluginMain.pluginApi && pluginMain.pluginApi.tr("overview.tooltip.xwayland") || "XWayland") + "]") : "")
                                color: Color.mSurface
                                pointSize: 11
                            }
                        }
                    }
                }
            }

            // === ACTIVE WORKSPACE INDICATOR ===
            Rectangle {
                id: focusedWorkspaceIndicator
                property int activeWorkspaceInGroup: ((monitor.activeWorkspace && monitor.activeWorkspace.id) || 1) - (root.workspaceGroup * root.workspacesShown)
                property int activeWorkspaceRowIndex: Math.floor((activeWorkspaceInGroup - 1) / pluginMain.gridColumns)
                property int activeWorkspaceColIndex: (activeWorkspaceInGroup - 1) % pluginMain.gridColumns
                x: (root.workspaceImplicitWidth + root.workspaceSpacing) * activeWorkspaceColIndex
                y: root.getVisualYOffset(activeWorkspaceRowIndex)
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                radius: Style.screenRadius * root.scale
                border.width: Style.borderL
                border.color: Color.mSecondary

                Behavior on x {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
