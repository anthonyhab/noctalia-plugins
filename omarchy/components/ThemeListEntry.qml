import QtQuick
import QtQuick.Layouts
import "../ThemeIdentity.js" as ThemeIdentity
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  required property var panelRoot
  required property var theme
  required property int entryIndex

  readonly property string themeName: ThemeIdentity.themeEntryDisplayName(theme)
  readonly property string themeDirName: ThemeIdentity.themeEntryDirName(theme)
  readonly property var themeColors: typeof theme === "object" ? theme.colors : []
  readonly property bool isCurrentTheme: themeDirName === panelRoot.pluginMain?.themeName
  readonly property bool isLoadingTheme: themeDirName === panelRoot.loadingThemeName && panelRoot.isLoading
  readonly property bool hovered: hoverArea.containsMouse
  readonly property bool selected: panelRoot.selectionEnabled && panelRoot.selectedThemeIndex === entryIndex
  readonly property bool highlighted: hovered || selected

  Layout.fillWidth: true
  implicitHeight: rowLayout.implicitHeight + (Style.marginS * 2)
  radius: Style.radiusM
  color: isCurrentTheme ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : (highlighted ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.05) : Color.mSurface)
  border.width: Style.borderS
  border.color: isCurrentTheme ? Color.mPrimary : (highlighted ? Color.mPrimary : Color.mOutline)

  RowLayout {
    id: rowLayout
    anchors.fill: parent
    anchors.leftMargin: Style.marginM
    anchors.rightMargin: Style.marginS
    anchors.topMargin: Style.marginS
    anchors.bottomMargin: Style.marginS
    spacing: Style.marginM

    NText {
      Layout.fillWidth: true
      color: Color.mOnSurface
      text: root.themeName
      pointSize: Style.fontSizeM
      font.weight: root.isCurrentTheme ? Style.fontWeightBold : Style.fontWeightMedium
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    NIcon {
      visible: root.isLoadingTheme
      icon: "refresh"
      color: Color.mPrimary
      pointSize: Style.fontSizeM
      Layout.alignment: Qt.AlignVCenter

      RotationAnimator on rotation {
        running: root.isLoadingTheme
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 1000
      }
    }

    Row {
      spacing: Style.marginXS / 2
      visible: root.themeColors.length > 0

      Repeater {
        model: root.themeColors

        Rectangle {
          width: Style.fontSizeM * 0.9
          height: Style.fontSizeM * 0.9
          radius: width / 2
          color: modelData
          border.color: Qt.darker(modelData, 1.2)
          border.width: Style.borderS
        }
      }
    }

    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      opacity: root.selected ? 1 : 0
      Layout.preferredWidth: Style.fontSizeM * 1.8
      Layout.preferredHeight: Style.fontSizeM * 1.8
      radius: Style.radiusS
      color: Color.mSurfaceVariant
      border.width: Style.borderS
      border.color: Color.mOnSurfaceVariant

      NIcon {
        anchors.centerIn: parent
        icon: "corner-down-left"
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    enabled: !root.panelRoot.isLoading
    onEntered: {
      if (root.panelRoot.selectionEnabled)
        root.panelRoot.selectedThemeIndex = root.entryIndex;
    }
    onClicked: {
      if (root.panelRoot.isLoading)
        return;
      root.panelRoot.handleThemeSelection(root.themeDirName);
    }
  }
}
