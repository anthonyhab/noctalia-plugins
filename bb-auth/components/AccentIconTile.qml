import QtQuick
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    property string icon: ""
    property color accentColor: Color.mPrimary
    property int tileSize: Math.round(40 * Style.uiScaleRatio)
    property int iconPointSize: Math.round(18 * Style.uiScaleRatio)
    property bool isDark: false
    property bool hovered: false

    implicitWidth: tileSize
    implicitHeight: tileSize
    radius: Style.radiusM
    color: Qt.alpha(accentColor, isDark ? 0.12 : 0.08)
    border.width: 1
    border.color: Qt.alpha(accentColor, hovered ? 0.6 : 0.3)
    // Subtle scale on hover - confirms interactivity
    scale: hovered ? 1.02 : 1

    NIcon {
        anchors.centerIn: parent
        icon: root.icon
        pointSize: root.iconPointSize
        color: root.accentColor
    }

    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }

    }

    Behavior on border.color {
        ColorAnimation {
            duration: 150
        }

    }

}
