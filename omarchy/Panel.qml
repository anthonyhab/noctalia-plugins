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
  readonly property int contentPreferredHeight: Math.round(500 * Style.uiScaleRatio)
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
  readonly property string availableThemesLabel: trOrDefault("fields.theme.available", trOrDefault("fields.theme.label", "Available themes"))
  readonly property string noThemesText: trOrDefault("errors.no-themes", "No themes found")

  readonly property bool isActive: pluginApi?.pluginSettings?.active || false

  readonly property color secondaryColor: Color.mSecondary !== undefined ? Color.mSecondary : Color.mPrimary

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    // Header card similar to legacy Omarchy panel
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + Style.marginS * 2

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: 0
        anchors.topMargin: Style.marginS
        anchors.bottomMargin: Style.marginS
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
          Layout.rightMargin: Style.marginM
          width: Style.fontSizeL
          height: Style.fontSizeL
          radius: width / 2
          color: isActive ? "#4ade80" : "#f87171"
          border.width: Style.borderS
          border.color: isActive ? "#22c55e" : "#ef4444"

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
      }
    }

    // Theme list block with compact margins
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true

      NScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginS
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        clip: true

        ColumnLayout {
          id: themeListLayout
          width: parent.width
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            text: availableThemesLabel
            font.pointSize: Style.fontSizeS
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }

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
              Layout.preferredHeight: Style.baseWidgetSize * 0.85
              radius: Style.radiusS
              color: isCurrentTheme ? Qt.alpha(secondaryColor, 0.4) : (hovered ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurface)
              border.width: Style.borderS
              border.color: isCurrentTheme ? secondaryColor : (hovered ? Color.mPrimary : Color.mOutline)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginM
                spacing: Style.marginM

                NText {
                  Layout.fillWidth: true
                  color: isCurrentTheme ? Color.mOnSurface : (hovered ? Color.mPrimary : Color.mOnSurface)
                  text: entry.themeName
                  pointSize: Style.fontSizeM
                  font.weight: isCurrentTheme ? Style.fontWeightBold : Font.Normal
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
