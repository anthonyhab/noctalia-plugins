import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
  id: root

  required property var panelRoot

  Layout.fillWidth: true
  Layout.preferredHeight: headerRow.implicitHeight + (Style.marginM * 2)

  RowLayout {
    id: headerRow
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    NIcon {
      Layout.alignment: Qt.AlignVCenter
      icon: "palette"
      pointSize: Style.fontSizeXXL
      color: Color.mPrimary
    }

    NText {
      Layout.alignment: Qt.AlignVCenter
      Layout.fillWidth: true
      text: root.panelRoot.titleText
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeL
      color: Color.mOnSurface
    }

    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: Style.toOdd(Style.baseWidgetSize * 0.8)
      Layout.preferredWidth: filterLabel.implicitWidth + (Style.marginM * 2)
      radius: Style.radiusM
      color: filterHover.containsMouse ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : Color.mSurface
      border.width: Style.borderS
      border.color: filterHover.containsMouse ? Color.mPrimary : Color.mOutline

      NText {
        id: filterLabel
        anchors.centerIn: parent
        text: root.panelRoot.themeFilterLabel
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      MouseArea {
        id: filterHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.panelRoot.cycleThemeFilter()
      }
    }

    NIconButton {
      Layout.alignment: Qt.AlignVCenter
      icon: "close"
      baseSize: Style.baseWidgetSize * 0.8
      tooltipText: root.panelRoot.trOrDefault("tooltips.close", "Close")
      onClicked: root.panelRoot.pluginApi?.closePanel(root.panelRoot.screen)
    }
  }
}
