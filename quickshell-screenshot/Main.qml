// Main.qml - Quickshell Screenshot entry point
// Provides full-screen overlay with draggable region selector

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Widgets
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null

    // Settings
    property bool showGrid: pluginApi?.pluginSettings?.showGrid !== false
    property bool copyToClipboard: pluginApi?.pluginSettings?.copyToClipboard !== false
    property bool openAfterCapture: pluginApi?.pluginSettings?.openAfterCapture === true

    // Freeze
    property bool freezeScreen: pluginApi?.pluginSettings?.freezeScreen !== false
    property string freezeImagePath: ""

    // Toolbar
    property string toolbarEdge: pluginApi?.pluginSettings?.toolbarEdge ?? "bottom"
    property bool toolbarRevealed: false

    // State
    property bool isActive: false
    property var savedRegion: null
    property var recentSizes: []
    property string captureMode: "region"
    property var undoStack: []

    // Screen info
    property var currentScreen: Quickshell.screens[0] || null
    property real screenScale: Screen.devicePixelRatio || 1.0

    // Paths
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string stateDir: homeDir + "/.cache/qs-screenshot"
    readonly property string stateFile: stateDir + "/state.json"
    readonly property string outputDir: homeDir + "/Pictures/screenshots"

    Component.onCompleted: readState()

    onIsActiveChanged: {
        if (isActive) {
            undoStack = []
            if (captureMode !== "last") regionSelector.visible = false
            if (captureMode === "last" && savedRegion) {
                regionSelector.x = savedRegion.x
                regionSelector.y = savedRegion.y
                regionSelector.width = savedRegion.width
                regionSelector.height = savedRegion.height
                regionSelector.visible = true
            }
            // window mode: WindowSelector visibility is driven by its `visible` binding
        } else {
            if (freezeImagePath !== "") {
                var rmProc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root)
                rmProc.command = ["rm", "-f", freezeImagePath]
                rmProc.running = true
                freezeImagePath = ""
            }
        }
    }

    onCaptureModeChanged: {
        if (captureMode === "last" && savedRegion) {
            regionSelector.x = savedRegion.x
            regionSelector.y = savedRegion.y
            regionSelector.width = savedRegion.width
            regionSelector.height = savedRegion.height
            regionSelector.visible = true
        } else {
            regionSelector.visible = false
        }
        // window mode: WindowSelector visibility is driven by its `visible` binding
    }

    // State Management
    function readState() {
        var process = Qt.createQmlObject('
            import QtQuick
            import Quickshell.Io
            Process {}
        ', root)
        process.command = ["cat", stateFile]
        process.running = true
        process.onExited.connect(function(exitCode) {
            if (exitCode === 0) {
                try {
                    var data = JSON.parse(process.stdout)
                    savedRegion = parseRegion(data.region || null)
                    recentSizes = data.recentSizes || []
                } catch (e) {
                    savedRegion = null
                }
            }
        })
    }

    function saveState() {
        var jsonStr = JSON.stringify({ region: formatRegion(savedRegion), recentSizes: recentSizes })
        var cmd = "mkdir -p " + stateDir + " && echo '" + jsonStr + "' > " + stateFile
        var process = Qt.createQmlObject('
            import QtQuick
            import Quickshell.Io
            Process {}
        ', root)
        process.command = ["sh", "-c", cmd]
        process.running = true
    }

    function clearRegion() {
        savedRegion = null
        saveState()
    }

    function parseRegion(regionStr) {
        if (!regionStr) return null
        var match = /^(\d+),(\d+)\s+(\d+)x(\d+)$/.exec(regionStr)
        if (match) return { x: parseInt(match[1]), y: parseInt(match[2]), width: parseInt(match[3]), height: parseInt(match[4]) }
        return null
    }

    function formatRegion(region) {
        if (!region) return null
        return Math.round(region.x) + "," + Math.round(region.y) + " " + Math.round(region.width) + "x" + Math.round(region.height)
    }

    // Screenshot
    function generateFilename() {
        var now = new Date()
        var dateStr = now.toISOString().split("T")[0]
        var timeStr = now.toTimeString().split(" ")[0].replace(/:/g, "-")
        return outputDir + "/" + dateStr + "/screenshot-" + dateStr + "_" + timeStr + ".png"
    }

    function captureScreenshot(region, callback) {
        if (!region) { if (callback) callback(false, null); return }

        var regionStr = formatRegion(region)
        var filename = generateFilename()
        var dir = filename.substring(0, filename.lastIndexOf("/"))

        var mkdirProcess = Qt.createQmlObject('
            import QtQuick
            import Quickshell.Io
            Process {}
        ', root)
        mkdirProcess.command = ["mkdir", "-p", dir]
        mkdirProcess.onExited.connect(function() {
            var grimProcess = Qt.createQmlObject('
                import QtQuick
                import Quickshell.Io
                Process {}
            ', root)
            grimProcess.command = ["grim", "-g", regionStr, filename]
            grimProcess.onExited.connect(function(exitCode) {
                if (exitCode === 0) {
                    if (copyToClipboard) {
                        var cp = Qt.createQmlObject('
                            import QtQuick
                            import Quickshell.Io
                            Process {}
                        ', root)
                        cp.command = ["sh", "-c", "cat '" + filename + "' | wl-copy"]
                        cp.running = true
                    }
                    if (openAfterCapture) openFile(filename)
                    if (callback) callback(true, filename)
                } else {
                    Logger.e("QuickshellScreenshot", pluginApi?.tr("log.grim-failed"), exitCode, pluginApi?.tr("log.region"), regionStr)
                    if (callback) callback(false, null)
                }
            })
            grimProcess.running = true
        })
        mkdirProcess.running = true
    }

    function openFile(path) {
        var p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root)
        p.command = ["xdg-open", path]
        p.running = true
    }

    function showNotification(title, message, iconPath) {
        var p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root)
        var args = [title, message, "-t", "5000"]
        if (iconPath) { args.push("-i"); args.push(iconPath) }
        p.command = ["notify-send"].concat(args)
        p.running = true
    }

    function captureAtRegion(region) {
        if (!region) return
        savedRegion = region
        saveState()
        isActive = false
        var t = Qt.createQmlObject('import QtQuick; Timer { interval: 300; repeat: false }', root)
        t.triggered.connect(function() {
            captureScreenshot(region, function(success, filename) {
                if (success)
                    showNotification(pluginApi?.tr("notifications.captured-title"), formatRegion(region), filename)
            })
        })
        t.running = true
    }

    function captureRegionSilent() {
        if (!savedRegion) { showSelector(); return }
        captureScreenshot(savedRegion, function(success, filename) {
            if (success)
                showNotification(pluginApi?.tr("notifications.captured-title"), formatRegion(savedRegion), filename)
        })
    }

    function captureFullscreen() {
        var screen = currentScreen
        var region = { x: 0, y: 0, width: screen.width, height: screen.height }
        captureAtRegion(region)
    }

    function showSelector() {
        if (freezeScreen) {
            var ts = Date.now()
            var outFile = "/tmp/qs-screenshot-freeze-" + ts + ".png"
            var mon = Hyprland.monitorFor(currentScreen)
            var outputName = mon ? mon.name : ""
            var p = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process {}', root)
            p.command = outputName ? ["grim", "-o", outputName, outFile] : ["grim", outFile]
            p.onExited.connect(function(code) {
                if (code === 0) freezeImagePath = outFile
                isActive = true
            })
            p.running = true
        } else {
            isActive = true
        }
    }
    function hideSelector() { isActive = false }

    function pushUndo() {
        var state = {
            visible: regionSelector.visible,
            x: regionSelector.x,
            y: regionSelector.y,
            width: regionSelector.width,
            height: regionSelector.height
        }
        undoStack = undoStack.concat([state])
    }

    function undo() {
        if (undoStack.length === 0) return
        var stack = undoStack.slice()
        var state = stack.pop()
        undoStack = stack
        regionSelector.x = state.x
        regionSelector.y = state.y
        regionSelector.width = state.width
        regionSelector.height = state.height
        regionSelector.visible = state.visible
    }

    // Overlay window
    PanelWindow {
        id: overlayWindow
        screen: currentScreen
        visible: root.isActive
        color: root.freezeImagePath !== "" ? "transparent"
             : root.captureMode === "window" ? Qt.rgba(0, 0, 0, 0.01)
             : (root.captureMode === "region" && regionSelector.visible) ? "transparent"
             : Qt.rgba(0, 0, 0, 0.75)

        WlrLayershell.namespace: "noctalia:quickshell-screenshot"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusiveZone: -1

        anchors { top: true; bottom: true; left: true; right: true }

        // Frozen background
        Image {
            anchors.fill: parent
            source: root.freezeImagePath ? "file://" + root.freezeImagePath : ""
            visible: root.freezeImagePath !== ""
            fillMode: Image.Stretch
            z: -1
            cache: false
        }

        // Dim overlay with cutout around region selector
        readonly property color dimColor: Qt.rgba(0, 0, 0, 0.75)
        readonly property bool showCutout: root.captureMode === "region" && regionSelector.visible
        readonly property bool showFullDim: root.freezeImagePath !== "" && !showCutout && root.captureMode !== "window"

        // Top strip
        Rectangle {
            visible: overlayWindow.showCutout
            color: overlayWindow.dimColor
            x: 0; y: 0
            width: overlayWindow.width
            height: regionSelector.y
        }
        // Bottom strip
        Rectangle {
            visible: overlayWindow.showCutout
            color: overlayWindow.dimColor
            x: 0; y: regionSelector.y + regionSelector.height
            width: overlayWindow.width
            height: overlayWindow.height - y
        }
        // Left strip
        Rectangle {
            visible: overlayWindow.showCutout
            color: overlayWindow.dimColor
            x: 0; y: regionSelector.y
            width: regionSelector.x
            height: regionSelector.height
        }
        // Right strip
        Rectangle {
            visible: overlayWindow.showCutout
            color: overlayWindow.dimColor
            x: regionSelector.x + regionSelector.width; y: regionSelector.y
            width: overlayWindow.width - x
            height: regionSelector.height
        }

        // Full-screen dim when freeze is active but no region drawn
        Rectangle {
            visible: overlayWindow.showFullDim
            anchors.fill: parent
            color: overlayWindow.dimColor
        }

        // Edge trigger zone — hover to reveal toolbar
        MouseArea {
            id: edgeTrigger
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: 15
            x: root.toolbarEdge === "right" ? parent.width - 8 : 0
            y: root.toolbarEdge === "bottom" ? parent.height - 8 : 0
            width: (root.toolbarEdge === "left" || root.toolbarEdge === "right") ? 8 : parent.width
            height: (root.toolbarEdge === "top" || root.toolbarEdge === "bottom") ? 8 : parent.height
            onContainsMouseChanged: {
                if (containsMouse) { hideTimer.stop(); root.toolbarRevealed = true }
                else if (!toolbarHover.containsMouse) hideTimer.restart()
            }
        }

        Timer {
            id: hideTimer
            interval: 400
            onTriggered: root.toolbarRevealed = false
        }

        // Auto-hide toolbar wrapper
        Item {
            id: toolbarWrapper
            z: 10
            width: modeToolbar.width
            height: modeToolbar.height

            readonly property bool isVertical: root.toolbarEdge === "left" || root.toolbarEdge === "right"

            x: {
                if (root.toolbarEdge === "left")
                    return root.toolbarRevealed ? 24 : -width
                if (root.toolbarEdge === "right")
                    return root.toolbarRevealed ? parent.width - width - 24 : parent.width
                return parent.width / 2 - width / 2
            }
            y: {
                if (root.toolbarEdge === "top")
                    return root.toolbarRevealed ? 24 : -height
                if (root.toolbarEdge === "bottom")
                    return root.toolbarRevealed ? parent.height - height - 24 : parent.height
                return parent.height / 2 - height / 2
            }

            Behavior on x { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }

            MouseArea {
                id: toolbarHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: {
                    if (containsMouse) hideTimer.stop()
                    else if (!edgeTrigger.containsMouse) hideTimer.restart()
                }
            }

            Column {
                id: modeToolbar
                spacing: 6

                NText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.captureMode === "region"     ? "Drag to select region" :
                          root.captureMode === "window"     ? "Hover over a window and click to capture" :
                          root.captureMode === "fullscreen" ? "Press Enter or click to capture full screen" :
                                                              "Resume last region"
                    color: Qt.alpha(Color.mOnSurface, 0.55)
                    pointSize: 8
                }

                Flow {
                    flow: toolbarWrapper.isVertical ? Flow.TopToBottom : Flow.LeftToRight
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "region",     labelKey: "capture-modes.region" },
                            { id: "window",     labelKey: "capture-modes.window" },
                            { id: "fullscreen", labelKey: "capture-modes.fullscreen" },
                            { id: "last",       labelKey: "capture-modes.last" }
                        ]

                        Rectangle {
                            property bool isSelected: root.captureMode === modelData.id
                            property bool isDisabled: modelData.id === "last" && root.savedRegion === null
                            property bool hovered: modeBtn.containsMouse && !isDisabled
                            height: 32
                            width: modeBtnLabel.implicitWidth + 24
                            radius: 16
                            color: isSelected ? Color.mPrimary
                                              : (hovered ? Qt.alpha(Color.mPrimary, 0.25) : Qt.alpha(Color.mPrimary, 0.15))
                            opacity: isDisabled ? 0.4 : 1.0

                            NText {
                                id: modeBtnLabel
                                text: pluginApi?.tr(modelData.labelKey)
                                color: isSelected ? Color.mOnPrimary : Color.mPrimary
                                pointSize: 9
                                font.weight: Font.Medium
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: modeBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !isDisabled
                                onClicked: root.captureMode = modelData.id
                            }
                        }
                    }
                }
            }
        }

        // Fullscreen click overlay (behind toolbar, full screen)
        MouseArea {
            anchors.fill: parent
            visible: root.captureMode === "fullscreen"
            z: 1
            onClicked: root.captureFullscreen()
        }

        // Fullscreen hint (center of screen)
        NText {
            visible: root.captureMode === "fullscreen"
            text: pluginApi?.tr("selector.fullscreen-hint")
            color: Qt.alpha(Color.mOnSurface, 0.7)
            pointSize: 16
            font.weight: Font.Bold
            anchors.centerIn: parent
            z: 2
        }

        MouseArea {
            id: initialSelector
            anchors.fill: parent
            visible: root.captureMode === "region" && !regionSelector.visible
            z: 3

            property point startPoint: Qt.point(0, 0)
            property bool isSelecting: false

            onPressed: function(mouse) {
                startPoint = Qt.point(mouse.x, mouse.y)
                isSelecting = true
                selectionPreview.visible = true
                selectionPreview.x = mouse.x
                selectionPreview.y = mouse.y
                selectionPreview.width = 0
                selectionPreview.height = 0
            }

            onReleased: function(mouse) {
                isSelecting = false
                selectionPreview.visible = false
                var x = Math.min(startPoint.x, mouse.x)
                var y = Math.min(startPoint.y, mouse.y)
                var w = Math.abs(mouse.x - startPoint.x)
                var h = Math.abs(mouse.y - startPoint.y)
                if (w >= 50 && h >= 50) {
                    root.pushUndo()
                    regionSelector.x = x
                    regionSelector.y = y
                    regionSelector.width = w
                    regionSelector.height = h
                    regionSelector.visible = true
                }
            }

            onPositionChanged: function(mouse) {
                if (!isSelecting) return
                var x = Math.min(startPoint.x, mouse.x)
                var y = Math.min(startPoint.y, mouse.y)
                selectionPreview.x = x
                selectionPreview.y = y
                selectionPreview.width = Math.abs(mouse.x - startPoint.x)
                selectionPreview.height = Math.abs(mouse.y - startPoint.y)
            }

            Rectangle {
                id: selectionPreview
                visible: false
                color: Qt.alpha(Color.mPrimary, 0.12)
                border.color: Color.mPrimary
                border.width: 2
            }
        }

        WindowSelector {
            id: windowSelector
            anchors.fill: parent
            visible: root.captureMode === "window" && root.isActive
            screen: root.currentScreen
            z: 5

            onRegionSelected: (x, y, w, h) => root.captureAtRegion({ x: x, y: y, width: w, height: h })
            onCancelled: {
                root.captureMode = "region"
                // isActive stays true — overlay remains open in region mode
            }
        }

        RegionSelector {
            id: regionSelector
            visible: false
            showGrid: root.showGrid
            recentSizes: root.recentSizes
            screenScale: root.screenScale
            z: 6
            pluginApi: root.pluginApi

            hasSavedRegion: root.savedRegion !== null
            onCaptureRequested: root.captureAtRegion(region)
            onCancelled: root.hideSelector()
            onClearRequested: { root.pushUndo(); root.clearRegion(); regionSelector.visible = false }
            onStateSnapshot: root.pushUndo()
            onSizeApplied: function(w, h) {
                var entry = { w: w, h: h }
                var filtered = root.recentSizes.filter(function(s) { return !(s.w === w && s.h === h) })
                root.recentSizes = [entry].concat(filtered).slice(0, 5)
                root.saveState()
            }
        }

        Rectangle {
            id: cancelButton
            width: 32
            height: 32
            color: cancelHover.containsMouse ? Qt.alpha(Color.mError, 0.8) : Color.mError
            radius: 16
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            z: 10

            NText {
                text: "×"
                color: Color.mOnSurface
                pointSize: 24
                font.weight: Font.Bold
                anchors.centerIn: parent
            }

            MouseArea {
                id: cancelHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.hideSelector()
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.hideSelector()
                event.accepted = true
            } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
                root.undo()
                event.accepted = true
            } else if (root.captureMode === "fullscreen" &&
                       (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                root.captureFullscreen()
                event.accepted = true
            }
        }

        Component.onCompleted: forceActiveFocus()
    }

    function activate() { showSelector() }

    IpcHandler {
        target: "quickshell-screenshot"
        function openSelector()  { root.showSelector() }
        function captureRegion() { root.captureRegionSilent() }
        function resetState()    { root.clearRegion() }
    }

    IpcHandler {
        target: "plugin:quickshell-screenshot"
        function openSelector()  { root.showSelector() }
        function captureRegion() { root.captureRegionSilent() }
        function resetState()    { root.clearRegion() }
    }
}
