import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
    id: root

    property var model: null
    property bool isDark: false
    property real fontScale: 1

    visible: model !== null
    radius: Style.radiusM
    color: Color.mSurfaceVariant
    border.color: Color.mOutline
    border.width: 1
    implicitHeight: visible ? (contentLoader.implicitHeight + (Style.marginM * 2)) : 0
    Layout.preferredHeight: visible ? implicitHeight : 0
    Layout.fillWidth: true

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // Hover Tint Overlay
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius
        color: model ? model.accentColor : "transparent"
        opacity: hoverArea.containsMouse ? (isDark ? 0.15 : 0.12) : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Style.animationFast
            }

        }

    }

    // Gradient glow
    Rectangle {
        anchors.fill: parent
        radius: parent.radius

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: {
                    if (!model)
                        return "transparent";

                    let opacity = isDark ? 0.3 : 0.22;
                    return Qt.alpha(model.accentColor, opacity);
                }
            }

            GradientStop {
                position: 0.18
                color: "transparent"
            }

        }

    }

    Loader {
        id: contentLoader

        anchors.fill: parent
        anchors.margins: Style.marginM
        sourceComponent: {
            if (!model)
                return null;

            return model.variant === "gpg" ? gpgComponent : vaultComponent;
        }
    }

    Component {
        id: gpgComponent

        RowLayout {
            spacing: Style.marginM

            AccentIconTile {
                Layout.alignment: Qt.AlignVCenter
                icon: model.tileIcon
                accentColor: model.accentColor
                iconPointSize: Math.round(model.tileIconPointSize * Style.uiScaleRatio)
                isDark: root.isDark
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                NText {
                    text: model.name
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeS * root.fontScale
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Color.mOnSurface
                }

                NText {
                    visible: model.email !== ""
                    text: model.email
                    color: Color.mOnSurfaceVariant
                    opacity: 0.9
                    pointSize: Style.fontSizeXS * root.fontScale
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                NText {
                    visible: model.meta !== ""
                    text: model.meta
                    color: Color.mOnSurfaceVariant
                    opacity: 0.7
                    pointSize: Style.fontSizeXS * 0.85 * root.fontScale
                    font.family: "Monospace"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

            }

        }

    }

    Component {
        id: vaultComponent

        RowLayout {
            spacing: Style.marginM

            AccentIconTile {
                Layout.alignment: Qt.AlignVCenter
                icon: model.tileIcon
                accentColor: model.accentColor
                iconPointSize: Math.round(model.tileIconPointSize * Style.uiScaleRatio)
                isDark: root.isDark
                tileSize: Math.round(40 * Style.uiScaleRatio)
            }

            NText {
                text: model.richText
                textFormat: Text.RichText
                pointSize: Style.fontSizeS
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

        }

    }

}
