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

  // --- 1. THE UNIT SYSTEM (Single source of truth) ---
  
  readonly property string barSpaciousness: Settings?.data?.bar?.spaciousness ?? "default"
  
  // The spacing 'U'
  readonly property int unit: {
    switch (barSpaciousness) {
      case "mini": return 4;
      case "compact": return 6;
      case "comfortable": return 12;
      case "spacious": return 16;
      default: return 8;
    }
  }

  // Padding Logic:
  // - Outer: 2U (Edge to items)
  // - Gaps: 2U (Between items)
  // - Inner: 1.5U (Item border to item content)
  readonly property int padOuter: unit * 2
  readonly property int padInner: Math.round(unit * 1.5)
  readonly property int gapItems: unit * 2
  readonly property int baseSize: Math.round(getStyle("baseWidgetSize", 32))
  readonly property int controlHeight: Math.round(baseSize * 1.4)
  readonly property int iconTile: baseSize
  readonly property int overlayButton: Math.round(baseSize * 0.75)

  // Radius Logic:
  // - Outer: XL (from theme)
  // - Inner: XL - P_OUTER (perfectly concentric)
  readonly property int radiusOuter: getStyle("radiusXL", 24)
  readonly property int radiusInner: Math.max(getStyle("radiusS", 4), radiusOuter - padOuter)

  // --- 2. THEME HELPERS ---

  function getColor(path, fallback) {
    if (typeof Color === "undefined" || Color === null) return fallback;
    const parts = path.split('.');
    let cur = Color;
    for (const p of parts) { if (cur[p] === undefined) return fallback; cur = cur[p]; }
    return cur;
  }

  function getStyle(prop, fallback) {
    if (typeof Style === "undefined" || Style === null) return fallback;
    return Style[prop] !== undefined ? Style[prop] : fallback;
  }

  // --- 3. COMPUTED DATA ---
  readonly property bool hasRequest: request !== null && request !== undefined && typeof request === "object" && request.id
  readonly property string displayUser: formatUser(request?.user ?? "")
  readonly property bool fingerprintAvailable: request?.fingerprintAvailable ?? false
  readonly property bool useBigLayout: !hasRequest || successState

  readonly property string commandPath: {
    if (!hasRequest || !request.message) return "";
    const msg = request.message;
    const match = msg.match(/'([^']+)'/);
    if (match && match[1]) return match[1];
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
    if (value.indexOf("unix-user:") === 0) return value.slice("unix-user:".length);
    return value;
  }

  function focusPasswordInput() {
    if (hasRequest && passwordInput.visible) {
      root.forceActiveFocus();
      passwordInput.inputItem.forceActiveFocus();
    }
  }

  property int stableHeight: 0
  function updateStableHeight() {
    if (!hasRequest) return;
    const next = mainColumn.implicitHeight + (padOuter * 2);
    if (next > stableHeight) stableHeight = next;
  }


  Connections {
    target: pluginMain
    function onRequestCompleted(success) {
      if (success) successState = true;
      else { shakeAnim.restart(); passwordInput.text = ""; focusPasswordInput(); }
    }
  }

  // --- 4. UI STRUCTURE ---

  implicitWidth: Math.round(400 * getStyle("uiScaleRatio", 1.0))
  implicitHeight: Math.max(mainColumn.implicitHeight + (padOuter * 2), stableHeight > 0 ? stableHeight : 0)

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: padOuter
    spacing: gapItems
    onImplicitHeightChanged: root.updateStableHeight()

    opacity: root.animateIn ? 1.0 : 0.0
    transform: Scale {
        origin.x: mainColumn.width / 2; origin.y: mainColumn.height / 2
        xScale: root.animateIn ? 1.0 : 0.95; yScale: root.animateIn ? 1.0 : 0.95
    }
    Behavior on opacity { NumberAnimation { duration: getStyle("animationNormal", 200); easing.type: Easing.OutCubic } }
    
    // Icon Section
    Item {
      visible: useBigLayout
      Layout.fillWidth: true
      Layout.preferredHeight: bigLockIcon.height
      Layout.topMargin: unit

      NIcon {
        id: bigLockIcon
        anchors.centerIn: parent
        icon: successState ? "circle-check" : (hasRequest ? "lock" : "shield")
        pointSize: Math.round(getStyle("fontSizeXXXL", 32) * 1.5)
        color: getColor("mPrimary", "blue")
      }
    }

    // Title Section
    NText {
      visible: useBigLayout
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: successState ? trOrDefault("status.authenticated", "Authenticated") : trOrDefault("title", "Polkit Authentication")
      font.weight: getStyle("fontWeightBold", 700)
      pointSize: getStyle("fontSizeXL", 20)
      color: getColor("mOnSurface", "black")
    }

    // Compact Header
    Rectangle {
        id: headerCard
        visible: !useBigLayout
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + (padInner * 2)
        color: getColor("mSurfaceVariant", "#eee")
        radius: radiusInner
        border.color: getColor("mOutline", "#ccc")
        border.width: 1

        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.margins: padInner
            spacing: padInner

            Rectangle {
                Layout.preferredWidth: iconTile
                Layout.preferredHeight: iconTile
                Layout.alignment: Qt.AlignVCenter
                radius: Math.max(4, radiusInner - 4)
                color: Qt.alpha(getColor("mPrimary", "blue"), 0.1)
                NIcon { anchors.centerIn: parent; icon: "lock"; pointSize: 16; color: getColor("mPrimary", "blue") }
            }

            NText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: trOrDefault("status.request", "Authentication Required")
                font.weight: getStyle("fontWeightBold", 700)
                pointSize: getStyle("fontSizeM", 14)
                color: getColor("mOnSurface", "black")
                elide: Text.ElideRight
            }

            NIconButton {
                Layout.preferredWidth: iconTile
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter
                icon: "x"; baseSize: Layout.preferredWidth; colorBg: "transparent"
                onClicked: {
                    if (hasRequest && !busy) {
                        pluginMain?.requestClose();
                        passwordInput.text = "";
                    }
                }
            }
        }
    }

    // Identity Card
    Rectangle {
      visible: hasRequest && !successState && (displayUser.length > 0 || commandPath !== "")
      Layout.fillWidth: true
      implicitHeight: contextCol.implicitHeight + (padInner * 2)
      radius: radiusInner
      color: getColor("mSurfaceVariant", "#eee")
      border.color: getColor("mOutline", "#ccc")
      border.width: 1

      ColumnLayout {
        id: contextCol
        anchors.fill: parent
        anchors.margins: padInner
        spacing: padInner

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: displayUser.length > 0
            spacing: unit

            Item {
                width: Math.round(baseSize * 0.8)
                height: width
                Rectangle {
                    anchors.fill: parent; radius: width / 2; color: getColor("mSecondaryContainer", "#ddd")
                    NIcon { anchors.centerIn: parent; visible: avatarImage.status !== Image.Ready; icon: "user"; pointSize: 12 }
                }
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

                    imageFillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
            }

            NText { text: displayUser; font.weight: 500; pointSize: 14 }
        }

        Rectangle { visible: displayUser.length > 0 && commandPath !== ""; Layout.fillWidth: true; Layout.preferredHeight: 1; color: getColor("mOutline", "#ccc"); opacity: 0.1 }

        NText {
            visible: commandPath !== ""; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: commandPath; font.family: "Monospace"; color: getColor("mOnSurfaceVariant", "#666"); pointSize: 12; elide: Text.ElideMiddle
        }
      }
    }

    // Password Input
    Rectangle {
      id: inputWrapper
      Layout.fillWidth: true
      implicitHeight: passwordInput.implicitHeight + (padInner * 2)
      visible: hasRequest && !successState
      radius: radiusInner
      color: getColor("mSurfaceVariant", "#eee")
      border.color: errorText.length > 0 ? getColor("mError", "red") : (passwordInput.activeFocus ? getColor("mPrimary", "blue") : getColor("mOutline", "#ccc"))
      border.width: passwordInput.activeFocus ? 2 : 1

      NTextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.leftMargin: padInner
        anchors.rightMargin: overlayIcons.width + padInner + unit
        anchors.topMargin: padInner
        anchors.bottomMargin: padInner
        
        inputItem.font.pointSize: getStyle("fontSizeM", 14)
        inputItem.verticalAlignment: TextInput.AlignVCenter
        placeholderText: request?.prompt || trOrDefault("placeholders.password", "Enter password")
        text: ""
        inputItem.echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
        enabled: !busy
        
        Component.onCompleted: { if (passwordInput.background) passwordInput.background.visible = false; }

        KeyNavigation.tab: authButton
        inputItem.Keys.onPressed: function (event) {
          if (event.key === Qt.Key_CapsLock) root.capsLockOn = !root.capsLockOn;
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (hasRequest && !busy && passwordInput.text.length > 0) pluginMain?.submitPassword(passwordInput.text);
          } else if (event.key === Qt.Key_Escape) {
            if (hasRequest && !busy) { pluginMain?.requestClose(); passwordInput.text = ""; }
          }
        }
      }

      Row {
        id: overlayIcons; anchors.right: parent.right; anchors.rightMargin: padInner; anchors.verticalCenter: parent.verticalCenter; spacing: unit
        NIcon { visible: root.capsLockOn; icon: "arrow-up-circle"; pointSize: 14; color: getColor("mError", "red") }
        NIconButton { icon: root.revealPassword ? "eye-off" : "eye"; baseSize: overlayButton; colorBg: "transparent"; onClicked: root.revealPassword = !root.revealPassword }
      }
    }

    // Authenticate Button
    NButton {
      id: authButton
      visible: hasRequest && !successState
      Layout.fillWidth: true
      Layout.preferredHeight: controlHeight
      text: busy ? trOrDefault("status.processing", "Verifying...") : trOrDefault("actions.authenticate", "Authenticate")
      enabled: !busy && passwordInput.text.length > 0
      
      Component.onCompleted: { if (authButton.background) authButton.background.radius = radiusInner; }
      onClicked: if (hasRequest && pluginMain) pluginMain.submitPassword(passwordInput.text)

      NIcon {
        anchors.right: parent.right; anchors.rightMargin: padInner; anchors.verticalCenter: parent.verticalCenter
        visible: busy; icon: "loader"; pointSize: 12
        RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: busy }
      }
    }

    // Fingerprint / Feedback
    ColumnLayout {
      Layout.fillWidth: true; spacing: unit
      visible: !successState && (errorText.length > 0 || (hasRequest && fingerprintAvailable && !busy))

      RowLayout {
        Layout.alignment: Qt.AlignHCenter; visible: hasRequest && fingerprintAvailable && !busy; spacing: unit
        NIcon { icon: "fingerprint"; pointSize: 14; color: getColor("mPrimary", "blue") }
        NText { text: trOrDefault("status.fingerprint-hint", "Touch fingerprint sensor"); color: getColor("mOnSurfaceVariant", "#666"); pointSize: 12 }
      }

      NText {
        Layout.fillWidth: true; visible: errorText.length > 0; horizontalAlignment: Text.AlignHCenter
        text: errorText; color: getColor("mError", "red"); pointSize: 12; wrapMode: Text.WordWrap
      }
    }
  }

  // State Management
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; from: 0; to: -8; duration: 50 }
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; to: 8; duration: 50 }
    NumberAnimation { target: mainColumn; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
  }
  Timer { id: focusTimer; interval: 100; onTriggered: focusPasswordInput() }
  Timer { id: animateInTimer; interval: 16; onTriggered: root.animateIn = true }
  onHasRequestChanged: {
    if (!hasRequest) stableHeight = 0;
    else { stableHeight = 0; successState = false; passwordInput.text = ""; revealPassword = false; focusTimer.restart(); updateStableHeight(); }
  }
  onVisibleChanged: if (visible && hasRequest) { focusTimer.restart(); updateStableHeight(); }
  Component.onCompleted: { animateInTimer.start(); if (hasRequest) { focusTimer.restart(); updateStableHeight(); } }
}
