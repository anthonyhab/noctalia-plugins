import QtQuick
import QtQuick.Layouts
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

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool isConnected: mainInstance?.connected || false
  readonly property bool isConnecting: mainInstance?.connecting || false
  readonly property bool isPlaying: mainInstance?.isPlaying || false
  readonly property bool isPaused: mainInstance?.isPaused || false
  readonly property int deviceCount: mainInstance?.mediaPlayers?.length || 0

  readonly property string mediaTitle: mainInstance?.mediaTitle || ""
  readonly property string mediaArtist: mainInstance?.mediaArtist || ""
  readonly property string friendlyName: mainInstance?.friendlyName || ""

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screen?.name)

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property int barWidgetMaxWidth: pluginApi?.pluginSettings?.barWidgetMaxWidth ?? defaultSettings.barWidgetMaxWidth ?? 200
  readonly property bool barWidgetUseFixedWidth: pluginApi?.pluginSettings?.barWidgetUseFixedWidth ?? defaultSettings.barWidgetUseFixedWidth ?? false
  readonly property string scrollingMode: pluginApi?.pluginSettings?.barWidgetScrollingMode ?? defaultSettings.barWidgetScrollingMode ?? "hover"

  readonly property string labelText: {
    if (!isConnected)
      return ""
    if (mediaTitle)
      return mediaTitle
    return friendlyName || ""
  }

  readonly property bool shouldShowText: !isBarVertical && labelText !== ""

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
      return pluginApi?.tr("status.connecting")
    if (!isConnected)
      return pluginApi?.tr("tooltips.disconnected")
    if (isPlaying && mediaTitle) {
      var tooltip = mediaTitle
      if (mediaArtist)
        tooltip += "\n" + mediaArtist
      tooltip += "\n" + pluginApi?.tr("tooltips.click-hint")
      return tooltip
    }
    return pluginApi?.tr("tooltips.connected", { count: deviceCount })
  }

  readonly property color computedIconColor: {
    if (!isConnected)
      return Color.mOnSurfaceVariant
    if (isConnecting || isPlaying)
      return Color.mPrimary
    return Color.mOnSurface
  }

  readonly property int iconSize: Style.toOdd(capsuleHeight * 0.48)
  readonly property int verticalSize: Style.toOdd(capsuleHeight * 0.85)

  property real mainContentWidth: 0
  readonly property real contentWidth: {
    if (isBarVertical)
      return verticalSize

    if (barWidgetUseFixedWidth)
      return barWidgetMaxWidth

    if (!shouldShowText) {
      mainContentWidth = 0
      return capsuleHeight
    }

    var iconWidth = iconSize
    var margins = Style.margin2S

    var textWidth = 0
    if (scrollText.measuredWidth > 0) {
      textWidth = scrollText.measuredWidth + Style.margin2XXS
    }

    var total = iconWidth + textWidth + margins
    mainContentWidth = total - textWidth
    return Math.min(total, barWidgetMaxWidth)
  }

  implicitWidth: isBarVertical ? verticalSize : contentWidth
  implicitHeight: isBarVertical ? verticalSize : capsuleHeight

  Behavior on implicitWidth {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.InOutCubic
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": isPlaying ? pluginApi?.tr("actions.pause") : pluginApi?.tr("actions.play"),
        "action": "play-pause",
        "icon": isPlaying ? "player-pause" : "player-play",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.next"),
        "action": "next",
        "icon": "player-track-next",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.previous"),
        "action": "previous",
        "icon": "player-track-prev",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.refresh"),
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("tooltips.widget-settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "play-pause") {
        mainInstance?.mediaPlayPause()
      } else if (action === "next") {
        mainInstance?.mediaNext()
      } else if (action === "previous") {
        mainInstance?.mediaPrevious()
      } else if (action === "refresh") {
        mainInstance?.refresh()
      } else if (action === "settings") {
        openPluginSettings()
      }
    }
  }

  Rectangle {
    id: container

    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: Style.toOdd(isBarVertical ? verticalSize : contentWidth)
    height: Style.toOdd(isBarVertical ? verticalSize : capsuleHeight)
    radius: Style.radiusM

    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on width {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.InOutCubic
      }
    }

    Item {
      anchors.fill: parent
      anchors.leftMargin: isBarVertical ? 0 : Style.marginS
      anchors.rightMargin: isBarVertical ? 0 : Style.marginS

      RowLayout {
        anchors.fill: parent
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.marginS
        visible: !isBarVertical
        z: 1

        NIcon {
          icon: iconName
          pointSize: iconSize
          applyUiScale: false
          color: computedIconColor
          Layout.preferredWidth: iconSize
          Layout.preferredHeight: iconSize
          Layout.alignment: Qt.AlignVCenter

          Behavior on color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }
        }

        NScrollText {
          id: scrollText

          text: shouldShowText ? labelText : ""
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredHeight: capsuleHeight

          scrollMode: {
            if (scrollingMode === "always")
              return NScrollText.ScrollMode.Always
            if (scrollingMode === "hover")
              return NScrollText.ScrollMode.Hover
            return NScrollText.ScrollMode.Never
          }
          maxWidth: root.barWidgetMaxWidth - root.mainContentWidth
          forcedHover: mainMouseArea.containsMouse
          gradientColor: container.color
          gradientWidth: Math.round(8 * Style.uiScaleRatio)
          cornerRadius: Style.radiusM
          cursorShape: Qt.PointingHandCursor

          NText {
            color: Color.mOnSurface
            pointSize: barFontSize
            applyUiScale: false
            elide: Text.ElideNone
          }
        }
      }

      Item {
        id: verticalLayout

        visible: isBarVertical
        width: Style.toOdd(verticalSize)
        height: Style.toOdd(width)
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)

        NIcon {
          anchors.centerIn: parent
          icon: iconName
          pointSize: iconSize
          applyUiScale: false
          color: computedIconColor
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
    onExited: TooltipService.hide()

    onClicked: mouse => {
      TooltipService.hide()
      if (mouse.button === Qt.LeftButton) {
        pluginApi?.togglePanel(root.screen, container)
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, container, screen)
      } else if (mouse.button === Qt.MiddleButton) {
        mainInstance?.mediaPlayPause()
      }
    }

    onWheel: wheel => {
      if (!isConnected)
        return
      if (wheel.angleDelta.y > 0) {
        mainInstance?.volumeUp()
      } else {
        mainInstance?.volumeDown()
      }
    }
  }

  function openPluginSettings() {
    if (!pluginApi || !root.screen)
      return

    PanelService.closeContextMenu(screen)
    BarService.openPluginSettings(root.screen, pluginApi.manifest)
  }
}
