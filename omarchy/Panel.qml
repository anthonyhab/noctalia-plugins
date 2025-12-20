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
  readonly property int contentPreferredWidth: Math.round(340 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: mainColumn.implicitHeight + (Style.marginL * 2)
  readonly property real maxListHeight: 300 * Style.uiScaleRatio

  readonly property var pluginMain: pluginApi?.mainInstance

  function trOrDefault(key, fallback) {
    if (pluginApi && pluginApi.tr) {
      const value = pluginApi.tr(key);
      if (value && !value.startsWith("##"))
        return value;
    }
    return fallback;
  }

  readonly property string titleText: trOrDefault("title", "Omarchy")
  readonly property string settingsHintText: trOrDefault("panel.settings-hint", "Configure Omarchy paths from Settings → Plugins → Omarchy.")
  readonly property string noThemesText: trOrDefault("errors.no-themes", "No themes found")

  readonly property bool isActive: pluginApi?.pluginSettings?.active || false

  readonly property color secondaryColor: Color.mSecondary !== undefined ? Color.mSecondary : Color.mPrimary

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // Header card
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + (Style.marginM * 2)

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "palette"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        NText {
          Layout.fillWidth: true
          text: titleText
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeL
          color: Color.mOnSurface
        }

        Rectangle {
          width: Style.fontSizeM
          height: Style.fontSizeM
          radius: width / 2
          color: isActive ? Color.mPrimary : Color.mError
          border.width: Style.borderS
          border.color: Color.mOutline

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (isActive) {
                pluginMain?.deactivate();
              } else {
                pluginMain?.activate();
              }
            }
          }
        }

        NIconButton {
          icon: "close"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: trOrDefault("tooltips.close", "Close")
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // Theme list
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(themeListLayout.implicitHeight + (Style.marginM * 2), maxListHeight)

      NScrollView {
        id: themeScrollView
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
            model: pluginMain?.availableThemes || []

            delegate: Rectangle {
              id: entry
              required property var modelData
              required property int index

              readonly property var theme: modelData
              readonly property string themeName: typeof theme === 'string' ? theme : theme.name
              readonly property var themeColors: typeof theme === 'object' ? theme.colors : []
              readonly property bool isCurrentTheme: themeName === pluginMain?.themeName
              readonly property bool hovered: hoverArea.containsMouse

              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + (Style.marginS * 2)
              radius: Style.radiusM
              color: isCurrentTheme ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : (hovered ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.05) : Color.mSurface)
              border.width: Style.borderS
              border.color: isCurrentTheme ? Color.mPrimary : (hovered ? Color.mPrimary : Color.mOutline)

              RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: Style.marginS
                spacing: Style.marginM

                NText {
                  Layout.fillWidth: true
                  color: Color.mOnSurface
                  text: entry.themeName
                  pointSize: Style.fontSizeM
                  font.weight: isCurrentTheme ? Style.fontWeightBold : Style.fontWeightMedium
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                }

                Row {
                  spacing: Style.marginXS / 2
                  visible: entry.themeColors.length > 0

                  Repeater {
                    model: entry.themeColors

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
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  pluginMain?.setTheme(entry.themeName);
                  if (pluginApi) {
                    pluginApi.closePanel(root.screen);
                  }
                }
              }
            }
          }

          NText {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.baseWidgetSize * 2
            visible: !pluginMain?.availableThemes || pluginMain.availableThemes.length === 0
            text: noThemesText
            pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }

  }
}
