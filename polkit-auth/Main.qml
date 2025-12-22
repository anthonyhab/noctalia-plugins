import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // Settings getter with fallback to manifest defaults
  function getSetting(key, fallback) {
    const userVal = pluginApi?.pluginSettings?.[key];
    if (userVal !== undefined && userVal !== null) return userVal;
    const defaultVal = pluginApi?.manifest?.metadata?.defaultSettings?.[key];
    if (defaultVal !== undefined && defaultVal !== null) return defaultVal;
    return fallback;
  }

  readonly property int pollInterval: getSetting("pollInterval", 100)
  readonly property bool autoOpenPanel: getSetting("autoOpenPanel", true)
  readonly property bool autoCloseOnSuccess: getSetting("autoCloseOnSuccess", true)
  readonly property bool autoCloseOnCancel: getSetting("autoCloseOnCancel", true)
  readonly property string displayMode: getSetting("displayMode", "floating")

  readonly property string socketPath: {
    const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
    return runtimeDir && runtimeDir.length > 0
      ? (runtimeDir + "/noctalia-polkit-agent.sock")
      : "";
  }

  property bool agentAvailable: false
  property string agentStatus: ""
  property string lastError: ""

  property var currentRequest: null
  property var requestQueue: []
  property bool requestInFlight: false
  property bool responseInFlight: false
  property string pendingPassword: ""
  property var socketQueue: []
  property var pendingSocketRequest: null
  property bool socketBusy: false
  property bool socketResponseReceived: false

  signal requestReceived()
  signal requestCompleted(bool success)

  function refresh() {
    checkAgent();
  }

  function checkAgent() {
    if (!socketPath) {
      agentAvailable = false;
      agentStatus = pluginApi?.tr("status.socket-unavailable") || "Polkit agent socket not available";
      return;
    }

    enqueueSocketCommand("PING", "", function(ok, response) {
      if (ok && response === "PONG") {
        agentAvailable = true;
        agentStatus = "";
      } else {
        agentAvailable = false;
        agentStatus = pluginApi?.tr("status.agent-unavailable") || "Polkit agent not reachable";
      }
    });
  }

  function pollRequests() {
    if (!agentAvailable)
      return;

    if (requestInFlight) {
      pollRetryTimer.restart();
      return;
    }

    requestInFlight = true;
    enqueueSocketCommand("NEXT", "", function(ok, response) {
      requestInFlight = false;

      if (!ok) {
        pollRetryTimer.restart();
        return;
      }

      const output = (response || "").trim();
      if (!output) {
        return;
      }

      let payload = null;
      try {
        payload = JSON.parse(output);
      } catch (e) {
        Logger.e("PolkitAuth", "Failed to parse agent payload:", e);
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
    });
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
    if (!currentRequest || responseInFlight)
      return;

    responseInFlight = true;
    lastError = "";
    pendingPassword = password;

    enqueueSocketCommand("RESPOND " + currentRequest.id, password, function(ok, response) {
      responseInFlight = false;
      pendingPassword = "";

      if (!ok || response !== "OK") {
        lastError = pluginApi?.tr("errors.auth-failed") || "Authentication failed";
      }

      Qt.callLater(pollImmediately);
    });
  }

  function cancelRequest() {
    if (!currentRequest)
      return;

    if (responseInFlight) {
      lastError = pluginApi?.tr("errors.busy") || "Please wait...";
      return;
    }

    responseInFlight = true;
    lastError = "";

    enqueueSocketCommand("CANCEL " + currentRequest.id, "", function(ok, response) {
      responseInFlight = false;

      if (!ok || response !== "OK") {
        lastError = pluginApi?.tr("errors.cancel-failed") || "Failed to cancel request";
        Qt.callLater(pollImmediately);
        return;
      }

      Qt.callLater(pollImmediately);
    });
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

  function enqueueSocketCommand(command, payload, onResponse) {
    if (!socketPath) {
      onResponse?.(false, "");
      return;
    }

    socketQueue = socketQueue.concat([{ command: command, payload: payload, onResponse: onResponse }]);
    startNextSocketCommand();
  }

  function startNextSocketCommand() {
    if (socketBusy || socketQueue.length === 0)
      return;

    pendingSocketRequest = socketQueue[0];
    socketQueue = socketQueue.slice(1);
    socketBusy = true;
    socketResponseReceived = false;
    agentSocket.connected = true;
    socketTimeout.restart();
  }

  function finishSocketCommand(ok, response) {
    socketTimeout.stop();
    socketResponseReceived = true;
    agentSocket.connected = false;
    socketBusy = false;
    const cb = pendingSocketRequest?.onResponse;
    pendingSocketRequest = null;
    cb?.(ok, response || "");
    Qt.callLater(startNextSocketCommand);
  }

  Socket {
    id: agentSocket
    path: root.socketPath
    connected: false

    onConnectedChanged: {
      if (connected) {
        if (!pendingSocketRequest) {
          connected = false;
          return;
        }

        let data = pendingSocketRequest.command + "\n";
        if (pendingSocketRequest.payload && pendingSocketRequest.payload.length > 0) {
          data += pendingSocketRequest.payload + "\n";
        }
        write(data);
        flush();
        return;
      }

      if (socketBusy && !socketResponseReceived) {
        finishSocketCommand(false, "");
      }
    }

    parser: SplitParser {
      onRead: function(line) {
        const response = (line || "").trim();
        finishSocketCommand(true, response);
      }
    }
  }

  Timer {
    id: socketTimeout
    interval: 1000
    repeat: false
    onTriggered: {
      if (socketBusy && !socketResponseReceived) {
        finishSocketCommand(false, "");
      }
    }
  }

  // Floating window mode
  FloatingWindow {
    id: authWindow
    title: "Authentication Required"
    visible: false
    color: Color.mSurface

    width: Math.round(420 * Style.uiScaleRatio)
    height: Math.round(480 * Style.uiScaleRatio)

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
