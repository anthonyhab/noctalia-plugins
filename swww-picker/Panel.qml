import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var screen: null

  readonly property bool allowAttach: true
  readonly property int contentPreferredWidth: Math.round(480 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: Math.min(
    mainColumn.implicitHeight + (Style.marginL * 2),
    560 * Style.uiScaleRatio
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

  readonly property int thumbSize: Math.round(120 * Style.uiScaleRatio)
  readonly property int gridColumns: Math.max(1, Math.floor((contentPreferredWidth - Style.marginL * 2 - Style.marginM * 2) / (thumbSize + Style.marginS)))
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
      if (value && !value.startsWith("##"))
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
            text: trOrDefault("title", "Wallpaper Picker")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: isAvailable
              ? (wallpapers.length + " " + trOrDefault("status.wallpapers", "wallpapers"))
              : trOrDefault("errors.daemon-not-running", "swww daemon not running")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            elide: Text.ElideRight
          }
        }

        Rectangle {
          id: headerStatusPill
          radius: height / 2
          color: autoCycleEnabled ? primaryAccentColor : Color.mSurfaceVariant
          border.width: Style.borderS
          border.color: autoCycleEnabled ? primaryAccentColor : Color.mOutline
          visible: isAvailable
          implicitHeight: Math.round(28 * Style.uiScaleRatio)
          implicitWidth: headerStatusRow.implicitWidth + (Style.marginM * 2)

          RowLayout {
            id: headerStatusRow
            anchors.centerIn: parent
            spacing: Style.marginS

            NIcon {
              icon: autoCycleEnabled ? "player-play" : "player-pause"
              pointSize: Style.fontSizeM
              color: autoCycleEnabled ? onPrimaryAccentColor : Color.mOnSurfaceVariant
            }

            NText {
              text: autoCycleEnabled
                ? trOrDefault("status.auto-cycle-on", "Auto-cycle on")
                : trOrDefault("status.auto-cycle-off", "Auto-cycle off")
              pointSize: Style.fontSizeS
              color: autoCycleEnabled ? onPrimaryAccentColor : Color.mOnSurfaceVariant
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pluginMain?.toggleAutoCycle()
          }
        }

        NIconButton {
          icon: "x"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: trOrDefault("actions.close", "Close")
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // Control buttons
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: controlsFlow.implicitHeight + (Style.marginM * 2)

      Flow {
        id: controlsFlow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NButton {
          text: trOrDefault("actions.random", "Random")
          enabled: isAvailable && hasWallpapers
          implicitHeight: Math.round(32 * Style.uiScaleRatio)
          onClicked: pluginMain?.random()
        }

        Rectangle {
          id: shuffleChip
          radius: height / 2
          color: shuffleMode ? secondaryContainerColor : Color.mSurfaceVariant
          border.width: Style.borderS
          border.color: shuffleMode ? secondaryContainerColor : Color.mOutline
          implicitHeight: Math.round(32 * Style.uiScaleRatio)
          implicitWidth: shuffleRow.implicitWidth + (Style.marginM * 2)
          opacity: isAvailable ? 1 : 0.5

          RowLayout {
            id: shuffleRow
            anchors.centerIn: parent
            spacing: Style.marginS

            NIcon {
              icon: "arrows-shuffle"
              pointSize: Style.fontSizeM
              color: shuffleMode ? onSecondaryContainerColor : Color.mOnSurfaceVariant
            }

            NText {
              text: trOrDefault("actions.shuffle", "Shuffle")
              pointSize: Style.fontSizeS
              color: shuffleMode ? onSecondaryContainerColor : Color.mOnSurfaceVariant
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: isAvailable
            onClicked: pluginMain?.toggleShuffleMode()
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        text: trOrDefault("sections.gallery", "Gallery")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      Item { Layout.fillWidth: true }

      NText {
        text: wallpapers.length + " " + trOrDefault("status.wallpapers", "wallpapers")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }
    }

    // Wallpaper grid
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(
        wallpaperFlow.implicitHeight + (Style.marginM * 2),
        320 * Style.uiScaleRatio
      )
      Layout.minimumHeight: thumbSize + Style.marginM * 2

      Flickable {
        id: wallpaperFlickable
        anchors.fill: parent
        anchors.margins: Style.marginM
        clip: true
        contentWidth: width
        contentHeight: wallpaperFlow.height
        boundsBehavior: Flickable.StopAtBounds

        Flow {
          id: wallpaperFlow
          width: parent.width
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
                thumbImage.source = "";
                Qt.callLater(() => {
                  thumbImage.source = "file://" + modelData;
                });
              }

              width: thumbSize
              height: thumbSize
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

                Image {
                  id: thumbImage
                  anchors.fill: parent
                  source: ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize.width: thumbSize * 2
                  sourceSize.height: thumbSize * 2
                  cache: false
                  visible: false
                }

                Rectangle {
                  id: thumbMask
                  anchors.fill: parent
                  radius: Style.radiusM
                  visible: false
                }

                OpacityMask {
                  anchors.fill: parent
                  source: thumbImage
                  maskSource: thumbMask
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
                    color: Color.mOnPrimary !== undefined ? Color.mOnPrimary : Qt.rgba(1, 1, 1, 0.92)
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

              Component.onCompleted: reloadThumbnail()

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

    // Status bar
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: statusRow.implicitHeight + (Style.marginS * 2)
      visible: isAvailable && hasWallpapers

      RowLayout {
        id: statusRow
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        NText {
          Layout.fillWidth: true
          text: trOrDefault("status.selected", "Selected") + ": " +
            (currentWallpaperName !== "" ? currentWallpaperName : trOrDefault("status.none", "None"))
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          elide: Text.ElideRight
        }

        NText {
          visible: shuffleMode
          text: trOrDefault("status.shuffle-on", "Shuffle on")
          color: Color.mSecondary
          pointSize: Style.fontSizeS
        }
      }
    }
  }

  Component.onCompleted: {
    pluginMain?.refresh();
  }
}
