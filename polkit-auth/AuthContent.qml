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

  // Computed property
  readonly property bool hasRequest: request !== null && request !== undefined && typeof request === "object" && request.id

  // Internal state
  property bool showDetails: false

  // Signal to request closing the container (window or panel)
  signal closeRequested()

  // Implicit sizing for parent containers
  implicitWidth: mainColumn.implicitWidth + (Style.marginXL * 2)
  implicitHeight: mainColumn.implicitHeight + (Style.marginXL * 2)

  function trOrDefault(key, fallback) {
    return fallback;
  }

  function focusPasswordInput() {
    if (hasRequest && passwordInput.visible) {
      root.forceActiveFocus();
      passwordInput.inputItem.forceActiveFocus();
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
    anchors.fill: parent
    anchors.margins: Style.marginXL
    spacing: Style.marginL

    // Spacer for top
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.marginM
    }

    // Large centered icon
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: lockIcon.height

      NIcon {
        id: lockIcon
        anchors.horizontalCenter: parent.horizontalCenter
        icon: hasRequest ? "lock" : "lock-open"
        pointSize: Math.round(Style.fontSizeXXXL * 1.8)
        color: Color.mPrimary
      }
    }

    // Title
    NText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: hasRequest
        ? trOrDefault("title.auth-required", "Authentication Required")
        : trOrDefault("title.waiting", "Polkit Authentication")
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeL
      color: Color.mOnSurface
    }

    // Subtitle / status (when no request)
    NText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      visible: !hasRequest
      text: agentAvailable
        ? trOrDefault("status.waiting", "Waiting for authentication requests")
        : (statusText || trOrDefault("status.unavailable", "Agent not available"))
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    // Message (when request active)
    NText {
      Layout.fillWidth: true
      Layout.topMargin: -Style.marginS
      horizontalAlignment: Text.AlignHCenter
      visible: hasRequest && (request?.message ?? "").length > 0
      text: request?.message ?? ""
      wrapMode: Text.WordWrap
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeM
    }

    // Spacer
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.marginS
      visible: hasRequest
    }

    // Password input (no label, just placeholder)
    NTextInput {
      id: passwordInput
      Layout.fillWidth: true
      visible: hasRequest
      placeholderText: (hasRequest && request?.prompt && request.prompt.length > 0)
        ? request.prompt
        : trOrDefault("input.password", "Enter password")
      text: ""
      inputItem.echoMode: (hasRequest && request?.echo === true) ? TextInput.Normal : TextInput.Password
      enabled: hasRequest && !busy
      inputItem.Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (hasRequest && !busy && passwordInput.text.length > 0) {
            pluginMain?.submitPassword(passwordInput.text);
            passwordInput.text = "";
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

    // Error message
    NText {
      Layout.fillWidth: true
      visible: errorText.length > 0
      horizontalAlignment: Text.AlignHCenter
      text: errorText
      color: Color.mError
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    // Authenticate button (full width)
    NButton {
      Layout.fillWidth: true
      visible: hasRequest
      text: busy
        ? trOrDefault("button.working", "Authenticating...")
        : trOrDefault("button.authenticate", "Authenticate")
      enabled: hasRequest && !busy && passwordInput.text.length > 0
      onClicked: {
        if (hasRequest && pluginMain) {
          pluginMain.submitPassword(passwordInput.text);
          passwordInput.text = "";
        }
      }
    }

    // Cancel text (subtle, clickable)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: cancelText.height
      visible: hasRequest && !busy

      NText {
        id: cancelText
        anchors.horizontalCenter: parent.horizontalCenter
        text: trOrDefault("button.cancel", "Cancel")
        color: cancelHover.hovered ? Color.mPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS

        Behavior on color {
          ColorAnimation { duration: Style.animationFast }
        }

        HoverHandler {
          id: cancelHover
          cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
          onTapped: {
            if (hasRequest && pluginMain) {
              pluginMain.cancelRequest();
              passwordInput.text = "";
            }
          }
        }
      }
    }

    // Spacer before details
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: Style.marginM
    }

    // Details toggle (very subtle)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: detailsToggle.height
      visible: hasRequest && (request?.actionId || request?.user)

      RowLayout {
        id: detailsToggle
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.marginXS

        NIcon {
          icon: showDetails ? "chevron-up" : "info"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          opacity: detailsHover.hovered ? 0.9 : 0.5
        }

        NText {
          text: showDetails
            ? trOrDefault("details.hide", "Hide details")
            : trOrDefault("details.show", "Details")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          opacity: detailsHover.hovered ? 0.9 : 0.5
        }

        HoverHandler {
          id: detailsHover
          cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
          onTapped: showDetails = !showDetails
        }
      }
    }

    // Expanded details
    ColumnLayout {
      Layout.fillWidth: true
      visible: showDetails && hasRequest
      spacing: Style.marginXS
      opacity: showDetails ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: Style.animationFast }
      }

      NText {
        visible: !!request?.actionId
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: request?.actionId ?? ""
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        elide: Text.ElideMiddle
        opacity: 0.7
      }

      NText {
        visible: !!request?.user
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: request?.user ?? ""
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        opacity: 0.7
      }
    }
  }

  // Focus management
  Timer {
    id: focusTimer
    interval: 100
    repeat: false
    onTriggered: focusPasswordInput()
  }

  onHasRequestChanged: {
    passwordInput.text = "";
    showDetails = false;
    if (hasRequest) {
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
