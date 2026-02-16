import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "components"
import qs.Commons
import qs.Commons as Commons

Item {
    // Check hideEmptyRows logic if needed.
    // This is complex because OverviewGrid calculates content based on windows.
    // Repplicating that here might be expensive.
    // For navigation, maybe we just iterate ALL valid slots in the grid and skip if hidden?
    // Simplification: Just include them all for now, or fetch from OverviewGrid if possible? No, can't access easily.
    // Let's just include all numeric IDs. If hideEmptyRows is on, we might jump to an empty one that is hidden?
    // Ideally we shouldn't.
    // Let's implement a simplified "hasContent" check here:
    // content = (activeWorkspace == wsId) OR (windows exist on wsId)

    id: root

    property var pluginApi: null
    // === OVERVIEW SETTINGS ===
    property int gridRows: getSetting("rows", 2)
    property int gridColumns: getSetting("columns", 5)
    property real gridScale: getSetting("scale", 0.16)
    property bool hideEmptyRows: getSetting("hideEmptyRows", true)
    property bool showScratchpadWorkspaces: getSetting("showScratchpadWorkspaces", false)
    property int gridSpacing: getSetting("gridSpacing", 0)
    property string overviewPosition: getSetting("position", "top")
    property int barMargin: getSetting("barMargin", 0)
    property bool useSlideAnimation: getSetting("useSlideAnimation", true)
    property int containerBorderWidth: getSetting("containerBorderWidth", -1)
    property int selectionBorderWidth: getSetting("selectionBorderWidth", -1)
    property string accentColorType: getSetting("accentColorType", "secondary")
    // === OVERVIEW STATE ===
    property bool overviewOpen: false
    // Track the last navigated index for smooth keyboard/mouse navigation
    // This is needed because activeWorkspace might not update immediately after dispatch
    property int lastNavigatedIndex: -1
    // Track the currently active special workspace name (for indicator)
    // This is needed because hyprctl activeworkspace may not report special workspaces correctly
    property string activeSpecialWorkspaceName: ""
    // === HYPRLAND DATA ===
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({
    })
    property var monitors: []
    property var activeWorkspace: null
    property var workspaces: []
    readonly property var specialWorkspaces: {
        if (!showScratchpadWorkspaces)
            return [];

        var byName = {
        };
        // From hyprctl workspaces
        var workspaceList = root.workspaces || [];
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
        // From windows (fallback for unlisted workspaces)
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
        // Attach windows
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

    // === SETTINGS HELPERS ===
    function getSetting(key, fallback) {
        if (!pluginApi)
            return fallback;

        try {
            var val = pluginApi.pluginSettings[key];
            if (val === undefined || val === null)
                val = pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings && pluginApi.manifest.metadata.defaultSettings[key];

            return (val === undefined || val === null) ? fallback : val;
        } catch (e) {
            return fallback;
        }
    }

    function toggle() {
        overviewOpen = !overviewOpen;
        if (overviewOpen) {
            lastNavigatedIndex = -1;
            activeSpecialWorkspaceName = "";
            updateAll();
        }
    }

    function open() {
        if (!overviewOpen) {
            overviewOpen = true;
            lastNavigatedIndex = -1;
            activeSpecialWorkspaceName = "";
            updateAll();
        }
    }

    function close() {
        overviewOpen = false;
        lastNavigatedIndex = -1;
        activeSpecialWorkspaceName = "";
    }

    function refresh() {
        gridRows = getSetting("rows", 2);
        gridColumns = getSetting("columns", 5);
        gridScale = getSetting("scale", 0.16);
        hideEmptyRows = getSetting("hideEmptyRows", true);
        showScratchpadWorkspaces = getSetting("showScratchpadWorkspaces", false);
        gridSpacing = getSetting("gridSpacing", 0);
        overviewPosition = getSetting("position", "top");
        barMargin = getSetting("barMargin", 0);
        useSlideAnimation = getSetting("useSlideAnimation", true);
        containerBorderWidth = getSetting("containerBorderWidth", -1);
        selectionBorderWidth = getSetting("selectionBorderWidth", -1);
        accentColorType = getSetting("accentColorType", "secondary");
    }

    function updateWindowList() {
        getClients.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getActiveWorkspace.running = true;
        getWorkspaces.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateWorkspaces();
    }

    // === SPECIAL WORKSPACE LOGIC ===
    function normalizeSpecialName(wsName) {
        var name = (wsName || "").toString().trim();
        if (name.startsWith("special:"))
            name = name.slice("special:".length);

        name = name.trim();
        return name.length > 0 ? name : "special";
    }

    function getVisibleWorkspaces(monitorId) {
        // Use pluginMain.activeWorkspace for consistency with OverviewGrid's getActiveWorkspaceValueForGrid()
        var workspacesPerGroup = gridRows * gridColumns;
        var currentWs = activeWorkspace;
        var currentId = (currentWs && currentWs.id) || 1;
        var currentGroup = 0;
        // If current is special, we need to find which group "owns" the view.
        // OverviewGrid uses logic: isViewingSpecial ? 0 : ...
        // So we default to group 0 when on a special workspace.
        if (currentId < 0)
            currentId = 1;

        currentGroup = Math.floor((currentId - 1) / workspacesPerGroup);
        var minWorkspaceId = currentGroup * workspacesPerGroup + 1;
        var visible = [];
        // Normal workspaces in group
        for (var i = 0; i < workspacesPerGroup; i++) {
            var wsId = minWorkspaceId + i;
            var maxNormalId = minWorkspaceId + workspacesPerGroup - 1;
            // Should we include this row?
            // Row index:
            var rowIndex = Math.floor(i / gridColumns);
            visible.push({
                "id": wsId,
                "type": "normal"
            });
        }
        // Special workspaces
        // We only show as many as fit in the remaining slots of the group, OR if we append them?
        // OverviewGrid replaces the *last* slots.
        var reservedSlots = 0;
        if (showScratchpadWorkspaces) {
            reservedSlots = Math.min(specialWorkspaces.length, workspacesPerGroup);
            // Logic from OverviewGrid: reserved = Math.min(reserved, Math.max(0, workspacesShown - 1));
            reservedSlots = Math.min(reservedSlots, Math.max(0, workspacesPerGroup - 1));
            // Replace last N items of visible with special
            for (var j = 0; j < reservedSlots; j++) {
                var special = specialWorkspaces[j];
                // Replace from end
                var targetIndex = visible.length - reservedSlots + j;
                if (targetIndex >= 0 && targetIndex < visible.length)
                    visible[targetIndex] = {
                    "id": special.id,
                    "type": "special",
                    "name": special.name,
                    "rawName": special.rawName
                };

            }
        }
        return visible;
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        function onRawEvent(event) {
            if (root.overviewOpen) {
                // If special workspace toggled/moved, update
                if (event.name.startsWith("createworkspace") || event.name.startsWith("destroyworkspace") || event.name.startsWith("activespecial"))
                    root.updateAll();

                // General update for other events if needed, throttled?
                // For now, just rely on open/toggle to strict update, and maybe some specific events.
                // Actually, let's just update on everything if open, safeguards are good.
                root.updateAll();
            }
        }

        target: Hyprland
    }

    // Settings change listener
    Connections {
        function onPluginSettingsChanged() {
            refresh();
        }

        target: pluginApi
    }

    Process {
        id: getClients

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            id: clientsCollector

            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(clientsCollector.text);
                    var tempWinByAddress = {
                    };
                    for (var i = 0; i < root.windowList.length; ++i) {
                        var win = root.windowList[i];
                        tempWinByAddress[win.address] = win;
                    }
                    root.windowByAddress = tempWinByAddress;
                    root.addresses = root.windowList.map(function(win) {
                        return win.address;
                    });
                } catch (e) {
                    Logger.e("WorkspaceOverview", "Failed to parse clients: " + e);
                }
            }
        }

    }

    Process {
        id: getMonitors

        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            id: monitorsCollector

            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(monitorsCollector.text);
                } catch (e) {
                    Logger.e("WorkspaceOverview", "Failed to parse monitors: " + e);
                }
            }
        }

    }

    Process {
        id: getActiveWorkspace

        command: ["hyprctl", "activeworkspace", "-j"]

        stdout: StdioCollector {
            id: activeWorkspaceCollector

            onStreamFinished: {
                try {
                    root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
                } catch (e) {
                    Logger.e("WorkspaceOverview", "Failed to parse active workspace: " + e);
                }
            }
        }

    }

    Process {
        id: getWorkspaces

        command: ["hyprctl", "workspaces", "-j"]

        stdout: StdioCollector {
            id: workspacesCollector

            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(workspacesCollector.text);
                } catch (e) {
                    Logger.e("WorkspaceOverview", "Failed to parse workspaces: " + e);
                }
            }
        }

    }

    IpcHandler {
        function toggle() {
            root.toggle();
        }

        function close() {
            root.close();
        }

        function open() {
            root.open();
        }

        target: "plugin:workspace-overview"
    }

    // === OVERLAY WINDOWS (one per screen) ===
    Variants {
        id: overviewVariants

        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow

            required property var modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(overlayWindow.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.id) == (monitor && monitor.id)

            screen: modelData
            visible: root.overviewOpen
            WlrLayershell.namespace: "noctalia:workspace-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusiveZone: -1
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // === FOCUS GRAB ===
            HyprlandFocusGrab {
                id: grab

                property bool canBeActive: overlayWindow.monitorIsFocused

                windows: [overlayWindow]
                active: false
                onCleared: () => {
                    if (!active)
                        root.overviewOpen = false;

                }
            }

            Connections {
                function onOverviewOpenChanged() {
                    if (root.overviewOpen)
                        delayedGrabTimer.start();

                }

                target: root
            }

            Timer {
                id: delayedGrabTimer

                interval: 150
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return ;

                    grab.active = root.overviewOpen;
                }
            }

            // === INPUT HANDLER (keyboard + scroll) ===
            Item {
                // Simple wrap or clamp? simple wrap.

                id: keyHandler

                anchors.fill: parent
                visible: root.overviewOpen
                focus: root.overviewOpen
                // --- Keyboard navigation ---
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
                        root.close();
                        event.accepted = true;
                        return ;
                    }
                    var visible = root.getVisibleWorkspaces(overlayWindow.monitor.id);
                    if (visible.length === 0)
                        return ;

                    // Determine current index: use lastNavigatedIndex if valid, otherwise find from activeWorkspace
                    var currentIndex = -1;
                    if (root.lastNavigatedIndex >= 0 && root.lastNavigatedIndex < visible.length) {
                        currentIndex = root.lastNavigatedIndex;
                    } else {
                        // Find current workspace in visible list from activeWorkspace
                        var currentWs = root.activeWorkspace;
                        var currentWsId = (currentWs && currentWs.id) || 1;
                        var currentWsName = (currentWs && currentWs.name) || "";
                        for (var i = 0; i < visible.length; i++) {
                            if (visible[i].type === "special") {
                                // For special workspaces, match by name
                                var normalizedCurrentName = root.normalizeSpecialName(currentWsName);
                                if (visible[i].name === normalizedCurrentName) {
                                    currentIndex = i;
                                    break;
                                }
                            } else {
                                // For normal workspaces, match by id
                                if (visible[i].id === currentWsId) {
                                    currentIndex = i;
                                    break;
                                }
                            }
                        }
                        if (currentIndex === -1)
                            currentIndex = 0;

                    }
                    var targetIndex = currentIndex;
                    var cols = root.gridColumns;
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        targetIndex--;
                        if (targetIndex < 0)
                            targetIndex = visible.length - 1;

                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        targetIndex++;
                        if (targetIndex >= visible.length)
                            targetIndex = 0;

                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        targetIndex -= cols;
                        if (targetIndex < 0)
                            targetIndex += visible.length;

                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        targetIndex += cols;
                        if (targetIndex >= visible.length)
                            targetIndex -= visible.length;

                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        // Direct indexing (1-9)
                        // This maps to the first 9 visible slots
                        var position = event.key - Qt.Key_0;
                        if (position <= visible.length)
                            targetIndex = position - 1;

                    } else if (event.key === Qt.Key_0) {
                        // Map to 10th slot if exists
                        if (visible.length >= 10)
                            targetIndex = 9;

                    }
                    if (targetIndex !== currentIndex && visible[targetIndex]) {
                        var target = visible[targetIndex];
                        root.lastNavigatedIndex = targetIndex;
                        if (target.type === "special") {
                            root.activeSpecialWorkspaceName = target.name;
                            Hyprland.dispatch("togglespecialworkspace " + target.name);
                        } else {
                            root.activeSpecialWorkspaceName = "";
                            Hyprland.dispatch("workspace " + target.id);
                        }
                        event.accepted = true;
                    } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                        // Number key was pressed but didn't change workspace (e.g., pressed 5 but only 3 workspaces)
                        event.accepted = true;
                    }
                }

                // --- Scroll wheel navigation ---
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        var visible = root.getVisibleWorkspaces(overlayWindow.monitor.id);
                        if (visible.length === 0)
                            return ;

                        // Determine current index: use lastNavigatedIndex if valid, otherwise find from activeWorkspace
                        var currentIndex = -1;
                        if (root.lastNavigatedIndex >= 0 && root.lastNavigatedIndex < visible.length) {
                            currentIndex = root.lastNavigatedIndex;
                        } else {
                            // Find current workspace in visible list from activeWorkspace
                            var currentWs = root.activeWorkspace;
                            var currentWsId = (currentWs && currentWs.id) || 1;
                            var currentWsName = (currentWs && currentWs.name) || "";
                            for (var i = 0; i < visible.length; i++) {
                                if (visible[i].type === "special") {
                                    // For special workspaces, match by name
                                    var normalizedCurrentName = root.normalizeSpecialName(currentWsName);
                                    if (visible[i].name === normalizedCurrentName) {
                                        currentIndex = i;
                                        break;
                                    }
                                } else {
                                    // For normal workspaces, match by id
                                    if (visible[i].id === currentWsId) {
                                        currentIndex = i;
                                        break;
                                    }
                                }
                            }
                            // If not found (e.g., on a different group's workspace), default to first
                            if (currentIndex === -1)
                                currentIndex = 0;

                        }
                        var targetIndex = currentIndex;
                        if (event.angleDelta.y > 0) {
                            // Scroll up → previous workspace (wrapping)
                            targetIndex = currentIndex - 1;
                            if (targetIndex < 0)
                                targetIndex = visible.length - 1;

                        } else if (event.angleDelta.y < 0) {
                            // Scroll down → next workspace (wrapping)
                            targetIndex = currentIndex + 1;
                            if (targetIndex >= visible.length)
                                targetIndex = 0;

                        }
                        if (targetIndex !== currentIndex && visible[targetIndex]) {
                            var target = visible[targetIndex];
                            root.lastNavigatedIndex = targetIndex;
                            if (target.type === "special") {
                                root.activeSpecialWorkspaceName = target.name;
                                Hyprland.dispatch("togglespecialworkspace " + target.name);
                            } else {
                                root.activeSpecialWorkspaceName = "";
                                Hyprland.dispatch("workspace " + target.id);
                            }
                        }
                    }
                }

            }

            // === OVERVIEW CONTENT ===
            Item {
                id: contentContainer

                // Calculate effective margin based on bar position + height
                readonly property real barHeight: Style.getBarHeightForScreen(overlayWindow.screen.name)
                readonly property string barPosition: Commons.Settings.getBarPositionForScreen(overlayWindow.screen.name)
                // Margin: bar height + user-configurable additional margin
                readonly property real baseMargin: {
                    if (root.overviewPosition === "top" && barPosition === "top")
                        return barHeight + root.barMargin;

                    if (root.overviewPosition === "bottom" && barPosition === "bottom")
                        return barHeight + root.barMargin;

                    return Style.marginM + root.barMargin;
                }
                // Position the content based on setting
                readonly property real contentY: {
                    if (root.overviewPosition === "top")
                        return baseMargin;

                    if (root.overviewPosition === "bottom")
                        return parent.height - contentColumn.height - baseMargin;

                    return (parent.height - contentColumn.height) / 2; // center
                }

                anchors.fill: parent

                Column {
                    id: contentColumn

                    visible: root.overviewOpen
                    x: (parent.width - width) / 2
                    y: contentContainer.contentY
                    opacity: root.overviewOpen ? 1 : 0

                    Loader {
                        id: overviewLoader

                        active: root.overviewOpen

                        sourceComponent: OverviewGrid {
                            pluginMain: root
                            panelWindow: overlayWindow
                            visible: true
                        }

                    }

                    Behavior on y {
                        enabled: root.useSlideAnimation

                        NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on opacity {
                        enabled: root.useSlideAnimation

                        NumberAnimation {
                            duration: Style.animationFast
                        }

                    }

                }

            }

            mask: Region {
                item: root.overviewOpen ? keyHandler : null
            }

        }

    }

}
