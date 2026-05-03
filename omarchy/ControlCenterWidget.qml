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
      return pluginApi?.tr("tooltips.inactive");
    if (!isAvailable)
      return pluginApi?.tr("tooltips.not-available");

    const template = pluginApi?.tr("tooltips.active");
    return (typeof template === "string" ? template : "").replace("{theme}", pluginMain?.themeDisplayName || "");
  }

  onClicked: {
    if (!isActive) {
      if (isAvailable)
        pluginMain?.activate();
      else
        pluginApi?.togglePanel(screen, this);
      return;
    }

    pluginApi?.togglePanel(screen, this);
  }
}
