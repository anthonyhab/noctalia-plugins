// WindowSelector.qml - QML-native window picker using Hyprland IPC data
// Adapted from HyprQuickFrame architecture (MIT, Ronin-CK / JamDon2)
// No slurp dependency — selection happens entirely inside QML while overlay stays active.
// Window geometry comes from `hyprctl clients -j` (same as hypr-overview).

import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Widgets

Item {
    id: root

    signal regionSelected(real x, real y, real width, real height)
    signal cancelled()

    // Pass currentScreen from Main.qml so we can derive monitor origin
    property var screen: null

    property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : null
    // Monitor origin in global coords (for grim -g which needs global coords)
    property real monX: hyprMonitor ? (hyprMonitor.x || 0) : 0
    property real monY: hyprMonitor ? (hyprMonitor.y || 0) : 0

    // Window list populated by hyprctl clients -j on activation
    property var windowList: []

    // Highlighted window bounds in monitor-local (overlay) coords
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property bool hasHover: false

    onVisibleChanged: {
        if (visible) {
            windowList = []
            hasHover = false
            clientsProc.running = true
        } else {
            windowList = []
            hasHover = false
        }
    }

    // Fetch window list from Hyprland IPC (same pattern as hypr-overview)
    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try {
                    var all = JSON.parse(clientsCollector.text)
                    var wsId = root.hyprMonitor?.activeWorkspace?.id ?? -1
                    root.windowList = all.filter(function(w) {
                        return w.mapped && !w.hidden &&
                               (wsId === -1 || w.workspace.id === wsId)
                    })
                } catch(e) {
                    root.windowList = []
                }
            }
        }
    }

    Behavior on selX { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    Behavior on selY { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    Behavior on selW { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    Behavior on selH { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

    // Dimming strips around the highlighted window (top / bottom / left / right)
    // Avoids any shader/.frag.qsb dependency.
    Rectangle {
        // Top strip
        x: 0; y: 0
        width: parent.width
        height: root.hasHover ? root.selY : parent.height
        color: Qt.alpha(Color.mSurface, 0.65)
        visible: root.hasHover
    }
    Rectangle {
        // Bottom strip
        x: 0
        y: root.hasHover ? root.selY + root.selH : parent.height
        width: parent.width
        height: root.hasHover ? parent.height - (root.selY + root.selH) : 0
        color: Qt.alpha(Color.mSurface, 0.65)
        visible: root.hasHover
    }
    Rectangle {
        // Left strip (between top/bottom strips)
        x: 0
        y: root.selY
        width: root.hasHover ? root.selX : 0
        height: root.selH
        color: Qt.alpha(Color.mSurface, 0.65)
        visible: root.hasHover
    }
    Rectangle {
        // Right strip (between top/bottom strips)
        x: root.hasHover ? root.selX + root.selW : parent.width
        y: root.selY
        width: root.hasHover ? parent.width - (root.selX + root.selW) : 0
        height: root.selH
        color: Qt.alpha(Color.mSurface, 0.65)
        visible: root.hasHover
    }

    // Highlight border around hovered window
    Rectangle {
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH
        color: "transparent"
        border.color: Color.mPrimary
        border.width: 2
        radius: 4
        visible: root.hasHover
    }

    // Window size label at top-left of highlight
    NText {
        visible: root.hasHover && root.selW > 0 && root.selH > 0
        x: root.selX + 8
        y: root.selY + 8
        text: Math.round(root.selW) + " × " + Math.round(root.selH)
        color: Color.mPrimary
        pointSize: 9
        font.weight: Font.Bold
    }

    // Mouse area: hover detection + click to select
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.hasHover ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPositionChanged: (mouse) => {
            // Mouse coords are monitor-local (overlay fills one screen).
            // hyprctl at[] is global — subtract monitor origin to compare.
            var mx = mouse.x
            var my = mouse.y
            var found = false

            for (var i = 0; i < root.windowList.length; i++) {
                var w = root.windowList[i]
                if (!w.at || !w.size) continue
                var wx = w.at[0] - root.monX
                var wy = w.at[1] - root.monY
                var ww = w.size[0]
                var wh = w.size[1]
                if (ww <= 0 || wh <= 0) continue
                if (mx >= wx && mx <= wx + ww && my >= wy && my <= wy + wh) {
                    root.selX = wx
                    root.selY = wy
                    root.selW = ww
                    root.selH = wh
                    root.hasHover = true
                    found = true
                    break
                }
            }

            if (!found) root.hasHover = false
        }

        onExited: { root.hasHover = false }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) { root.cancelled(); return }
            if (root.hasHover) {
                // Emit logical global coords: overlay-local + logical monitor origin
                root.regionSelected(
                    Math.round(root.selX + root.monX),
                    Math.round(root.selY + root.monY),
                    Math.round(root.selW),
                    Math.round(root.selH)
                )
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.cancelled(); event.accepted = true }
    }
}
