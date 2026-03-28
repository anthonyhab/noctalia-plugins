// RegionSelector.qml - Draggable screenshot region selector with resize handles

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    // Properties
    property int minSize: 50
    property bool showGrid: true
    property bool isDragging: false
    property bool isResizing: false
    property string resizeHandle: "" // "tl", "tr", "bl", "br", "t", "b", "l", "r"
    property var recentSizes: []
    property bool popupOpen: false
    property real screenScale: 1.0

    // Computed region
    property var region: ({
        x: x,
        y: y,
        width: width,
        height: height
    })

    // Signals
    signal regionUpdated(var region)
    signal captureRequested()
    signal clearRequested()
    signal cancelled()
    signal sizeApplied(int w, int h)
    signal stateSnapshot()

    property bool hasSavedRegion: false

    // Visual styling
    color: "transparent"
    border.color: Color.mPrimary
    border.width: 2

    // Handle size
    readonly property int handleSize: 12
    readonly property int halfHandle: handleSize / 2

    function applySize(w, h) {
        root.stateSnapshot()
        var lw = Math.round(w / screenScale)
        var lh = Math.round(h / screenScale)
        root.x = Math.max(0, Math.round(root.x + root.width / 2 - lw / 2))
        root.y = Math.max(0, Math.round(root.y + root.height / 2 - lh / 2))
        root.width = lw
        root.height = lh
        root.popupOpen = false
        root.sizeApplied(Math.round(lw * screenScale), Math.round(lh * screenScale))
    }

    // Grid overlay
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: root.showGrid && !root.isDragging && !root.isResizing
        opacity: 0.3

        onPaint: {
            var ctx = getContext("2d")
            ctx.strokeStyle = Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 1)
            ctx.lineWidth = 1

            // Draw rule of thirds grid
            var w = width
            var h = height

            // Vertical lines
            ctx.beginPath()
            ctx.moveTo(w / 3, 0)
            ctx.lineTo(w / 3, h)
            ctx.moveTo(2 * w / 3, 0)
            ctx.lineTo(2 * w / 3, h)
            ctx.stroke()

            // Horizontal lines
            ctx.beginPath()
            ctx.moveTo(0, h / 3)
            ctx.lineTo(w, h / 3)
            ctx.moveTo(0, 2 * h / 3)
            ctx.lineTo(w, 2 * h / 3)
            ctx.stroke()
        }
    }

    // Corner resize handles
    Rectangle {
        id: handleTL
        width: root.handleSize
        height: root.handleSize
        color: Color.mPrimary
        x: -root.halfHandle
        y: -root.halfHandle

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeFDiagCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "tl"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dx = g.x - lastGlobalPos.x
                var dy = g.y - lastGlobalPos.y
                lastGlobalPos = g
                var newW = root.width - dx
                var newH = root.height - dy
                if (newW >= root.minSize) { root.x += dx; root.width = newW }
                if (newH >= root.minSize) { root.y += dy; root.height = newH }
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    Rectangle {
        id: handleTR
        width: root.handleSize
        height: root.handleSize
        color: Color.mPrimary
        x: root.width - root.halfHandle
        y: -root.halfHandle

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeBDiagCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "tr"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dx = g.x - lastGlobalPos.x
                var dy = g.y - lastGlobalPos.y
                lastGlobalPos = g
                var newW = root.width + dx
                var newH = root.height - dy
                if (newW >= root.minSize) root.width = newW
                if (newH >= root.minSize) { root.y += dy; root.height = newH }
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    Rectangle {
        id: handleBL
        width: root.handleSize
        height: root.handleSize
        color: Color.mPrimary
        x: -root.halfHandle
        y: root.height - root.halfHandle

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeBDiagCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "bl"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dx = g.x - lastGlobalPos.x
                var dy = g.y - lastGlobalPos.y
                lastGlobalPos = g
                var newW = root.width - dx
                var newH = root.height + dy
                if (newW >= root.minSize) { root.x += dx; root.width = newW }
                if (newH >= root.minSize) root.height = newH
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    Rectangle {
        id: handleBR
        width: root.handleSize
        height: root.handleSize
        color: Color.mPrimary
        x: root.width - root.halfHandle
        y: root.height - root.halfHandle

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeFDiagCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "br"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dx = g.x - lastGlobalPos.x
                var dy = g.y - lastGlobalPos.y
                lastGlobalPos = g
                var newW = root.width + dx
                var newH = root.height + dy
                if (newW >= root.minSize) root.width = newW
                if (newH >= root.minSize) root.height = newH
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    // Edge resize handles
    Rectangle {
        id: handleT
        width: 40
        height: 6
        color: Color.mPrimary
        anchors.horizontalCenter: parent.horizontalCenter
        y: -3

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeVerCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "t"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dy = g.y - lastGlobalPos.y
                lastGlobalPos = g
                var newH = root.height - dy
                if (newH >= root.minSize) { root.y += dy; root.height = newH }
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    Rectangle {
        id: handleB
        width: 40
        height: 6
        color: Color.mPrimary
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - 3

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeVerCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "b"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dy = g.y - lastGlobalPos.y
                lastGlobalPos = g
                var newH = root.height + dy
                if (newH >= root.minSize) root.height = newH
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    Rectangle {
        id: handleL
        width: 6
        height: 40
        color: Color.mPrimary
        anchors.verticalCenter: parent.verticalCenter
        x: -3

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeHorCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "l"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dx = g.x - lastGlobalPos.x
                lastGlobalPos = g
                var newW = root.width - dx
                if (newW >= root.minSize) { root.x += dx; root.width = newW }
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    Rectangle {
        id: handleR
        width: 6
        height: 40
        color: Color.mPrimary
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - 3

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.SizeHorCursor
            property point lastGlobalPos: Qt.point(0, 0)

            onPressed: function(mouse) {
                root.stateSnapshot()
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isResizing = true
                root.resizeHandle = "r"
            }
            onPositionChanged: function(mouse) {
                var g = mapToGlobal(mouse.x, mouse.y)
                var dx = g.x - lastGlobalPos.x
                lastGlobalPos = g
                var newW = root.width + dx
                if (newW >= root.minSize) root.width = newW
            }
            onReleased: { root.isResizing = false; root.resizeHandle = "" }
        }
    }

    // Dimension badge (clickable — opens size picker popup)
    Rectangle {
        id: dimensionBadge
        color: root.popupOpen ? Color.mSurfaceVariant : Color.mPrimary
        radius: 6
        width: badgeContent.width + 24
        height: badgeContent.height + 12
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.isDragging && !root.isResizing

        Column {
            id: badgeContent
            anchors.centerIn: parent
            spacing: 2

            NText {
                text: Math.round(root.width * screenScale) + " × " + Math.round(root.height * screenScale)
                color: root.popupOpen ? Color.mPrimary : Color.mOnPrimary
                pointSize: 13
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
            NText {
                text: Math.round(root.x * screenScale) + ", " + Math.round(root.y * screenScale)
                color: root.popupOpen
                    ? Qt.alpha(Color.mPrimary, 0.65)
                    : Qt.alpha(Color.mOnPrimary, 0.65)
                pointSize: 8
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.popupOpen = !root.popupOpen
        }
    }

    // Click-outside dismissal: covers selector area, sits behind popup
    MouseArea {
        anchors.fill: parent
        visible: root.popupOpen
        z: 99
        onClicked: root.popupOpen = false
    }

    // Size picker popup
    Rectangle {
        id: sizePopup
        visible: root.popupOpen
        z: 100
        width: 280
        height: popupColumn.height + 24
        color: Color.mSurfaceVariant
        radius: 8
        border.color: Qt.alpha(Color.mPrimary, 0.3)
        border.width: 1

        x: root.width / 2 - width / 2
        y: {
            var above = -(dimensionBadge.height + height + 16)
            return (root.y + above < 10) ? (root.height + 60) : above
        }

        function applyCustomSize() {
            var w = parseInt(wInput.text)
            var h = parseInt(hInput.text)
            if (w >= 50 && h >= 50) {
                root.applySize(w, h)
                wInput.text = ""
                hInput.text = ""
            }
        }

        Column {
            id: popupColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            NText {
                text: "Presets"
                pointSize: 8
                color: Qt.alpha(Color.mOnSurface, 0.5)
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { w: 1920, h: 1080 },
                        { w: 1280, h: 720  },
                        { w: 1024, h: 768  },
                        { w: 800,  h: 600  },
                        { w: 640,  h: 480  },
                        { w: 400,  h: 300  }
                    ]

                    Rectangle {
                        property bool hovered: presetArea.containsMouse
                        width: presetLabel.width + 16
                        height: presetLabel.height + 10
                        color: hovered ? Color.mPrimary : Qt.alpha(Color.mPrimary, 0.15)
                        radius: 4

                        NText {
                            id: presetLabel
                            anchors.centerIn: parent
                            text: modelData.w + "×" + modelData.h
                            color: parent.hovered ? Color.mOnPrimary : Color.mPrimary
                            pointSize: 10
                        }

                        MouseArea {
                            id: presetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applySize(modelData.w, modelData.h)
                        }
                    }
                }
            }

            // Recent sizes section — hidden when empty
            Column {
                visible: root.recentSizes.length > 0
                width: parent.width
                spacing: 6

                NText {
                    text: "Recent"
                    pointSize: 8
                    color: Qt.alpha(Color.mOnSurface, 0.5)
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.recentSizes

                        Rectangle {
                            property bool hovered: recentArea.containsMouse
                            width: recentLabel.width + 16
                            height: recentLabel.height + 10
                            color: hovered ? Color.mSecondary : Qt.alpha(Color.mSecondary, 0.15)
                            radius: 4

                            NText {
                                id: recentLabel
                                anchors.centerIn: parent
                                text: modelData.w + "×" + modelData.h
                                color: parent.hovered ? Color.mOnSecondary : Color.mSecondary
                                pointSize: 10
                            }

                            MouseArea {
                                id: recentArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applySize(modelData.w, modelData.h)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.alpha(Color.mOnSurface, 0.12)
            }

            // Custom size input row
            Row {
                spacing: 6

                Rectangle {
                    width: 70
                    height: 30
                    color: Color.mSurface
                    radius: 4
                    border.color: wInput.activeFocus ? Color.mPrimary : Qt.alpha(Color.mOnSurface, 0.2)
                    border.width: 1

                    TextInput {
                        id: wInput
                        anchors.fill: parent
                        anchors.margins: 6
                        color: Color.mOnSurface
                        font.pixelSize: 13
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 50; top: Math.round(7680 / screenScale) }
                        Keys.onPressed: function(e) {
                            if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                                hInput.forceActiveFocus()
                                e.accepted = true
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                sizePopup.applyCustomSize()
                                e.accepted = true
                            } else if (e.key === Qt.Key_Escape) {
                                root.popupOpen = false
                                e.accepted = true
                            }
                        }
                    }
                }

                NText {
                    text: "×"
                    color: Qt.alpha(Color.mOnSurface, 0.5)
                    pointSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 70
                    height: 30
                    color: Color.mSurface
                    radius: 4
                    border.color: hInput.activeFocus ? Color.mPrimary : Qt.alpha(Color.mOnSurface, 0.2)
                    border.width: 1

                    TextInput {
                        id: hInput
                        anchors.fill: parent
                        anchors.margins: 6
                        color: Color.mOnSurface
                        font.pixelSize: 13
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 50; top: Math.round(7680 / screenScale) }
                        Keys.onPressed: function(e) {
                            if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                                wInput.forceActiveFocus()
                                e.accepted = true
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                sizePopup.applyCustomSize()
                                e.accepted = true
                            } else if (e.key === Qt.Key_Escape) {
                                root.popupOpen = false
                                e.accepted = true
                            }
                        }
                    }
                }

                Rectangle {
                    width: applyLabel.width + 20
                    height: 30
                    color: applyArea.containsMouse ? Color.mPrimary : Qt.alpha(Color.mPrimary, 0.8)
                    radius: 4

                    NText {
                        id: applyLabel
                        text: "Apply"
                        color: Color.mOnPrimary
                        pointSize: 10
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sizePopup.applyCustomSize()
                    }
                }
            }
        }
    }

    // Action bar (Capture + Clear) inside selection
    Row {
        id: actionBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        visible: !root.isDragging && !root.isResizing && root.height >= 80
        z: 50

        Rectangle {
            width: captureLabel.width + 24; height: 32
            color: captureArea.containsMouse ? Qt.alpha(Color.mPrimary, 0.8) : Color.mPrimary
            radius: 6
            NText { id: captureLabel; text: "Capture"; color: Color.mOnPrimary; pointSize: 9; font.weight: Font.Bold; anchors.centerIn: parent }
            MouseArea { id: captureArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.captureRequested() }
        }

        Rectangle {
            visible: root.hasSavedRegion
            width: clearLabel.width + 20; height: 32
            color: clearArea.containsMouse ? Qt.alpha(Color.mError, 0.8) : Qt.alpha(Color.mError, 0.6)
            radius: 6
            NText { id: clearLabel; text: "Clear"; color: "#FFFFFF"; pointSize: 8; font.weight: Font.Bold; anchors.centerIn: parent }
            MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearRequested() }
        }
    }

    // Center drag area (left-click = move, right-click = resize from nearest corner)
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.margins: root.handleSize
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: isRightResize ? Qt.SizeFDiagCursor
                                   : (root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
        property point lastGlobalPos: Qt.point(0, 0)
        property bool isRightResize: false
        // Which corner is being dragged: "tl", "tr", "bl", "br"
        property string resizeCorner: ""

        onPressed: function(mouse) {
            if (root.isResizing) return
            root.stateSnapshot()

            if (mouse.button === Qt.RightButton) {
                var cx = root.width / 2 - root.handleSize
                var cy = root.height / 2 - root.handleSize
                // Nearest corner follows cursor; pick based on quadrant
                if (mouse.x < cx && mouse.y < cy) resizeCorner = "tl"
                else if (mouse.x >= cx && mouse.y < cy) resizeCorner = "tr"
                else if (mouse.x < cx && mouse.y >= cy) resizeCorner = "bl"
                else resizeCorner = "br"

                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                isRightResize = true
                root.isResizing = true
            } else {
                lastGlobalPos = mapToGlobal(mouse.x, mouse.y)
                root.isDragging = true
            }
        }
        onPositionChanged: function(mouse) {
            var g = mapToGlobal(mouse.x, mouse.y)
            if (isRightResize) {
                var dx = g.x - lastGlobalPos.x
                var dy = g.y - lastGlobalPos.y
                lastGlobalPos = g
                var newW, newH
                if (resizeCorner === "tl") {
                    newW = root.width - dx; newH = root.height - dy
                    if (newW >= root.minSize) { root.x += dx; root.width = newW }
                    if (newH >= root.minSize) { root.y += dy; root.height = newH }
                } else if (resizeCorner === "tr") {
                    newW = root.width + dx; newH = root.height - dy
                    if (newW >= root.minSize) root.width = newW
                    if (newH >= root.minSize) { root.y += dy; root.height = newH }
                } else if (resizeCorner === "bl") {
                    newW = root.width - dx; newH = root.height + dy
                    if (newW >= root.minSize) { root.x += dx; root.width = newW }
                    if (newH >= root.minSize) root.height = newH
                } else {
                    newW = root.width + dx; newH = root.height + dy
                    if (newW >= root.minSize) root.width = newW
                    if (newH >= root.minSize) root.height = newH
                }
            } else if (root.isDragging) {
                root.x = Math.max(0, root.x + g.x - lastGlobalPos.x)
                root.y = Math.max(0, root.y + g.y - lastGlobalPos.y)
                lastGlobalPos = g
            }
        }
        onReleased: {
            if (isRightResize) {
                isRightResize = false
                resizeCorner = ""
                root.isResizing = false
                root.regionUpdated(root.region)
            } else {
                root.isDragging = false
                root.regionUpdated(root.region)
            }
        }
        onDoubleClicked: root.captureRequested()
    }

    // Keyboard shortcuts
    Keys.onPressed: function(event) {
        switch (event.key) {
            case Qt.Key_Escape:
                if (root.popupOpen) {
                    root.popupOpen = false
                } else {
                    root.cancelled()
                }
                event.accepted = true
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (!root.popupOpen) {
                    root.captureRequested()
                    event.accepted = true
                }
                break
        }
    }

    onPopupOpenChanged: {
        if (!popupOpen) root.forceActiveFocus()
    }

    Component.onCompleted: {
        forceActiveFocus()
    }
}
