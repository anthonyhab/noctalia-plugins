import QtQuick
import QtQuick.Controls
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
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // --- Header ---
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
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // --- Media Content ---
    NBox {
      Layout.fillWidth: true
      visible: isConnected && (mediaTitle !== "" || entityPicture !== "")

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // Album Art
        NBox {
          Layout.fillWidth: true
          Layout.preferredHeight: width
          Layout.maximumHeight: 200 * Style.uiScaleRatio
          visible: entityPicture !== "" && !albumArtFailed
          color: Color.mSurfaceVariant
          clip: true
          Image {
            anchors.fill: parent
            source: entityPicture
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            onStatusChanged: if (status === Image.Error) albumArtFailed = true;
          }
        }

        // Metadata
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS
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
          NText {
            Layout.fillWidth: true
            visible: mediaAlbum !== ""
            text: mediaAlbum
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
          }
        }
      }
    }

    // --- Progress Bar ---
    NBox {
      Layout.fillWidth: true
      visible: isConnected && canSeek && mediaDuration > 0
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS
        NSlider {
          Layout.fillWidth: true
          from: 0
          to: mediaDuration
          value: calculatedPosition
          enabled: isConnected && canSeek
          onPressedChanged: if (!pressed && Math.abs(value - calculatedPosition) > 1) pluginMain?.seek(value);
        }
        RowLayout {
          Layout.fillWidth: true
          NText { text: formatTime(calculatedPosition); pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; family: Settings.data.ui.fontFixed }
          Item { Layout.fillWidth: true }
          NText { text: formatTime(mediaDuration); pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant; family: Settings.data.ui.fontFixed }
        }
      }
    }

    // --- Transport Controls (Uniform Size) ---
    NBox {
      Layout.fillWidth: true
      visible: isConnected
      RowLayout {
        anchors.centerIn: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        readonly property real btnSize: Style.baseWidgetSize * 1.1

        NIconButton {
          visible: canShuffle
          icon: "arrows-shuffle"
          baseSize: parent.btnSize
          colorFg: shuffleEnabled ? Color.mSecondary : Color.mPrimary
          colorBg: shuffleEnabled ? Qt.rgba(Color.mSecondary.r, Color.mSecondary.g, Color.mSecondary.b, 0.15) : Color.mSurfaceVariant
          onClicked: pluginMain?.toggleShuffle()
        }
        NIconButton {
          visible: canPrevious
          icon: "player-track-prev"
          baseSize: parent.btnSize
          onClicked: pluginMain?.mediaPrevious()
        }
        NIconButton {
          icon: isPlaying ? "player-pause" : "player-play"
          baseSize: parent.btnSize
          colorBg: Color.mPrimary
          colorFg: Color.mOnPrimary
          onClicked: pluginMain?.mediaPlayPause()
        }
        NIconButton {
          visible: canNext
          icon: "player-track-next"
          baseSize: parent.btnSize
          onClicked: pluginMain?.mediaNext()
        }
        NIconButton {
          visible: canRepeat
          icon: repeatMode === "one" ? "repeat-1" : "repeat"
          baseSize: parent.btnSize
          colorFg: repeatMode !== "off" ? Color.mSecondary : Color.mPrimary
          colorBg: repeatMode !== "off" ? Qt.rgba(Color.mSecondary.r, Color.mSecondary.g, Color.mSecondary.b, 0.15) : Color.mSurfaceVariant
          onClicked: pluginMain?.cycleRepeat()
        }
      }
    }

    // --- Volume Control ---
    NBox {
      Layout.fillWidth: true
      visible: isConnected && (canVolumeSet || canVolumeMute)
      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM
        NIconButton {
          visible: canVolumeMute
          icon: isVolumeMuted ? "volume-off" : (volumeLevel > 0.5 ? "volume" : "volume-2")
          baseSize: Style.baseWidgetSize * 0.9
          onClicked: pluginMain?.toggleMute()
        }
        NSlider {
          id: volumeSlider
          Layout.fillWidth: true
          visible: canVolumeSet
          from: 0; to: 1; value: localVolumeLevel
          enabled: isConnected && !isVolumeMuted
          onMoved: localVolumeLevel = value
          onPressedChanged: if (!pressed) pluginMain?.setVolume(localVolumeLevel);
        }
        NText {
          visible: canVolumeSet
          text: Math.round(localVolumeLevel * 100) + "%"
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          family: Settings.data.ui.fontFixed
          Layout.preferredWidth: Math.round(40 * Style.uiScaleRatio)
          horizontalAlignment: Text.AlignRight
        }
      }
    }

    // --- Device Selector (Unified) ---
    NBox {
      Layout.fillWidth: true
      visible: isConnected && (pluginMain?.mediaPlayers?.length || 0) > 1
      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "devices"
          pointSize: Style.fontSizeL
          color: Color.mPrimary
        }

        ComboBox {
          id: deviceSelector
          Layout.fillWidth: true
          flat: true
          model: pluginMain?.mediaPlayers?.map(p => ({ "key": p.entity_id, "name": p.friendly_name || p.entity_id })) || []
          currentIndex: {
            const selected = pluginMain?.selectedMediaPlayer || "";
            for (var i = 0; i < model.length; i++) if (model[i].key === selected) return i;
            return 0;
          }
          onActivated: {
            var item = model[currentIndex];
            if (item && item.key) pluginMain?.selectMediaPlayer(item.key);
          }

          background: Item {} // Transparent background, reliance on NBox

          contentItem: NText {
            leftPadding: 0
            verticalAlignment: Text.AlignVCenter
            text: deviceSelector.currentIndex >= 0 ? deviceSelector.model[deviceSelector.currentIndex].name : ""
            color: Color.mOnSurface
            font.weight: Style.fontWeightMedium
            elide: Text.ElideRight
          }

          indicator: NIcon {
            x: deviceSelector.width - width
            y: (deviceSelector.height - height) / 2
            icon: "selector"
            pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant
          }
          
          popup: Popup {
            y: deviceSelector.height + Style.marginS
            width: deviceSelector.width
            implicitHeight: Math.min(200 * Style.uiScaleRatio, listview.contentHeight + (Style.marginM * 2))
            padding: Style.marginS
            background: NBox { color: Color.mSurfaceVariant; border.color: Color.mOutline }
            contentItem: ListView {
                id: listview
                clip: true
                model: deviceSelector.model
                delegate: Rectangle {
                    width: listview.width
                    height: Math.round(40 * Style.uiScaleRatio)
                    color: index === deviceSelector.currentIndex ? Color.mHover : "transparent"
                    radius: Style.radiusS
                    NText {
                        anchors.fill: parent; anchors.leftMargin: Style.marginM
                        text: modelData.name; verticalAlignment: Text.AlignVCenter
                        color: index === deviceSelector.currentIndex ? Color.mOnHover : Color.mOnSurface
                    }
                    MouseArea { anchors.fill: parent; onClicked: { deviceSelector.currentIndex = index; deviceSelector.activated(index); deviceSelector.popup.close(); } }
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
