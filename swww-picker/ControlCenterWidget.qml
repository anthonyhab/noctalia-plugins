import QtQuick
import Quickshell
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  id: root

  property ShellScreen screen
  property var pluginApi: null

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool autoCycleEnabled: pluginMain?.autoCycleEnabled || false
  readonly property string currentWallpaperName: {
    const wallpaper = pluginMain?.currentWallpaper || "";
    if (!wallpaper)
      return pluginApi?.tr("status.none");
    return wallpaper.split("/").pop() || pluginApi?.tr("status.none");
  }

  icon: !isAvailable
    ? "photo-off"
    : (autoCycleEnabled ? "player-play" : "photo")
  tooltipText: currentWallpaperName

  onClicked: pluginMain?.next()
  onMiddleClicked: pluginMain?.previous()
  onRightClicked: pluginMain?.random()
}
