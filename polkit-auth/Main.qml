import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // Helper to get setting with fallback to manifest defaults
  function getSetting(key, fallback) {
    const userVal = pluginApi?.pluginSettings?.[key];
    if (userVal !== undefined && userVal !== null) return userVal;
    const defaultVal = pluginApi?.manifest?.metadata?.defaultSettings?.[key];
    if (defaultVal !== undefined && defaultVal !== null) return defaultVal;
    return fallback;
  }

  readonly property string helperPath: getSetting("helperPath", "")
  readonly property int pollInterval: getSetting("pollInterval", 100)
  readonly property bool autoOpenPanel: getSetting("autoOpenPanel", true)
  readonly property bool autoCloseOnSuccess: getSetting("autoCloseOnSuccess", true)
  readonly property bool autoCloseOnCancel: getSetting("autoCloseOnCancel", true)
  readonly property string displayMode: getSetting("displayMode", "floating")

  property bool agentAvailable: false
  property string agentStatus: ""
  property string lastError: ""

  property var currentRequest: null
  property var requestQueue: []
  property bool requestInFlight: false
  property bool responseInFlight: false
  property string pendingPassword: ""

  signal requestReceived()
  signal requestCompleted(bool success)

  function refresh() {
    checkAgent();
  }

  function checkAgent() {
    if (!helperPath) {
      agentAvailable = false;
      agentStatus = pluginApi?.tr("status.missing-helper") || "Helper path not configured";
      return;
    }

    if (pingProcess.running)
      return;

    pingProcess.command = [helperPath, "--ping"];
    pingProcess.running = true;
  }

  function pollRequests() {
    if (!agentAvailable || !helperPath)
      return;

    if (requestInFlight) {
      pollRetryTimer.restart();
      return;
    }

    requestInFlight = true;
    pollProcess.command = [helperPath, "--next"];
    pollProcess.running = true;
  }

  function pollImmediately() {
    if (agentAvailable && !requestInFlight) {
      pollRequests();
    }
  }

  function clearStaleState() {
    if (currentRequest && !responseInFlight) {
      currentRequest = null;
      requestQueue = [];
      lastError = "";
    }
  }

  function enqueueRequest(request) {
    if (!request || !request.id)
      return;

    const isDuplicate = requestQueue.some(r => r.id === request.id) ||
                        (currentRequest && currentRequest.id === request.id);
    if (isDuplicate) {
      if (currentRequest && currentRequest.id === request.id) {
        currentRequest = request;
      }
      return;
    }

    requestQueue = requestQueue.concat([request]);
    requestReceived();

    if (!currentRequest)
      advanceQueue();
  }

  function advanceQueue() {
    if (requestQueue.length === 0) {
      currentRequest = null;
      return;
    }

    const nextRequest = requestQueue[0];
    requestQueue = requestQueue.slice(1);
    lastError = "";
    currentRequest = nextRequest;

    if (autoOpenPanel && currentRequest) {
      openPanelTimer.restart();
    }
  }

  function openAuthUI() {
    if (!currentRequest)
      return;

    if (displayMode === "floating") {
      authWindow.visible = true;
    } else {
      pluginApi?.withCurrentScreen(function(screen) {
        pluginApi?.openPanel(screen);
      });
    }
  }

  function closeAuthUI() {
    if (displayMode === "floating") {
      authWindow.visible = false;
    } else {
      pluginApi?.withCurrentScreen(function(screen) {
        pluginApi?.closePanel(screen);
      });
    }
  }

  function submitPassword(password) {
    if (!currentRequest || responseInFlight || !helperPath)
      return;

    responseInFlight = true;
    lastError = "";
    pendingPassword = password;

    respondProcess.command = [helperPath, "--respond", currentRequest.id];
    respondProcess.stdinEnabled = true;
    respondProcess.running = true;
  }

  function cancelRequest() {
    if (!currentRequest || !helperPath)
      return;

    if (responseInFlight) {
      lastError = pluginApi?.tr("errors.busy") || "Please wait...";
      return;
    }

    responseInFlight = true;
    lastError = "";

    cancelProcess.command = [helperPath, "--cancel", currentRequest.id];
    cancelProcess.running = true;
  }

  function handleRequestComplete(requestId, success, wasCancelled) {
    if (currentRequest && currentRequest.id === requestId) {
      currentRequest = null;
      requestCompleted(success);

      if (success) {
        lastError = "";
        if (autoCloseOnSuccess) {
          closeAuthUI();
        }
      } else if (wasCancelled) {
        lastError = "";
        if (autoCloseOnCancel) {
          closeAuthUI();
        }
      }
      // On failure (!success && !wasCancelled): keep window/panel open with error, but request is done

      advanceQueue();
    } else {
      requestQueue = requestQueue.filter(r => r.id !== requestId);
    }
  }

  Timer {
    id: pollTimer
    interval: Math.max(50, root.pollInterval)
    repeat: true
    running: agentAvailable
    onTriggered: pollRequests()
  }

  Timer {
    id: pollRetryTimer
    interval: 50
    repeat: false
    running: false
    onTriggered: pollRequests()
  }

  Timer {
    id: pingTimer
    interval: 3000
    repeat: true
    running: true
    onTriggered: checkAgent()
  }

  Timer {
    id: openPanelTimer
    interval: 16
    repeat: false
    running: false
    onTriggered: openAuthUI()
  }

  Timer {
    id: staleRequestTimer
    interval: 30000
    repeat: true
    running: currentRequest !== null && !responseInFlight
    onTriggered: {
      if (currentRequest && !responseInFlight) {
        Logger.w("PolkitAuth", "Request timed out, clearing stale state");
        clearStaleState();
      }
    }
  }

  onAgentAvailableChanged: {
    if (agentAvailable) {
      Qt.callLater(pollImmediately);
    }
  }

  Process {
    id: pingProcess
    running: false
    stdout: StdioCollector {}
    onExited: function(code) {
      const wasAvailable = agentAvailable;
      if (code === 0) {
        agentAvailable = true;
        agentStatus = "";
      } else {
        agentAvailable = false;
        const output = (stdout.text || "").trim();
        agentStatus = output || (pluginApi?.tr("status.agent-unavailable") || "Polkit agent not reachable");
      }
    }
  }

  Process {
    id: pollProcess
    running: false
    stdout: StdioCollector {}
    onExited: function(code) {
      requestInFlight = false;

      if (code !== 0) {
        pollRetryTimer.restart();
        return;
      }

      const output = (stdout.text || "").trim();
      if (!output) {
        return;
      }

      let payload = null;
      try {
        payload = JSON.parse(output);
      } catch (e) {
        Logger.e("PolkitAuth", "Failed to parse helper payload:", e);
        return;
      }

      if (payload.type === "request") {
        enqueueRequest(payload);
        Qt.callLater(pollImmediately);
      } else if (payload.type === "update") {
        if (payload.error) {
          lastError = payload.error;
        }
        if (payload.id && currentRequest && currentRequest.id === payload.id) {
          if (payload.prompt) {
            currentRequest = Object.assign({}, currentRequest, { prompt: payload.prompt });
          }
        }
        Qt.callLater(pollImmediately);
      } else if (payload.type === "complete") {
        const isSuccess = payload.result === "success";
        const isCancelled = payload.result === "cancelled";
        handleRequestComplete(payload.id, isSuccess, isCancelled);
        Qt.callLater(pollImmediately);
      }
    }
  }

  Process {
    id: respondProcess
    running: false
    stdout: StdioCollector {}
    onStarted: {
      if (pendingPassword !== "") {
        write(pendingPassword + "\n");
        pendingPassword = "";
        closeStdinTimer.restart();
      } else {
        stdinEnabled = false;
      }
    }
    onExited: function(code) {
      responseInFlight = false;
      pendingPassword = "";
      closeStdinTimer.stop();

      if (code !== 0) {
        lastError = pluginApi?.tr("errors.auth-failed") || "Authentication failed";
      }

      Qt.callLater(pollImmediately);
    }
  }

  Timer {
    id: closeStdinTimer
    interval: 50
    repeat: false
    onTriggered: {
      respondProcess.stdinEnabled = false;
    }
  }

  Process {
    id: cancelProcess
    running: false
    stdout: StdioCollector {}
    onExited: function(code) {
      responseInFlight = false;

      if (code !== 0) {
        lastError = pluginApi?.tr("errors.cancel-failed") || "Failed to cancel request";
        Qt.callLater(pollImmediately);
        return;
      }

      Qt.callLater(pollImmediately);
    }
  }

  // Floating window mode
  FloatingWindow {
    id: authWindow
    title: "Authentication Required"
    visible: false
    color: Color.mSurface

    implicitWidth: Math.round(420 * Style.uiScaleRatio)
    implicitHeight: Math.round(400 * Style.uiScaleRatio)

    AuthContent {
      id: floatingAuthContent
      anchors.fill: parent
      pluginMain: root
      request: root.currentRequest
      busy: root.responseInFlight
      agentAvailable: root.agentAvailable
      statusText: root.agentStatus
      errorText: root.lastError
      onCloseRequested: authWindow.visible = false
    }
  }

  Component.onCompleted: {
    refresh();
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      refresh();
    }
  }
}
