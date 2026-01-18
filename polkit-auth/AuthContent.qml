import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "ColorUtils.js" as ColorUtils
import "components"
import "utils/AuthLogic.js" as AuthLogic

Item {
    id: root

    // Required properties from parent
    property var pluginMain: null
    property var incomingRequest: null
    property var request: null

    onIncomingRequestChanged: {
        if (incomingRequest) {
            // New request: Reset state and accept
            successState = false
            outcome = "none"
            request = incomingRequest
        } else if (!successState) {
            // Clear only if NOT in success state to prevent UI glitch during exit
            request = null
        }
    }

    property bool busy: false
    property bool agentAvailable: true
    property string statusText: ""
    property string errorText: ""

    // Internal state
    property bool successState: false
    property bool timedOutState: false
    property bool wasEverRequested: false
    property bool revealPassword: false
    property bool capsLockOn: false
    property bool showDetails: false
    property bool animateIn: false
    property bool isDark: true // Default to dark, bind to Color.isDark if available in future

    // Outcome state machine
    property string outcome: "none" // "none", "success", "fail"
    property int outcomeEpoch: 0    // Increments to restart animations

    // Submit state (tight feedback loop)
    property bool awaitingResult: false
    property bool submitPulseActive: false
    readonly property bool busyVisual: (busy || awaitingResult || submitPulseActive) && outcome === "none" && !successState

    readonly property bool detailsEnabled: pluginMain ? pluginMain.getSetting("showDetailsByDefault", false) : false

    onDetailsEnabledChanged: {
        if (!detailsEnabled) {
            showDetails = false
        }
    }

    onRequestChanged: {
        showDetails = false
    }

    // --- 0. RICH CONTEXT DATA ---
    readonly property var appProfiles: AuthLogic.getAppProfiles(Color)
    readonly property var contextModel: AuthLogic.getContextModel(request, requestor, subject, appProfiles, Color)


    readonly property var requestor: request?.requestor ?? null
    readonly property var subject: request?.subject ?? null
    readonly property string requestorIconName: {
        if (requestor && requestor.iconName)
            return requestor.iconName
        if (request && request.hint && request.hint.iconName)
            return request.hint.iconName
        if (request && request.icon)
            return request.icon
        return ""
    }
    readonly property string requestorIconPath: {
        if (!requestorIconName)
            return ""
        if (requestorIconName.startsWith("/"))
            return requestorIconName
        return ThemeIcons.iconFromName(requestorIconName, "")
    }
    readonly property bool hasRequestorIcon: requestorIconPath !== ""

    readonly property var richContext: AuthLogic.getRichContext(request, Color, secondaryAccent)


    readonly property var gpgInfo: AuthLogic.getGpgInfo(request)


    readonly property string displayAction: AuthLogic.getDisplayAction(request, richContext, secondaryAccent)


    // Signal to request closing the container (window or panel)
    signal closeRequested()

    // --- 1. THEME & METRICS ---
    readonly property double fontScale: (typeof Settings !== "undefined" ? Settings.data.ui.fontDefaultScale : 1.0)
    readonly property int baseSize: Style.baseWidgetSize
    readonly property int controlHeight: Math.round(baseSize * 1.1)
    readonly property int iconTile: baseSize
    readonly property int overlayButton: Math.round(baseSize * 0.75)

    // Spacing Grid (Noctalia Native)
    readonly property int framePad: Style.marginXL
    readonly property int sectionGap: Style.marginL
    readonly property int microGap: Style.marginS
    readonly property int cardPad: Style.marginM

    readonly property color secondaryAccent: Color.mSecondary !== undefined ? Color.mSecondary : Color.mPrimary
    readonly property color secondaryAccentContainer: Color.mSecondaryContainer !== undefined ? Color.mSecondaryContainer : Qt.alpha(secondaryAccent, 0.18)
    readonly property color colorFlowLine: Qt.alpha(secondaryAccent, 0.2)
    readonly property color colorFlowActive: secondaryAccent
    readonly property int cardRadius: Style.radiusL

    // --- 2. COMPUTED DATA ---
    readonly property color successColor: Color.mPrimary
    readonly property color errorColor: Color.mError
    readonly property bool hasRequest: !!(request && request.id)
    readonly property string displayUser: formatUser(request?.user ?? "")
    readonly property bool fingerprintAvailable: !!(request && request.fingerprintAvailable)

    readonly property string commandPath: {
        if (!hasRequest || !request.message) return ""
        const msg = request.message
        const match = msg.match(/'([^']+)'/)
        if (match && match[1]) return match[1]
        const matchPath = msg.match(/(\/[a-zA-Z0-9_\-\.\/]+)/)
        if (matchPath && matchPath[1]) return matchPath[1]
        return ""
    }

    readonly property string detailsSummary: {
        if (!hasRequest) return ""
        const source = (request.actionId || "").includes("polkit") ? "polkit" : "keyring"
        const actionId = request.actionId || "N/A"
        const message = request.message || "N/A"
        const cmdline = (subject && subject.cmdline) || "N/A"
        const description = request.description || "N/A"
        return "Source: " + source + "\nAction: " + actionId + "\nMessage: " + message + "\nCommand: " + cmdline + "\nDescription: " + description
    }

    function trOrDefault(key, fallback) {
        if (pluginMain?.pluginApi?.tr) {
            const val = pluginMain.pluginApi.tr(key)
            if (val && !val.startsWith("!!") && !val.startsWith("##"))
                return val
        }
        return fallback
    }

    function formatUser(value) {
        if (!value)
            return ""
        if (value.indexOf("unix-user:") === 0)
            return value.slice("unix-user:".length)
        return value
    }

    function startSubmitFeedback() {
        submitPulseActive = true
        submitPulseTimer.restart()
        awaitingResult = true
        outcome = "none"
    }

    function submitPasswordAttempt() {
        if (!hasRequest)
            return
        if (successState)
            return
        if (busyVisual)
            return
        if (!passwordInput.text || passwordInput.text.length === 0)
            return

        startSubmitFeedback()
        pluginMain?.submitPassword(passwordInput.text)
    }

    function focusPasswordInput() {

        if (hasRequest && passwordInput.visible) {
            root.forceActiveFocus()
            passwordInput.inputItem.forceActiveFocus()
        }
    }

    // --- 3. DYNAMIC SIZING ---
    implicitWidth: Math.round(360 * Style.uiScaleRatio)
    implicitHeight: targetHeight

    readonly property int targetHeight: {
        let base = 0
        if (!agentAvailable)
            base = errorSection.implicitHeight
        else if (hasRequest || successState)
            base = mainContentCol.implicitHeight
        else if (timedOutState)
            base = timeoutSection.implicitHeight
        else
            base = idleSection.implicitHeight

        // Perfectly symmetrical framePad
        return base + (framePad * 2)
    }

    Connections {
        target: pluginMain
        function onRequestCompleted(success) {
            if (root.visible) console.log("AuthContent: onRequestCompleted success=" + success)
            awaitingResult = false
            submitPulseActive = false
            submitPulseTimer.stop()

            if (success) {
                outcome = "success"
                outcomeEpoch++
                successState = true
            } else {
                outcome = "fail"
                outcomeEpoch++
                shakeAnim.restart()
                passwordInput.text = ""
                focusPasswordInput()
            }
        }
    }

    onErrorTextChanged: {
        if (awaitingResult && errorText.length > 0 && !successState) {
            awaitingResult = false
            submitPulseActive = false
            submitPulseTimer.stop()
            outcome = "fail"
            outcomeEpoch++
            shakeAnim.restart()
        }
    }

    // --- 4. COMPONENTS ---

    NIconButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.marginL
        z: 10
        icon: "close"
        baseSize: Style.baseWidgetSize * 0.7
        colorBg: Qt.alpha(Color.mSurfaceVariant, 0.5)
        radius: width / 2
        tooltipText: trOrDefault("actions.close", "Close")
        onClicked: root.closeRequested()
    }

    // --- 5. MAIN CONTENT ---
    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.topMargin: framePad
        anchors.bottomMargin: framePad
        anchors.leftMargin: framePad
        anchors.rightMargin: framePad

        opacity: root.animateIn ? 1.0 : 0.0
        transform: [
            Scale {
                origin.x: mainContainer.width / 2
                origin.y: mainContainer.height / 2
                xScale: root.animateIn ? 1.0 : 0.95
                yScale: root.animateIn ? 1.0 : 0.95
            },
            Translate {
                y: root.animateIn ? 0 : 16
            }
        ]
        Behavior on opacity {
            NumberAnimation {
                duration: Style.animationNormal
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: mainContentCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: sectionGap
            visible: (hasRequest || successState) && !timedOutState && agentAvailable

            ColumnLayout {
                id: headerStack
                Layout.fillWidth: true
                spacing: microGap
                    ConnectionFlow {
                        Layout.alignment: Qt.AlignHCenter
                        outcome: root.outcome
                        epoch: root.outcomeEpoch
                        busy: root.busy
                        contextModel: root.contextModel
                        requestor: root.requestor
                        hasRequestorIcon: root.hasRequestorIcon
                        requestorIconPath: root.requestorIconPath
                        isDark: root.isDark
                    }

                NText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    pointSize: Style.fontSizeM * fontScale
                    color: Color.mOnSurface
                    text: {
                        let appName = (requestor && requestor.displayName) || ""
                        if (!appName || appName.toLowerCase() === "unknown")
                            return "Allow an application to " + displayAction
                        return "Allow <font face='Monospace'><b>" + appName + "</b></font> to " + displayAction
                    }
                }
            }

            // Details Cluster (diagnostics)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: detailsEnabled
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: detailsEnabled ? (28 * Style.uiScaleRatio) : 0
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: microGap
                        opacity: detailsMA.containsMouse ? 1.0 : 0.6
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                        NText {
                            text: root.showDetails ? trOrDefault("actions.hide-details", "Hide details") : trOrDefault("actions.show-details", "Show details")
                            color: Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeXS * fontScale
                            font.weight: 500
                        }
                        NIcon {
                            icon: "chevron-down"
                            pointSize: 10 * Style.uiScaleRatio
                            color: Color.mOnSurfaceVariant
                            rotation: root.showDetails ? 180 : 0
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: detailsMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showDetails = !root.showDetails
                        hoverEnabled: true
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.showDetails ? Math.min(detailsCard.implicitHeight, 200 * Style.uiScaleRatio) : 0
                    clip: true
                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutQuint
                        }
                    }
                    opacity: root.showDetails ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                        }
                    }
                    NBox {
                        id: detailsCard
                        width: parent.width
                        radius: root.cardRadius
                        color: Color.mSurfaceVariant
                        border.color: Color.mOutline
                        border.width: 1
                        implicitHeight: contextCol.implicitHeight + (cardPad * 2)



                        ScrollView {
                            id: detailsScrollView
                            anchors.fill: parent
                            anchors.margins: 2
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                id: contextCol
                                width: detailsCard.width - (cardPad * 2)
                                x: cardPad
                                y: cardPad
                                spacing: microGap
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: displayUser.length > 0
                                    spacing: Style.marginM
                                    NIcon {
                                        icon: "user"
                                        pointSize: Style.fontSizeS
                                        color: Color.mOnSurfaceVariant
                                    }
                                    NText {
                                        text: displayUser
                                        font.weight: 500
                                        pointSize: Style.fontSizeM * fontScale
                                    }
                                }
                                NDivider {
                                    visible: displayUser.length > 0 && (subject !== null || commandPath !== "")
                                    Layout.fillWidth: true
                                }
                                Item {
                                    id: detailsCopyArea
                                    Layout.fillWidth: true
                                    implicitHeight: detailsTextCol.implicitHeight

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: TooltipService.show(detailsCopyArea, trOrDefault("actions.copy-details", "Click to copy details"))
                                        onExited: TooltipService.hide()
                                        onClicked: {
                                            TooltipService.hide()
                                            Quickshell.execDetached(["wl-copy", root.detailsSummary])
                                        }
                                    }

                                    ColumnLayout {
                                        id: detailsTextCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        spacing: 2

                                        NText {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: (subject && subject.exe) || commandPath
                                            font.family: "Monospace"
                                            color: Color.mOnSurfaceVariant
                                            pointSize: Style.fontSizeXS * 1.1 * fontScale
                                            wrapMode: Text.Wrap
                                        }
                                        NText {
                                            visible: !!(subject && subject.cmdline && subject.cmdline !== subject.exe)
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: (subject && subject.cmdline) || ""
                                            font.family: "Monospace"
                                            color: Color.mOnSurfaceVariant
                                            pointSize: Style.fontSizeXS * 0.9 * fontScale
                                            wrapMode: Text.Wrap
                                        }
                                        NText {
                                            visible: !!(request && request.description) && !gpgInfo
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: (request && request.description) || ""
                                            color: Color.mOnSurfaceVariant
                                            pointSize: Style.fontSizeXS * fontScale
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                        }
                    }
                }
            }

            }

            NBox {
                id: contextCard
                Layout.fillWidth: true
                visible: gpgInfo !== null || (contextModel && (contextModel.label === "1Password" || contextModel.label === "Bitwarden" || contextModel.label === "KeePassXC" || contextModel.label === "Proton Pass"))
                radius: root.cardRadius
                color: Color.mSurfaceVariant
                border.color: Color.mOutline
                border.width: 1
                implicitHeight: cardContent.implicitHeight + (cardPad * 2)

                // Proper rounded clipping (Noctalia pattern): use MultiEffect mask
                // on a content layer, not on the whole card.
                Item {
                    id: contextCardClip
                    anchors.fill: parent
                    anchors.margins: contextCard.border.width

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        // These reduce edge halos and "random" clipping artifacts
                        maskThresholdMin: 0.95
                        maskSpreadAtMin: 0.15
                        maskSource: ShaderEffectSource {
                            sourceItem: Rectangle {
                                width: contextCardClip.width
                                height: contextCardClip.height
                                radius: Math.max(0, contextCard.radius - contextCard.border.width)
                                color: "white"
                            }
                        }
                    }

                    // Accent strip (clipped to rounded container)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3 * Style.uiScaleRatio
                        color: contextModel.accentColor
                    }

                    ColumnLayout {
                        id: cardContent
                        anchors.fill: parent
                        anchors.leftMargin: cardPad + (4 * Style.uiScaleRatio)
                        anchors.rightMargin: cardPad
                        anchors.topMargin: cardPad
                        anchors.bottomMargin: cardPad
                        spacing: microGap

                        RowLayout {
                        visible: gpgInfo !== null
                        Layout.fillWidth: true
                        spacing: Style.marginM
                        NIcon {
                            Layout.alignment: Qt.AlignVCenter
                            icon: (gpgInfo && gpgInfo.isGithub) ? "brand-github" : "key"
                            pointSize: 22 * Style.uiScaleRatio
                            color: contextModel.accentColor
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            NText {
                                text: gpgInfo ? gpgInfo.name : ""
                                font.weight: Style.fontWeightBold
                                pointSize: Style.fontSizeS * fontScale
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                color: Color.mOnSurface
                            }
                            NText {
                                visible: !!(gpgInfo && gpgInfo.email)
                                text: gpgInfo ? gpgInfo.email : ""
                                color: Color.mOnSurfaceVariant
                                opacity: 0.8
                                pointSize: Style.fontSizeXS * fontScale
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                            NText {
                                visible: !!(gpgInfo && gpgInfo.keyType)
                                text: gpgInfo ? (gpgInfo.keyType + " • " + gpgInfo.keyId) : ""
                                color: Color.mOnSurfaceVariant
                                opacity: 0.5
                                pointSize: Style.fontSizeXS * 0.85 * fontScale
                                font.family: "Monospace"
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    RowLayout {
                        visible: gpgInfo === null && (contextModel && (contextModel.label === "1Password" || contextModel.label === "Bitwarden" || contextModel.label === "KeePassXC" || contextModel.label === "Proton Pass"))
                        Layout.fillWidth: true
                        spacing: Style.marginM
                        NIcon {
                            icon: contextModel.glyph
                            pointSize: 18 * Style.uiScaleRatio
                            color: contextModel.accentColor
                        }
                        NText {
                            text: "Unlock <b><font color='" + contextModel.accentColor + "'>" + contextModel.label + "</font></b> vault"
                            textFormat: Text.RichText
                            pointSize: Style.fontSizeS
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            }

            NBox {
                id: inputWrapper
                Layout.fillWidth: true
                implicitHeight: passwordInput.implicitHeight + (cardPad * 2)
                radius: root.cardRadius
                color: {
                    if (successState) return Qt.alpha(successColor, 0.12)
                    if (outcome === "fail") return Qt.alpha(errorColor, 0.15)
                    return Color.mSurfaceVariant
                }
                border.color: {
                    if (successState) return successColor
                    if (outcome === "fail") return errorColor
                    return passwordInput.activeFocus ? Color.mPrimary : Color.mOutline
                }
                border.width: (successState || outcome === "fail") ? 2.0 : (passwordInput.activeFocus ? 1.2 : 1.0)
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on border.width { NumberAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 250 } }

                // Success Message (Centered)
                NText {
                    anchors.centerIn: parent
                    visible: successState
                    text: "Authenticated"
                    color: successColor
                    font.family: "Monospace"
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeM * fontScale
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                NTextInput {
                    id: passwordInput
                    anchors.fill: parent
                    visible: !successState
                    opacity: busyVisual ? 0.6 : 1.0
                    anchors.leftMargin: cardPad
                    anchors.topMargin: cardPad
                    anchors.bottomMargin: cardPad
                    anchors.rightMargin: overlayIcons.width + cardPad + microGap
                    inputItem.font.pointSize: Style.fontSizeM * fontScale
                    inputItem.font.family: Settings.data.ui.fontDefault
                    inputItem.verticalAlignment: TextInput.AlignVCenter
                    placeholderText: request?.prompt || trOrDefault("placeholders.password", "Enter password")
                    text: ""
                    inputItem.echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
                    enabled: !busyVisual
                    Component.onCompleted: {
                        if (passwordInput.background) passwordInput.background.visible = false
                    }
                    KeyNavigation.tab: authButton
                    inputItem.Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_CapsLock)
                            root.capsLockOn = !root.capsLockOn
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            submitPasswordAttempt()
                        } else if (event.key === Qt.Key_Escape) {
                            if (hasRequest && !busy) {
                                pluginMain?.requestClose()
                                passwordInput.text = ""
                            }
                        }
                    }
                    onTextChanged: {
                        if (outcome === "fail") {
                            outcome = "none"
                        }
                    }
                }
                Row {
                    id: overlayIcons
                    anchors.right: parent.right
                    anchors.rightMargin: cardPad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: microGap
                    NIcon {
                        visible: root.capsLockOn
                        icon: "arrow-up-circle"
                        pointSize: Style.fontSizeM
                        color: Color.mError
                    }
                    NIconButton {
                        icon: root.revealPassword ? "eye-off" : "eye"
                        baseSize: overlayButton
                        colorBg: "transparent"
                        onClicked: root.revealPassword = !root.revealPassword
                    }
                }
            }

            NButton {
                id: authButton
                Layout.fillWidth: true
                Layout.preferredHeight: controlHeight
                fontSize: Style.fontSizeM * 1.2 * fontScale
                text: (busyVisual || successState) ? "" : trOrDefault("actions.authenticate", "Authenticate")
                backgroundColor: successState ? successColor : (busyVisual ? Color.mSurfaceVariant : Color.mPrimary)
                enabled: !busyVisual && !successState && passwordInput.text.length > 0
                opacity: authButton.enabled ? 1.0 : (busyVisual ? 0.85 : 0.6)

                // Centered Busy Content
                RowLayout {
                    anchors.centerIn: parent
                    visible: busyVisual && !successState
                    spacing: Style.marginS

                    NIcon {
                        icon: "loader"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: busyVisual
                        }
                    }

                    NText {
                        text: "Verifying..."
                        font.pointSize: Style.fontSizeM * fontScale
                        color: Color.mOnSurfaceVariant
                    }
                }

                // Content for success icon
                NIcon {
                    anchors.centerIn: parent
                    visible: successState
                    icon: "check"
                    pointSize: Style.fontSizeL
                    color: Color.mOnPrimary
                }

                Binding {
                    target: authButton.background || null
                    property: "radius"
                    value: root.cardRadius
                    when: authButton.background !== undefined
                }
                onClicked: submitPasswordAttempt()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: errorText.length > 0 || (hasRequest && fingerprintAvailable && !busy)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: hasRequest && fingerprintAvailable && !busy
                    spacing: Style.marginS
                    NIcon {
                        icon: "fingerprint"
                        pointSize: Style.fontSizeM
                        color: Color.mPrimary
                    }
                    NText {
                        text: trOrDefault("status.fingerprint-hint", "Touch fingerprint sensor")
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS * fontScale
                    }
                }
                NText {
                    Layout.fillWidth: true
                    visible: errorText.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    text: errorText
                    color: Color.mError
                    font.family: "Monospace"
                    pointSize: Style.fontSizeS
                    wrapMode: Text.WordWrap
                }
            }
        }

        // TIMEOUT LAYER
        ColumnLayout {
            id: timeoutSection
            anchors.centerIn: parent
            width: parent.width
            spacing: Style.marginM
            visible: timedOutState && !hasRequest && !successState
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 250
                }
            }
            NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "clock-stop"
                pointSize: 48 * Style.uiScaleRatio
                color: Color.mOnSurfaceVariant
                opacity: 0.5
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: trOrDefault("status.timed-out", "Request Timed Out")
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeL * fontScale
                color: Color.mOnSurface
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: trOrDefault("status.timed-out-detail", "This authentication request is no longer valid.")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS * fontScale
            }
        }

        // IDLE/EMPTY LAYER
        ColumnLayout {
            id: idleSection
            anchors.centerIn: parent
            width: parent.width
            spacing: Style.marginM
            visible: !hasRequest && !successState && !timedOutState && agentAvailable
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 250
                }
            }
            NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "shield"
                pointSize: 48 * Style.uiScaleRatio
                color: Color.mPrimary
                opacity: 0.4
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: trOrDefault("status.waiting", "Waiting for requests...")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeM * fontScale
            }
        }

        // ERROR/AGENT UNAVAILABLE LAYER
        ColumnLayout {
            id: errorSection
            anchors.centerIn: parent
            width: parent.width
            spacing: Style.marginM
            visible: !agentAvailable
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 250
                }
            }
            NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "alert-circle"
                pointSize: 48 * Style.uiScaleRatio
                color: Color.mError
                opacity: 0.6
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: statusText || trOrDefault("status.agent-unavailable", "Polkit Agent Unavailable")
                color: Color.mError
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeL * fontScale
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Check if noctalia-polkit-agent is running."
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS * fontScale
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        ParallelAnimation {
            NumberAnimation {
                target: mainContainer
                property: "anchors.horizontalCenterOffset"
                from: 0
                to: -12
                duration: 40
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: inputWrapper
                property: "border.width"
                to: 2.0
                duration: 40
            }
        }
        SpringAnimation {
            target: mainContainer
            property: "anchors.horizontalCenterOffset"
            to: 0
            spring: 4
            damping: 0.15
            epsilon: 0.25
        }
        NumberAnimation {
            target: inputWrapper
            property: "border.width"
            to: 1.0
            duration: 200
        }
    }
    Timer {
        id: submitPulseTimer
        interval: 200
        repeat: false
        onTriggered: submitPulseActive = false
    }
    Timer {
        id: focusTimer
        interval: 100
        onTriggered: focusPasswordInput()
    }
    Timer {
        id: animateInTimer
        interval: 16
        onTriggered: root.animateIn = true
    }

    onHasRequestChanged: {
        if (hasRequest) {
            outcome = "none"
            successState = false
            timedOutState = false
            wasEverRequested = true
            passwordInput.text = ""
            revealPassword = false
            focusTimer.restart()
        } else {
            if (wasEverRequested && !successState) {
                timedOutState = true
            }
            passwordInput.text = ""
            revealPassword = false
        }
    }
    onVisibleChanged: if (visible && hasRequest) focusTimer.restart()
    Component.onCompleted: {
        animateInTimer.start()
        if (hasRequest) focusTimer.restart()
    }
}
