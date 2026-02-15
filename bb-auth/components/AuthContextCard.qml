import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NBox {
    id: root

    property var model: null
    property bool isDark: false
    property real fontScale: 1

    visible: model !== null
    radius: Style.radiusM
    color: Color.mSurfaceVariant
    border.color: clickArea.containsMouse ? Qt.alpha(model ? model.accentColor : Color.mOutline, 0.4) : Color.mOutline
    border.width: 1
    implicitHeight: visible ? (contentLoader.implicitHeight + (Style.marginM * 2)) : 0
    Layout.preferredHeight: visible ? implicitHeight : 0
    Layout.fillWidth: true

    // Anchor positioned above the card so tooltip doesn't interfere with hover
    Item {
        id: tooltipAnchor

        anchors.bottom: parent.top
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: 1
        height: 1
    }

    MouseArea {
        id: clickArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (model && model.copyText) {
                Quickshell.execDetached(["wl-copy", model.copyText]);
                TooltipService.show(tooltipAnchor, model.copyTooltip || "Copied to clipboard");
                Qt.callLater(function() {
                    TooltipService.hide();
                });
            }
        }
        onEntered: {
            if (model && model.copyText)
                TooltipService.show(tooltipAnchor, model.copyHint || "Click to copy details");

        }
        onExited: TooltipService.hide()
    }

    // Subtle hover tint - indicates this element is interactive
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius
        color: model ? model.accentColor : "transparent"
        opacity: clickArea.containsMouse ? (isDark ? 0.05 : 0.03) : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
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
                hovered: clickArea.containsMouse
            }

            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true

                NText {
                    text: model.name
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeS * root.fontScale
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Color.mOnSurface
                }

                // Email as a subtle pill - groups related info visually
                Rectangle {
                    visible: model.email !== ""
                    color: Qt.alpha(model.accentColor, 0.1)
                    radius: Style.radiusS
                    implicitWidth: emailLabel.implicitWidth + 10
                    implicitHeight: emailLabel.implicitHeight + 5

                    NText {
                        id: emailLabel

                        anchors.centerIn: parent
                        text: model.email
                        color: model.accentColor
                        opacity: 0.9
                        pointSize: Style.fontSizeXS * root.fontScale
                    }

                }

                // Meta info - technical details in subdued style
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
                hovered: clickArea.containsMouse
            }

            NText {
                text: model.richText
                textFormat: Text.RichText
                pointSize: Style.fontSizeS * root.fontScale
                Layout.fillWidth: true
                Layout.minimumWidth: 100
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
            }

        }

    }

    // Border color transition - smooth state change feedback
    Behavior on border.color {
        ColorAnimation {
            duration: 150
        }

    }

}
