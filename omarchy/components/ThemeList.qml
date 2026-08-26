import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
  id: root

  required property var panelRoot

  Layout.fillWidth: true
  Layout.preferredHeight: Math.min(themeListLayout.implicitHeight + (Style.marginM * 2), panelRoot.maxListHeight)

  NScrollView {
    anchors.fill: parent
    anchors.margins: Style.marginM
    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AsNeeded
    clip: true

    ColumnLayout {
      id: themeListLayout
      width: parent.width
      spacing: Style.marginS

      Repeater {
        model: root.panelRoot.filteredThemes

        delegate: ThemeListEntry {
          required property var modelData
          required property int index

          panelRoot: root.panelRoot
          theme: modelData
          entryIndex: index
        }
      }

      NText {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.baseWidgetSize * 2
        visible: !root.panelRoot.filteredThemes || root.panelRoot.filteredThemes.length === 0
        text: root.panelRoot.noThemesText
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
      }
    }
  }
}
