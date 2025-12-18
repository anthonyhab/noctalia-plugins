import QtQuick

Item {
  id: root

  // Plugin API injected by PluginService
  property var pluginApi: null

  // Settings from pluginApi
  readonly property string textCommand: pluginApi?.pluginSettings?.textCommand || "omarchy-update-available"
  readonly property int interval: pluginApi?.pluginSettings?.interval || 3600

  Component.onCompleted: {
    if (pluginApi) {
      console.log("[waybar-update] Plugin loaded");
    }
  }
}
