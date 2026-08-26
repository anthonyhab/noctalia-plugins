import Quickshell
import "PluginUi.js" as PluginUi
import qs.Commons
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isActive: pluginApi?.pluginSettings?.active === true
  readonly property bool isAvailable: pluginMain?.available === true
  readonly property bool isBusy: pluginMain?.isBusy === true

  icon: "palette"
  colorFg: (!isActive || !isAvailable) ? Color.mOnSurface : Color.mPrimary
  tooltipText: PluginUi.omarchyTooltip(pluginApi, isBusy, isActive, isAvailable, pluginMain?.themeDisplayName || "")

  onClicked: {
    const action = PluginUi.primaryAction(isActive, isAvailable);
    if (action === "activate")
      pluginMain?.activate();
    else
      pluginApi?.togglePanel(screen, this);
  }
}
