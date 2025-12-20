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
  }

  // Calculate current position based on last update time
  property real calculatedPosition: mediaPosition
  Timer {
    id: positionTimer
    interval: 1000
    repeat: true
    running: isPlaying && mediaDuration > 0
    onTriggered: {
      if (mediaPositionUpdatedAt) {
        const updatedAt = new Date(mediaPositionUpdatedAt);
        const now = new Date();
        const elapsed = (now - updatedAt) / 1000;
        calculatedPosition = Math.min(mediaPosition + elapsed, mediaDuration);
      }
    }
  }

  // Reset calculated position when media position changes
  onMediaPositionChanged: calculatedPosition = mediaPosition

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    // Header
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
          Layout.rightMargin: Style.marginM
          width: Style.fontSizeL
          height: Style.fontSizeL
          radius: width / 2
          color: isConnected ? "#4ade80" : (isConnecting ? "#fbbf24" : "#f87171")
          border.width: Style.borderS
          border.color: isConnected ? "#22c55e" : (isConnecting ? "#f59e0b" : "#ef4444")
        }
      }
    }

    // Media player controls
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // Album art
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: width
          Layout.maximumHeight: 180 * Style.uiScaleRatio
          color: Color.mSurface
          radius: Style.radiusS
          border.width: Style.borderS
          border.color: Color.mOutline

          Image {
            id: albumArt
            anchors.fill: parent
            anchors.margins: Style.marginXS
            source: entityPicture
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready

            layer.enabled: true
            layer.effect: ShaderEffect {
              property real radius: Style.radiusM - Style.marginXS
            }
          }

          NIcon {
            anchors.centerIn: parent
            visible: !albumArt.visible
            icon: isPlaying ? "music" : "music-off"
            pointSize: 48
            color: Color.mOnSurfaceVariant
          }
        }

        // Track info
        ColumnLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.marginS
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
          Layout.topMargin: Style.marginS
          spacing: Style.marginXS
          visible: mediaDuration > 0

          Slider {
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
            }

            Item {
              Layout.fillWidth: true
            }

            NText {
              text: formatTime(mediaDuration)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }
        }

        // Transport controls
        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: Style.marginS
          spacing: Style.marginS

          NIconButton {
            icon: "arrows-shuffle"
            baseSize: 20
            enabled: isConnected
            colorFg: shuffleEnabled ? Color.mSecondary : Color.mPrimary
            colorBg: shuffleEnabled ? Color.mSecondaryContainer : Color.mSurfaceVariant
            tooltipText: pluginApi?.tr("actions.shuffle") || "Shuffle"
            onClicked: pluginMain?.toggleShuffle()
          }

          NIconButton {
            icon: "player-track-prev"
            baseSize: 28
            enabled: isConnected
            tooltipText: pluginApi?.tr("actions.previous") || "Previous"
            onClicked: pluginMain?.mediaPrevious()
          }

          NIconButton {
            icon: isPlaying ? "player-pause" : "player-play"
            baseSize: 48
            enabled: isConnected
            tooltipText: isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play")
            onClicked: pluginMain?.mediaPlayPause()
          }

          NIconButton {
            icon: "player-track-next"
            baseSize: 28
            enabled: isConnected
            tooltipText: pluginApi?.tr("actions.next") || "Next"
            onClicked: pluginMain?.mediaNext()
          }

          NIconButton {
            icon: repeatMode === "one" ? "repeat-1" : "repeat"
            baseSize: 20
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

        // Spacer to push volume and device selector to bottom
        Item {
          Layout.fillHeight: true
          Layout.fillWidth: true
        }

        // Volume control
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NIconButton {
            icon: isVolumeMuted ? "volume-off" : (volumeLevel > 0.5 ? "volume" : "volume-2")
            baseSize: 20
            enabled: isConnected
            tooltipText: isVolumeMuted ? (pluginApi?.tr("actions.unmute") || "Unmute") : (pluginApi?.tr("actions.mute") || "Mute")
            onClicked: pluginMain?.toggleMute()
          }

          Slider {
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
            Layout.preferredWidth: 35
          }
        }

        // Device selector
        NComboBox {
          Layout.fillWidth: true
          visible: (pluginMain?.mediaPlayers?.length || 0) > 1

          model: pluginMain?.mediaPlayers?.map(p => ({
                                                       "key": p.entity_id,
                                                       "name": p.friendly_name || p.entity_id
                                                     })) || []

          currentKey: pluginMain?.selectedMediaPlayer || ""

          onSelected: key => {
                        if (key) {
                          pluginMain?.selectMediaPlayer(key);
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
