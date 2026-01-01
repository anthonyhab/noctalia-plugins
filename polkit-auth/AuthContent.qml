import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

  // Signal to request closing the container (window or panel)
  signal closeRequested()

  // Implicit sizing for parent containers
  implicitWidth: mainColumn.implicitWidth + (Style.marginXL * 2)
  implicitHeight: mainColumn.implicitHeight + (Style.marginXL * 2)

  // Computed property
  readonly property bool hasRequest: request !== null && request !== undefined && typeof request === "object" && request.id
  readonly property string displayUser: formatUser(request?.user ?? "")
  readonly property bool hasActionDetails: !!request?.actionId
  readonly property bool fingerprintAvailable: request?.fingerprintAvailable ?? false

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
      } else {
        shakeAnim.restart();
        passwordInput.text = "";
        focusPasswordInput();
      }
    }
  }

  // Close button (top right, subtle)
  NIconButton {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.marginS
    z: 10
    visible: hasRequest && !successState
    icon: "x"
    baseSize: Math.round(Style.baseWidgetSize * 0.75)
    colorBg: "transparent"
    colorFg: Color.mOnSurfaceVariant
    colorBgHover: Color.mSurfaceVariant
    colorFgHover: Color.mOnSurface
    tooltipText: trOrDefault("actions.close", "Close")
    onClicked: {
      if (hasRequest) {
        pluginMain?.cancelRequest();
      }
      root.closeRequested();
    }
  }

  ColumnLayout {
    id: mainColumn
    anchors.centerIn: parent
    width: parent.width - (Style.marginXL * 2)
    spacing: Style.marginL

    // Icon (Animated)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: lockIcon.height

      NIcon {
        id: lockIcon
        anchors.horizontalCenter: parent.horizontalCenter
        icon: successState ? "lock-open" : (hasRequest ? "lock" : "shield")
        pointSize: Math.round(Style.fontSizeXXXL * 2.0)
        color: successState ? Color.mPrimary : Color.mPrimary

        Behavior on color {
          ColorAnimation { duration: Style.animationFast || 150 }
        }
      }
    }

    // Title
    NText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: {
        if (successState) return trOrDefault("status.authenticated", "Authenticated");
        if (hasRequest) return trOrDefault("status.request", "Authentication Required");
        return trOrDefault("title", "Polkit Authentication");
      }
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeXL
      color: Color.mOnSurface
    }

    // Command Pill (New)
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.maximumWidth: parent.width
      visible: hasRequest && commandPath !== "" && !successState
      color: Color.mSurfaceVariant
      radius: Style.radiusM
      implicitWidth: cmdText.implicitWidth + Style.marginL
      implicitHeight: cmdText.implicitHeight + Style.marginS
      
      border.color: Color.mOutline
      border.width: 1

      NText {
        id: cmdText
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - Style.marginXL * 3)
        text: commandPath
        font.family: "Monospace"
        color: Color.mOnSurfaceVariant
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
      }
    }

    // User Identity (New)
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      visible: hasRequest && displayUser.length > 0 && !successState
      spacing: Style.marginS

      Rectangle {
        width: Style.iconSizeM && Style.iconSizeM > 0 ? Style.iconSizeM : Math.round(Style.baseWidgetSize * 0.8)
        height: width
        radius: width / 2
        color: (Color.mSecondaryContainer !== undefined) ? Color.mSecondaryContainer : Color.mSurfaceVariant
        
        NIcon {
          anchors.centerIn: parent
          icon: "user"
          pointSize: Style.fontSizeS
          color: (Color.mOnSecondaryContainer !== undefined) ? Color.mOnSecondaryContainer : Color.mPrimary
        }
      }

      NText {
        text: displayUser
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
        pointSize: Style.fontSizeM
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
      
      // Focus Glow
      Rectangle {
        anchors.fill: passwordInput
        anchors.margins: -2
        radius: Style.radiusM
        color: "transparent"
        border.color: Color.mPrimary
        border.width: 2
        opacity: passwordInput.activeFocus ? 0.6 : 0
        
        Behavior on opacity { NumberAnimation { duration: 150 } }
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
        
        Behavior on anchors.rightMargin { NumberAnimation { duration: 100 } }

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
    NButton {
      id: authButton
      Layout.fillWidth: true
      Layout.preferredHeight: Style.baseWidgetSize * 1.2
      visible: hasRequest && !successState
      
      property bool showSpinner: busy
      
      text: busy
        ? trOrDefault("status.processing", "Verifying...")
        : trOrDefault("actions.authenticate", "Authenticate")
      
      enabled: !busy && passwordInput.text.length > 0
      
      opacity: busy ? 0.7 : 1
      
      Behavior on opacity { NumberAnimation { duration: 150 } }
      
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
    
    // Spacer
    Item {
       Layout.fillWidth: true
       Layout.preferredHeight: Style.marginS
       visible: hasRequest && !successState
    }

    // Cancel Button (Secondary)
    NText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      visible: hasRequest && !busy && !successState
      text: trOrDefault("actions.cancel", "Cancel")
      color: cancelHover.hovered ? Color.mPrimary : Color.mOnSurfaceVariant
      font.underline: cancelHover.hovered
      
      HoverHandler {
        id: cancelHover
        cursorShape: Qt.PointingHandCursor
      }
      
      TapHandler {
        onTapped: {
           pluginMain?.cancelRequest();
           passwordInput.text = "";
        }
      }
    }

    // Details Section
    ColumnLayout {
      Layout.fillWidth: true
      visible: hasRequest && hasActionDetails && !successState
      spacing: Style.marginXS
      
      RowLayout {
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
         Layout.fillWidth: true
         Layout.preferredHeight: detailsCol.implicitHeight + Style.marginM
         color: Color.mSurfaceVariant // Used in other plugin for thumbs
         radius: Style.radiusM
         visible: showDetails
         opacity: showDetails ? 1 : 0
         
         Behavior on opacity { NumberAnimation { duration: 200 } }
         
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
    if (hasRequest) {
      focusTimer.restart();
    }
  }
}
