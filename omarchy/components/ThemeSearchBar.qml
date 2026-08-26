import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
  id: root

  required property var panelRoot
  property alias text: searchInput.text
  readonly property bool inputActiveFocus: searchInput.activeFocus

  function focusInput() {
    searchInput.forceActiveFocus();
  }

  Layout.fillWidth: true
  Layout.preferredHeight: Math.round(34 * Style.uiScaleRatio)
  color: Color.mSurfaceVariant

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginM
    anchors.rightMargin: Style.marginS
    spacing: Style.marginS

    NIcon {
      icon: "search"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignVCenter
    }

    TextField {
      id: searchInput
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignVCenter
      text: root.panelRoot.searchQuery
      color: Color.mOnSurface
      font.family: root.panelRoot.settingsGroupValue("ui", "fontDefault", "")
      font.pointSize: Style.fontSizeS * (root.panelRoot.settingsGroupValue("ui", "fontDefaultScale", 1) * Style.uiScaleRatio)
      font.weight: Style.fontWeightMedium
      verticalAlignment: TextInput.AlignVCenter
      selectByMouse: true
      selectionColor: Color.mPrimary
      selectedTextColor: Color.mOnPrimary
      background: null
      leftPadding: 0
      rightPadding: 0
      topPadding: 0
      bottomPadding: 0

      onTextChanged: {
        if (root.panelRoot.searchQuery !== text)
          root.panelRoot.searchQuery = text;

        if (text.trim() === "")
          root.panelRoot.selectedThemeIndex = -1;
        else
          root.panelRoot.selectedThemeIndex = 0;
      }

      onAccepted: {
        root.panelRoot.applySelectedTheme();
      }

      Keys.onPressed: function (event) {
        if (!root.panelRoot.selectionEnabled)
          return;
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
          root.panelRoot.moveSelection(1);
          event.accepted = true;
          return;
        }

        if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
          root.panelRoot.moveSelection(-1);
          event.accepted = true;
          return;
        }
      }

      NText {
        text: root.panelRoot.trOrDefault("panel.search-placeholder", "Search themes...")
        visible: searchInput.text === "" && !searchInput.activeFocus
        color: Color.mOnSurfaceVariant
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        pointSize: Style.fontSizeS
      }

      Component.onCompleted: forceActiveFocus()
    }

    NIconButton {
      icon: "circle-x"
      visible: root.panelRoot.searchQuery !== ""
      baseSize: Style.baseWidgetSize * 0.65
      Layout.alignment: Qt.AlignVCenter
      onClicked: {
        root.panelRoot.searchQuery = "";
        searchInput.text = "";
        searchInput.forceActiveFocus();
      }
    }
  }
}
