import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var screen: pluginApi?.panelOpenScreen || null

  readonly property int activeGridColumns: pluginMain?.gridColumns || 2
  readonly property int contentPreferredWidth: Math.round((activeGridColumns === 1 ? 280 : (activeGridColumns === 2 ? 400 : 540)) * Style.uiScaleRatio)

  readonly property int contentPreferredHeight: Math.min(
    mainColumn.implicitHeight + (Style.marginL * 2),
    600 * Style.uiScaleRatio
  )

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool autoCycleEnabled: pluginMain?.autoCycleEnabled || false
  readonly property bool shuffleMode: pluginMain?.shuffleMode || false
  readonly property var wallpapers: pluginMain?.wallpaperList || []
  readonly property string currentWallpaper: pluginMain?.currentWallpaper || ""

  readonly property bool hasWallpapers: wallpapers.length > 0
  readonly property string currentWallpaperName: {
    if (!currentWallpaper)
      return "";
    const parts = currentWallpaper.split("/");
    return parts[parts.length - 1] || "";
  }

  readonly property color secondaryContainerColor: Color.mSecondaryContainer !== undefined
    ? Color.mSecondaryContainer
    : Color.mSurfaceVariant
  readonly property color onSecondaryContainerColor: Color.mOnSecondaryContainer !== undefined
    ? Color.mOnSecondaryContainer
    : Color.mOnSurfaceVariant
  readonly property color primaryAccentColor: Color.mPrimary !== undefined
    ? Color.mPrimary
    : secondaryContainerColor
  readonly property color onPrimaryAccentColor: Color.mOnPrimary !== undefined
    ? Color.mOnPrimary
    : Color.mOnSurface

  readonly property real thumbAspect: 0.6
  readonly property int gridColumns: activeGridColumns
  readonly property int thumbWidth: {
    const available = contentPreferredWidth - (Style.marginL * 2) - (Style.marginM * 2);
    return Math.floor((available - (gridColumns - 1) * Style.marginS) / gridColumns);
  }
  readonly property int thumbHeight: Math.round(thumbWidth * thumbAspect)
  property int thumbReloadToken: 0

  onWallpapersChanged: {
    thumbReloadToken += 1;
  }

  Connections {
    target: Settings.data.colorSchemes
    function onPredefinedSchemeChanged() {
      thumbReloadToken += 1;
      pluginMain?.refresh();
    }
    function onDarkModeChanged() {
      thumbReloadToken += 1;
    }
    function onUseWallpaperColorsChanged() {
      thumbReloadToken += 1;
      pluginMain?.refresh();
    }
  }

  function trOrDefault(key, fallback) {
    if (pluginApi && pluginApi.tr) {
      const value = pluginApi.tr(key);
      if (value && !value.startsWith("##") && !value.startsWith("!!"))
        return value;
    }
    return fallback;
  }

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    onVisibleChanged: {
      if (visible) {
        pluginMain?.refresh();
        pluginMain?.checkResolvedWallpapersDir();
      }
    }

    // Header
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + (Style.marginM * 2)

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "photo"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            text: trOrDefault("title", "Swww Picker")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
            elide: Text.ElideRight
          }

          NText {
            visible: !isAvailable
            Layout.fillWidth: true
            text: trOrDefault("errors.daemon-not-running", "swww daemon not running")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            elide: Text.ElideRight
          }
        }

        NIconButton {
          icon: "layout-grid"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: trOrDefault("actions.toggle-layout", "Toggle Layout")
          onClicked: pluginMain?.toggleGridColumns()
        }

        NIconButton {
          icon: "x"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: trOrDefault("actions.close", "Close")
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // Wallpaper grid
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(
        wallpaperFlow.implicitHeight + (Style.marginM * 2),
        480 * Style.uiScaleRatio
      )
      Layout.minimumHeight: thumbHeight + Style.marginM * 2

      Flickable {
        id: wallpaperFlickable
        anchors.fill: parent
        anchors.margins: Style.marginM
        clip: true
        contentWidth: wallpaperFlow.width
        contentHeight: wallpaperFlow.height
        boundsBehavior: Flickable.StopAtBounds

        Flow {
          id: wallpaperFlow
          width: contentPreferredWidth - (Style.marginL * 2) - (Style.marginM * 2)
          spacing: Style.marginS

          Repeater {
            model: wallpapers

            delegate: Rectangle {
              id: thumbDelegate
              required property string modelData
              required property int index

              readonly property bool isCurrent: modelData === currentWallpaper
              readonly property bool hovered: thumbMouse.containsMouse
              readonly property string fileName: {
                const parts = modelData.split("/");
                return parts[parts.length - 1] || "";
              }
              function reloadThumbnail() {
                thumbImage.source = "file://" + modelData;
              }

              width: thumbWidth
              height: thumbHeight

              radius: Style.radiusM

              color: isCurrent
                ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.15)
                : (hovered ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : Color.mSurface)
              border.width: isCurrent ? 2 : Style.borderS
              border.color: isCurrent ? Color.mPrimary : (hovered ? Color.mPrimary : Color.mOutline)

              Behavior on color {
                ColorAnimation { duration: 140 }
              }

              Rectangle {
                anchors.fill: parent
                anchors.margins: Style.borderS
                radius: Style.radiusM - Style.borderS
                color: Color.mSurfaceVariant
                clip: true

                Image {
                  id: thumbImage
                  anchors.fill: parent
                  source: "file://" + modelData
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize.width: 400 * Style.uiScaleRatio
                  sourceSize.height: 240 * Style.uiScaleRatio
                  visible: status === Image.Ready
                }

                Rectangle {
                  anchors.fill: parent
                  color: Color.mSurfaceVariant
                  visible: thumbImage.status !== Image.Ready
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: Math.round(24 * Style.uiScaleRatio)
                  color: Qt.rgba(0, 0, 0, hovered ? 0.55 : 0)
                  visible: hovered
                  radius: Style.radiusM
                  clip: true

                  NText {
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    text: fileName
                    pointSize: Style.fontSizeS
                    color: Qt.rgba(1, 1, 1, 0.92)
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                id: thumbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  pluginMain?.setWallpaper(modelData);
                }
              }

              // Current indicator
              Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                width: 14
                height: 14
                radius: 7
                color: Color.mPrimary
                visible: isCurrent

                NIcon {
                  anchors.centerIn: parent
                  icon: "check"
                  pointSize: 8
                  color: Color.mOnPrimary
                }
              }

              Connections {
                target: root
                function onThumbReloadTokenChanged() {
                  reloadThumbnail();
                }
              }
            }
          }
        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }
      }

      // Empty state
      NText {
        anchors.centerIn: parent
        visible: !isAvailable || !hasWallpapers
        text: !isAvailable
          ? trOrDefault("errors.daemon-not-running", "swww daemon not running\nRun: swww-daemon")
          : trOrDefault("status.no-wallpapers", "No wallpapers found\nCheck your wallpapers directory in settings")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
    }
  }

  Component.onCompleted: {
    pluginMain?.refresh();
  }
}
