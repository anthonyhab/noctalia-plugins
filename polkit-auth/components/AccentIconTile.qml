import QtQuick
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    property string icon: ""
    property color accentColor: Color.mPrimary
    property int tileSize: Math.round(44 * Style.uiScaleRatio)
    property int iconPointSize: Math.round(20 * Style.uiScaleRatio)
    property bool isDark: false

    implicitWidth: tileSize
    implicitHeight: tileSize
    radius: Style.radiusM
    color: Qt.alpha(accentColor, isDark ? 0.15 : 0.1)
    border.width: Math.round(1.5 * Style.uiScaleRatio)
    border.color: Qt.alpha(accentColor, isDark ? 1 : 0.8)

    NIcon {
        anchors.centerIn: parent
        icon: root.icon
        pointSize: root.iconPointSize
        color: root.accentColor
    }

    Behavior on color {
        ColorAnimation {
            duration: Style.animationNormal
        }

    }

    Behavior on border.color {
        ColorAnimation {
            duration: Style.animationNormal
        }

    }

}
