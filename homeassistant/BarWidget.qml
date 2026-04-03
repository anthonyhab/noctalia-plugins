import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

NIconButton {
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

  icon: {
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

  tooltipText: {
    if (isConnecting)
      return pluginApi?.tr("status.connecting")
    if (!isConnected)
      return pluginApi?.tr("tooltips.disconnected")
    return pluginApi?.tr("tooltips.connected", { count: deviceCount })
  }

  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL

  colorBg: Style.capsuleColor
  colorFg: {
    if (!isConnected)
      return Color.mOnSurfaceVariant
    if (isConnecting || isPlaying)
      return Color.mPrimary
    return Color.mOnSurface
  }
  colorBgHover: Color.mHover
  colorFgHover: Color.mOnHover

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    pluginApi?.togglePanel(root.screen, root)
  }
}
