import "../ColorUtils.js" as ColorUtils
import QtQuick

Rectangle {
    id: root

    property bool isDark: false
    property string letter: "?"
    property string key: "unknown"
    property bool showLetter: true

    color: ColorUtils.getStableColor(root.key,
                                     ColorUtils.getVibrantPalette(root.isDark))

    Text {
        anchors.centerIn: parent
        text: root.letter
        font.bold: true
        font.pixelSize: parent.height * 0.4
        color: root.isDark ? "black" : "white"
        visible: root.showLetter
    }
}
