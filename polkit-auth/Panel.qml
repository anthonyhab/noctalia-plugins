import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var screen: null

  readonly property bool allowAttach: true
  readonly property int contentPreferredWidth: Math.round(460 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: {
    const baseHeight = mainColumn.implicitHeight + (Style.marginL * 2);
    const minHeight = Math.round(200 * Style.uiScaleRatio);
    const maxHeight = Math.round(520 * Style.uiScaleRatio);
    return Math.max(minHeight, Math.min(baseHeight, maxHeight));
  }

  readonly property var pluginMain: pluginApi?.mainInstance ?? null
  readonly property var request: pluginMain?.currentRequest ?? null
  readonly property bool busy: pluginMain?.responseInFlight ?? false
  readonly property bool agentAvailable: pluginMain?.agentAvailable ?? false
  readonly property string statusText: pluginMain?.agentStatus ?? ""
  readonly property string errorText: pluginMain?.lastError ?? ""
  readonly property bool hasRequest: request !== null && request !== undefined && typeof request === "object" && request.id
  property bool showDetails: false

  readonly property string detailsText: {
    if (!hasRequest || !request.details)
      return "";
    const parts = [];
    for (const key in request.details) {
      parts.push(key + ": " + request.details[key]);
    }
    return parts.join("\n");
  }

  function trOrDefault(key, fallback) {
    if (pluginApi && pluginApi.tr) {
      const value = pluginApi.tr(key);
      if (value && !value.startsWith("##"))
        return value;
    }
    return fallback;
  }

  function closePanel() {
    pluginApi?.closePanel(root.screen);
  }

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + (Style.marginM * 2)

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "lock"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            Layout.fillWidth: true
            text: trOrDefault("title", "Polkit Authentication")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: {
              if (!agentAvailable)
                return statusText || trOrDefault("status.agent-unavailable", "Agent not available");
              if (hasRequest)
                return trOrDefault("status.authenticating", "Authentication in progress");
              return trOrDefault("status.waiting", "Waiting for authentication requests");
            }
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            elide: Text.ElideRight
          }
        }

        NIconButton {
          icon: "x"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: trOrDefault("actions.close", "Close")
          onClicked: closePanel()
        }
      }
    }

    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: bodyColumn.implicitHeight + (Style.marginM * 2)
      Layout.minimumHeight: Math.round(120 * Style.uiScaleRatio)

      ColumnLayout {
        id: bodyColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          visible: !hasRequest
          text: trOrDefault("status.idle", "No pending authentication requests.")
          wrapMode: Text.WordWrap
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
        }

        NText {
          Layout.fillWidth: true
          visible: hasRequest
          text: request?.message || trOrDefault("status.request", "Authentication required")
          wrapMode: Text.WordWrap
          color: Color.mOnSurface
        }

        NText {
          visible: hasRequest && request?.actionId
          Layout.fillWidth: true
          text: trOrDefault("labels.action", "Action") + ": " + (request?.actionId ?? "")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          wrapMode: Text.WordWrap
        }

        NText {
          visible: hasRequest && request?.user
          Layout.fillWidth: true
          text: trOrDefault("labels.user", "User") + ": " + (request?.user ?? "")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
        }

        RowLayout {
          Layout.fillWidth: true
          visible: hasRequest && detailsText.length > 0
          spacing: Style.marginS

          NButton {
            text: showDetails
              ? trOrDefault("actions.hide-details", "Hide details")
              : trOrDefault("actions.show-details", "Show details")
            implicitHeight: Math.round(30 * Style.uiScaleRatio)
            onClicked: showDetails = !showDetails
          }

          Item { Layout.fillWidth: true }
        }

        NText {
          visible: hasRequest && showDetails && detailsText.length > 0
          Layout.fillWidth: true
          text: detailsText
          wrapMode: Text.WordWrap
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
        }

        NTextInput {
          id: passwordInput
          Layout.fillWidth: true
          visible: hasRequest
          label: (hasRequest && request?.prompt && request.prompt.length > 0)
            ? request.prompt
            : trOrDefault("labels.password", "Password")
          placeholderText: trOrDefault("placeholders.password", "Enter your password")
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

        NText {
          visible: errorText.length > 0
          Layout.fillWidth: true
          text: errorText
          color: Color.mError
          pointSize: Style.fontSizeS
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: hasRequest

          NButton {
            text: busy
              ? trOrDefault("status.processing", "Working...")
              : trOrDefault("actions.authenticate", "Authenticate")
            enabled: hasRequest && !busy && passwordInput.text.length > 0
            onClicked: {
              if (hasRequest && pluginMain) {
                pluginMain.submitPassword(passwordInput.text);
                passwordInput.text = "";
              }
            }
          }

          NButton {
            text: trOrDefault("actions.cancel", "Cancel")
            enabled: hasRequest && !busy
            onClicked: {
              if (hasRequest && pluginMain) {
                pluginMain.cancelRequest();
                passwordInput.text = "";
              }
            }
          }

          Item { Layout.fillWidth: true }
        }
      }
    }
  }

  Connections {
    target: pluginMain
    ignoreUnknownSignals: true

    function onCurrentRequestChanged() {
      passwordInput.text = "";
      showDetails = false;
      if (hasRequest) {
        focusTimer.restart();
      }
    }

    function onRequestReceived() {
      if (hasRequest) {
        focusTimer.restart();
      }
    }
  }

  Timer {
    id: focusTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (hasRequest && passwordInput.visible) {
        root.forceActiveFocus();
        passwordInput.inputItem.forceActiveFocus();
      }
    }
  }

  onVisibleChanged: {
    if (visible && hasRequest) {
      focusTimer.restart();
    }
  }

  onHasRequestChanged: {
    if (hasRequest && visible) {
      focusTimer.restart();
    }
  }

  Component.onCompleted: {
    if (hasRequest) {
      focusTimer.restart();
    }
  }
}
