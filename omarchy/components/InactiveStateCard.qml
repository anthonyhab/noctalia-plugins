import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
  id: root

  required property var panelRoot

  Layout.fillWidth: true
  color: Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08)
  border.width: Style.borderS
  border.color: Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.35)

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NText {
      Layout.fillWidth: true
      text: root.panelRoot.inactiveTitleText
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
      wrapMode: Text.WordWrap
    }

    NText {
      Layout.fillWidth: true
      text: root.panelRoot.isAvailable ? root.panelRoot.inactiveDescriptionText : root.panelRoot.settingsHintText
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        text: root.panelRoot.trOrDefault("actions.activate", "Activate")
        enabled: !!root.panelRoot.pluginMain && root.panelRoot.isAvailable && !root.panelRoot.isLoading
        onClicked: root.panelRoot.activatePlugin()
      }

      NButton {
        text: root.panelRoot.trOrDefault("tooltips.close", "Close")
        onClicked: root.panelRoot.pluginApi?.closePanel(root.panelRoot.screen)
      }
    }
  }
}
