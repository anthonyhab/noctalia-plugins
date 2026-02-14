import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import "components"

Item {
    id: root

    property var pluginApi: null

    // === SETTINGS HELPERS ===
    function getSetting(key, fallback) {
        if (!pluginApi) return fallback
        try {
            var val = pluginApi.pluginSettings[key]
            if (val === undefined || val === null) {
                val = pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings && pluginApi.manifest.metadata.defaultSettings[key]
            }
            return (val === undefined || val === null) ? fallback : val
        } catch (e) {
            return fallback
        }
    }

    // === OVERVIEW SETTINGS ===
    property int gridRows: getSetting("rows", 2)
    property int gridColumns: getSetting("columns", 5)
    property real gridScale: getSetting("scale", 0.16)
    property bool hideEmptyRows: getSetting("hideEmptyRows", true)
    property string overviewPosition: getSetting("position", "top")

    // === OVERVIEW STATE ===
    property bool overviewOpen: false

    function toggle() {
        overviewOpen = !overviewOpen
        if (overviewOpen) {
            updateAll()
        }
    }

    function open() {
        if (!overviewOpen) {
            overviewOpen = true
            updateAll()
        }
    }

    function close() {
        overviewOpen = false
    }

    function refresh() {
        gridRows = getSetting("rows", 2)
        gridColumns = getSetting("columns", 5)
        gridScale = getSetting("scale", 0.16)
        hideEmptyRows = getSetting("hideEmptyRows", true)
        overviewPosition = getSetting("position", "top")
    }

    // === HYPRLAND DATA ===
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var monitors: []
    property var activeWorkspace: null

    function updateWindowList() {
        getClients.running = true
    }

    function updateMonitors() {
        getMonitors.running = true
    }

    function updateWorkspaces() {
        getActiveWorkspace.running = true
    }

    function updateAll() {
        updateWindowList()
        updateMonitors()
        updateWorkspaces()
    }

    Component.onCompleted: {
        updateAll()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (root.overviewOpen) {
                root.updateAll()
            }
        }
    }

    // Settings change listener
    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            refresh()
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(clientsCollector.text)
                    var tempWinByAddress = {}
                    for (var i = 0; i < root.windowList.length; ++i) {
                        var win = root.windowList[i]
                        tempWinByAddress[win.address] = win
                    }
                    root.windowByAddress = tempWinByAddress
                    root.addresses = root.windowList.map(function(win) { return win.address })
                } catch (e) {
                    Logger.e("WorkspaceOverview", "Failed to parse clients: " + e)
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
                    root.monitors = JSON.parse(monitorsCollector.text)
                } catch (e) {
                    Logger.e("WorkspaceOverview", "Failed to parse monitors: " + e)
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
                    root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text)
                } catch (e) {
                    Logger.e("WorkspaceOverview", "Failed to parse active workspace: " + e)
                }
            }
        }
    }

    // === IPC HANDLER ===
    IpcHandler {
        target: "plugin:workspace-overview"

        function toggle() {
            root.toggle()
        }
        function close() {
            root.close()
        }
        function open() {
            root.open()
        }
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
            color: "transparent"

            mask: Region {
                item: root.overviewOpen ? keyHandler : null
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // === FOCUS GRAB ===
            HyprlandFocusGrab {
                id: grab
                windows: [overlayWindow]
                property bool canBeActive: overlayWindow.monitorIsFocused
                active: false
                onCleared: () => {
                    if (!active)
                        root.overviewOpen = false
                }
            }

            Connections {
                target: root
                function onOverviewOpenChanged() {
                    if (root.overviewOpen) {
                        delayedGrabTimer.start()
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: 150
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return
                    grab.active = root.overviewOpen
                }
            }

            implicitWidth: contentColumn.implicitWidth
            implicitHeight: contentColumn.implicitHeight

            // === INPUT HANDLER (keyboard + scroll) ===
            Item {
                id: keyHandler
                anchors.fill: parent
                visible: root.overviewOpen
                focus: root.overviewOpen

                // --- Scroll wheel navigation ---
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var workspacesPerGroup = root.gridRows * root.gridColumns
                        var currentId = (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace && Hyprland.focusedMonitor.activeWorkspace.id) || 1
                        var currentGroup = Math.floor((currentId - 1) / workspacesPerGroup)
                        var minWorkspaceId = currentGroup * workspacesPerGroup + 1
                        var maxWorkspaceId = minWorkspaceId + workspacesPerGroup - 1
                        var targetId = null

                        if (event.angleDelta.y > 0) {
                            // Scroll up → previous workspace (wrapping)
                            targetId = currentId - 1
                            if (targetId < minWorkspaceId) targetId = maxWorkspaceId
                        } else if (event.angleDelta.y < 0) {
                            // Scroll down → next workspace (wrapping)
                            targetId = currentId + 1
                            if (targetId > maxWorkspaceId) targetId = minWorkspaceId
                        }

                        if (targetId !== null) {
                            Hyprland.dispatch("workspace " + targetId)
                        }
                    }
                }

                // --- Keyboard navigation ---
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
                        root.close()
                        event.accepted = true
                        return
                    }

                    var workspacesPerGroup = root.gridRows * root.gridColumns
                    var currentId = (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace && Hyprland.focusedMonitor.activeWorkspace.id) || 1
                    var currentGroup = Math.floor((currentId - 1) / workspacesPerGroup)
                    var minWorkspaceId = currentGroup * workspacesPerGroup + 1
                    var maxWorkspaceId = minWorkspaceId + workspacesPerGroup - 1

                    var currentRow = Math.floor((currentId - minWorkspaceId) / root.gridColumns)
                    var rowMinId = minWorkspaceId + currentRow * root.gridColumns
                    var rowMaxId = rowMinId + root.gridColumns - 1

                    var targetId = null

                    if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        targetId = currentId - 1
                        if (root.hideEmptyRows) {
                            if (targetId < rowMinId) targetId = rowMaxId
                        } else {
                            if (targetId < minWorkspaceId) targetId = maxWorkspaceId
                        }
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        targetId = currentId + 1
                        if (root.hideEmptyRows) {
                            if (targetId > rowMaxId) targetId = rowMinId
                        } else {
                            if (targetId > maxWorkspaceId) targetId = minWorkspaceId
                        }
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        targetId = currentId - root.gridColumns
                        if (targetId < minWorkspaceId) targetId += workspacesPerGroup
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        targetId = currentId + root.gridColumns
                        if (targetId > maxWorkspaceId) targetId -= workspacesPerGroup
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        var position = event.key - Qt.Key_0
                        if (position <= workspacesPerGroup) {
                            targetId = minWorkspaceId + position - 1
                        }
                    } else if (event.key === Qt.Key_0) {
                        if (workspacesPerGroup >= 10) {
                            targetId = minWorkspaceId + 9
                        }
                    }

                    if (targetId !== null) {
                        Hyprland.dispatch("workspace " + targetId)
                        event.accepted = true
                    }
                }
            }

            // === OVERVIEW CONTENT ===
            Column {
                id: contentColumn
                visible: root.overviewOpen

                // Calculate effective margin based on bar position + height
                readonly property real barHeight: Style.getBarHeightForScreen(overlayWindow.screen.name)
                readonly property string barPosition: Commons.Settings.getBarPositionForScreen(overlayWindow.screen.name)

                // Margin: attach directly to bar (no gap), otherwise small margin from screen edge
                readonly property real effectiveMargin: {
                    if (root.overviewPosition === "top") {
                        if (barPosition === "top") return barHeight // Attach directly to bar
                        return Style.marginM // Small margin when no bar
                    }
                    if (root.overviewPosition === "bottom") {
                        if (barPosition === "bottom") return barHeight // Attach directly to bar
                        return Style.marginM // Small margin when no bar
                    }
                    return Style.marginM // Default for center
                }

                // Dynamic anchoring based on position setting
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: root.overviewPosition === "top" ? parent.top : undefined
                anchors.bottom: root.overviewPosition === "bottom" ? parent.bottom : undefined
                anchors.verticalCenter: root.overviewPosition === "center" ? parent.verticalCenter : undefined
                anchors.topMargin: root.overviewPosition === "top" ? effectiveMargin : 0
                anchors.bottomMargin: root.overviewPosition === "bottom" ? effectiveMargin : 0

                Loader {
                    id: overviewLoader
                    active: root.overviewOpen
                    sourceComponent: OverviewGrid {
                        pluginMain: root
                        panelWindow: overlayWindow
                        visible: true
                    }
                }
            }
        }
    }
}
