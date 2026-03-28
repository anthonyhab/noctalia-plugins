import "./components"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
    id: root

    property var pluginApi: null
    property int rows: getSetting("rows", 10)
    property int columns: getSetting("columns", 1)
    property real scale: getSetting("scale", 0.16)
    property int workspaceSpacing: getSetting("workspaceSpacing", 10)
    property real dimOpacity: getSetting("dimOpacity", 0.72)
    property bool showWorkspaceLabels: getSetting("showWorkspaceLabels", true)
    property bool showAllMonitors: getSetting("showAllMonitors", false)
    property bool includeSpecialWorkspaces: getSetting("includeSpecialWorkspaces", false)
    property bool useLivePreviews: getSetting("useLivePreviews", true)
    property bool overviewOpen: false
    property int activeWorkspaceId: 1
    property var activeWorkspace: null
    property var monitors: []
    property var windowList: []
    property var windowByAddress: ({
    })
    property var workspaces: []
    property string draggingWindowAddress: ""
    property int draggingFromWorkspace: -1
    property int draggingToWorkspace: -1
    property bool pendingWindowRefresh: false
    property bool pendingMonitorRefresh: false
    property bool pendingWorkspaceRefresh: false

    function getSetting(key, fallback) {
        if (!pluginApi)
            return fallback;

        try {
            var value = undefined;
            if (pluginApi.pluginSettings && pluginApi.pluginSettings[key] !== undefined)
                value = pluginApi.pluginSettings[key];
            else if (pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings && pluginApi.manifest.metadata.defaultSettings[key] !== undefined)
                value = pluginApi.manifest.metadata.defaultSettings[key];
            return (value === undefined || value === null) ? fallback : value;
        } catch (e) {
            return fallback;
        }
    }

    function refreshSettings() {
        rows = getSetting("rows", 10);
        columns = getSetting("columns", 1);
        scale = getSetting("scale", 0.16);
        workspaceSpacing = getSetting("workspaceSpacing", 10);
        dimOpacity = getSetting("dimOpacity", 0.72);
        showWorkspaceLabels = getSetting("showWorkspaceLabels", true);
        showAllMonitors = getSetting("showAllMonitors", false);
        includeSpecialWorkspaces = getSetting("includeSpecialWorkspaces", false);
        useLivePreviews = getSetting("useLivePreviews", true);
    }

    function normalizeAddress(address) {
        var normalized = (address || "").toString();
        if (normalized === "")
            return "";

        return normalized.startsWith("0x") ? normalized : ("0x" + normalized);
    }

    function toggle() {
        if (overviewOpen)
            close();
        else
            open();
    }

    function open() {
        if (overviewOpen)
            return ;

        overviewOpen = true;
        updateAll();
    }

    function close() {
        if (!overviewOpen)
            return ;

        overviewOpen = false;
        resetDragState();
    }

    function switchToWorkspace(workspaceId) {
        var target = Math.max(1, workspaceId);
        activeWorkspaceId = target;
        Hyprland.dispatch("workspace " + target);
    }

    function focusWindow(windowData) {
        if (!windowData)
            return ;

        var address = normalizeAddress(windowData.address);
        if (address === "")
            return ;

        Hyprland.dispatch("focuswindow address:" + address);
        close();
    }

    function beginWindowDrag(address, workspaceId) {
        draggingWindowAddress = normalizeAddress(address);
        draggingFromWorkspace = workspaceId;
        draggingToWorkspace = -1;
    }

    function setDragTarget(workspaceId) {
        if (draggingWindowAddress === "")
            return ;

        draggingToWorkspace = workspaceId;
    }

    function finishWindowDrag() {
        if (draggingWindowAddress !== "" && draggingToWorkspace > 0 && draggingToWorkspace !== draggingFromWorkspace)
            Hyprland.dispatch("movetoworkspace " + draggingToWorkspace + ",address:" + draggingWindowAddress);

        resetDragState();
    }

    function resetDragState() {
        draggingWindowAddress = "";
        draggingFromWorkspace = -1;
        draggingToWorkspace = -1;
    }

    function workspaceHasWindows(workspaceId, monitorId) {
        var list = windowList || [];
        for (var i = 0; i < list.length; ++i) {
            var win = list[i];
            if (!win || !win.workspace)
                continue;

            if (win.workspace.id !== workspaceId)
                continue;

            if (monitorId !== undefined && monitorId !== null && win.monitor !== monitorId)
                continue;

            return true;
        }
        return false;
    }

    function updateWindowList() {
        getClients.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateWorkspaces();
    }

    function queueRefreshForEvent(eventName) {
        var name = (eventName || "").toString();
        if (name === "")
            return ;

        if (name.startsWith("openwindow") || name.startsWith("closewindow") || name.startsWith("movewindow") || name.startsWith("windowtitle") || name.startsWith("activewindow"))
            pendingWindowRefresh = true;

        if (name.startsWith("workspace") || name.startsWith("workspacev2") || name.startsWith("createworkspace") || name.startsWith("destroyworkspace") || name.startsWith("renameworkspace") || name.startsWith("activespecial"))
            pendingWorkspaceRefresh = true;

        if (name.startsWith("monitoradded") || name.startsWith("monitorremoved") || name.startsWith("focusedmon"))
            pendingMonitorRefresh = true;

        refreshDebounce.restart();
    }

    function flushRefreshQueue() {
        if (pendingWindowRefresh)
            updateWindowList();

        if (pendingMonitorRefresh)
            updateMonitors();

        if (pendingWorkspaceRefresh)
            updateWorkspaces();

        pendingWindowRefresh = false;
        pendingMonitorRefresh = false;
        pendingWorkspaceRefresh = false;
    }

    onActiveWorkspaceChanged: {
        if (activeWorkspace && activeWorkspace.id > 0)
            activeWorkspaceId = activeWorkspace.id;

    }
    Component.onCompleted: {
        refreshSettings();
        updateAll();
        Logger.i("ScrollingOverview", "Plugin initialized");
    }

    Timer {
        id: refreshDebounce

        interval: 40
        repeat: false
        onTriggered: {
            if (!root.overviewOpen)
                return ;

            root.flushRefreshQueue();
        }
    }

    Timer {
        id: liveWindowRefresh

        interval: 120
        repeat: true
        running: root.overviewOpen
        onTriggered: {
            if (!getClients.running)
                root.updateWindowList();

        }
    }

    Connections {
        function onRawEvent(event) {
            if (!root.overviewOpen)
                return ;

            root.queueRefreshForEvent(event && event.name);
        }

        target: Hyprland
    }

    Connections {
        function onPluginSettingsChanged() {
            root.refreshSettings();
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
                    var byAddress = ({
                    });
                    for (var i = 0; i < root.windowList.length; ++i) {
                        var win = root.windowList[i];
                        if (win && win.address)
                            byAddress[win.address] = win;

                    }
                    root.windowByAddress = byAddress;
                } catch (e) {
                    Logger.e("ScrollingOverview", "Failed to parse clients: " + e);
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
                    Logger.e("ScrollingOverview", "Failed to parse monitors: " + e);
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
                    Logger.e("ScrollingOverview", "Failed to parse workspaces: " + e);
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
                    Logger.e("ScrollingOverview", "Failed to parse active workspace: " + e);
                }
            }
        }

    }

    IpcHandler {
        function toggle() {
            root.toggle();
        }

        function togglePanel() {
            root.toggle();
        }

        function open() {
            root.open();
        }

        function openPanel() {
            root.open();
        }

        function close() {
            root.close();
        }

        function closePanel() {
            root.close();
        }

        target: "plugin:scrolling-overview"
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: overlayWindow

            required property ShellScreen modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(overlayWindow.screen)
            readonly property bool monitorIsFocused: (Hyprland.focusedMonitor && overlayWindow.monitor) ? Hyprland.focusedMonitor.id === overlayWindow.monitor.id : true

            screen: modelData
            visible: root.overviewOpen && (root.showAllMonitors || monitorIsFocused)
            WlrLayershell.namespace: "noctalia:scrolling-overview"
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

            HyprlandFocusGrab {
                id: focusGrab

                windows: [overlayWindow]
                active: overlayWindow.visible && overlayWindow.monitorIsFocused
                onCleared: {
                    if (!active)
                        root.close();

                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Color.mSurface, root.dimOpacity)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.close();
                    }
                }

            }

            Item {
                id: keyCatcher

                anchors.fill: parent
                focus: overlayWindow.visible
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        root.switchToWorkspace(root.activeWorkspaceId - 1);
                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        root.switchToWorkspace(root.activeWorkspaceId + 1);
                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_PageUp) {
                        root.switchToWorkspace(root.activeWorkspaceId - root.rows);
                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_PageDown) {
                        root.switchToWorkspace(root.activeWorkspaceId + root.rows);
                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.close();
                        event.accepted = true;
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        if (event.angleDelta.y > 0)
                            root.switchToWorkspace(root.activeWorkspaceId - 1);
                        else if (event.angleDelta.y < 0)
                            root.switchToWorkspace(root.activeWorkspaceId + 1);
                    }
                }

            }

            ScrollingOverviewScene {
                anchors.fill: parent
                anchors.margins: Style.marginXL
                pluginMain: root
                panelWindow: overlayWindow
            }

        }

    }

}
