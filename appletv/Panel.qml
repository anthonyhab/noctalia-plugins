import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var screen: null

  readonly property bool allowAttach: true
  readonly property int contentPreferredWidth: Math.round(340 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: Math.round(500 * Style.uiScaleRatio)

  readonly property var pluginMain: pluginApi?.mainInstance

  readonly property bool connected: pluginMain?.connected || false
  readonly property bool connecting: pluginMain?.connecting || false
  readonly property string connectionError: pluginMain?.connectionError || ""

  property real calculatedPosition: pluginMain?.mediaPosition || 0

  Timer {
    id: positionTimer
    interval: 1000
    repeat: true
    running: pluginMain?.isPlaying && (pluginMain?.mediaDuration || 0) > 0
    onTriggered: {
      if (!pluginMain)
        return;
      const updatedAt = pluginMain.mediaPositionUpdatedAt ? new Date(pluginMain.mediaPositionUpdatedAt) : null;
      if (updatedAt) {
        const elapsed = (Date.now() - updatedAt.getTime()) / 1000;
        calculatedPosition = Math.min(pluginMain.mediaPosition + elapsed, pluginMain.mediaDuration);
      } else {
        calculatedPosition = pluginMain.mediaPosition || 0;
      }
    }
  }

  onVisibleChanged: if (visible && pluginMain)
                      pluginMain.refresh?.()

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + Style.marginS * 2

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginS
        anchors.bottomMargin: Style.marginS
        spacing: Style.marginM

        NIcon {
          icon: "device-tv"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true

          NText {
            text: pluginApi?.tr("title") || pluginMain?.deviceLabel || "Apple TV"
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
          }

          NText {
            text: connecting ? (pluginApi?.tr("status.connecting") || "Connecting...") : (connected ? (pluginApi?.tr("status.connected") || "Connected") : (pluginApi?.tr("status.disconnected") || "Disconnected"))
            pointSize: Style.fontSizeS
            color: connected ? Color.mSecondary : Color.mOnSurfaceVariant
          }
        }

        Rectangle {
          width: Style.fontSizeL
          height: Style.fontSizeL
          radius: width / 2
          color: connected ? "#4ade80" : (connecting ? "#fbbf24" : "#f87171")
          border.width: Style.borderS
          border.color: connected ? "#22c55e" : (connecting ? "#f59e0b" : "#ef4444")
        }
      }
    }

    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            Layout.fillWidth: true
            text: pluginMain?.displayTitle || (pluginApi?.tr("media.no-media") || "Nothing playing")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM
            color: Color.mOnSurface
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }

          NText {
            Layout.fillWidth: true
            visible: (pluginMain?.mediaArtist || "") !== ""
            text: pluginMain?.mediaArtist || ""
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }

          NText {
            Layout.fillWidth: true
            visible: (pluginMain?.mediaAlbum || "") !== ""
            text: pluginMain?.mediaAlbum || ""
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS
          visible: (pluginMain?.mediaDuration || 0) > 0

          Slider {
            id: progressSlider
            Layout.fillWidth: true
            from: 0
            to: pluginMain?.mediaDuration || 0
            value: calculatedPosition
            enabled: connected && (pluginMain?.mediaDuration || 0) > 0

            onPressedChanged: {
              if (!pressed) {
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
              text: formatTime(pluginMain?.mediaDuration || 0)
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.marginM

          NIconButton {
            icon: "player-track-prev"
            baseSize: 28
            enabled: connected
            tooltipText: pluginApi?.tr("actions.previous") || "Previous"
            onClicked: pluginMain?.previousTrack()
          }

          NIconButton {
            icon: pluginMain?.isPlaying ? "player-pause" : "player-play"
            baseSize: 48
            enabled: connected
            tooltipText: pluginMain?.isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play")
            onClicked: pluginMain?.togglePlayPause()
          }

          NIconButton {
            icon: "player-track-next"
            baseSize: 28
            enabled: connected
            tooltipText: pluginApi?.tr("actions.next") || "Next"
            onClicked: pluginMain?.nextTrack()
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NIconButton {
            icon: pluginMain?.isVolumeMuted ? "volume-off" : ((pluginMain?.volumeLevel || 0) > 0.5 ? "volume" : "volume-2")
            baseSize: 20
            enabled: connected
            tooltipText: pluginMain?.isVolumeMuted ? (pluginApi?.tr("actions.unmute") || "Unmute") : (pluginApi?.tr("actions.mute") || "Mute")
            onClicked: pluginMain?.isVolumeMuted ? pluginMain?.unmute() : pluginMain?.mute()
          }

          Slider {
            id: volumeSlider
            Layout.fillWidth: true
            from: 0
            to: 1
            value: pluginMain?.volumeLevel || 0
            enabled: connected

            onMoved: {
              if (pluginMain)
                pluginMain.volumeLevel = value;
            }

            onPressedChanged: {
              if (!pressed && pluginMain) {
                pluginMain.setVolume(value);
              }
            }
          }

          NText {
            text: Math.round((pluginMain?.volumeLevel || 0) * 100) + "%"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            Layout.preferredWidth: 35
          }
        }

        NText {
          Layout.fillWidth: true
          visible: connectionError !== ""
          text: connectionError
          color: Color.mError
          wrapMode: Text.WordWrap
        }

        NText {
          Layout.fillWidth: true
          visible: !connected
          text: pluginApi?.tr("panel.settings-hint") || "Configure the helper path and Apple TV credentials in plugin settings."
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
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
