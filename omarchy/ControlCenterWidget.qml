import Quickshell
import qs.Commons
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isActive: pluginApi?.pluginSettings?.active === true
  readonly property bool isAvailable: pluginMain?.available === true

  icon: "palette"
  colorFg: (!isActive || !isAvailable) ? Color.mOnSurface : Color.mPrimary
  tooltipText: {
    if (!isActive)
      return pluginApi?.tr("tooltips.inactive")
    if (!isAvailable)
      return pluginApi?.tr("tooltips.not-available")
    return pluginApi?.tr("tooltips.active", { "theme": pluginMain?.themeDisplayName || "" })
  }

  onClicked: {
    pluginApi?.togglePanel(screen, this)
  }
}
