import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import "ColorUtils.js" as ColorUtils

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

  // --- 0. RICH CONTEXT DATA ---
  readonly property var requestor: request?.requestor ?? null
  readonly property var subject: request?.subject ?? null
  
  readonly property string displayAction: {
    if (!hasRequest || !request.message) return "authenticate";
    const msg = request.message;
    // Common polkit message patterns:
    // "Authentication is needed to run `/usr/bin/echo' as the super user"
    const runMatch = msg.match(/run `([^']+)'/);
    if (runMatch && runMatch[1]) {
        const parts = runMatch[1].split('/');
        return "run " + parts[parts.length - 1];
    }
    
    // Default to a cleaned up version of the message if it's short
    if (msg.length < 40) return msg.toLowerCase();
    
    return "perform this action";
  }

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
  // Use standard radii from Style to respect user's container radius settings.
  readonly property int radiusInner: getStyle("radiusM", 8)

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

  // Fallback Icon Square component
  component FallbackIcon: NBox {
    property string letter: ""
    property string key: ""
    implicitWidth: iconTile * 1.5
    implicitHeight: width
    radius: radiusInner
    color: ColorUtils.getStableColor(key, ColorUtils.getVibrantPalette(true)) // Assuming dark mode for now, should check theme
    NText {
        anchors.centerIn: parent
        text: letter
        font.weight: getStyle("fontWeightBold", 700)
        pointSize: Math.round(parent.width * 0.5)
        color: "white"
    }
  }

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
    
    // Visual Identity Section (1Password Style)
    ColumnLayout {
        visible: !successState && hasRequest
        Layout.fillWidth: true
        spacing: unit
        
        // Visual Connection Row
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: gapItems
            
            // Requestor Icon
            Item {
                Layout.preferredWidth: iconTile * 1.5
                Layout.preferredHeight: width
                
                NIcon {
                    anchors.fill: parent
                    visible: requestor && requestor.iconName
                    icon: requestor ? requestor.iconName : ""
                    pointSize: Math.round(parent.width * 0.8)
                    color: getColor("mPrimary", "blue")
                }
                
                FallbackIcon {
                    anchors.fill: parent
                    visible: !requestor || !requestor.iconName
                    letter: requestor ? requestor.fallbackLetter : "?"
                    key: requestor ? requestor.fallbackKey : "unknown"
                }
            }
            
            // Connection line with check
            RowLayout {
                spacing: 0
                Rectangle { width: unit * 2; height: 1; color: getColor("mOutline", "#ccc") }
                NBox {
                    width: unit * 2; height: width; radius: width/2; color: "green"; border.width: 0
                    NIcon { anchors.centerIn: parent; icon: "check"; pointSize: 8; color: "white" }
                }
                Rectangle { width: unit * 2; height: 1; color: getColor("mOutline", "#ccc") }
            }
            
            // Polkit Icon (Providing App)
            NBox {
                Layout.preferredWidth: iconTile * 1.5
                Layout.preferredHeight: width
                radius: width/2
                color: Qt.alpha(getColor("mPrimary", "blue"), 0.1)
                border.width: 0
                NIcon {
                    anchors.centerIn: parent
                    icon: "lock"
                    pointSize: Math.round(parent.width * 0.5)
                    color: getColor("mPrimary", "blue")
                }
            }
        }
        
        // Instructional Message
        NText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
                const app = requestor ? "<b>" + requestor.displayName + "</b>" : "An application";
                return "Allow " + app + " to " + displayAction;
            }
            textFormat: Text.RichText
            pointSize: getStyle("fontSizeM", 14)
            color: getColor("mOnSurface", "black")
        }
    }

    // Success State Section
    ColumnLayout {
      visible: successState
      Layout.fillWidth: true
      spacing: unit
      
      NIcon {
        Layout.alignment: Qt.AlignHCenter
        icon: "circle-check"
        pointSize: Math.round(getStyle("fontSizeXXXL", 32) * 1.5)
        color: "green"
      }
      
      NText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: trOrDefault("status.authenticated", "Authenticated")
        font.weight: getStyle("fontWeightBold", 700)
        pointSize: getStyle("fontSizeXL", 20)
        color: getColor("mOnSurface", "black")
      }
    }

    // Compact Header (Fallback for when no request)
    NBox {
        id: headerCard
        visible: !hasRequest && !successState

    // Identity Card
    NBox {
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
                NBox {
                    anchors.fill: parent; radius: width / 2; color: getColor("mSecondaryContainer", "#ddd")
                    border.width: 0
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

        NDivider { visible: displayUser.length > 0 && commandPath !== ""; Layout.fillWidth: true }

        NText {
            visible: commandPath !== ""; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: commandPath; font.family: "Monospace"; color: getColor("mOnSurfaceVariant", "#666"); pointSize: 12; elide: Text.ElideMiddle
        }
      }
    }

    // Password Input
    NBox {
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
      
      Binding {
        target: authButton.background || null
        property: "radius"
        value: radiusInner
        when: authButton.background !== undefined
      }

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
