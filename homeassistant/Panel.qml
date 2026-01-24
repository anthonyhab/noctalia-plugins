import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var screen: pluginApi?.panelOpenScreen || null

  readonly property bool allowAttach: Settings.data.ui.panelsAttachedToBar
  readonly property int contentPreferredWidth: Math.round(360 * Style.uiScaleRatio)
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

  // Capability booleans
  readonly property bool canPause: pluginMain?.canPause || false
  readonly property bool canSeek: pluginMain?.canSeek || false
  readonly property bool canVolumeSet: pluginMain?.canVolumeSet || false
  readonly property bool canVolumeMute: pluginMain?.canVolumeMute || false
  readonly property bool canPrevious: pluginMain?.canPrevious || false
  readonly property bool canNext: pluginMain?.canNext || false
  readonly property bool canShuffle: pluginMain?.canShuffle || false
  readonly property bool canRepeat: pluginMain?.canRepeat || false

  readonly property bool shuffleEnabled: pluginMain?.shuffleEnabled || false
  readonly property string repeatMode: pluginMain?.repeatMode || "off"

  // Local volume state
  property real localVolumeLevel: volumeLevel
  onVolumeLevelChanged: {
    if (!volumeSlider.pressed) localVolumeLevel = volumeLevel;
  }

  Component.onCompleted: {
    pluginMain?.refresh();
    Qt.callLater(updateCalculatedPosition);
  }

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
    interval: 1000
    repeat: true
    running: isPlaying && mediaDuration > 0
    onTriggered: updateCalculatedPosition()
  }

  onMediaPositionChanged: updateCalculatedPosition()
  onMediaPositionUpdatedAtChanged: updateCalculatedPosition()

  property bool albumArtFailed: false
  onEntityPictureChanged: albumArtFailed = false
  onMediaTitleChanged: albumArtFailed = false

  ColumnLayout {
    id: mainColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // --- Header ---
    NBox {
      Layout.fillWidth: true
      implicitHeight: headerRow.implicitHeight + (Style.marginM * 2)

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
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // --- Media Content Block ---
    NBox {
      Layout.fillWidth: true
      implicitHeight: metadataColumn.implicitHeight + (Style.marginM * 2)
      visible: isConnected && (mediaTitle !== "" || entityPicture !== "")

      ColumnLayout {
        id: metadataColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

	        // Album Art
	        NBox {
	          id: albumArtBox
	          Layout.fillWidth: true
	          Layout.preferredHeight: width * 0.56 // 16:9 like
	          Layout.maximumHeight: 200 * Style.uiScaleRatio
	          visible: entityPicture !== "" && !albumArtFailed
	          color: Color.mSurface
	          radius: Style.radiusM

	          // Rounded clip for the album art (avoids rectangular `clip: true` edges).
	          Item {
	            anchors.fill: parent
	            layer.enabled: true
	            layer.smooth: true
	            layer.effect: MultiEffect {
	              maskEnabled: true
	              maskThresholdMin: 0.95
	              maskSpreadAtMin: 0.15
	              maskSource: ShaderEffectSource {
	                sourceItem: Rectangle {
	                  width: albumArtBox.width
	                  height: albumArtBox.height
	                  radius: albumArtBox.radius
	                  color: "white"
	                }
	              }
	            }

	            Image {
	              anchors.fill: parent
	              source: entityPicture
	              fillMode: Image.PreserveAspectCrop
	              asynchronous: true
	              smooth: true
	              visible: status === Image.Ready
	              onStatusChanged: if (status === Image.Error) albumArtFailed = true
	            }
	          }
	        }

        // Metadata
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS
          NText {
            Layout.fillWidth: true
            text: mediaTitle || (pluginApi?.tr("media.no-media") || "Nothing playing")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }
          NText {
            Layout.fillWidth: true
            visible: mediaArtist !== ""
            text: mediaArtist
            font.weight: Style.fontWeightMedium
            pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }

    // --- Playback Controls (Progress + Transport) ---
    NBox {
      Layout.fillWidth: true
      implicitHeight: playbackColumn.implicitHeight + (Style.marginM * 2)
      visible: isConnected

      ColumnLayout {
        id: playbackColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // Progress
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS
          visible: canSeek && mediaDuration > 0
          
          NSlider {
            Layout.fillWidth: true
            from: 0
            to: mediaDuration
            value: calculatedPosition
            enabled: isConnected && canSeek
            heightRatio: 0.4 // Smaller knob
            cutoutColor: Color.mSurfaceVariant
            onPressedChanged: if (!pressed && Math.abs(value - calculatedPosition) > 1) pluginMain?.seek(value);
          }
          RowLayout {
            Layout.fillWidth: true
            NText {
              text: formatTime(calculatedPosition)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              family: Settings.data.ui.fontFixed
              Layout.preferredWidth: Math.round(Style.marginL * 3)
              horizontalAlignment: Text.AlignLeft
            }
            Item { Layout.fillWidth: true }
            NText {
              text: formatTime(mediaDuration)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
              family: Settings.data.ui.fontFixed
              Layout.preferredWidth: Math.round(Style.marginL * 3)
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        // Transport
        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.marginM

          readonly property real btnSize: Style.baseWidgetSize * 1.0

          NIconButton {
            visible: canShuffle
            icon: "arrows-shuffle"
            baseSize: parent.btnSize
            colorFg: shuffleEnabled ? Color.mSecondary : Qt.alpha(Color.mOnSurfaceVariant, 0.6)
            colorBg: "transparent"
            colorBgHover: Color.mHover
            onClicked: pluginMain?.toggleShuffle()
          }
          NIconButton {
            visible: canPrevious
            icon: "player-track-prev"
            baseSize: parent.btnSize
            colorFg: Color.mOnSurface
            colorBg: "transparent"
            colorBgHover: Color.mHover
            onClicked: pluginMain?.mediaPrevious()
          }
          NIconButton {
            icon: isPlaying ? "player-pause" : "player-play"
            baseSize: parent.btnSize * 1.2
            colorBg: Color.mPrimary
            colorFg: Color.mOnPrimary
            onClicked: pluginMain?.mediaPlayPause()
          }
          NIconButton {
            visible: canNext
            icon: "player-track-next"
            baseSize: parent.btnSize
            colorFg: Color.mOnSurface
            colorBg: "transparent"
            colorBgHover: Color.mHover
            onClicked: pluginMain?.mediaNext()
          }
          NIconButton {
            visible: canRepeat
            icon: repeatMode === "one" ? "repeat-1" : "repeat"
            baseSize: parent.btnSize
            colorFg: repeatMode !== "off" ? Color.mSecondary : Qt.alpha(Color.mOnSurfaceVariant, 0.6)
            colorBg: "transparent"
            colorBgHover: Color.mHover
            onClicked: pluginMain?.cycleRepeat()
          }
        }
      }
    }

    // --- Audio & Device Controls ---
    NBox {
      Layout.fillWidth: true
      implicitHeight: audioColumn.implicitHeight + (Style.marginM * 2)
      visible: isConnected && (canVolumeSet || canVolumeMute || (pluginMain?.mediaPlayers?.length || 0) > 1)

      ColumnLayout {
        id: audioColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // Volume
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: canVolumeSet || canVolumeMute
          
          NIconButton {
            visible: canVolumeMute
            icon: isVolumeMuted ? "volume-off" : (volumeLevel > 0.5 ? "volume" : "volume-2")
            baseSize: Style.baseWidgetSize * 0.9
            colorBg: "transparent"
            onClicked: pluginMain?.toggleMute()
          }
          NSlider {
            id: volumeSlider
            Layout.fillWidth: true
            visible: canVolumeSet
            from: 0; to: 1; value: localVolumeLevel
            enabled: isConnected && !isVolumeMuted
            heightRatio: 0.4 // Smaller knob
            cutoutColor: Color.mSurfaceVariant
            onMoved: localVolumeLevel = value
            onPressedChanged: if (!pressed) pluginMain?.setVolume(localVolumeLevel);
          }
          NText {
            visible: canVolumeSet
            text: Math.round(localVolumeLevel * 100) + "%"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            family: Settings.data.ui.fontFixed
            Layout.preferredWidth: Math.round(Style.marginL * 3)
            Layout.rightMargin: Style.marginXS
            horizontalAlignment: Text.AlignRight
          }
        }

        // Device Select
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: (pluginMain?.mediaPlayers?.length || 0) > 1

          NIcon {
            icon: "devices"
            pointSize: Style.fontSizeM
            color: Color.mSecondary
          }

          // Custom dropdown (avoids Qt ComboBox system styling)
          Item {
            Layout.fillWidth: true
            implicitHeight: Style.capsuleHeight

            Rectangle {
              id: deviceButton
              anchors.fill: parent
              color: deviceButtonMA.containsMouse ? Color.mHover : Qt.alpha(Color.mSurface, 0.3)
              radius: Style.radiusM
              border.color: Color.mOutline
              border.width: Style.borderS

              NText {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: Style.marginL
                verticalAlignment: Text.AlignVCenter
                text: {
                  const players = pluginMain?.mediaPlayers || []
                  const selected = pluginMain?.selectedMediaPlayer || ""
                  for (var i = 0; i < players.length; i++) {
                    if (players[i].entity_id === selected)
                      return players[i].friendly_name || players[i].entity_id
                  }
                  return players[0]?.friendly_name || "Select Device"
                }
                color: Color.mOnSurface
                font.weight: Style.fontWeightMedium
                elide: Text.ElideRight
              }

              NIcon {
                anchors.right: parent.right
                anchors.rightMargin: Style.marginM
                anchors.verticalCenter: parent.verticalCenter
                icon: "selector"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
              }

              MouseArea {
                id: deviceButtonMA
                anchors.fill: parent
                hoverEnabled: true
                onClicked: devicePopup.open()
              }
            }

            Popup {
              id: devicePopup
              y: deviceButton.height + Style.marginS
              width: deviceButton.width
              implicitHeight: Math.min(
                Style.capsuleHeight * 5,
                deviceListView.contentHeight + devicePopup.topPadding + devicePopup.bottomPadding
              )
              padding: Style.marginS

              background: NBox {
                color: Color.mSurfaceVariant
                border.color: Color.mOutline
              }

              contentItem: ListView {
                id: deviceListView
                clip: true
                model: pluginMain?.mediaPlayers || []

                delegate: Rectangle {
                  width: deviceListView.width
                  height: Style.capsuleHeight
                  radius: Style.radiusS
                  color: deviceDelegateMA.containsMouse ? Color.mHover : "transparent"

                  NText {
                    anchors.fill: parent
                    anchors.leftMargin: Style.marginM
                    text: modelData.friendly_name || modelData.entity_id
                    verticalAlignment: Text.AlignVCenter
                    color: deviceDelegateMA.containsMouse ? Color.mOnHover : Color.mOnSurface
                    font.weight: modelData.entity_id === pluginMain?.selectedMediaPlayer
                      ? Style.fontWeightBold : Style.fontWeightMedium
                  }

                  MouseArea {
                    id: deviceDelegateMA
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      pluginMain?.selectMediaPlayer(modelData.entity_id)
                      devicePopup.close()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    NText {
      Layout.fillWidth: true
      visible: !isConnected
      text: connectionError !== "" ? connectionError : (pluginApi?.tr("panel.settings-hint") || "Configure connection in Settings > Plugins > Home Assistant")
      color: connectionError !== "" ? Color.mError : Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      pointSize: Style.fontSizeS
      horizontalAlignment: Text.AlignHCenter
    }
  }

  function formatTime(seconds) {
    if (!seconds || seconds < 0) return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return mins + ":" + (secs < 10 ? "0" : "") + secs;
  }
}
