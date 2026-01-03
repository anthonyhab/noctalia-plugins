import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
  id: root

  // Required properties from parent
  property var pluginMain: null
  property var request: null
  property bool busy: false
  property bool agentAvailable: true
  property string statusText: ""
  property string errorText: ""

  // Internal state
  property bool showDetails: false
  property bool successState: false
  property bool revealPassword: false
  property bool capsLockOn: false
  property bool animateIn: false

  // Signal to request closing the container (window or panel)
  signal closeRequested()

  // Clipboard copy helper process
  Process {
    id: copyProcess
    command: ["wl-copy", commandPath]
  }

  // Implicit sizing for parent containers
  implicitWidth: mainColumn.implicitWidth + (Style.marginXL * 2)
  implicitHeight: mainColumn.implicitHeight + (Style.marginXL * 2) + Style.marginL

  // Computed property
  readonly property bool hasRequest: request !== null && request !== undefined && typeof request === "object" && request.id
  readonly property string displayUser: formatUser(request?.user ?? "")
  readonly property bool hasActionDetails: !!request?.actionId
  readonly property bool fingerprintAvailable: request?.fingerprintAvailable ?? false
  readonly property bool useBigLayout: !hasRequest || successState

  // Command extraction
  readonly property string commandPath: {
    if (!hasRequest || !request.message) return "";
    const msg = request.message;
    // Look for content in single quotes
    const match = msg.match(/'([^']+)'/);
    if (match && match[1]) return match[1];
    // Look for absolute paths
    const matchPath = msg.match(/(\/[a-zA-Z0-9_\-\.\/]+)/);
    if (matchPath && matchPath[1]) return matchPath[1];
    return "";
  }

  function trOrDefault(key, fallback) {
    const translated = pluginMain?.pluginApi?.tr ? pluginMain.pluginApi.tr(key) : "";
    return translated && translated.length > 0 ? translated : fallback;
  }

  function formatUser(value) {
    if (!value) return "";
    if (value.indexOf("unix-user:") === 0) {
      return value.slice("unix-user:".length);
    }
    return value;
  }

  function focusPasswordInput() {
    if (hasRequest && passwordInput.visible) {
      root.forceActiveFocus();
      passwordInput.inputItem.forceActiveFocus();
    }
  }

  Connections {
    target: pluginMain
    function onRequestCompleted(success) {
      if (success) {
        successState = true;
        // Animation handled by binding
      } else {
        shakeAnim.restart();
        passwordInput.text = "";
        focusPasswordInput();
      }
    }
  }

  // Close button for Success State (Big Layout)
  NIconButton {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.marginS
    z: 10
    visible: useBigLayout && successState
    icon: "x"
    baseSize: Math.round(Style.baseWidgetSize * 0.75)
    colorBg: "transparent"
    colorFg: Color.mOnSurfaceVariant
    colorBgHover: Color.mSurfaceVariant
    colorFgHover: Color.mOnSurface
    onClicked: root.closeRequested()
  }

  ColumnLayout {
    id: mainColumn
    anchors.centerIn: parent
    width: parent.width - (Style.marginXL * 2)
    spacing: Style.marginL

    // Entrance animation
    scale: root.animateIn ? 1.0 : 0.95
    opacity: root.animateIn ? 1.0 : 0.0

    Behavior on scale {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on opacity {
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    // Big Icon (Idle / Success)
    Item {
      visible: useBigLayout
      Layout.fillWidth: true
      Layout.preferredHeight: bigLockIcon.height + 8

      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.4
        shadowOpacity: 0.35
        shadowColor: Color.mPrimary
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
      }

      NIcon {
        id: bigLockIcon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        icon: successState ? "circle-check" : (hasRequest ? "lock" : "shield")
        pointSize: Math.round(Style.fontSizeXXXL * 2.0)
        color: Color.mPrimary

        SequentialAnimation on scale {
          id: bigSuccessBounce
          running: successState
          NumberAnimation { to: 1.15; duration: Style.animationFast; easing.type: Easing.OutCubic }
          NumberAnimation { to: 1.0; duration: Style.animationFast; easing.type: Easing.OutCubic }
        }

        Behavior on color { ColorAnimation { duration: Style.animationFast } }
      }
    }

    // Big Title
    NText {
      visible: useBigLayout
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: {
        if (successState) return trOrDefault("status.authenticated", "Authenticated");
        return trOrDefault("title", "Polkit Authentication");
      }
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeXL
      color: Color.mOnSurface
    }

    // Header (Structured) - Compact Mode
    Rectangle {
        visible: !useBigLayout
        Layout.fillWidth: true
        Layout.preferredHeight: Style.baseWidgetSize * 1.5 + Style.marginS
        
        color: Color.mSurfaceVariant
        radius: Style.iRadiusL
        border.color: Color.mOutline
        border.width: Style.borderS

        // Left: Lock Icon Container
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Style.marginS
            anchors.verticalCenter: parent.verticalCenter
            width: Style.baseWidgetSize * 1.5
            height: Style.baseWidgetSize * 1.5
            radius: Style.iRadiusM
            color: Qt.alpha(Color.mPrimary, 0.1)
            border.color: Qt.alpha(Color.mPrimary, 0.3)
            border.width: Style.borderS

            NIcon {
                anchors.centerIn: parent
                icon: successState ? "check" : (hasRequest ? "lock" : "shield")
                pointSize: Style.fontSizeXL
                color: Color.mPrimary
                
                SequentialAnimation on scale {
                    id: successBounce
                    running: false
                    NumberAnimation { to: 1.2; duration: Style.animationFast; easing.type: Easing.OutCubic }
                    NumberAnimation { to: 1.0; duration: Style.animationFast; easing.type: Easing.OutCubic }
                }
                
                Behavior on color { ColorAnimation { duration: Style.animationFast } }
            }
        }

        // Center: Title
        NText {
            anchors.centerIn: parent
            text: {
                if (successState) return trOrDefault("status.authenticated", "Authenticated");
                if (hasRequest) return trOrDefault("status.request", "Authentication Required");
                return trOrDefault("title", "Polkit Authentication");
            }
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
        }

        // Right: Close Button
        NIconButton {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: Style.marginS
            anchors.verticalCenter: parent.verticalCenter
            
            visible: hasRequest && !successState
            icon: "x"
            baseSize: Math.round(Style.baseWidgetSize * 0.75)
            colorBg: "transparent"
            colorFg: Color.mOnSurfaceVariant
            colorBgHover: Color.mSurface
            colorFgHover: Color.mOnSurface
            tooltipText: trOrDefault("actions.close", "Close")
            onClicked: {
              if (hasRequest) {
                pluginMain?.cancelRequest();
              }
              root.closeRequested();
            }
        }
    }

    // Queue indicator
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      visible: hasRequest && !successState && (pluginMain?.requestQueue?.length ?? 0) > 0
      spacing: Style.marginXS
      opacity: visible ? 1.0 : 0.0

      Behavior on opacity {
        NumberAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }

      Rectangle {
        width: queueText.implicitWidth + Style.marginM
        height: queueText.implicitHeight + Style.marginXS
        radius: Style.iRadiusS
        color: Color.mTertiary
        border.color: Color.mOutline
        border.width: Style.borderS

        NText {
          id: queueText
          anchors.centerIn: parent
          text: "+" + (pluginMain?.requestQueue?.length ?? 0) + " " +
                trOrDefault("status.more-requests", "more")
          pointSize: Style.fontSizeXS
          color: Color.mOnTertiary
        }
      }
    }

    // Context Card (User + Command)
    Rectangle {
      id: contextCard
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      Layout.maximumWidth: parent.width
      
      visible: hasRequest && !successState && (displayUser.length > 0 || commandPath !== "")
      
      implicitHeight: contextCol.implicitHeight + (Style.marginS * 2)
      
      radius: Style.iRadiusL
      color: Color.mSurfaceVariant
      border.color: Color.mOutline
      border.width: Style.borderS

      ColumnLayout {
        id: contextCol
        anchors.centerIn: parent
        width: parent.width
        spacing: 0

        // User Identity Section
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: commandPath !== "" ? Style.marginXS : 0
            visible: displayUser.length > 0
            spacing: Style.marginS

            // Avatar Item
            Item {
                Layout.alignment: Qt.AlignVCenter
                width: Style.iconSizeM && Style.iconSizeM > 0 ? Style.iconSizeM : Math.round(Style.baseWidgetSize * 0.7)
                height: width

                // Container Background & Border (Frame)
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: (Color.mSecondaryContainer !== undefined) ? Color.mSecondaryContainer : Color.mSurfaceVariant
                    border.color: Color.mOutline
                    border.width: Style.borderS
                    
                    // Fallback Icon
                    NIcon {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        icon: "user"
                        pointSize: Style.fontSizeS
                        color: (Color.mOnSecondaryContainer !== undefined) ? Color.mOnSecondaryContainer : Color.mPrimary
                    }
                }

                // Avatar Image
                NImageRounded {
                    id: avatarImage
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: width / 2
                    
                    property string userName: displayUser
                    property string currentUser: Quickshell.env("USER")
                    
                    imagePath: {
                        if (!userName) return "";
                        if (userName === currentUser && typeof Settings !== "undefined") {
                            return Settings.preprocessPath(Settings.data.general.avatarImage);
                        }
                        return "/var/lib/AccountsService/icons/" + userName;
                    }
                    
                    fallbackIcon: "" 
                    imageFillMode: Image.PreserveAspectCrop
                    borderWidth: 0 
                    visible: status === Image.Ready
                }
            }

            NText {
                text: displayUser
                font.weight: Style.fontWeightMedium
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
            }
        }

        // Separator
        Item {
            visible: displayUser.length > 0 && commandPath !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: Style.marginS
            
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - (Style.marginM * 2)
                height: 1
                color: Color.mOutline
                opacity: 0.3
            }
        }

        // Command Section
        Item {
            visible: commandPath !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(cmdText.implicitHeight + Style.marginXS, 26)
            
            Rectangle {
                id: cmdBackground
                anchors.fill: parent
                radius: Style.iRadiusS
                color: cmdHover.hovered ? Qt.alpha(Color.mOnSurface, 0.05) : "transparent"
                
                Behavior on color { ColorAnimation { duration: Style.animationFast } }
            }

            HoverHandler { id: cmdHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                  copyProcess.running = true;
                  cmdCopyFeedback.restart();
                }
            }
            
            NText {
                id: cmdText
                anchors.centerIn: parent
                width: parent.width - Style.marginS
                text: commandPath
                font.family: "Monospace"
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Copy Feedback Overlay
            Rectangle {
                anchors.fill: parent
                radius: Style.iRadiusS
                color: Color.mPrimary
                opacity: 0
                
                NText {
                    anchors.centerIn: parent
                    text: trOrDefault("feedback.copied", "Copied!")
                    color: Color.mOnPrimary
                    pointSize: Style.fontSizeXS
                }
                
                SequentialAnimation on opacity {
                    id: cmdCopyFeedback
                    running: false
                    NumberAnimation { to: 1; duration: Style.animationFaster }
                    PauseAnimation { duration: 500 }
                    NumberAnimation { to: 0; duration: Style.animationFast }
                }
            }
        }
      }
    }

    // Status / Message Text
    NText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      visible: !successState
      text: {
        if (!hasRequest) {
          return agentAvailable
            ? trOrDefault("status.waiting", "Waiting for authentication requests")
            : (statusText || trOrDefault("status.agent-unavailable", "Agent unavailable"));
        }
        if (commandPath !== "") {
          return trOrDefault("status.auth-command", "Authentication is required to run this command as the super user.");
        }
        return request?.message ?? "";
      }
      wrapMode: Text.WordWrap
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeM
      lineHeight: 1.2
    }

    // Password Input Area
    Item {
      id: inputContainer
      Layout.fillWidth: true
      Layout.preferredHeight: passwordInput.implicitHeight
      visible: hasRequest && !successState
      
      // Focus/Error Glow
      Rectangle {
        anchors.fill: passwordInput
        anchors.margins: -2
        radius: Style.iRadiusM
        color: "transparent"
        border.color: errorText.length > 0 ? Color.mError : Color.mSecondary
        border.width: 2
        opacity: (passwordInput.activeFocus || errorText.length > 0) ? 0.5 : 0

        Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Style.animationFast } }
      }

      // Icons Overlay (Caps Lock, Reveal)
      RowLayout {
        id: overlayRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // Shift left if text is present to avoid native clear button, but keep it tight
        anchors.rightMargin: Style.marginXS + (passwordInput.text.length > 0 ? Math.round(Style.baseWidgetSize * 0.9) : 0)
        spacing: 2
        z: 5
        
        Behavior on anchors.rightMargin { NumberAnimation { duration: Style.animationFaster } }

        // Caps Lock Warning
        NIcon {
            visible: root.capsLockOn
            icon: "arrow-up-circle" // or a generic warning/caps icon
            pointSize: Style.fontSizeM
            color: Color.mError
            
            ToolTip.visible: mouseAreaCaps.containsMouse
            ToolTip.text: trOrDefault("warnings.caps-lock", "Caps Lock is on")
            
            MouseArea {
                id: mouseAreaCaps
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        // Reveal Button
        NIconButton {
          icon: root.revealPassword ? "eye-off" : "eye"
          baseSize: Math.round(Style.baseWidgetSize * 0.7)
          colorBg: "transparent"
          colorFg: Color.mOnSurfaceVariant
          onClicked: root.revealPassword = !root.revealPassword
        }
      }

      NTextInput {
        id: passwordInput
        anchors.left: parent.left
        anchors.right: parent.right
        
        // Dynamic padding based on the overlay width + its offset
        inputItem.rightPadding: overlayRow.width + overlayRow.anchors.rightMargin + Style.marginXS

        placeholderText: request?.prompt || trOrDefault("placeholders.password", "Enter your password")
        text: ""
        
        inputItem.echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
        enabled: !busy
        
        KeyNavigation.tab: authButton
        
        inputItem.Keys.onPressed: function (event) {
          // Best-effort Caps Lock detection
          if (event.modifiers & Qt.ShiftModifier) {
             // This assumes typing regular chars. Not perfect but helpful.
             // Real Caps Lock detection requires C++.
          }
          
          if (event.key === Qt.Key_CapsLock) {
             root.capsLockOn = !root.capsLockOn; // Toggle guess
          }

          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (hasRequest && !busy && passwordInput.text.length > 0) {
              pluginMain?.submitPassword(passwordInput.text);
              event.accepted = true;
            }
          } else if (event.key === Qt.Key_Escape) {
            if (hasRequest && !busy) {
              pluginMain?.cancelRequest();
              passwordInput.text = "";
              event.accepted = true;
            }
          }
        }
      }
    }

    // Fingerprint hint
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      visible: hasRequest && fingerprintAvailable && !successState && !busy
      spacing: Style.marginS

      Rectangle {
        width: 1
        height: Style.fontSizeS
        color: Color.mOutline
        Layout.alignment: Qt.AlignVCenter
      }

      NText {
        text: trOrDefault("status.fingerprint-or", "or")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      Rectangle {
        width: 1
        height: Style.fontSizeS
        color: Color.mOutline
        Layout.alignment: Qt.AlignVCenter
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      visible: hasRequest && fingerprintAvailable && !successState
      spacing: Style.marginS
      opacity: busy ? 0.5 : 1

      NIcon {
        icon: "fingerprint"
        pointSize: Style.fontSizeL
        color: Color.mPrimary

        SequentialAnimation on opacity {
          running: hasRequest && fingerprintAvailable && !successState && !busy
          loops: Animation.Infinite
          NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
        }
      }

      NText {
        text: trOrDefault("status.fingerprint-hint", "Touch fingerprint sensor")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }

    // Error Message
    NText {
      Layout.fillWidth: true
      visible: errorText.length > 0 && !successState
      horizontalAlignment: Text.AlignHCenter
      text: errorText
      color: Color.mError
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    // Authenticate Button
    Item {
      id: authButtonWrapper
      Layout.fillWidth: true
      Layout.preferredHeight: Style.baseWidgetSize * 1.2
      visible: hasRequest && !successState

      scale: authButtonTap.pressed ? 0.98 : 1.0
      Behavior on scale {
        NumberAnimation {
          duration: Style.animationFaster
          easing.type: Easing.OutCubic
        }
      }

      NButton {
        id: authButton
        anchors.fill: parent

        property bool showSpinner: busy

        text: busy
          ? trOrDefault("status.processing", "Verifying...")
          : trOrDefault("actions.authenticate", "Authenticate")

        enabled: !busy && passwordInput.text.length > 0

        opacity: busy ? 0.7 : 1

        Behavior on opacity { NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }

        onClicked: {
          if (hasRequest && pluginMain) {
            pluginMain.submitPassword(passwordInput.text);
          }
        }

        Item {
          width: Style.fontSizeM
          height: width
          anchors.right: parent.right
          anchors.rightMargin: Style.marginM
          anchors.verticalCenter: parent.verticalCenter
          visible: authButton.showSpinner

          NIcon {
            id: spinnerIcon
            anchors.centerIn: parent
            icon: "loader"
            pointSize: Style.fontSizeS
            color: Color.mOnPrimary

            RotationAnimation on rotation {
              from: 0
              to: 360
              duration: 1000
              loops: Animation.Infinite
              running: authButton.showSpinner
              easing.type: Easing.Linear
            }
          }
        }
      }

      TapHandler {
        id: authButtonTap
        gesturePolicy: TapHandler.WithinBounds
      }
    }

    // Details Section
    ColumnLayout {
      Layout.fillWidth: true
      visible: hasRequest && hasActionDetails && !successState
      spacing: Style.marginXS
      Layout.preferredHeight: showDetailsButton.implicitHeight + detailsBox.implicitHeight + Style.marginS
      
      RowLayout {
        id: showDetailsButton
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginXS
        
        NIcon {
          icon: showDetails ? "chevron-up" : "chevron-down"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
        
        NText {
          text: showDetails ? trOrDefault("actions.hide-details", "Hide details") : trOrDefault("actions.show-details", "Show details")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
        }
        
        HoverHandler {
            id: detailsHover
            cursorShape: Qt.PointingHandCursor
        }
        
        TapHandler {
            onTapped: showDetails = !showDetails
        }
      }
      
      Rectangle {
         id: detailsBox
         Layout.fillWidth: true
         Layout.preferredHeight: detailsCol.implicitHeight + Style.marginM
         color: Color.mSurfaceVariant
         radius: Style.radiusM
         opacity: showDetails ? 1 : 0
         border.color: showDetails ? Color.mOutline : Color.transparent
         border.width: Style.borderS

         Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
         Behavior on border.color { ColorAnimation { duration: Style.animationFast } }
         
        ColumnLayout {
            id: detailsCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.marginS
            spacing: Style.marginXS
            
            NText {
               visible: hasActionDetails
                Layout.fillWidth: true
                text: trOrDefault("labels.action", "Action") + ": " + (request?.actionId ?? "")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                wrapMode: Text.WrapAnywhere
             }
        }
      }
    }
  }

  // Shake Animation on Error
  SequentialAnimation {
    id: shakeAnim
    loops: 1
    
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50; easing.type: Easing.InOutQuad }
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; to: 10; duration: 50; easing.type: Easing.InOutQuad }
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50; easing.type: Easing.InOutQuad }
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; to: 10; duration: 50; easing.type: Easing.InOutQuad }
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50; easing.type: Easing.InOutQuad }
  }

  // Focus management
  Timer {
    id: focusTimer
    interval: 100
    repeat: false
    onTriggered: focusPasswordInput()
  }

  // Entrance animation timer
  Timer {
    id: animateInTimer
    interval: 16
    repeat: false
    onTriggered: root.animateIn = true
  }

  onHasRequestChanged: {
    if (hasRequest) {
      successState = false;
      passwordInput.text = "";
      showDetails = false;
      revealPassword = false;
      focusTimer.restart();
    }
  }

  onVisibleChanged: {
    if (visible && hasRequest) {
      focusTimer.restart();
    }
  }

  Component.onCompleted: {
    animateInTimer.start();
    if (hasRequest) {
      focusTimer.restart();
    }
  }
}
