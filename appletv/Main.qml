import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  readonly property string pythonPath: pluginApi?.pluginSettings?.pythonPath || "python3"
  readonly property string helperScriptPath: pluginApi?.pluginSettings?.helperScriptPath || (pluginApi?.pluginDir ? pluginApi.pluginDir + "/helper/appletv_helper.py" : "")
  readonly property string deviceIdentifier: pluginApi?.pluginSettings?.deviceIdentifier || ""
  readonly property string deviceAddress: pluginApi?.pluginSettings?.deviceAddress || ""
  readonly property string deviceName: pluginApi?.pluginSettings?.deviceName || ""
  readonly property string deviceLabel: pluginApi?.pluginSettings?.displayName || deviceName || deviceIdentifier || "Apple TV"
  readonly property string mrpCredentials: pluginApi?.pluginSettings?.mrpCredentials || ""
  readonly property string companionCredentials: pluginApi?.pluginSettings?.companionCredentials || ""
  readonly property string airplayCredentials: pluginApi?.pluginSettings?.airplayCredentials || ""
  readonly property int pollInterval: Math.max(2000, pluginApi?.pluginSettings?.pollInterval || 5000)
  readonly property int scanTimeout: pluginApi?.pluginSettings?.scanTimeout || 8

  readonly property bool helperConfigured: pythonPath !== "" && helperScriptPath !== "" && (deviceIdentifier !== "" || deviceAddress !== "" || deviceName !== "")

  property bool connecting: false
  property bool connected: false
  property bool pollInFlight: false
  property string connectionError: ""

  property string playbackState: "idle"
  property string mediaTitle: ""
  property string mediaArtist: ""
  property string mediaAlbum: ""
  property string nowPlayingApp: ""
  property real mediaDuration: 0
  property real mediaPosition: 0
  property string mediaPositionUpdatedAt: ""
  property real volumeLevel: 0
  property bool isVolumeMuted: false

  readonly property bool isPlaying: playbackState === "playing"
  readonly property bool isPaused: playbackState === "paused"

  property var volumeOverrides: ({})
  property string selectedDeviceKey: deviceIdentifier || deviceAddress || deviceName || ""

  Timer {
    id: pollTimer
    interval: pollInterval
    repeat: true
    running: helperConfigured
    onTriggered: refresh()
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      loadSettingsSnapshot();
      if (helperConfigured) {
        refresh();
      } else {
        connected = false;
      }
    }
  }

  Component.onCompleted: {
    loadSettingsSnapshot();
    if (helperConfigured) {
      refresh();
      pollTimer.restart();
    }
  }

  onHelperConfiguredChanged: {
    if (helperConfigured) {
      connectionError = "";
      refresh();
      pollTimer.restart();
    } else {
      pollTimer.stop();
      connected = false;
    }
  }

  function loadSettingsSnapshot() {
    if (!pluginApi || !pluginApi.pluginSettings)
      return;
    volumeOverrides = pluginApi.pluginSettings.volumeOverrides || {};
  }

  function refresh() {
    if (!helperConfigured || pollInFlight)
      return;
    pollInFlight = true;
    connecting = !connected;
    runHelperCommand("state", [], function (success, payload) {
      pollInFlight = false;
      connecting = false;
      if (!success) {
        connected = false;
        return;
      }
      const state = payload?.state || {};
      handleStateUpdate(state);
    });
  }

  function handleStateUpdate(state) {
    connected = true;
    connectionError = "";
    playbackState = state.device_state || "idle";
    mediaTitle = state.title || "";
    mediaArtist = state.artist || "";
    mediaAlbum = state.album || "";
    nowPlayingApp = state.app || "";
    mediaDuration = state.duration || 0;
    if (state.position !== null && state.position !== undefined)
      mediaPosition = state.position;
    if (state.updated)
      mediaPositionUpdatedAt = state.updated;
    if (state.volume !== null && state.volume !== undefined) {
      volumeLevel = state.volume;
      storeVolumeOverride(selectedDeviceKey, state.volume);
    } else {
      const cached = getVolumeOverride(selectedDeviceKey);
      if (cached !== null && cached !== undefined)
        volumeLevel = cached;
    }
    isVolumeMuted = state.is_muted || false;
  }

  function buildCommonArgs(command) {
    var args = [pythonPath, helperScriptPath, "--command", command, "--scan-timeout", String(scanTimeout)];
    if (deviceIdentifier)
      args.push("--identifier", deviceIdentifier);
    if (deviceAddress)
      args.push("--address", deviceAddress);
    if (deviceName)
      args.push("--name", deviceName);
    if (mrpCredentials)
      args.push("--mrp-credentials", mrpCredentials);
    if (companionCredentials)
      args.push("--companion-credentials", companionCredentials);
    if (airplayCredentials)
      args.push("--airplay-credentials", airplayCredentials);
    return args;
  }

  function runHelperCommand(command, extraArgs, callback) {
    if (!helperConfigured) {
      connectionError = pluginApi?.tr("errors.not-configured") || "Helper not configured";
      if (callback)
        callback(false, null);
      return;
    }
    var args = buildCommonArgs(command);
    if (extraArgs && extraArgs.length)
      args = args.concat(extraArgs);
    const proc = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { }', root);
    proc.command = args;
    proc.stdout = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stdout");
    proc.stderr = Qt.createQmlObject('import QtQuick; import Quickshell.Io; StdioCollector {}', proc, "stderr");
    proc.exited.connect(function (exitCode) {
      const out = String(proc.stdout.text || "").trim();
      const err = String(proc.stderr.text || "").trim();
      var payload = null;
      try {
        if (out.length > 0)
          payload = JSON.parse(out);
      } catch (e) {
        payload = null;
      }
      const success = payload && payload.hasOwnProperty("success") ? payload.success : exitCode === 0;
      if (!success) {
        connectionError = payload?.error || err || "Helper command failed";
        Logger.e("AppleTV", "Helper command failed", command, connectionError);
      } else {
        connectionError = "";
      }
      if (callback)
        callback(success, payload);
      proc.destroy();
    });
    proc.running = true;
  }

  function setVolume(level) {
    const clamped = Math.max(0, Math.min(1, level));
    runHelperCommand("set_volume", ["--level", String(clamped)], function (success) {
      if (success) {
        volumeLevel = clamped;
        storeVolumeOverride(selectedDeviceKey, clamped);
        Qt.callLater(refresh);
      }
    });
  }

  function togglePlayPause() {
    const action = isPlaying ? "pause" : "play";
    runHelperCommand(action, [], function (success) {
      if (success)
        Qt.callLater(refresh);
    });
  }

  function play() {
    runHelperCommand("play", [], function (success) {
      if (success)
        Qt.callLater(refresh);
    });
  }

  function pause() {
    runHelperCommand("pause", [], function (success) {
      if (success)
        Qt.callLater(refresh);
    });
  }

  function nextTrack() {
    runHelperCommand("next", [], function (success) {
      if (success)
        Qt.callLater(refresh);
    });
  }

  function previousTrack() {
    runHelperCommand("previous", [], function (success) {
      if (success)
        Qt.callLater(refresh);
    });
  }

  function seek(positionSeconds) {
    runHelperCommand("seek", ["--position", String(positionSeconds)], function (success) {
      if (success) {
        mediaPosition = positionSeconds;
        mediaPositionUpdatedAt = new Date().toISOString();
        Qt.callLater(refresh);
      }
    });
  }

  function mute() {
    runHelperCommand("mute", [], function (success) {
      if (success) {
        isVolumeMuted = true;
        Qt.callLater(refresh);
      }
    });
  }

  function unmute() {
    runHelperCommand("unmute", [], function (success) {
      if (success) {
        isVolumeMuted = false;
        Qt.callLater(refresh);
      }
    });
  }

  function storeVolumeOverride(deviceKey, level) {
    if (!deviceKey)
      return;
    if (!volumeOverrides)
      volumeOverrides = {};
    if (volumeOverrides[deviceKey] === level)
      return;
    const copy = Object.assign({}, volumeOverrides);
    copy[deviceKey] = level;
    volumeOverrides = copy;
    if (pluginApi && pluginApi.pluginSettings) {
      pluginApi.pluginSettings.volumeOverrides = copy;
      pluginApi.saveSettings();
    }
  }

  function getVolumeOverride(deviceKey) {
    if (!volumeOverrides || !deviceKey)
      return null;
    if (!Object.prototype.hasOwnProperty.call(volumeOverrides, deviceKey))
      return null;
    return volumeOverrides[deviceKey];
  }
}
