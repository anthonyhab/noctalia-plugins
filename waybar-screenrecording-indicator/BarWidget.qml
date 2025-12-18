import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

  readonly property string textCommand: pluginApi?.pluginSettings?.textCommand || "$OMARCHY_PATH/default/waybar/indicators/screen-recording.sh"
  readonly property int intervalMs: (pluginApi?.pluginSettings?.interval || 0) * 1000
  readonly property bool isStreaming: intervalMs <= 0

  property string _displayText: ""
  property string _displayIcon: ""
  property string _displayTooltip: ""

  readonly property string pillText: isBarVertical ? "" : _displayText
  readonly property string iconName: _displayIcon || "code"

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill

    screen: root.screen
    density: Settings.data.bar.density
    oppositeDirection: BarService.getPillDirection(root)
    icon: iconName
    text: pillText
    tooltipText: _displayTooltip || _displayText
    forceOpen: !isBarVertical && _displayText !== ""
    onClicked: Quickshell.execDetached(['sh', '-c', 'omarchy-cmd-screenrecord'])
  }

  SplitParser {
    id: stdoutSplit
    onRead: line => root.parseOutput(line)
  }

  StdioCollector {
    id: stdoutCollect
    onStreamFinished: () => root.parseOutput(this.text)
  }

  Process {
    id: textProc
    command: ["sh", "-lc", textCommand]
    stdout: isStreaming ? stdoutSplit : stdoutCollect
    stderr: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (isStreaming) {
        Logger.w("waybar-screenrecording-indicator", "Streaming command exited, restarting...");
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: Math.max(250, intervalMs)
    repeat: true
    running: !isStreaming && textCommand.length > 0
    triggeredOnStart: true
    onTriggered: runCommand()
  }

  Timer {
    id: restartTimer
    interval: 1000
    running: isStreaming && !textProc.running
    onTriggered: runCommand()
  }

  function runCommand() {
    if (!textCommand || textProc.running) return;
    textProc.running = true;
  }

  function parseOutput(content) {
    var str = String(content || "").trim();
    if (!str) return;

    // JSON parsing
    try {
      var parsed = JSON.parse(str);
      _displayText = parsed.text || "";
      _displayIcon = parsed.icon || "";
      _displayTooltip = parsed.tooltip || "";
    } catch (e) {
      _displayText = str;
      _displayIcon = "";
      _displayTooltip = str;
    }
  }

  Component.onCompleted: {
    if (isStreaming) {
      runCommand();
    }
  }
}
