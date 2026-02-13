import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: flowRoot

    property string outcome: "none"
    property int epoch: 0
    property bool busy: false
    property var contextModel: null
    property var requestor: null
    property bool hasRequestorIcon: false
    property string requestorIconPath: ""
    property bool isDark: false
    property bool colorizeIcons: true
    readonly property int dotCount: 5
    property real animationPhase: 0
    property real shieldBreath: 0
    readonly property color successColor: Color.mPrimary
    readonly property color errorColor: Color.mError
    // Ensure contextModel is safe to access
    readonly property color safeAccentColor: contextModel ? contextModel.accentColor : Color.mPrimary
    readonly property string safeLabel: contextModel ? contextModel.label : ""
    readonly property string safeGlyph: contextModel ? contextModel.glyph : "shield"
    readonly property color activeColor: outcome === "fail" ? errorColor : (outcome === "success" ? successColor : safeAccentColor)

    implicitWidth: 180 * Style.uiScaleRatio
    implicitHeight: 48 * Style.uiScaleRatio
    onEpochChanged: {
        if (outcome === "fail")
            failureAnim.restart()

        if (outcome === "success") {
            successPing.restart()
            successEchoPing.restart()
        }
    }

    // Shield breathing animation — subtle y-axis float
    SequentialAnimation {
        running: outcome === "none" && Style.animationNormal > 0
        loops: Animation.Infinite

        NumberAnimation {
            target: flowRoot
            property: "shieldBreath"
            from: 0
            to: 1
            duration: 3000
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: flowRoot
            property: "shieldBreath"
            from: 1
            to: 0
            duration: 3000
            easing.type: Easing.InOutSine
        }
    }

    SequentialAnimation {
        id: handshakeAnim

        running: Style.animationNormal > 0 && outcome === "none"
        loops: Animation.Infinite

        NumberAnimation {
            target: flowRoot
            property: "animationPhase"
            from: 0
            to: 1
            duration: busy ? 800 : 1800
            easing.type: Easing.InOutSine
        }

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: pingRing
                    property: "opacity"
                    from: 0
                    to: 0.6
                    duration: 100
                }

                NumberAnimation {
                    target: pingRing
                    property: "opacity"
                    from: 0.6
                    to: 0
                    duration: 400
                }
            }

            SequentialAnimation {
                NumberAnimation {
                    target: pingRing
                    property: "scale"
                    from: 1
                    to: 1.5
                    duration: 500
                    easing.type: Easing.OutCubic
                }

                PropertyAction {
                    target: pingRing
                    property: "scale"
                    value: 1
                }
            }
        }

        PauseAnimation {
            duration: busy ? 200 : 600
        }

        PropertyAction {
            target: flowRoot
            property: "animationPhase"
            value: 0
        }
    }

    // Failure Glitch Animation
    SequentialAnimation {
        id: failureAnim

        running: false

        NumberAnimation {
            target: flowRoot
            property: "animationPhase"
            from: 0
            to: 1
            duration: 100
        }

        PropertyAction {
            target: flowRoot
            property: "animationPhase"
            value: 0
        }

        NumberAnimation {
            target: flowRoot
            property: "animationPhase"
            from: 0
            to: 1
            duration: 100
        }

        PropertyAction {
            target: flowRoot
            property: "animationPhase"
            value: 0.5
        }

        PauseAnimation {
            duration: 100
        }

        PropertyAction {
            target: flowRoot
            property: "animationPhase"
            value: 0
        }
    }

    ParallelAnimation {
        id: successPing

        SequentialAnimation {
            NumberAnimation {
                target: pingRing
                property: "opacity"
                from: 0
                to: 0.8
                duration: 150
            }

            NumberAnimation {
                target: pingRing
                property: "opacity"
                from: 0.8
                to: 0
                duration: 750
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: pingRing
                property: "scale"
                from: 1
                to: 2.4
                duration: 900
                easing.type: Easing.OutCubic
            }

            PropertyAction {
                target: pingRing
                property: "scale"
                value: 1
            }
        }
    }

    // Delayed echo ripple for double-pulse effect
    SequentialAnimation {
        id: successEchoPing

        PauseAnimation {
            duration: 200
        }

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: echoRing
                    property: "opacity"
                    from: 0
                    to: 0.3
                    duration: 100
                }
                NumberAnimation {
                    target: echoRing
                    property: "opacity"
                    from: 0.3
                    to: 0
                    duration: 600
                }
            }
            SequentialAnimation {
                NumberAnimation {
                    target: echoRing
                    property: "scale"
                    from: 1
                    to: 2.0
                    duration: 700
                    easing.type: Easing.OutCubic
                }
                PropertyAction {
                    target: echoRing
                    property: "scale"
                    value: 1
                }
            }
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Style.marginS

        // App Icon Container (Left - Squircle)
        NBox {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 46 * Style.uiScaleRatio
            Layout.preferredHeight: 46 * Style.uiScaleRatio

            radius: Style.radiusM
            color: Color.mSurfaceVariant
            border.color: flowRoot.activeColor
            border.width: 1.5 * Style.uiScaleRatio

            // Removed obnoxious accent glow
            Item {
                anchors.fill: parent
                anchors.margins: 6 * Style.uiScaleRatio

                FallbackIcon {
                    anchors.fill: parent
                    visible: !hasRequestorIcon
                    isDark: flowRoot.isDark
                    letter: {
                        if (requestor && requestor.fallbackLetter)
                            return requestor.fallbackLetter

                        if (safeLabel)
                            return safeLabel.charAt(0)

                        return "?"
                    }
                    key: {
                        if (requestor && requestor.fallbackKey)
                            return requestor.fallbackKey

                        if (safeLabel)
                            return safeLabel.toLowerCase()

                        return "unknown"
                    }
                    showLetter: true
                    radius: Style.radiusS
                }

                NImageRounded {
                    anchors.fill: parent
                    radius: Style.radiusS
                    visible: hasRequestorIcon
                    imagePath: requestorIconPath
                    imageFillMode: Image.PreserveAspectFit

                    layer.enabled: flowRoot.colorizeIcons && hasRequestorIcon
                    layer.effect: ShaderEffect {
                        property color targetColor: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mSurfaceVariant
                        property real colorizeMode: 1.0
                        fragmentShader: Qt.resolvedUrl(
                                            Quickshell.shellDir
                                            + "/Shaders/qsb/appicon_colorize.frag.qsb")
                    }
                }
            }
        }

        // Bitstream Connection
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4 * Style.uiScaleRatio

            Repeater {
                model: flowRoot.dotCount

                Rectangle {
                    width: 4 * Style.uiScaleRatio
                    height: width
                    radius: width / 2
                    color: flowRoot.activeColor
                    opacity: {
                        if (flowRoot.outcome === "success")
                            return 0.85

                        if (flowRoot.outcome === "fail") {
                            // Rapid alternating flash
                            let glitch = Math.sin(
                                    flowRoot.animationPhase * 50 + index) > 0
                            return glitch ? 0.9 : 0.05
                        }
                        // Comet-tail: active dot at full, trailing dots fade
                        let activeIdx = Math.floor(
                                flowRoot.animationPhase * flowRoot.dotCount)
                        let dist = index - activeIdx
                        if (dist < 0)
                            dist += flowRoot.dotCount
                        if (dist === 0)
                            return 0.9
                        if (dist === 1)
                            return 0.45
                        if (dist === 2)
                            return 0.2
                        return 0.08
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: flowRoot.outcome === "fail" ? 40 : 120
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }

        // System Shield Container (Right - Circle)
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 38 * Style.uiScaleRatio
            Layout.preferredHeight: 38 * Style.uiScaleRatio

            // Breathing transform
            transform: Translate {
                y: flowRoot.outcome === "none" ? (flowRoot.shieldBreath * 1.5 - 0.75) : 0
            }

            // Handshake Ping Ring
            Rectangle {
                id: pingRing

                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: "transparent"
                border.width: 1 * Style.uiScaleRatio
                border.color: flowRoot.activeColor
                opacity: 0
                scale: 1
            }

            // Echo Ping Ring (second ripple)
            Rectangle {
                id: echoRing

                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: "transparent"
                border.width: 0.5 * Style.uiScaleRatio
                border.color: flowRoot.activeColor
                opacity: 0
                scale: 1
            }

            NBox {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(flowRoot.activeColor, 0.1)
                border.width: 1.5 * Style.uiScaleRatio
                border.color: flowRoot.activeColor

                NIcon {
                    anchors.centerIn: parent
                    icon: flowRoot.outcome === "success" ? "circle-check" : safeGlyph
                    pointSize: 18 * Style.uiScaleRatio
                    color: flowRoot.activeColor

                    Behavior on icon {
                        SequentialAnimation {
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                to: 0
                                duration: 100
                            }

                            PropertyAction {}

                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                to: 1
                                duration: 200
                            }
                        }
                    }
                }
            }
        }
    }
}
