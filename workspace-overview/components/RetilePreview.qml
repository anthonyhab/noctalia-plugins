import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
    id: root

    // Zone visualization props
    property real targetX: 0
    property real targetY: 0
    property real targetW: 0
    property real targetH: 0
    property string activeDirection: "" // "l", "r", "u", "d", "swap", ""
    property string pendingDirection: ""
    property real directionConfidence: 0
    property bool directionLocked: false
    // Result preview props
    property real previewX: 0
    property real previewY: 0
    property real previewWidth: 0
    property real previewHeight: 0
    property real targetNewX: 0
    property real targetNewY: 0
    property real targetNewW: 0
    property real targetNewH: 0
    property bool showPreview: false
    property real previewOpacityScale: 0.55
    readonly property real zoneEdgeSize: 0.33
    readonly property color zoneColor: Color.mPrimary
    readonly property real zoneOpacity: 0.06 * previewOpacityScale
    readonly property real activeOpacity: (directionLocked ? 0.5 : 0.36) * previewOpacityScale
    readonly property real pendingOpacity: 0.25 * previewOpacityScale

    function getDirectionIcon(direction) {
        switch (direction) {
        case "l":
            return "\ue314";
        case "r":
            return "\ue315";
        case "u":
            return "\ue316";
        case "d":
            return "\ue313";
        case "swap":
            return "\ue8d4";
        default:
            return "";
        }
    }

    function getDirectionLabel(direction) {
        switch (direction) {
        case "l":
            return "Split Left";
        case "r":
            return "Split Right";
        case "u":
            return "Split Top";
        case "d":
            return "Split Bottom";
        case "swap":
            return "Swap";
        default:
            return "";
        }
    }

    function zoneOpacityFor(direction) {
        if (activeDirection === direction)
            return activeOpacity;

        if (pendingDirection === direction)
            return pendingOpacity;

        return zoneOpacity;
    }

    visible: showPreview && targetW > 0 && targetH > 0
    z: 99998

    // Zone overlay container
    Item {
        anchors.fill: parent

        // Left zone
        Rectangle {
            x: targetX
            y: targetY
            width: targetW * zoneEdgeSize
            height: targetH
            radius: Style.radiusS
            color: zoneColor
            opacity: zoneOpacityFor("l")

            // Icon and label for active zone
            Column {
                anchors.centerIn: parent
                spacing: 4
                visible: activeDirection === "l"

                Text {
                    text: getDirectionIcon("l")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.25
                    font.family: "Material Symbols Outlined"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: getDirectionLabel("l")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.08
                    font.family: Settings.data.ui.fontDefault
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

        }

        // Right zone
        Rectangle {
            x: targetX + targetW * (1 - zoneEdgeSize)
            y: targetY
            width: targetW * zoneEdgeSize
            height: targetH
            radius: Style.radiusS
            color: zoneColor
            opacity: zoneOpacityFor("r")

            Column {
                anchors.centerIn: parent
                spacing: 4
                visible: activeDirection === "r"

                Text {
                    text: getDirectionIcon("r")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.25
                    font.family: "Material Symbols Outlined"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: getDirectionLabel("r")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.08
                    font.family: Settings.data.ui.fontDefault
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

        }

        // Top zone
        Rectangle {
            x: targetX + targetW * zoneEdgeSize
            y: targetY
            width: targetW * (1 - 2 * zoneEdgeSize)
            height: targetH * zoneEdgeSize
            radius: Style.radiusS
            color: zoneColor
            opacity: zoneOpacityFor("u")

            Column {
                anchors.centerIn: parent
                spacing: 4
                visible: activeDirection === "u"

                Text {
                    text: getDirectionIcon("u")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.25
                    font.family: "Material Symbols Outlined"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: getDirectionLabel("u")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.08
                    font.family: Settings.data.ui.fontDefault
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

        }

        // Bottom zone
        Rectangle {
            x: targetX + targetW * zoneEdgeSize
            y: targetY + targetH * (1 - zoneEdgeSize)
            width: targetW * (1 - 2 * zoneEdgeSize)
            height: targetH * zoneEdgeSize
            radius: Style.radiusS
            color: zoneColor
            opacity: zoneOpacityFor("d")

            Column {
                anchors.centerIn: parent
                spacing: 4
                visible: activeDirection === "d"

                Text {
                    text: getDirectionIcon("d")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.25
                    font.family: "Material Symbols Outlined"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: getDirectionLabel("d")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.08
                    font.family: Settings.data.ui.fontDefault
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

        }

        // Center zone (swap)
        Rectangle {
            x: targetX + targetW * zoneEdgeSize
            y: targetY + targetH * zoneEdgeSize
            width: targetW * (1 - 2 * zoneEdgeSize)
            height: targetH * (1 - 2 * zoneEdgeSize)
            radius: Style.radiusS
            color: zoneColor
            opacity: zoneOpacityFor("swap")

            Column {
                anchors.centerIn: parent
                spacing: 4
                visible: activeDirection === "swap"

                Text {
                    text: getDirectionIcon("swap")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.25
                    font.family: "Material Symbols Outlined"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: getDirectionLabel("swap")
                    color: zoneColor
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.08
                    font.family: Settings.data.ui.fontDefault
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

        }

    }

    Rectangle {
        visible: showPreview && (activeDirection !== "" || pendingDirection !== "")
        x: targetX + Math.max(8, targetW * 0.03)
        y: targetY + Math.max(8, targetH * 0.03)
        radius: Style.radiusS
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.85)
        border.width: 1
        border.color: Qt.rgba(zoneColor.r, zoneColor.g, zoneColor.b, directionLocked ? 0.65 : 0.45)
        width: statusText.implicitWidth + 12
        height: statusText.implicitHeight + 8

        Text {
            id: statusText

            anchors.centerIn: parent
            text: {
                var dir = activeDirection !== "" ? activeDirection : pendingDirection;
                var label = getDirectionLabel(dir);
                var confidence = Math.round(Math.max(0, Math.min(1, directionConfidence)) * 100);
                return directionLocked ? (label + "  " + confidence + "%") : (label + "  ...");
            }
            color: Color.mOnSurface
            font.family: Settings.data.ui.fontDefault
            font.pixelSize: Math.min(12, Math.max(9, Math.min(targetW, targetH) * 0.08))
        }

    }

    // Result preview - where dragged window lands
    Rectangle {
        x: previewX
        y: previewY
        width: previewWidth
        height: previewHeight
        radius: Style.radiusM
        color: Qt.rgba(zoneColor.r, zoneColor.g, zoneColor.b, directionLocked ? 0.28 : 0.18)
        border.color: directionLocked ? Qt.lighter(zoneColor, 1.15) : Qt.rgba(zoneColor.r, zoneColor.g, zoneColor.b, 0.85)
        border.width: directionLocked ? 2 : 1
        opacity: (directionLocked ? 1 : 0.9) * previewOpacityScale
        visible: showPreview && activeDirection !== "" && activeDirection !== "swap"
        layer.enabled: true

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(zoneColor.r, zoneColor.g, zoneColor.b, 0.3)
            shadowBlur: 0.3
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 2
        }

        Behavior on x {
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }

        }

    }

    // Target shrink preview - where target window shrinks to
    Rectangle {
        x: targetNewX
        y: targetNewY
        width: targetNewW
        height: targetNewH
        radius: Style.radiusM
        color: "transparent"
        border.color: Qt.rgba(zoneColor.r, zoneColor.g, zoneColor.b, directionLocked ? 0.65 : 0.45)
        border.width: 1
        opacity: (directionLocked ? 0.62 : 0.45) * previewOpacityScale
        visible: showPreview && activeDirection !== "" && activeDirection !== "swap"

        Behavior on x {
            NumberAnimation {
                duration: 85
                easing.type: Easing.OutCubic
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: 85
                easing.type: Easing.OutCubic
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: 85
                easing.type: Easing.OutCubic
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 85
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 80
            easing.type: Easing.OutCubic
        }

    }

}
