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

  readonly property var pluginMain: pluginApi?.mainInstance

  readonly property bool isConnected: pluginMain?.connected || false
  readonly property bool isConnecting: pluginMain?.connecting || false
  readonly property string connectionError: pluginMain?.connectionError || ""

  readonly property bool isPlaying: pluginMain?.isPlaying || false
  readonly property bool isPaused: pluginMain?.isPaused || false
  readonly property bool isIdle: pluginMain?.isIdle || false

  readonly property string mediaTitle: pluginMain?.mediaTitle || ""
  readonly property string mediaArtist: pluginMain?.mediaArtist || ""
  readonly property string mediaAlbum: pluginMain?.mediaAlbum || ""
  readonly property string friendlyName: pluginMain?.friendlyName || ""
  readonly property string entityPicture: pluginMain?.entityPicture || ""

  readonly property real mediaDuration: pluginMain?.mediaDuration || 0
  readonly property real mediaPosition: pluginMain?.mediaPosition || 0
  readonly property string mediaPositionUpdatedAt: pluginMain?.mediaPositionUpdatedAt || ""

  readonly property real volumeLevel: pluginMain?.volumeLevel || 0
  readonly property bool isVolumeMuted: pluginMain?.isVolumeMuted || false
  readonly property bool shuffleEnabled: pluginMain?.shuffleEnabled || false
  readonly property string repeatMode: pluginMain?.repeatMode || "off"
  // Local volume state keeps the slider responsive while waiting for HA updates
  property real localVolumeLevel: volumeLevel

  onVolumeLevelChanged: {
    if (!volumeSlider.pressed) {
      localVolumeLevel = volumeLevel;
    }
  }

  Component.onCompleted: {
    // Refresh state when panel opens to ensure current values
    pluginMain?.refresh();
    // Calculate position immediately after refresh
    Qt.callLater(updateCalculatedPosition);
  }

  // Calculate current position based on last update time
  property real calculatedPosition: mediaPosition

  function updateCalculatedPosition() {
    if (mediaPositionUpdatedAt && mediaDuration > 0) {
      const updatedAt = new Date(mediaPositionUpdatedAt);
      const now = new Date();
      const elapsed = (now - updatedAt) / 1000;
      calculatedPosition = Math.min(mediaPosition + elapsed, mediaDuration);
    } else {
      calculatedPosition = mediaPosition;
    }
  }

  Timer {
    id: positionTimer
    interval: 1000
    repeat: true
    running: isPlaying && mediaDuration > 0
    onTriggered: updateCalculatedPosition()
  }

  // Recalculate when position data updates from Home Assistant
  onMediaPositionChanged: updateCalculatedPosition()
  onMediaPositionUpdatedAtChanged: updateCalculatedPosition()

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

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
          icon: "home"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("title") || "Home Assistant"
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeL
          color: Color.mOnSurface
        }

        Rectangle {
          width: Style.fontSizeM
          height: Style.fontSizeM
          radius: width / 2
          color: isConnected ? Color.mPrimary : (isConnecting ? Color.mSecondary : Color.mError)
          border.width: Style.borderS
          border.color: Color.mOutline
        }

        NIconButton {
          icon: "close"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: pluginApi?.tr("tooltips.close") || "Close"
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // Media player controls
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: mediaControlsColumn.implicitHeight + (Style.marginM * 2)

      ColumnLayout {
        id: mediaControlsColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // Album art
        NBox {
          id: albumArtContainer
          Layout.fillWidth: true
          Layout.preferredHeight: width
          Layout.maximumHeight: 180 * Style.uiScaleRatio
          color: Color.mSurface
          layer.enabled: true
          clip: true

          Image {
            id: albumArt
            anchors.fill: parent
            source: entityPicture
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
          }

          NIcon {
            anchors.centerIn: parent
            visible: !albumArt.visible
            icon: isPlaying ? "music" : "music-off"
            pointSize: Style.fontSizeXXXL
            color: Color.mOnSurfaceVariant
          }
        }

        // Track info
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            Layout.fillWidth: true
            text: mediaTitle || (pluginApi?.tr("media.no-media") || "Nothing playing")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM
            color: Color.mOnSurface
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }

          NText {
            Layout.fillWidth: true
            visible: mediaArtist !== ""
            text: mediaArtist
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }

          NText {
            Layout.fillWidth: true
            visible: mediaAlbum !== ""
            text: mediaAlbum
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
          }
        }

        // Progress bar
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS
          visible: mediaDuration > 0

          NSlider {
            id: progressSlider
            Layout.fillWidth: true
            from: 0
            to: mediaDuration
            value: calculatedPosition
            enabled: isConnected && mediaDuration > 0

            onPressedChanged: {
              if (!pressed && value !== calculatedPosition) {
                pluginMain?.seek(value);
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true

            NText {
              text: formatTime(calculatedPosition)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              family: Settings.data.ui.fontFixed
              Layout.preferredWidth: Math.round(50 * Style.uiScaleRatio)
            }

            Item {
              Layout.fillWidth: true
            }

            NText {
              text: formatTime(mediaDuration)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              family: Settings.data.ui.fontFixed
              Layout.preferredWidth: Math.round(50 * Style.uiScaleRatio)
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        // Transport controls
        RowLayout {
          Layout.fillWidth: true

          Item {
            Layout.fillWidth: true
          }

          RowLayout {
            spacing: Style.marginS

            NIconButton {
              icon: "arrows-shuffle"
              baseSize: Style.baseWidgetSize * 0.6
              enabled: isConnected
              colorFg: shuffleEnabled ? Color.mSecondary : Color.mPrimary
              colorBg: shuffleEnabled ? Color.mSecondaryContainer : Color.mSurfaceVariant
              tooltipText: pluginApi?.tr("actions.shuffle") || "Shuffle"
              onClicked: pluginMain?.toggleShuffle()
            }

            NIconButton {
              icon: "player-track-prev"
              baseSize: Style.baseWidgetSize * 0.85
              enabled: isConnected
              tooltipText: pluginApi?.tr("actions.previous") || "Previous"
              onClicked: pluginMain?.mediaPrevious()
            }

            NIconButton {
              icon: isPlaying ? "player-pause" : "player-play"
              baseSize: Style.baseWidgetSize * 1.45
              enabled: isConnected
              tooltipText: isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play")
              onClicked: pluginMain?.mediaPlayPause()
            }

            NIconButton {
              icon: "player-track-next"
              baseSize: Style.baseWidgetSize * 0.85
              enabled: isConnected
              tooltipText: pluginApi?.tr("actions.next") || "Next"
              onClicked: pluginMain?.mediaNext()
            }

            NIconButton {
              icon: repeatMode === "one" ? "repeat-1" : "repeat"
              baseSize: Style.baseWidgetSize * 0.6
              enabled: isConnected
              colorFg: repeatMode !== "off" ? Color.mSecondary : Color.mPrimary
              colorBg: repeatMode !== "off" ? Color.mSecondaryContainer : Color.mSurfaceVariant
              tooltipText: {
                switch (repeatMode) {
                case "off":
                  return pluginApi?.tr("actions.repeat-off") || "Repeat: Off";
                case "all":
                  return pluginApi?.tr("actions.repeat-all") || "Repeat: All";
                case "one":
                  return pluginApi?.tr("actions.repeat-one") || "Repeat: One";
                default:
                  return "Repeat";
                }
              }
              onClicked: pluginMain?.cycleRepeat()
            }
          }

          Item {
            Layout.fillWidth: true
          }
        }

        // Volume control
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NIconButton {
            icon: isVolumeMuted ? "volume-off" : (volumeLevel > 0.5 ? "volume" : "volume-2")
            baseSize: Style.baseWidgetSize * 0.6
            enabled: isConnected
            tooltipText: isVolumeMuted ? (pluginApi?.tr("actions.unmute") || "Unmute") : (pluginApi?.tr("actions.mute") || "Mute")
            onClicked: pluginMain?.toggleMute()
          }

          NSlider {
            id: volumeSlider
            Layout.fillWidth: true
            from: 0
            to: 1
            value: localVolumeLevel
            enabled: isConnected && !isVolumeMuted

            onMoved: localVolumeLevel = value

            onPressedChanged: {
              if (!pressed) {
                pluginMain?.setVolume(localVolumeLevel);
              }
            }
          }

          NText {
            text: Math.round(localVolumeLevel * 100) + "%"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            family: Settings.data.ui.fontFixed
            Layout.preferredWidth: Math.round(45 * Style.uiScaleRatio)
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
          }
        }

        // Device selector
        ComboBox {
          id: deviceSelector
          Layout.fillWidth: true
          visible: (pluginMain?.mediaPlayers?.length || 0) > 1

          readonly property var playerModel: pluginMain?.mediaPlayers?.map(p => ({
                                                                                  "key": p.entity_id,
                                                                                  "name": p.friendly_name || p.entity_id
                                                                                })) || []

          model: playerModel
          currentIndex: {
            if (!playerModel || playerModel.length === 0)
              return -1;
            const selected = pluginMain?.selectedMediaPlayer || "";
            for (var i = 0; i < playerModel.length; i++) {
              if (playerModel[i].key === selected)
                return i;
            }
            return 0;
          }

          onActivated: {
            var item = playerModel[currentIndex];
            if (item && item.key) {
              pluginMain?.selectMediaPlayer(item.key);
            }
          }

          background: Rectangle {
            implicitWidth: Style.baseWidgetSize * 3.75
            implicitHeight: Style.baseWidgetSize * 1.1 * Style.uiScaleRatio
            color: Color.mSurface
            border.color: deviceSelector.activeFocus ? Color.mSecondary : Color.mOutline
            border.width: Style.borderS
            radius: Style.radiusM

            Behavior on border.color {
              ColorAnimation {
                duration: Style.animationFast
              }
            }
          }

          contentItem: NText {
            leftPadding: Style.marginL
            rightPadding: deviceSelector.indicator.width + Style.marginL
            pointSize: Style.fontSizeM
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: deviceSelector.currentIndex >= 0 ? Color.mOnSurface : Color.mOnSurfaceVariant
            text: {
              if (deviceSelector.currentIndex >= 0 && deviceSelector.currentIndex < deviceSelector.playerModel.length) {
                return deviceSelector.playerModel[deviceSelector.currentIndex].name;
              }
              return pluginApi?.tr("settings.default-player") || "Default Media Player";
            }
          }

          indicator: NIcon {
            x: deviceSelector.width - width - Style.marginM
            y: deviceSelector.topPadding + (deviceSelector.availableHeight - height) / 2
            icon: "caret-down"
            pointSize: Style.fontSizeL
          }

          popup: Popup {
            y: deviceSelector.height
            implicitWidth: deviceSelector.width - Style.marginM
            implicitHeight: Math.min(180 * Style.uiScaleRatio, listView.contentHeight + Style.marginM * 2)
            padding: Style.marginM

            contentItem: ListView {
              id: listView
              clip: true
              model: deviceSelector.popup.visible ? deviceSelector.playerModel : null
              boundsBehavior: Flickable.StopAtBounds
              highlightMoveDuration: 0

              ScrollBar.vertical: ScrollBar {
                policy: listView.contentHeight > listView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                contentItem: Rectangle {
                  implicitWidth: 6
                  implicitHeight: 100
                  radius: Style.iRadiusM
                  color: parent.pressed ? Qt.alpha(Color.mHover, 0.9) : parent.hovered ? Qt.alpha(Color.mHover, 0.9) : Qt.alpha(Color.mHover, 0.8)
                  opacity: parent.active ? 1.0 : 0.0

                  Behavior on opacity {
                    NumberAnimation {
                      duration: Style.animationFast
                    }
                  }

                  Behavior on color {
                    ColorAnimation {
                      duration: Style.animationFast
                    }
                  }
                }

                background: Rectangle {
                  implicitWidth: 6
                  implicitHeight: 100
                  color: Color.transparent
                  opacity: parent.active ? 0.3 : 0.0
                  radius: Style.iRadiusM / 2

                  Behavior on opacity {
                    NumberAnimation {
                      duration: Style.animationFast
                    }
                  }
                }
              }

              delegate: Rectangle {
                required property int index
                required property var modelData
                width: listView.width
                height: delegateText.implicitHeight + Style.marginS * 2
                radius: Style.radiusS
                color: listView.currentIndex === index ? Color.mHover : Color.transparent

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }

                NText {
                  id: delegateText
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.marginM
                  anchors.rightMargin: Style.marginM
                  pointSize: Style.fontSizeM
                  color: listView.currentIndex === index ? Color.mOnHover : Color.mOnSurface
                  elide: Text.ElideRight
                  text: modelData.name

                  Behavior on color {
                    ColorAnimation {
                      duration: Style.animationFast
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onContainsMouseChanged: {
                    if (containsMouse)
                      listView.currentIndex = index;
                  }
                  onClicked: {
                    if (modelData && modelData.key) {
                      pluginMain?.selectMediaPlayer(modelData.key);
                      deviceSelector.popup.close();
                    }
                  }
                }
              }
            }

            background: Rectangle {
              color: Color.mSurfaceVariant
              border.color: Color.mOutline
              border.width: Style.borderS
              radius: Style.radiusM
            }
          }
        }

        // Footer hint
        NText {
          Layout.fillWidth: true
          visible: !isConnected
          text: pluginApi?.tr("panel.settings-hint") || "Configure connection in Settings > Plugins > Home Assistant"
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          pointSize: Style.fontSizeS
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  function formatTime(seconds) {
    if (!seconds || seconds < 0)
      return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return mins + ":" + (secs < 10 ? "0" : "") + secs;
  }
}
