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
    property var incomingSession: null
    property var session: null

    onIncomingSessionChanged: {
        // New session, retry, or cleared session: Reset UI state, accept session
        successState = false
        session = incomingSession
        warningDismissed = false
        passwordInput.text = ""
        awaitingResult = false
        submitPulseActive = false
        submitPulseTimer.stop()
        if (incomingSession) {
            // Reset stagger entrance for cascading animation on NEW session only
            stageHeader = false
            stageCard = false
            stageInput = false
            stageButton = false
            focusTimer.restart()
            animateInTimer.restart()
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (hasSession)
                focusTimer.restart()
        } else {
            successState = false
            passwordInput.text = ""
            warningDismissed = false
        }
    }

    readonly property string mainState: (pluginMain
                                         && pluginMain.sessionState) || "idle"
    readonly property bool hasActiveSession: mainState !== "idle"
    readonly property bool isVerifying: mainState === "verifying"
    readonly property bool isSuccess: mainState === "success"
    readonly property bool isError: mainState === "error"

    onMainStateChanged: {
        if (mainState === "idle") {
            // Only clear if not in closing animation (let UI persist)
            if (!(pluginMain && pluginMain.isClosingUI)) {
                session = null
                passwordInput.text = ""
                awaitingResult = false
            }
        } else if (mainState === "prompting" || mainState === "error") {
            // Ensure password field is focused when needing input
            focusTimer.restart()
            awaitingResult = false
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
    property bool animateIn: false
    readonly property bool isDark: Settings.data.colorSchemes.darkMode
    property bool colorizeIcons: true

    // Staggered entrance delays
    property bool stageHeader: false
    property bool stageCard: false
    property bool stageInput: false
    property bool stageButton: false

    // Outcome state machine
    property int outcomeEpoch: 0 // Increments to restart animations

    property bool warningDismissed: false
    readonly property string requestWarning: (!warningDismissed && session
                                              && session.error) ? session.error : ""

    // Submit state (tight feedback loop)
    property bool awaitingResult: false
    property bool submitPulseActive: false
    readonly property bool busyVisual: isVerifying || (awaitingResult
                                                       && !isSuccess
                                                       && !isError)

    // --- 0. RICH CONTEXT DATA ---
    readonly property var appProfiles: AuthLogic.getAppProfiles(Color)
    readonly property var contextModel: AuthLogic.getContextModel(session,
                                                                  requestor,
                                                                  subject,
                                                                  appProfiles,
                                                                  Color)

    readonly property var requestor: (session && session.requestor) || null
    readonly property var subject: (session && session.details
                                    && session.details.subject) || null
    readonly property string requestorIconName: {
        if (requestor) {
            if (requestor.icon)
                return requestor.icon
        }
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

    readonly property var richContext: AuthLogic.getRichContext(session, Color,
                                                                secondaryAccent)

    readonly property var gpgInfo: AuthLogic.getGpgInfo(session)

    readonly property string displayAction: AuthLogic.getDisplayAction(
                                                session, richContext,
                                                secondaryAccent)
    readonly property var contextCardModel: AuthLogic.getContextCardModel(
                                                contextModel, gpgInfo, session)

    // Signal to request closing the container (window or panel)
    signal closeRequested

    // --- 1. THEME & METRICS ---
    readonly property double fontScale: (typeof Settings
                                         !== "undefined" ? Settings.data.ui.fontDefaultScale : 1.0)
    readonly property int baseSize: Style.baseWidgetSize
    readonly property int controlHeight: Math.round(baseSize * 1.1)
    readonly property int iconTile: baseSize
    readonly property int overlayButton: Math.round(baseSize * 0.75)

    // Spacing Grid (Noctalia Native)
    readonly property int framePad: Style.marginXL
    readonly property int sectionGap: Style.marginL
    readonly property int microGap: Style.marginS
    readonly property int cardPad: Style.marginM

    readonly property color secondaryAccent: Color.mSecondary
                                             !== undefined ? Color.mSecondary : Color.mPrimary
    readonly property color secondaryAccentContainer: Color.mSecondaryContainer
                                                      !== undefined ? Color.mSecondaryContainer : Qt.alpha(
                                                                          secondaryAccent,
                                                                          0.18)
    readonly property color colorFlowLine: Qt.alpha(secondaryAccent, 0.2)
    readonly property color colorFlowActive: secondaryAccent
    readonly property real cardRadius: Style.radiusM
    readonly property real inputRadius: Style.iRadiusM

    // Simple radius clamp - ensures radius doesn't exceed half the smallest dimension
    function nestedRadius(baseRadius, baseWidth, baseHeight, gap) {
        const maxRadius = Math.min(baseWidth, baseHeight) / 2
        return Math.min(baseRadius + gap, maxRadius)
    }

    // --- 2. COMPUTED DATA ---
    readonly property color successColor: "#10B981" // Emerald 500
    readonly property color errorColor: Color.mError
    readonly property bool hasSession: hasActiveSession && !!(session
                                                              && session.id)
    readonly property string displayUser: formatUser((session
                                                      && session.user) || "")
    readonly property bool fingerprintAvailable: false

    readonly property string commandPath: {
        if (!hasSession || !session && session.message)
            return ""
        const msg = session.message
        const match = msg.match(/'([^']+)'/)
        if (match && match[1])
            return match[1]
        const matchPath = msg.match(/(\/[a-zA-Z0-9_\-\.\/]+)/)
        if (matchPath && matchPath[1])
            return matchPath[1]
        return ""
    }

    function trOrDefault(key, fallback) {
        if (pluginMain && pluginMain.pluginApi && pluginMain.pluginApi.tr) {
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
    }

    function submitPasswordAttempt() {
        if (!hasSession)
            return
        if (successState)
            return
        if (busyVisual)
            return
        if (!passwordInput.text || passwordInput.text.length === 0)
            return

        startSubmitFeedback()
        pluginMain && pluginMain.submitPassword(passwordInput.text)
    }

    function focusPasswordInput() {

        if (hasSession && passwordInput.visible) {
            root.forceActiveFocus()
            passwordInput.forceActiveFocus()
        }
    }

    // --- 3. DYNAMIC SIZING ---
    implicitWidth: Math.round(360 * Style.uiScaleRatio)
    implicitHeight: targetHeight

    readonly property int targetHeight: {
        let base = 0
        if (!agentAvailable)
            base = errorSection.implicitHeight
        else if (hasActiveSession || successState)
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
        function onSessionCompleted(success) {
            if (!root.visible)
                return
            awaitingResult = false
            submitPulseActive = false
            submitPulseTimer.stop()

            // Defensive check: ensure main state agrees with success signal
            if (success && root.isSuccess) {
                outcomeEpoch++
                successState = true
            } else {
                const reason = (pluginMain && pluginMain.closeReason) || ""
                if (reason !== "cancelled" && reason !== "timeout"
                        && reason !== "closed") {
                    outcomeEpoch++
                    shakeAnim.restart()
                    passwordInput.text = ""
                    focusPasswordInput()
                }
            }
        }

        function onSessionRetry() {
            awaitingResult = false
            submitPulseActive = false
            submitPulseTimer.stop()
            outcomeEpoch++
            shakeAnim.restart()
            passwordInput.text = ""
            focusPasswordInput()
        }
    }

    onErrorTextChanged: {
        if (errorText.length > 0 && !successState) {
            if (awaitingResult) {
                awaitingResult = false
                submitPulseActive = false
                submitPulseTimer.stop()
            }
            outcomeEpoch++
            shakeAnim.restart()
            passwordInput.text = ""
            focusPasswordInput()
        }
    }

    // --- 4. COMPONENTS ---
    NIconButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.marginL
        z: 10
        icon: "close"
        baseSize: Style.baseWidgetSize * 0.8
        tooltipText: I18n.tr("common.close")
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
            spacing: 0
            visible: (hasActiveSession || successState
                      || ((pluginMain && pluginMain.isClosingUI) || false))
                     && !timedOutState && agentAvailable

            ColumnLayout {
                id: headerStack
                Layout.fillWidth: true
                spacing: microGap
                opacity: root.stageHeader ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                ConnectionFlow {
                    Layout.alignment: Qt.AlignHCenter
                    outcome: isSuccess ? "success" : (isError ? "fail" : "none")
                    epoch: root.outcomeEpoch
                    busy: root.busy
                    contextModel: root.contextModel
                    requestor: root.requestor
                    hasRequestorIcon: root.hasRequestorIcon
                    requestorIconPath: root.requestorIconPath
                    isDark: root.isDark
                    colorizeIcons: root.colorizeIcons
                }

                NText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    pointSize: Style.fontSizeM * fontScale
                    color: Color.mOnSurface
                    text: {
                        let appName = (requestor && requestor.name) || ""
                        if (!appName || appName.toLowerCase() === "unknown")
                            return "Allow an application to " + displayAction
                        return "Allow <font face='Monospace'><b>" + appName
                                + "</b></font> to " + displayAction
                    }
                }
            }

            AuthContextCard {
                Layout.topMargin: sectionGap
                model: root.contextCardModel
                isDark: root.isDark
                fontScale: root.fontScale
                opacity: root.stageCard ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            NBox {
                id: inputWrapper
                Layout.fillWidth: true
                Layout.topMargin: sectionGap
                implicitHeight: passwordInput.implicitHeight + (cardPad * 2)
                radius: root.nestedRadius(root.inputRadius, inputWrapper.width,
                                          inputWrapper.height, 0)
                antialiasing: true
                color: {
                    if (successState)
                        return Qt.alpha(successColor, 0.12)
                    if (isError)
                        return Qt.alpha(errorColor, 0.15)
                    return Qt.alpha(Color.mSurfaceVariant, isDark ? 0.68 : 0.60)
                }
                border.color: {
                    if (successState)
                        return successColor
                    if (isError)
                        return errorColor
                    return passwordInput.activeFocus ? Qt.alpha(
                                                           contextModel ? contextModel.accentColor : Color.mSecondary,
                                                           0.6) : Color.mOutline
                }
                border.width: {
                    if (successState || isError)
                        return 2.5
                    return 1
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on border.width {
                    enabled: !shakeAnim.running
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutElastic
                        easing.amplitude: 0.6
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }

                // Success Message (Centered)
                NText {
                    anchors.centerIn: parent
                    visible: successState
                    text: (session && session.source
                           === "keyring") ? trOrDefault(
                                                "status.submitted",
                                                "Submitted") : trOrDefault(
                                                "status.authenticated",
                                                "Authenticated")
                    color: successColor
                    font.family: "Monospace"
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeM * fontScale
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                TextField {
                    id: passwordInput
                    anchors.fill: parent
                    visible: !successState
                    opacity: busyVisual ? 0.35 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    anchors.leftMargin: cardPad
                    anchors.topMargin: cardPad
                    anchors.bottomMargin: cardPad
                    anchors.rightMargin: overlayIcons.width + cardPad + microGap
                    font.pointSize: Style.fontSizeM * fontScale
                    font.family: Settings.data.ui.fontDefault
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: session && session.prompt || trOrDefault(
                                         "placeholders.password",
                                         "Enter password")
                    text: ""
                    echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
                    enabled: hasSession && !busyVisual
                    background: null
                    color: Color.mOnSurface
                    placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                    selectionColor: contextModel ? contextModel.accentColor : Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    selectByMouse: true

                    KeyNavigation.tab: authButton
                    KeyNavigation.backtab: authButton

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_CapsLock)
                            root.capsLockOn = !root.capsLockOn
                        if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter) {
                            submitPasswordAttempt()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            if (hasSession && !busy) {
                                pluginMain && pluginMain.requestClose()
                                passwordInput.text = ""
                                event.accepted = true
                            }
                        }
                    }
                    onTextChanged: {

                        // Resetting local failure visuals if user types
                    }
                    onTextEdited: {
                        root.warningDismissed = true
                        pluginMain && pluginMain.clearError()
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
                        colorBg: eyeHover.containsMouse ? Qt.alpha(
                                                              Color.mOnSurfaceVariant,
                                                              0.1) : "transparent"
                        onClicked: {
                            root.revealPassword = !root.revealPassword
                            passwordInput.forceActiveFocus()
                        }
                        MouseArea {
                            id: eyeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }

            NButton {
                id: authButton
                Layout.fillWidth: true
                Layout.topMargin: Style.marginM
                Layout.preferredHeight: controlHeight
                fontSize: Style.fontSizeM * 1.2 * fontScale
                text: busyVisual ? "" : (successState ? trOrDefault(
                                                            "status.verified",
                                                            "Verified") : trOrDefault(
                                                            "actions.authenticate",
                                                            "Authenticate"))
                backgroundColor: {
                    if (successState)
                        return successColor
                    if (busyVisual)
                        return Color.mSurfaceVariant
                    if (hoverActive)
                        return Qt.lighter(Color.mPrimary,
                                          root.isDark ? 1.15 : 1.08)
                    return Color.mPrimary
                }
                enabled: hasSession && !busyVisual && !successState
                         && passwordInput.text.length > 0
                opacity: (authButton.enabled
                          || successState) ? 1.0 : (busyVisual ? 0.85 : 0.55)
                activeFocusOnTab: true
                focusPolicy: Qt.TabFocus

                // Micro-bounce on click
                property real clickScale: 1.0
                scale: clickScale
                Behavior on clickScale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }

                // Hover state - subtle background change
                property bool hoverActive: false

                // Hover detection
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: authButton.hoverActive = true
                    onExited: authButton.hoverActive = false
                }

                // Focus indicator - show border on the button itself
                Binding {
                    target: authButton
                    property: "border.width"
                    value: authButton.activeFocus ? 2 : 0
                }
                Binding {
                    target: authButton
                    property: "border.color"
                    value: contextModel ? contextModel.accentColor : Color.mSecondary
                }

                KeyNavigation.tab: passwordInput
                KeyNavigation.backtab: passwordInput

                Keys.onPressed: function (event) {
                    if ((event.key === Qt.Key_Return
                         || event.key === Qt.Key_Enter
                         || event.key === Qt.Key_Space) && authButton.enabled) {
                        submitPasswordAttempt()
                        event.accepted = true
                    }
                }

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

                Binding {
                    target: authButton.background || null
                    property: "radius"
                    value: root.nestedRadius(root.inputRadius,
                                             authButton.width,
                                             authButton.height, 0)
                    when: authButton.background !== undefined
                }
                Binding {
                    target: authButton.background || null
                    property: "antialiasing"
                    value: true
                    when: authButton.background !== undefined
                }
                onClicked: {
                    clickScale = 0.97
                    Qt.callLater(function () {
                        clickScale = 1.0
                    })
                    submitPasswordAttempt()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Style.marginS
                spacing: Style.marginS
                visible: errorText.length > 0 || requestWarning.length > 0
                         || (hasSession && fingerprintAvailable && !busy)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: hasSession && fingerprintAvailable && !busy
                    spacing: Style.marginS
                    NIcon {
                        icon: "fingerprint"
                        pointSize: Style.fontSizeM
                        color: Color.mPrimary
                    }
                    NText {
                        text: trOrDefault("status.fingerprint-hint",
                                          "Touch fingerprint sensor")
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS * fontScale
                    }
                }
                NText {
                    Layout.fillWidth: true
                    visible: errorText.length > 0 || requestWarning.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    text: errorText.length > 0 ? errorText : requestWarning
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
            visible: timedOutState && !hasActiveSession && !successState
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
                wrapMode: Text.WordWrap
                text: trOrDefault("status.timed-out", "Request Timed Out")
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeL * fontScale
                color: Color.mOnSurface
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: trOrDefault(
                          "status.timed-out-detail",
                          "This authentication request is no longer valid.")
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
            visible: !hasActiveSession && !successState && !timedOutState
                     && agentAvailable
                     && !((pluginMain && pluginMain.isClosingUI) || false)
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
                wrapMode: Text.WordWrap
                text: trOrDefault("status.waiting", "Waiting for requests...")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeM * fontScale
            }
            NText {
                Layout.fillWidth: true
                visible: errorText.length > 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: errorText
                color: Color.mError
                font.family: "Monospace"
                pointSize: Style.fontSizeS
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
                wrapMode: Text.WordWrap
                text: statusText || trOrDefault("status.agent-unavailable",
                                                "Polkit Agent Unavailable")
                color: Color.mError
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeL * fontScale
            }
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Check if bb-auth.service is running."
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
                to: -10
                duration: 45
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: inputWrapper
                property: "border.width"
                to: 2.0
                duration: 45
            }
        }
        SpringAnimation {
            target: mainContainer
            property: "anchors.horizontalCenterOffset"
            to: 0
            spring: 3
            damping: 0.22
            epsilon: 0.25
        }
        NumberAnimation {
            target: inputWrapper
            property: "border.width"
            to: 1.0
            duration: 250
            easing.type: Easing.OutCubic
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
        onTriggered: {
            root.animateIn = true
            stageHeaderTimer.start()
        }
    }

    // Stagger timers for cascading entrance
    Timer {
        id: stageHeaderTimer
        interval: 30
        onTriggered: {
            root.stageHeader = true
            stageCardTimer.start()
        }
    }
    Timer {
        id: stageCardTimer
        interval: 60
        onTriggered: {
            root.stageCard = true
            stageInputTimer.start()
        }
    }
    Timer {
        id: stageInputTimer
        interval: 60
        onTriggered: {
            root.stageInput = true
            stageButtonTimer.start()
        }
    }
    Timer {
        id: stageButtonTimer
        interval: 60
        onTriggered: root.stageButton = true
    }

    onHasSessionChanged: {
        if (hasSession) {
            successState = false
            timedOutState = false
            wasEverRequested = true
            passwordInput.text = ""
            revealPassword = false
            focusTimer.restart()
        } else {
            // Use explicit close reason from Main.qml instead of guessing
            const reason = (pluginMain && pluginMain.closeReason) || ""
            timedOutState = (reason === "timeout")
            successState = false
            passwordInput.text = ""
            revealPassword = false
        }
    }

    Component.onCompleted: {
        animateInTimer.start()
        if (hasSession)
            focusTimer.restart()
    }
}
