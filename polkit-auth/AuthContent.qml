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
    return fallback; // Placeholder for actual translation logic if available
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
    icon: "x"
    baseSize: Math.round(Style.baseWidgetSize * 0.75)
    colorBg: "transparent"
    colorFg: Color.mOnSurfaceVariant
    colorBgHover: Color.mSurfaceVariant
    colorFgHover: Color.mOnSurface
    tooltipText: trOrDefault("actions.close", "Close")
    onClicked: root.closeRequested()
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
          ColorAnimation { duration: Style.animationNormal } // animationNormal might be missing, assume animationFast or 150
        }
      }
    }

    // Title
    NText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: {
        if (successState) return trOrDefault("title.authenticated", "Authenticated");
        if (hasRequest) return trOrDefault("title.auth-required", "Authentication Required");
        return trOrDefault("title.waiting", "Polkit Agent");
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
      visible: hasRequest && (request?.user || "").length > 0 && !successState
      spacing: Style.marginS

      Rectangle {
        width: Style.iconSizeM // iconSizeM might be missing? BaseWidgetSize is safer?
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
        text: (request?.user ?? "")
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
            ? trOrDefault("status.waiting", "Waiting for requests...")
            : (statusText || trOrDefault("status.unavailable", "Agent unavailable"));
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
      Layout.preferredHeight: passwordInput.height
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
            color: Color.mWarning
            
            ToolTip.visible: mouseAreaCaps.containsMouse
            ToolTip.text: trOrDefault("warning.caps-lock", "Caps Lock is On")
            
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

        placeholderText: request?.prompt || trOrDefault("input.password", "Password")
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
        ? trOrDefault("button.working", "Verifying...")
        : trOrDefault("button.authenticate", "Authenticate")
      
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
      text: trOrDefault("button.cancel", "Cancel")
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
      visible: hasRequest && (request?.actionId || request?.user) && !successState
      spacing: Style.marginXS
      
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.marginM
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginXS
        
        NIcon {
          icon: showDetails ? "chevron-up" : "chevron-down"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
        
        NText {
          text: showDetails ? trOrDefault("details.hide", "Hide Details") : trOrDefault("details.show", "Show Details")
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
                visible: !!request?.actionId
                Layout.fillWidth: true
                text: "<b>Action:</b> " + (request?.actionId ?? "")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                wrapMode: Text.WrapAnywhere
             }
             
             NText {
                visible: !!request?.user
                Layout.fillWidth: true
                text: "<b>User:</b> " + (request?.user ?? "")
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
             }
             
             NText {
                 visible: !!request?.message
                 Layout.fillWidth: true
                 text: "<b>Message:</b> " + (request?.message ?? "")
                 color: Color.mOnSurfaceVariant
                 pointSize: Style.fontSizeXS
                 wrapMode: Text.Wrap
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