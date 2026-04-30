import Quickshell
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  icon: "layout-dashboard"
  tooltipText: pluginApi?.tr("widget.tooltip")
  onClicked: pluginApi?.mainInstance?.toggle()
}
