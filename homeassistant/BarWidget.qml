import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isConnected: pluginMain?.connected || false
  readonly property bool isConnecting: pluginMain?.connecting || false
  readonly property bool isPlaying: pluginMain?.isPlaying || false
  readonly property bool isPaused: pluginMain?.isPaused || false
  property bool hasEverConnected: false

  onIsConnectedChanged: {
    if (isConnected)
      hasEverConnected = true
  }

  readonly property string mediaTitle: pluginMain?.mediaTitle || ""
  readonly property string mediaArtist: pluginMain?.mediaArtist || ""
  readonly property string friendlyName: pluginMain?.friendlyName || ""

  readonly property string labelText: {
    if (!isConnected)
      return pluginApi?.tr("title") || "Home Assistant"
    if (mediaTitle)
      return mediaTitle
    return friendlyName || (pluginApi?.tr("title") || "Home Assistant")
  }

  readonly property string pillText: isBarVertical ? "" : labelText

  readonly property string iconName: {
    if (isConnecting)
      return "home-search"
    if (!isConnected)
      return "home-off"
    if (isPlaying)
      return "player-play"
    if (isPaused)
      return "player-pause"
    return "home"
  }

  readonly property string tooltipText: {
    if (isConnecting)
      return pluginApi?.tr("status.connecting") || "Connecting..."
    if (!isConnected)
      return pluginApi?.tr("tooltips.disconnected") || "Home Assistant (disconnected)\nClick to configure"
    if (isPlaying && mediaTitle) {
      let tooltip = mediaTitle
      if (mediaArtist)
        tooltip += "\n" + mediaArtist
      tooltip += "\n" + (pluginApi?.tr("tooltips.click-hint") || "Click to control")
      return tooltip
    }
    return pluginApi?.tr("tooltips.connected", {
                           count: pluginMain?.mediaPlayers?.length || 0
                         }) || "Home Assistant\n" + (pluginMain?.mediaPlayers?.length || 0) + " devices available"
  }

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string scrollingMode: pluginApi?.pluginSettings?.barWidgetScrollingMode || defaultSettings.barWidgetScrollingMode || "hover"
  readonly property int barWidgetMaxWidth: pluginApi?.pluginSettings?.barWidgetMaxWidth ?? defaultSettings.barWidgetMaxWidth ?? 200
  readonly property bool barWidgetUseFixedWidth: pluginApi?.pluginSettings?.barWidgetUseFixedWidth ?? defaultSettings.barWidgetUseFixedWidth ?? false

  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
  readonly property real barHeight: Style.getBarHeightForScreen(screen?.name)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screen?.name)
  readonly property int iconSize: Style.toOdd(capsuleHeight * 0.7)
  readonly property int verticalSize: Style.toOdd(capsuleHeight * 0.85)

  function calculateContentWidth() {
    var contentWidth = 0
    var margins = isBarVertical ? 0 : Style.margin2S

    contentWidth += iconSize
    contentWidth += Style.marginS

    if (!isBarVertical && pillText !== "") {
      contentWidth += titleContainer.measuredWidth
      contentWidth += Style.margin2XXS
    }

    contentWidth += margins
    return Math.ceil(contentWidth)
  }

  readonly property real dynamicWidth: {
    if (barWidgetUseFixedWidth) {
      return barWidgetMaxWidth
    }
    return Math.min(calculateContentWidth(), barWidgetMaxWidth)
  }

  implicitWidth: isBarVertical ? verticalSize : dynamicWidth
  implicitHeight: isBarVertical ? verticalSize : barHeight

  Behavior on implicitWidth {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.InOutCubic
    }
  }

  Behavior on implicitHeight {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.InOutCubic
    }
  }

  function popupWindow() {
    if (!screen)
      return null
    return PanelService.getPopupMenuWindow(screen)
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        label: isPlaying ? (pluginApi?.tr("actions.pause") || "Pause") : (pluginApi?.tr("actions.play") || "Play"),
        action: "play-pause",
        icon: isPlaying ? "player-pause" : "player-play",
        enabled: isConnected
      },
      {
        label: pluginApi?.tr("actions.next") || "Next",
        action: "next",
        icon: "player-track-next",
        enabled: isConnected
      },
      {
        label: pluginApi?.tr("actions.previous") || "Previous",
        action: "previous",
        icon: "player-track-prev",
        enabled: isConnected
      },
      {
        label: pluginApi?.tr("actions.refresh") || "Refresh",
        action: "refresh",
        icon: "refresh"
      },
      {
        label: pluginApi?.tr("tooltips.widget-settings") || "Widget settings",
        action: "settings",
        icon: "settings"
      }
    ]

    onTriggered: action => {
                   PanelService.closeContextMenu(screen)
                   if (action === "play-pause") {
                     pluginMain?.mediaPlayPause()
                   } else if (action === "next") {
                     pluginMain?.mediaNext()
                   } else if (action === "previous") {
                     pluginMain?.mediaPrevious()
                   } else if (action === "refresh") {
                     pluginMain?.refresh()
                   } else if (action === "settings") {
                     openPluginSettings()
                   }
                 }
  }

  Rectangle {
    id: container

    x: isBarVertical ? Style.pixelAlignCenter(parent.width, width) : 0
    y: isBarVertical ? 0 : Style.pixelAlignCenter(parent.height, height)
    width: isBarVertical ? verticalSize : dynamicWidth
    height: isBarVertical ? verticalSize : capsuleHeight
    radius: Style.radiusM

    color: {
      if (!isConnected && hasEverConnected)
        return Color.mSurfaceVariant
      return Style.capsuleColor
    }

    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on width {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.InOutCubic
      }
    }

    Item {
      id: mainContainer

      anchors.fill: parent
      anchors.leftMargin: isBarVertical ? 0 : Style.marginS
      anchors.rightMargin: isBarVertical ? 0 : Style.marginS

      RowLayout {
        id: rowLayout

        height: iconSize
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: Style.marginS
        visible: !isBarVertical

        Item {
          Layout.preferredWidth: iconSize
          Layout.preferredHeight: iconSize
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            anchors.centerIn: parent
            icon: iconName
            pointSize: iconSize * 0.5
            color: {
              if (!isConnected && hasEverConnected)
                return Color.mOnSurface
              return Color.mOnSurface
            }
          }
        }

        NScrollText {
          id: titleContainer

          text: pillText
          Layout.alignment: Qt.AlignVCenter
          maxWidth: {
            var iconWidth = iconSize + Style.marginS
            var margins = Style.margin2XXS
            var available = mainContainer.width - iconWidth - margins
            return Math.max(20, available)
          }
          scrollMode: {
            var mode = NScrollText.ScrollMode.Never
            if (scrollingMode === "always")
              mode = NScrollText.ScrollMode.Always
            else if (scrollingMode === "hover")
              mode = NScrollText.ScrollMode.Hover
            return mode
          }
          forcedHover: mainMouseArea.containsMouse
          gradientColor: container.color
          gradientWidth: Math.round(8 * Style.uiScaleRatio)
          cornerRadius: Style.radiusM
          cursorShape: Qt.PointingHandCursor
          visible: pillText !== ""

          NText {
            text: pillText
            color: {
              if (!isConnected && hasEverConnected)
                return Color.mOnSurface
              return Color.mOnSurface
            }
            pointSize: barFontSize
            applyUiScale: false
          }
        }
      }

      Item {
        id: verticalLayout

        width: parent.width - Style.margin2M
        height: parent.height - Style.margin2M
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        visible: isBarVertical

        NIcon {
          anchors.centerIn: parent
          icon: iconName
          pointSize: iconSize * 0.5
          color: Color.mOnSurface
        }
      }
    }
  }

  MouseArea {
    id: mainMouseArea

    anchors.fill: parent
    anchors.leftMargin: (!isBarVertical && section === "left" && sectionWidgetIndex === 0) ? -Style.marginS : 0
    anchors.rightMargin: (!isBarVertical && section === "right" && sectionWidgetIndex === sectionWidgetsCount - 1) ? -Style.marginS : 0
    anchors.topMargin: (isBarVertical && section === "left" && sectionWidgetIndex === 0) ? -Style.marginM : 0
    anchors.bottomMargin: (isBarVertical && section === "right" && sectionWidgetIndex === sectionWidgetsCount - 1) ? -Style.marginM : 0

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onEntered: {
      if (isBarVertical || scrollingMode === "never") {
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection(screen?.name))
      }
    }
    onExited: {
      TooltipService.hide()
    }
    onClicked: mouse => {
                 TooltipService.hide()
                 if (mouse.button === Qt.LeftButton) {
                   pluginApi?.togglePanel(root.screen, container)
                 } else if (mouse.button === Qt.RightButton) {
                   PanelService.showContextMenu(contextMenu, container, screen)
                 } else if (mouse.button === Qt.MiddleButton) {
                   pluginMain?.mediaPlayPause()
                 }
               }
    onWheel: wheel => {
               if (!isConnected)
                 return
               const step = pluginMain?.wheelVolumeStep || 0.05
               pluginMain?.queueVolumeStep(wheel.angleDelta.y > 0 ? step : -step)
             }
  }

  function openPluginSettings() {
    if (!pluginApi || !root.screen)
      return
    PanelService.closeContextMenu(screen)
    BarService.openPluginSettings(root.screen, pluginApi.manifest)
  }
}
