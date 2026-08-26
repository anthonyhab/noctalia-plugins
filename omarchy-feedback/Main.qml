// qmllint disable signal-handler-parameters
import QtQuick
import Quickshell
import Quickshell.Io
import "OmarchyCommands.js" as OmarchyCommands
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  property bool omarchyAvailable: false
  property string omarchyPath: ""

  property string voxtypeState: "idle"
  property bool screenRecordingActive: false
  property bool idleDisabledActive: false
  property bool updateAvailable: false

  readonly property bool showVoxtype: pluginApi?.pluginSettings?.showVoxtype !== false
  readonly property bool showScreenRecording: pluginApi?.pluginSettings?.showScreenRecording !== false
  readonly property bool showIdleDisabled: pluginApi?.pluginSettings?.showIdleDisabled !== false
  readonly property bool showUpdateAvailable: pluginApi?.pluginSettings?.showUpdateAvailable !== false

  function runShell(process, script, args) {
    const command = ["bash", "-lc", script, "_"];
    process.command = args && args.length > 0 ? command.concat(args) : command;
    process.running = true;
  }

  function runOmarchyShell(process, script, args) {
    const commandArgs = [omarchyPath || ""];
    if (args && args.length > 0)
      commandArgs.push.apply(commandArgs, args);
    runShell(process, OmarchyCommands.omarchyBootstrapSnippet() + script, commandArgs);
  }

  function runOmarchyCommand(process, dispatcherCommand, legacyBinaryName, legacyArgs) {
    const args = [legacyBinaryName];
    if (legacyArgs && legacyArgs.length > 0)
      args.push.apply(args, legacyArgs);
    const script = OmarchyCommands.commandScript(dispatcherCommand);
    runOmarchyShell(process, script, args);
  }

  function detectOmarchyPath() {
    const env = Quickshell.env("OMARCHY_PATH") || "";
    const envTrimmed = env.trim();
    const home = Quickshell.env("HOME") || "~";
    const fallback = home + "/.local/share/omarchy";
    runShell(detectProcess, OmarchyCommands.detectScript(), [envTrimmed, fallback]);
  }

  function refresh() {
    detectOmarchyPath();
  }

  function clearIndicators() {
    voxtypeState = "idle";
    screenRecordingActive = false;
    idleDisabledActive = false;
    updateAvailable = false;
  }

  function markUnavailable() {
    omarchyAvailable = false;
    omarchyPath = "";
    clearIndicators();
  }

  function runToggleAndRefresh(dispatcherCommand, legacyBinaryName, refreshFn) {
    delayedRefreshTimer.pendingRefresh = refreshFn || null;
    runOmarchyCommand(actionProcess, dispatcherCommand, legacyBinaryName);
  }

  function openVoxtypeModel() {
    runOmarchyCommand(actionProcess, "omarchy voxtype model", "omarchy-voxtype-model");
  }

  function openVoxtypeConfig() {
    runOmarchyCommand(actionProcess, "omarchy voxtype config", "omarchy-voxtype-config");
  }

  function toggleScreenRecording() {
    runToggleAndRefresh("omarchy capture screenrecord", "omarchy-capture-screenrecording", function () {
      checkScreenRecording();
    });
  }

  function toggleIdle() {
    runToggleAndRefresh("omarchy toggle idle", "omarchy-toggle-idle", function () {
      checkIdleDisabled();
    });
  }

  function runOmarchyUpdate() {
    runOmarchyCommand(actionProcess, "omarchy launch floating terminal with presentation \"omarchy update\"", "omarchy-launch-floating-terminal-with-presentation", ["omarchy-update"]);
  }

  function checkVoxtype() {
    if (!omarchyAvailable || !showVoxtype) {
      voxtypeState = "idle";
      return;
    }
    runOmarchyShell(voxtypeProcess, "voxtype status --extended --format json 2>/dev/null");
  }

  function checkScreenRecording() {
    if (!omarchyAvailable || !showScreenRecording) {
      screenRecordingActive = false;
      return;
    }
    runOmarchyShell(screenRecordingProcess, "pgrep -f '^gpu-screen-recorder' >/dev/null");
  }

  function checkIdleDisabled() {
    if (!omarchyAvailable || !showIdleDisabled) {
      idleDisabledActive = false;
      return;
    }
    runOmarchyShell(idleProcess, "! pgrep -x hypridle >/dev/null");
  }

  function checkUpdateAvailable() {
    if (!omarchyAvailable || !showUpdateAvailable) {
      updateAvailable = false;
      return;
    }
    runOmarchyCommand(updateProcess, "omarchy update available", "omarchy-update-available");
  }

  function refreshIndicators() {
    checkVoxtype();
    checkScreenRecording();
    checkIdleDisabled();
    checkUpdateAvailable();
  }

  Component.onCompleted: refresh()

  Connections {
    target: pluginApi

    function onPluginSettingsChanged() {
      refreshIndicators();
    }
  }

  Process {
    id: detectProcess
    running: false
    stdout: StdioCollector {
      id: detectStdout
    }

    onExited: function (code) {
      const detected = (detectStdout.text || "").trim();
      omarchyAvailable = code === 0;
      omarchyPath = detected;
      if (!omarchyAvailable) {
        clearIndicators();
        return;
      }
      refreshIndicators();
    }
  }

  Process {
    id: voxtypeProcess
    running: false
    stdout: StdioCollector {
      id: voxtypeStdout
    }

    onExited: function (code) {
      if (code !== 0) {
        voxtypeState = "idle";
        if (code === 127)
          markUnavailable();
        return;
      }

      const output = (voxtypeStdout.text || "").trim();
      if (!output) {
        voxtypeState = "idle";
        return;
      }

      try {
        const parsed = JSON.parse(output);
        const nextState = String(parsed.class || "idle").trim().toLowerCase();
        if (nextState === "recording" || nextState === "transcribing")
          voxtypeState = nextState;
        else
          voxtypeState = "idle";
      } catch (e) {
        Logger.w("OmarchyFeedback", "Failed parsing voxtype status");
        voxtypeState = "idle";
      }
    }
  }

  Process {
    id: screenRecordingProcess
    running: false

    onExited: function (code) {
      screenRecordingActive = code === 0;
      if (code === 127)
        markUnavailable();
    }
  }

  Process {
    id: idleProcess
    running: false

    onExited: function (code) {
      idleDisabledActive = code === 0;
      if (code === 127)
        markUnavailable();
    }
  }

  Process {
    id: updateProcess
    running: false

    onExited: function (code) {
      updateAvailable = code === 0;
      if (code === 127)
        markUnavailable();
    }
  }

  Process {
    id: actionProcess
    running: false

    onExited: function (code) {
      if (code === 127) {
        markUnavailable();
        return;
      }
      if (delayedRefreshTimer.pendingRefresh)
        delayedRefreshTimer.start();
    }
  }

  Timer {
    id: voxtypePollTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: checkVoxtype()
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: checkScreenRecording()
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: checkIdleDisabled()
  }

  Timer {
    interval: 21600000
    repeat: true
    running: true
    onTriggered: checkUpdateAvailable()
  }

  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: detectOmarchyPath()
  }

  Timer {
    id: delayedRefreshTimer
    interval: 500
    repeat: false
    property var pendingRefresh: null

    onTriggered: {
      if (pendingRefresh)
        pendingRefresh();
      pendingRefresh = null;
    }
  }

  IpcHandler {
    target: "plugin:omarchy-feedback"

    function refresh() {
      root.refresh();
    }
  }
}
