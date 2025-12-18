import QtQuick

Item {
  id: root

  // Plugin API injected by PluginService
  property var pluginApi: null

  // Settings from pluginApi
  readonly property string textCommand: pluginApi?.pluginSettings?.textCommand || "$OMARCHY_PATH/default/waybar/indicators/screen-recording.sh"
  readonly property int interval: pluginApi?.pluginSettings?.interval || 0

  Component.onCompleted: {
    if (pluginApi) {
      console.log("[waybar-screenrecording-indicator] Plugin loaded");
    }
  }
}
