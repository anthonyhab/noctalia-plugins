import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Services.Power
import qs.Widgets

Item {
    // 20px padding each side

    id: root

    required property var pluginMain
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: pluginMain.gridRows * pluginMain.gridColumns
    readonly property bool isViewingSpecialWorkspace: (monitor.activeWorkspace && monitor.activeWorkspace.id) < 0
    readonly property int workspaceGroup: isViewingSpecialWorkspace ? 0 : Math.floor((((monitor.activeWorkspace && monitor.activeWorkspace.id) || 1) - 1) / workspacesShown)
    readonly property var specialWorkspaces: {
        if (!pluginMain.showScratchpadWorkspaces)
            return [];

        var byName = {
        };
        var workspaceList = pluginMain.workspaces || [];
        for (var i = 0; i < workspaceList.length; i++) {
            var ws = workspaceList[i];
            if (!ws)
                continue;

            var rawName = ws.name || "";
            var isSpecial = (ws.id < 0) || (rawName && rawName.toString().startsWith("special:")) || rawName === "special";
            if (!isSpecial)
                continue;

            var normalizedName = normalizeSpecialName(rawName);
            if (!byName[normalizedName])
                byName[normalizedName] = {
                    "id": ws.id,
                    "rawName": rawName,
                    "name": normalizedName,
                    "windows": []
                };

        }
        // Fallback: include any special workspace currently containing windows, even if not in `hyprctl workspaces`.
        for (var addr in windowByAddress) {
            var win = windowByAddress[addr];
            if (win && win.workspace && win.workspace.id < 0) {
                var rawWinName = win.workspace.name || "";
                var normalizedWinName = normalizeSpecialName(rawWinName);
                if (!byName[normalizedWinName])
                    byName[normalizedWinName] = {
                        "id": win.workspace.id,
                        "rawName": rawWinName,
                        "name": normalizedWinName,
                        "windows": []
                    };

            }
        }
        // Attach windows to each special workspace.
        for (var addr2 in windowByAddress) {
            var win2 = windowByAddress[addr2];
            if (win2 && win2.workspace && win2.workspace.id < 0) {
                var rawWinName2 = win2.workspace.name || "";
                var normalizedWinName2 = normalizeSpecialName(rawWinName2);
                if (byName[normalizedWinName2])
                    byName[normalizedWinName2].windows.push(win2);

            }
        }
        var result = [];
        for (var key in byName) result.push(byName[key])
        result.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
        return result;
    }
    readonly property int reservedSpecialSlots: {
        if (!pluginMain.showScratchpadWorkspaces)
            return 0;

        var reserved = Math.min(root.specialWorkspaces.length, root.workspacesShown);
        reserved = Math.min(reserved, Math.max(0, root.workspacesShown - 1));
        return reserved;
    }
    // Baseline overflow behavior: only show the first N special workspaces (A→Z) that fit.
    // Extension point: page/scroll `visibleSpecialWorkspaces` by applying an offset.
    readonly property var visibleSpecialWorkspaces: root.specialWorkspaces.slice(0, root.reservedSpecialSlots)
    readonly property int groupFirstWorkspaceId: root.workspaceGroup * root.workspacesShown + 1
    readonly property int groupLastWorkspaceId: root.groupFirstWorkspaceId + root.workspacesShown - 1
    readonly property int lastNumericWorkspaceId: root.groupLastWorkspaceId - root.reservedSpecialSlots
    property bool monitorIsFocused: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) == monitor.name
    property var windows: pluginMain.windowList
    property var windowByAddress: pluginMain.windowByAddress
    property var windowAddresses: pluginMain.addresses
    property var monitorData: pluginMain.monitors.find(function(m) {
        return m.id === (root.monitor && root.monitor.id);
    })
    property real cellScale: pluginMain.gridScale
    // === FIT-TO-SCREEN LOGIC ===
    // Available space calculation (accounting for margins based on position)
    readonly property real marginXL: Style.marginXL
    readonly property real marginM: Style.marginM
    readonly property real barAwareMargin: {
        // Get bar info from parent context (passed via property or calculated)
        var barHeight = Style.getBarHeightForScreen(panelWindow.screen.name);
        var barPos = Commons.Settings.getBarPositionForScreen(panelWindow.screen.name);
        var pos = pluginMain.overviewPosition;
        if (pos === "top" && barPos === "top")
            return marginXL + barHeight + marginM;

        if (pos === "bottom" && barPos === "bottom")
            return marginXL + barHeight + marginM;

        return marginXL;
    }
    readonly property real availableWidth: (monitorData && monitorData.transform % 2 === 1) ? (monitor.height / monitor.scale) - barAwareMargin * 2 : (monitor.width / monitor.scale) - barAwareMargin * 2
    readonly property real availableHeight: (monitorData && monitorData.transform % 2 === 1) ? (monitor.width / monitor.scale) - barAwareMargin * 2 : (monitor.height / monitor.scale) - barAwareMargin * 2
    // Grid's natural size (without fit scaling)
    readonly property real gridNaturalWidth: pluginMain.gridColumns * workspaceImplicitWidth + (pluginMain.gridColumns - 1) * workspaceSpacing + 40
    // 20px padding each side
    readonly property real gridNaturalHeight: {
        var visibleRows = pluginMain.hideEmptyRows && rowsWithContent ? rowsWithContent.size : pluginMain.gridRows;
        if (visibleRows === 0)
            visibleRows = 1;

        // At least one row
        return visibleRows * workspaceImplicitHeight + (visibleRows - 1) * workspaceSpacing + 40;
    }
    // Fit scale to ensure grid stays on screen (never upscale, only downscale if needed)
    readonly property real fitScale: Math.min(1, Math.min(availableWidth / Math.max(1, gridNaturalWidth), availableHeight / Math.max(1, gridNaturalHeight)))
    // Workspace cell dimensions (accounting for rotated monitors)
    property real workspaceImplicitWidth: (monitorData && monitorData.transform % 2 === 1) ? ((monitor.height / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[0]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[2]) || 0)) * root.cellScale) : ((monitor.width / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[0]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[2]) || 0)) * root.cellScale)
    property real workspaceImplicitHeight: (monitorData && monitorData.transform % 2 === 1) ? ((monitor.width / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[1]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[3]) || 0)) * root.cellScale) : ((monitor.height / monitor.scale - ((monitorData && monitorData.reserved && monitorData.reserved[1]) || 0) - ((monitorData && monitorData.reserved && monitorData.reserved[3]) || 0)) * root.cellScale)
    // Z-ordering
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5
    // Drag state
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property var draggingTargetSpecial: null // For special workspace drag targets
    // Rows that have windows or contain the active workspace slot.
    property var rowsWithContent: {
        if (!pluginMain.hideEmptyRows)
            return null;

        var rows = new Set();
        var groupFirst = root.groupFirstWorkspaceId;
        var groupLast = root.groupLastWorkspaceId;
        var activeValue = root.getActiveWorkspaceValueForGrid();
        if (activeValue !== null && activeValue >= groupFirst && activeValue <= groupLast) {
            var activeInGroup = activeValue - (root.workspaceGroup * root.workspacesShown);
            rows.add(Math.floor((activeInGroup - 1) / pluginMain.gridColumns));
        }
        for (var addr in windowByAddress) {
            var win = windowByAddress[addr];
            var effectiveValue = root.getEffectiveWorkspaceValueForWindow(win);
            if (effectiveValue === null)
                continue;

            if (effectiveValue < groupFirst || effectiveValue > groupLast)
                continue;

            var inGroup = effectiveValue - (root.workspaceGroup * root.workspacesShown);
            var rowIndex = Math.floor((inGroup - 1) / pluginMain.gridColumns);
            rows.add(rowIndex);
        }
        return rows;
    }

    // === SPECIAL WORKSPACES ===
    // We discover special workspaces from `hyprctl workspaces -j` (pluginMain.workspaces)
    // so they appear even when empty.
    function normalizeSpecialName(wsName) {
        var name = (wsName || "").toString().trim();
        if (name.startsWith("special:"))
            name = name.slice("special:".length);

        name = name.trim();
        return name.length > 0 ? name : "special";
    }

    // Get label for a special workspace (first letter of first window's class/title, or first letter of name)
    function getSpecialWorkspaceLabel(specialWs) {
        if (!specialWs || !specialWs.name)
            return "S";

        if (!specialWs.windows || specialWs.windows.length === 0)
            return specialWs.name.charAt(0).toUpperCase();

        var firstWin = specialWs.windows[0] || {
        };
        var cls = firstWin.class || "";
        var title = firstWin.title || "";
        var labelSource = cls.length > 0 ? cls : title;
        if (labelSource.length > 0)
            return labelSource.charAt(0).toUpperCase();

        return specialWs.name.charAt(0).toUpperCase();
    }

    function getVisibleSpecialWorkspaceIndex(normalizedName) {
        if (!normalizedName)
            return -1;

        for (var i = 0; i < root.visibleSpecialWorkspaces.length; i++) {
            if (root.visibleSpecialWorkspaces[i].name === normalizedName)
                return i;

        }
        return -1;
    }

    function getEffectiveWorkspaceValueForWindow(windowData) {
        if (!windowData || !windowData.workspace)
            return null;

        var wsId = windowData.workspace.id;
        if (wsId < 0) {
            if (root.reservedSpecialSlots <= 0)
                return null;

            var normalizedName = normalizeSpecialName(windowData.workspace.name || "");
            var idx = getVisibleSpecialWorkspaceIndex(normalizedName);
            if (idx < 0)
                return null;

            return root.lastNumericWorkspaceId + 1 + idx;
        }
        if (wsId < root.groupFirstWorkspaceId || wsId > root.lastNumericWorkspaceId)
            return null;

        return wsId;
    }

    function getActiveWorkspaceValueForGrid() {
        if (!monitor || !monitor.activeWorkspace)
            return null;

        var ws = monitor.activeWorkspace;
        if (ws.id < 0) {
            if (root.reservedSpecialSlots <= 0)
                return null;

            var normalizedName = normalizeSpecialName(ws.name || "");
            var idx = getVisibleSpecialWorkspaceIndex(normalizedName);
            if (idx >= 0)
                return root.lastNumericWorkspaceId + 1 + idx;

            // Special workspace not visible due to overflow: clamp indicator to last slot.
            return root.groupLastWorkspaceId;
        }
        if (ws.id < root.groupFirstWorkspaceId || ws.id > root.lastNumericWorkspaceId)
            return null;

        return ws.id;
    }

    function getVisualYOffset(rowIndex) {
        if (!pluginMain.hideEmptyRows)
            return rowIndex * (root.workspaceImplicitHeight + root.workspaceSpacing);

        var visualIndex = 0;
        for (var i = 0; i < rowIndex; i++) {
            if (root.rowsWithContent && root.rowsWithContent.has(i))
                visualIndex++;

        }
        return visualIndex * (root.workspaceImplicitHeight + root.workspaceSpacing);
    }

    // Update pluginMain with the minimum fit scale across all screens (for Settings UI warning)
    onFitScaleChanged: {
        if (pluginMain && pluginMain.reportFitScale)
            pluginMain.reportFitScale(fitScale);

    }
    implicitWidth: (overviewBackground.implicitWidth + 20) * fitScale
    implicitHeight: (overviewBackground.implicitHeight + 20) * fitScale

    // Scaled container for fit-to-screen
    Item {
        id: scaledContainer

        anchors.centerIn: parent
        width: overviewBackground.implicitWidth + 20
        height: overviewBackground.implicitHeight + 20
        scale: root.fitScale

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
                        property bool rowVisible: !pluginMain.hideEmptyRows || (root.rowsWithContent && root.rowsWithContent.has(rowIndex))

                        spacing: workspaceSpacing
                        visible: rowVisible

                        Repeater {
                            model: pluginMain.gridColumns

                            delegate: Rectangle {
                                id: workspace

                                property int colIndex: index
                                property int workspaceValue: root.workspaceGroup * root.workspacesShown + rowIndex * pluginMain.gridColumns + colIndex + 1
                                property bool isSpecialSlot: root.reservedSpecialSlots > 0 && workspaceValue > root.lastNumericWorkspaceId
                                property int specialIndex: isSpecialSlot ? (workspaceValue - (root.lastNumericWorkspaceId + 1)) : -1
                                property var specialWorkspace: (isSpecialSlot && specialIndex >= 0 && specialIndex < root.visibleSpecialWorkspaces.length) ? root.visibleSpecialWorkspaces[specialIndex] : null
                                property string cellLabel: isSpecialSlot && specialWorkspace ? root.getSpecialWorkspaceLabel(specialWorkspace) : ("" + workspaceValue)
                                property bool hoveredWhileDragging: false

                                implicitWidth: root.workspaceImplicitWidth
                                implicitHeight: root.workspaceImplicitHeight
                                color: hoveredWhileDragging ? Qt.lighter(Color.mSurfaceVariant, 1.05) : Color.mSurfaceVariant // Lighter "card" background
                                // Use scaled screen radius for the workspace preview
                                radius: Style.screenRadius * root.cellScale
                                border.width: Style.borderS
                                border.color: hoveredWhileDragging ? Qt.lighter(Color.mSecondary, 1.1) : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.2)

                                // Workspace number / special label
                                Text {
                                    anchors.centerIn: parent
                                    text: workspace.cellLabel
                                    font.family: Settings.data.ui.fontDefault
                                    font.pixelSize: 250 * root.cellScale * ((monitor && monitor.scale) || 1)
                                    font.weight: Style.fontWeightSemiBold
                                    color: workspace.isSpecialSlot ? Color.mSecondary : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.2)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (root.draggingTargetWorkspace !== -1 || root.draggingTargetSpecial)
                                            return ;

                                        pluginMain.close();
                                        if (workspace.isSpecialSlot && workspace.specialWorkspace)
                                            Hyprland.dispatch("togglespecialworkspace " + workspace.specialWorkspace.name);
                                        else
                                            Hyprland.dispatch("workspace " + workspace.workspaceValue);
                                    }
                                }

                                // Drop target for drag-and-drop
                                DropArea {
                                    anchors.fill: parent
                                    onEntered: {
                                        if (workspace.isSpecialSlot) {
                                            root.draggingTargetWorkspace = -1;
                                            root.draggingTargetSpecial = workspace.specialWorkspace;
                                            if (!root.draggingTargetSpecial)
                                                return ;

                                        } else {
                                            root.draggingTargetWorkspace = workspace.workspaceValue;
                                            root.draggingTargetSpecial = null;
                                            if (root.draggingFromWorkspace == root.draggingTargetWorkspace)
                                                return ;

                                        }
                                        workspace.hoveredWhileDragging = true;
                                    }
                                    onExited: {
                                        workspace.hoveredWhileDragging = false;
                                        if (workspace.isSpecialSlot) {
                                            if (root.draggingTargetSpecial === workspace.specialWorkspace)
                                                root.draggingTargetSpecial = null;

                                        } else {
                                            if (root.draggingTargetWorkspace == workspace.workspaceValue)
                                                root.draggingTargetWorkspace = -1;

                                        }
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
                                var address = "0x" + toplevel.HyprlandToplevel.address;
                                var win = root.windowByAddress[address];
                                if (!win)
                                    return false;

                                var effectiveValue = root.getEffectiveWorkspaceValueForWindow(win);
                                if (effectiveValue === null)
                                    return false;

                                return effectiveValue >= root.groupFirstWorkspaceId && effectiveValue <= root.groupLastWorkspaceId;
                            }).sort(function(a, b) {
                                var addrA = "0x" + a.HyprlandToplevel.address;
                                var addrB = "0x" + b.HyprlandToplevel.address;
                                var winA = root.windowByAddress[addrA];
                                var winB = root.windowByAddress[addrB];
                                // Pinned windows always on top
                                if ((winA && winA.pinned) !== (winB && winB.pinned))
                                    return (winA && winA.pinned) ? 1 : -1;

                                // Floating windows above tiled
                                if ((winA && winA.floating) !== (winB && winB.floating))
                                    return (winA && winA.floating) ? 1 : -1;

                                // Sort by focus history (lower = more recent = higher)
                                return ((winB && winB.focusHistoryID) || 0) - ((winA && winA.focusHistoryID) || 0);
                            });
                        }
                    }

                    delegate: WindowPreview {
                        id: windowDelegate

                        required property var modelData
                        required property int index
                        property int monitorId: ((windowData && windowData.monitor) || -1)
                        property var windowMonitor: pluginMain.monitors.find(function(m) {
                            return m.id === monitorId;
                        })
                        property var address: "0x" + modelData.HyprlandToplevel.address
                        // Scale relative to source monitor
                        property real sourceMonitorWidth: (windowMonitor && windowMonitor.transform % 2 === 1) ? ((windowMonitor && windowMonitor.height) || 1920) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[0]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[2]) || 0) : ((windowMonitor && windowMonitor.width) || 1920) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[0]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[2]) || 0)
                        property real sourceMonitorHeight: (windowMonitor && windowMonitor.transform % 2 === 1) ? ((windowMonitor && windowMonitor.width) || 1080) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[1]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[3]) || 0) : ((windowMonitor && windowMonitor.height) || 1080) / ((windowMonitor && windowMonitor.scale) || 1) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[1]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[3]) || 0)
                        property bool atInitPosition: (initX == x && initY == y)
                        property int rawWorkspaceId: (windowData && windowData.workspace && windowData.workspace.id) || 1
                        property int effectiveWorkspaceValue: root.getEffectiveWorkspaceValueForWindow(windowData) || root.groupFirstWorkspaceId
                        property int workspaceInGroup: effectiveWorkspaceValue - (root.workspaceGroup * root.workspacesShown)
                        // Position calculation
                        property int workspaceColIndex: Math.max(0, (workspaceInGroup - 1) % pluginMain.gridColumns)
                        property int workspaceRowIndex: Math.max(0, Math.floor((workspaceInGroup - 1) / pluginMain.gridColumns))

                        pluginMain: root.pluginMain
                        windowData: root.windowByAddress[address]
                        toplevel: modelData
                        monitorData: windowMonitor
                        windowScale: Math.min(root.workspaceImplicitWidth / sourceMonitorWidth, root.workspaceImplicitHeight / sourceMonitorHeight)
                        availableWorkspaceWidth: root.workspaceImplicitWidth
                        availableWorkspaceHeight: root.workspaceImplicitHeight
                        widgetMonitorId: root.monitor.id
                        overviewOpen: root.pluginMain.overviewOpen
                        // Position within the grid slot
                        xOffset: (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColIndex
                        yOffset: root.getVisualYOffset(workspaceRowIndex)
                        z: atInitPosition ? (root.windowZ + index) : root.windowDraggingZ
                        Drag.hotSpot.x: targetWindowWidth / 2
                        Drag.hotSpot.y: targetWindowHeight / 2

                        Timer {
                            id: updateWindowPosition

                            interval: 150
                            repeat: false
                            running: false
                            onTriggered: {
                                windowDelegate.x = Math.round(Math.max((((windowDelegate.windowData && windowDelegate.windowData.at[0]) || 0) - ((windowDelegate.windowMonitor && windowDelegate.windowMonitor.x) || 0) - ((windowDelegate.monitorData && windowDelegate.monitorData.reserved && windowDelegate.monitorData.reserved[0]) || 0)) * windowDelegate.windowScale, 0) + windowDelegate.xOffset);
                                windowDelegate.y = Math.round(Math.max((((windowDelegate.windowData && windowDelegate.windowData.at[1]) || 0) - ((windowDelegate.windowMonitor && windowDelegate.windowMonitor.y) || 0) - ((windowDelegate.monitorData && windowDelegate.monitorData.reserved && windowDelegate.monitorData.reserved[1]) || 0)) * windowDelegate.windowScale, 0) + windowDelegate.yOffset);
                            }
                        }

                        MouseArea {
                            id: dragArea

                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: windowDelegate.hovered = true
                            onExited: windowDelegate.hovered = false
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            drag.target: parent
                            onPressed: (mouse) => {
                                root.draggingFromWorkspace = ((windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1);
                                windowDelegate.pressed = true;
                                windowDelegate.Drag.active = true;
                                windowDelegate.Drag.source = windowDelegate;
                                windowDelegate.Drag.hotSpot.x = mouse.x;
                                windowDelegate.Drag.hotSpot.y = mouse.y;
                            }
                            onReleased: {
                                var targetWorkspace = root.draggingTargetWorkspace;
                                var targetSpecial = root.draggingTargetSpecial;
                                windowDelegate.pressed = false;
                                windowDelegate.Drag.active = false;
                                root.draggingFromWorkspace = -1;
                                root.draggingTargetSpecial = null;
                                var currentWsId = (windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1;
                                var currentWsName = (windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.name) || "";
                                var currentSpecialName = root.normalizeSpecialName(currentWsName);
                                if (targetSpecial) {
                                    // Dropped onto a special workspace slot
                                    if (currentWsId >= 0 || currentSpecialName !== targetSpecial.name) {
                                        Hyprland.dispatch("movetoworkspacesilent special:" + targetSpecial.name + ", address:" + (windowDelegate.windowData && windowDelegate.windowData.address));
                                        updateWindowPosition.restart();
                                    } else {
                                        windowDelegate.x = windowDelegate.initX;
                                        windowDelegate.y = windowDelegate.initY;
                                    }
                                } else if (targetWorkspace !== -1 && targetWorkspace !== currentWsId) {
                                    // Dropped onto a regular workspace
                                    Hyprland.dispatch("movetoworkspacesilent " + targetWorkspace + ", address:" + (windowDelegate.windowData && windowDelegate.windowData.address));
                                    updateWindowPosition.restart();
                                } else {
                                    windowDelegate.x = windowDelegate.initX;
                                    windowDelegate.y = windowDelegate.initY;
                                }
                            }
                            onClicked: (event) => {
                                if (!windowDelegate.windowData)
                                    return ;

                                if (event.button === Qt.LeftButton) {
                                    root.pluginMain.close();
                                    Hyprland.dispatch("focuswindow address:" + windowDelegate.windowData.address);
                                    event.accepted = true;
                                } else if (event.button === Qt.MiddleButton) {
                                    Hyprland.dispatch("closewindow address:" + windowDelegate.windowData.address);
                                    event.accepted = true;
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
                                    text: ((windowDelegate.windowData && windowDelegate.windowData.title) || (pluginMain.pluginApi && pluginMain.pluginApi.tr("overview.tooltip.unknown") || "Unknown")) + "\n[" + ((windowDelegate.windowData && windowDelegate.windowData.class) || (pluginMain.pluginApi && pluginMain.pluginApi.tr("overview.tooltip.unknown-class") || "unknown")) + "]" + (windowDelegate.windowData && windowDelegate.windowData.xwayland ? (" [" + (pluginMain.pluginApi && pluginMain.pluginApi.tr("overview.tooltip.xwayland") || "XWayland") + "]") : "")
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

                    property var activeWorkspaceValue: root.getActiveWorkspaceValueForGrid()
                    property bool indicatorVisible: activeWorkspaceValue !== null
                    property int activeWorkspaceInGroup: indicatorVisible ? (activeWorkspaceValue - (root.workspaceGroup * root.workspacesShown)) : 1
                    property int activeWorkspaceRowIndex: Math.floor((activeWorkspaceInGroup - 1) / pluginMain.gridColumns)
                    property int activeWorkspaceColIndex: (activeWorkspaceInGroup - 1) % pluginMain.gridColumns

                    visible: indicatorVisible
                    x: (root.workspaceImplicitWidth + root.workspaceSpacing) * activeWorkspaceColIndex
                    y: root.getVisualYOffset(activeWorkspaceRowIndex)
                    z: root.windowZ
                    width: root.workspaceImplicitWidth
                    height: root.workspaceImplicitHeight
                    color: "transparent"
                    radius: Style.screenRadius * root.cellScale
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

            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: Style.shadowBlurMax
                shadowBlur: Style.shadowBlur * 1.5
                shadowOpacity: Style.shadowOpacity
                shadowColor: "black"
                shadowHorizontalOffset: Settings.data.general.shadowOffsetX
                shadowVerticalOffset: Settings.data.general.shadowOffsetY
            }

        }

    }

}
