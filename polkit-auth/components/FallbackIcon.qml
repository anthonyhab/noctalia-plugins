import "../ColorUtils.js" as ColorUtils
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Services.UI
import qs.Widgets

NBox {
    id: root

    property string letter: ""
    property string key: ""
    property bool showLetter: true
    property bool isDark: false
    readonly property color accent: ColorUtils.getStableColor(key, ColorUtils.getVibrantPalette(isDark))

    implicitWidth: 48 * Style.uiScaleRatio
    implicitHeight: width
    radius: Style.radiusM
    color: Qt.alpha(accent, 0.1)
    border.width: 2 * Style.uiScaleRatio
    border.color: accent

    NText {
        anchors.centerIn: parent
        text: root.letter
        visible: root.showLetter
        font.weight: Style.fontWeightBold
        pointSize: Math.round(parent.width * 0.45)
        color: root.accent
    }

}
