import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // Settings getter with fallback to manifest defaults and error handling
  function getSetting(key, fallback) {
    if (!pluginApi) return fallback;
    try {
      const userVal = pluginApi?.pluginSettings?.[key];
      if (userVal !== undefined && userVal !== null) return userVal;
      const defaultVal = pluginApi?.manifest?.metadata?.defaultSettings?.[key];
      if (defaultVal !== undefined && defaultVal !== null) return defaultVal;
      return fallback;
    } catch (e) {
      Logger.e("PolkitAuth", "Error accessing plugin settings:", e);
      return fallback;
    }
  }

  readonly property bool autoOpenPanel: true
  readonly property bool autoCloseOnSuccess: true
  readonly property bool autoCloseOnCancel: true
  readonly property bool showSuccessAnimation: true
  readonly property string settingsPanelMode: getSetting("settingsPanelMode", "centered")
  readonly property bool showDetailsByDefault: getSetting("showDetailsByDefault", false)
  readonly property bool closeInstantly: getSetting("closeInstantly", false)
  readonly property int successAnimationDuration: closeInstantly ? 0 : 300

  readonly property string socketPath: {
    const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
    return runtimeDir && runtimeDir.length > 0
      ? (runtimeDir + "/noctalia-auth.sock")
      : "";
  }

  property bool agentAvailable: false
  property string agentVersion: "1.0"
  property string agentStatus: ""
  property string lastError: ""

  // === STATE MACHINE ===
  property string sessionState: "idle"
  property string closeReason: ""
  property var currentSession: null
  property string currentSessionId: ""
  property var sessionQueue: []
  property bool sessionInFlight: false
  property int retryCount: 0
  property int reconnectDelay: 0
  readonly property int maxReconnectDelay: 3000
  property bool subscribed: false
  property bool userRequestedClose: false
  property bool isClosingUI: false

  signal sessionReceived()
  signal sessionCompleted(bool success)
  signal sessionRetry()

  function clearError() {
    lastError = ""
  }

  function refresh() {
    checkAgent();
  }

  function checkAgent() {
    if (!socketPath) {
      agentAvailable = false;
      agentStatus = pluginApi?.tr("status.socket-unavailable") ?? "Polkit agent socket not available";
      return;
    }

    if (!agentSocket.connected) {
      agentSocket.connected = true;
    }
  }

  function sendCommand(message) {
    if (!agentSocket.connected) {
      Logger.w("PolkitAuth", "Cannot send command - not connected");
      return false;
    }
    const data = JSON.stringify(message) + "\n";
    agentSocket.write(data);
    agentSocket.flush();
    return true;
  }

  function handleMessage(response) {
    if (!response) return;

    switch (response.type) {
      case "subscribed":
        Logger.d("PolkitAuth", "Subscribed, active sessions: " + response.sessionCount);
        subscribed = true;
        agentAvailable = true;
        reconnectDelay = 0;
        break;

      case "pong":
        agentAvailable = true;
        if (response.version) agentVersion = response.version;
        break;

      case "session.created":
        handleSessionCreated(response);
        break;

      case "session.updated":
        handleSessionUpdated(response);
        break;

      case "session.closed":
        handleSessionClosed(response);
        break;

      case "ok":
        break;

      case "error":
        Logger.e("PolkitAuth", "Agent error: " + response.message);
        break;

      default:
        Logger.w("PolkitAuth", "Unknown message type: " + response.type);
    }
  }

  function handleSessionCreated(event) {
    Logger.d("PolkitAuth", "Session created: " + event.id + " source: " + event.source);

    var session = {
      id: event.id,
      source: event.source,
      message: event.context.message || "",
      actionId: event.context.actionId || "",
      user: event.context.user || "",
      requestor: event.context.requestor || {},
      description: event.context.description || "",
      curRetry: event.context.curRetry || 0,
      maxRetries: event.context.maxRetries || 3,
      confirmOnly: event.context.confirmOnly || false,
      prompt: "",
      echo: true
    };

    if (currentSession) {
      sessionQueue.push(session);
      Logger.d("PolkitAuth", "Queued session, queue length: " + sessionQueue.length);
    } else {
      activateSession(session);
    }
  }

  function handleSessionUpdated(event) {
    if (!currentSession || currentSession.id !== event.id) {
      Logger.w("PolkitAuth", "Update for unknown session: " + event.id);
      return;
    }

    if (event.prompt) {
      currentSession.prompt = event.prompt;
      currentSession.echo = event.echo !== undefined ? event.echo : true;
    }

    if (event.error) {
      lastError = event.error;
      sessionState = "prompting";
      retryCount++;
      sessionRetry();
      Logger.d("PolkitAuth", "Retry #" + retryCount + ": " + event.error);
    } else if (sessionState === "verifying") {
      sessionState = "prompting";
    }

    currentSessionChanged();
  }

  function handleSessionClosed(event) {
    if (!currentSession || currentSession.id !== event.id) {
      Logger.w("PolkitAuth", "Close for unknown session: " + event.id);
      return;
    }

    const result = (event.result || "").toString()
    const wasSuccess = result === "success"
    const wasCancelled = result === "cancelled" || result === "canceled"

    Logger.d("PolkitAuth", "Session closed: " + result);

    if (wasSuccess) {
      sessionState = "success";
      closeReason = "success";
    } else {
      closeReason = wasCancelled ? "cancelled" : "error";
      if (wasCancelled) {
        lastError = "Cancelled";
      } else if (event.error) {
        lastError = event.error;
      } else {
        lastError = pluginApi?.tr("errors.auth-failed") ?? "Authentication failed";
      }
    }

    sessionCompleted(wasSuccess);

    if (wasSuccess) {
      if (!autoCloseOnSuccess) return
      if (closeInstantly) {
        transitionToIdle("success");
      } else if (showSuccessAnimation) {
        successTimer.restart()
      } else {
        transitionToIdle("success")
      }
      return
    }

    // Session is closed and won't accept further input. If the agent immediately creates a new
    // session (common for retries), switch to it without closing the UI to avoid flicker.
    currentSession = null
    currentSessionId = ""

    if (sessionQueue.length > 0) {
      advanceSessionQueue()
      return
    }

    sessionState = "idle"

    if (wasCancelled && autoCloseOnCancel) {
      transitionToIdle("cancelled")
    }
  }

  function activateSession(session) {
    closeReason = "";
    currentSession = session;
    currentSessionId = session.id;
    sessionState = "prompting";
    successTimer.stop()

    const isRetry = (session.curRetry || 0) > 0
    if (!isRetry) lastError = "";
    retryCount = 0;
    sessionReceived();
    
    if (autoOpenPanel) {
      openPanelTimer.restart();
    }
  }

  function submitPassword(password) {
    if (!currentSession || sessionState !== "prompting") return;

    sessionState = "verifying";
    lastError = ""

    sendCommand({
      type: "session.respond",
      id: currentSession.id,
      response: password
    });
  }

  function cancelSession() {
    if (!currentSession) return;

    sendCommand({
      type: "session.cancel",
      id: currentSession.id
    });
  }

  function advanceSessionQueue() {
    if (sessionQueue.length === 0) {
      currentSession = null;
      currentSessionId = "";
      sessionState = "idle";
      return;
    }

    const nextSession = sessionQueue[0];
    sessionQueue = sessionQueue.slice(1);
    activateSession(nextSession);
  }

  function openAuthUI() {
    if (!currentSession) return;

    if (settingsPanelMode === "window") {
      authWindow.visible = true;
    } else {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(function(screen) {
        pluginApi.openPanel(screen);
      });
    }
  }

  function closeAuthUI(reason) {
    if (settingsPanelMode === "window") {
      authWindow.visible = false;
    } else {
      pluginApi?.withCurrentScreen(function(screen) {
        pluginApi?.closePanel(screen);
      });
    }
  }

  function requestClose() {
    if (!currentSession) {
      closeAuthUI("user-close");
      return;
    }
    cancelSession();
  }

  function transitionToIdle(reason) {
    Logger.d("PolkitAuth", "Transition to idle: " + reason);
    isClosingUI = true;
    closeAuthUI(reason);
    // Delay state cleanup until after close animation completes
    cleanupTimer.start();
  }

  Timer {
    id: reconnectTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (!agentSocket.connected && socketPath) {
        Logger.d("PolkitAuth", "Reconnecting... (delay: " + reconnectDelay + "ms)");
        agentSocket.connected = true;
      }
    }
  }

  Timer {
    id: successTimer
    interval: root.successAnimationDuration
    repeat: false
    onTriggered: transitionToIdle("success")
  }

  Timer {
    id: cleanupTimer
    interval: Style.animationNormal || 300  // Match close animation duration
    repeat: false
    onTriggered: {
      currentSession = null;
      currentSessionId = "";
      sessionState = "idle";
      lastError = "";
      closeReason = "";
      userRequestedClose = false;
      isClosingUI = false;
      advanceSessionQueue();
    }
  }

  Timer {
    id: pingTimer
    interval: 3000
    repeat: true
    running: true
    onTriggered: {
      if (agentSocket.connected && subscribed) {
        sendCommand({ type: "ping" });
      } else {
        checkAgent();
      }
    }
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
    repeat: false
    running: sessionState === "prompting" || sessionState === "error" || sessionState === "verifying"
    onTriggered: {
      Logger.w("PolkitAuth", "Session timed out in state: " + sessionState);
      closeReason = "timeout";
      transitionToIdle("timeout");
    }
  }

  onSessionStateChanged: {
    if (sessionState !== "idle" && sessionState !== "success") {
        staleRequestTimer.restart();
    } else {
        staleRequestTimer.stop();
    }
  }

  Socket {
    id: agentSocket
    path: root.socketPath
    connected: false

    onConnectedChanged: {
      if (connected) {
        Logger.d("PolkitAuth", "Connected to agent, subscribing...");
        subscribed = false;
        sendCommand({ type: "subscribe" });
      } else {
        Logger.w("PolkitAuth", "Disconnected from agent");
        agentAvailable = false;
        subscribed = false;

        // Exponential backoff reconnection
        reconnectTimer.interval = Math.min(
          reconnectDelay || 100,
          maxReconnectDelay
        );
        reconnectDelay = Math.min(reconnectDelay * 2 || 100, maxReconnectDelay);
        reconnectTimer.start();
      }
    }

    parser: SplitParser {
      onRead: function(line) {
        const response = (line || "").trim();
        if (!response) return;

        try {
          const parsed = JSON.parse(response);
          handleMessage(parsed);
        } catch (e) {
          Logger.e("PolkitAuth", "Failed to parse: " + e);
        }
      }
    }
  }

  FloatingWindow {
    id: authWindow
    title: "Authentication Required"
    visible: false
    color: Color.mSurface

    readonly property int windowWidth: Math.round(420 * Style.uiScaleRatio)
    readonly property int windowHeight: Math.round(450 * Style.uiScaleRatio)

    implicitWidth: windowWidth
    implicitHeight: windowHeight
    minimumSize: Qt.size(windowWidth, windowHeight)

    AuthContent {
      id: floatingAuthContent
      anchors.fill: parent
      pluginMain: root
      incomingSession: root.currentSession
      busy: root.sessionState === "verifying"
      agentAvailable: root.agentAvailable
      statusText: root.agentStatus
      errorText: root.lastError
      onCloseRequested: root.requestClose()
    }
  }

  Component.onCompleted: {
    if (!pluginApi) {
      Logger.e("PolkitAuth", "Plugin initialized without API");
      Qt.callLater(refresh);
    } else {
      Logger.d("PolkitAuth", "Plugin initialized successfully with API");
      refresh();
    }
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      refresh();
    }
  }
}
