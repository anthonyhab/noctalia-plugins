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
  property string agentConflictMode: "session"
  property string agentStatus: ""
  property string lastError: ""

  // === STATE MACHINE ===
  property string sessionState: "idle"
  property string closeReason: ""
  property var currentSession: null
  property string currentSessionId: ""
  property var sessionQueue: []
  property bool submitPending: false
  property string pendingSubmitSessionId: ""
  property int retryCount: 0
  property int reconnectDelay: 0
  readonly property int maxReconnectDelay: 3000
  property bool subscribed: false
  property bool providerRegistered: false
  property string providerId: ""
  property bool providerActive: true
  property bool providerActivityKnown: false
  property bool pendingActiveKnown: false
  property string pendingActiveProviderId: ""
  property double lastPongMs: 0
  property int subscribeAttempts: 0
  property int writeFailureCount: 0
  property int parseFailureCount: 0
  readonly property int maxTransientFailures: 3
  property bool isClosingUI: false

  signal sessionReceived()
  signal sessionCompleted(bool success)
  signal sessionRetry()

  function clearError() {
    lastError = ""
  }

  function nowMs() {
    return Date.now()
  }

  function resetConnectionState() {
    subscribed = false
    providerRegistered = false
    providerId = ""
    providerActive = true
    providerActivityKnown = false
    pendingActiveKnown = false
    pendingActiveProviderId = ""
    subscribeAttempts = 0
    writeFailureCount = 0
    parseFailureCount = 0
    subscribeDeadlineTimer.stop()
  }

  function registerProvider() {
    if (!agentSocket.connected) return false
    return sendCommand({
      type: "ui.register",
      name: "polkit-auth",
      kind: "quickshell",
      priority: 100,
      version: agentVersion
    })
  }

  function subscribeToAgent() {
    if (!agentSocket.connected) return false

    const sent = sendCommand({ type: "subscribe" })
    if (sent) {
      subscribeAttempts += 1
      if (!subscribeDeadlineTimer.running) {
        subscribeDeadlineTimer.restart()
      }
    }
    return sent
  }

  function forceReconnect(reason) {
    Logger.w("PolkitAuth", "Forcing reconnect: " + reason)
    agentStatus = "Reconnecting to auth daemon..."

    scheduleReconnect(reason, 100)
  }

  function scheduleReconnect(reason, baseDelay) {
    if (!socketPath) {
      return
    }

    const minDelay = Math.max(baseDelay || 100, 100)
    const attemptDelay = Math.min(Math.max(reconnectDelay || minDelay, minDelay), maxReconnectDelay)

    reconnectTimer.interval = attemptDelay
    reconnectDelay = Math.min(attemptDelay * 2, maxReconnectDelay)

    if (!reconnectTimer.running) {
      reconnectTimer.start()
    }

    if (agentSocket.connected) {
      agentSocket.connected = false
    }

    Logger.d("PolkitAuth", "Reconnect scheduled: " + reason + " in " + attemptDelay + "ms")
  }

  function refresh() {
    checkAgent();
  }

  function checkAgent() {
    if (!socketPath) {
      agentAvailable = false;
      agentStatus = pluginApi?.tr("status.socket-unavailable") ?? "Auth daemon socket not available";
      return;
    }

    if (!agentSocket.connected) {
      agentSocket.connected = true;
      return
    }

    if (!providerRegistered) {
      registerProvider()
    }

    if (!subscribed) {
      subscribeToAgent()
    }
  }

  function sendCommand(message) {
    if (!agentSocket.connected) {
      Logger.w("PolkitAuth", "Cannot send command - not connected");
      return false;
    }
    const data = JSON.stringify(message) + "\n";
    const written = agentSocket.write(data);
    if (written <= 0) {
      writeFailureCount += 1
      Logger.w("PolkitAuth", "Socket write failed for command: " + message.type)

      if (writeFailureCount >= maxTransientFailures) {
        forceReconnect("socket-write-failure")
      }
      return false
    }

    writeFailureCount = 0
    agentSocket.flush();
    return true;
  }

  function setProviderActiveState(nextActive, inactiveStatus) {
    const normalizedActive = !!nextActive
    const changed = !providerActivityKnown || providerActive !== normalizedActive

    providerActive = normalizedActive
    providerActivityKnown = true

    if (providerActive) {
      agentStatus = ""
      if (changed && providerRegistered && agentSocket.connected) {
        subscribeToAgent()
      }
      return
    }

    agentStatus = inactiveStatus || "Another authentication UI is currently active"
    if (changed && currentSession) {
      transitionToIdle("provider-inactive")
    }
  }

  function applyActiveProviderAnnouncement(active, activeId, inactiveStatus) {
    if (!active) {
      if (!providerRegistered) {
        pendingActiveKnown = true
        pendingActiveProviderId = ""
        return
      }

      // No active provider currently announced, remain ready for election.
      setProviderActiveState(true, "")
      pendingActiveKnown = false
      pendingActiveProviderId = ""
      return
    }

    const announcedId = activeId || ""
    if (!providerId) {
      pendingActiveKnown = true
      pendingActiveProviderId = announcedId
      return
    }

    pendingActiveKnown = false
    pendingActiveProviderId = ""
    setProviderActiveState(announcedId === providerId, inactiveStatus || "Another authentication UI is currently active")
  }

  function handleMessage(response) {
    if (!response) return;

    parseFailureCount = 0

    if (providerRegistered && providerActivityKnown && !providerActive &&
        (response.type === "session.created" || response.type === "session.updated" || response.type === "session.closed")) {
      Logger.d("PolkitAuth", "Ignoring session event while inactive provider")
      return
    }

    switch (response.type) {
      case "subscribed":
        Logger.d("PolkitAuth", "Subscribed, active sessions: " + response.sessionCount);
        subscribed = true;
        agentAvailable = true;
        reconnectDelay = 0;
        subscribeAttempts = 0
        subscribeDeadlineTimer.stop()
        if (response.active !== undefined) {
          setProviderActiveState(!!response.active, "Another authentication UI is currently active")
        }
        break;

      case "pong":
        agentAvailable = true;
        lastPongMs = nowMs()
        if (response.version) agentVersion = response.version;
        if (response.bootstrap && response.bootstrap.mode) {
          agentConflictMode = response.bootstrap.mode
        }
        if (response.provider) {
          const activeProviderId = response.provider.id || ""
          applyActiveProviderAnnouncement(true, activeProviderId, "Fallback auth UI is active")
        } else if (providerRegistered) {
          applyActiveProviderAnnouncement(false, "", "")
        }
        break;

      case "ui.registered":
        providerRegistered = true
        providerId = response.id || providerId
        if (response.active !== undefined) {
          setProviderActiveState(!!response.active, "Another authentication UI is currently active")
        } else if (pendingActiveKnown) {
          if (pendingActiveProviderId.length > 0) {
            setProviderActiveState(pendingActiveProviderId === providerId, "Another authentication UI is currently active")
          } else {
            setProviderActiveState(true, "")
          }
        } else {
          setProviderActiveState(true, "")
        }

        pendingActiveKnown = false
        pendingActiveProviderId = ""
        break;

      case "ui.active": {
        const active = !!response.active
        const activeId = (response.id || "")
        applyActiveProviderAnnouncement(active, activeId, "Another authentication UI is currently active")
        break;
      }

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
        if (submitPending) {
          submitPending = false
          if (currentSession && currentSession.id === pendingSubmitSessionId && sessionState === "submitting") {
            sessionState = "verifying"
            lastError = ""
          }
          pendingSubmitSessionId = ""
        }
        break;

      case "error":
        Logger.e("PolkitAuth", "Agent error: " + response.message);
        if (response.message === "Provider not registered") {
          providerRegistered = false
          registerProvider()
        } else if (response.message === "Not active UI provider") {
          setProviderActiveState(false, "Another authentication UI is currently active")
        }
        if (submitPending || sessionState === "submitting" || sessionState === "verifying") {
          submitPending = false
          pendingSubmitSessionId = ""
          sessionState = "prompting"
          lastError = response.message || (pluginApi?.tr("errors.agent-failed") ?? "Authentication error")
        }
        break;

      default:
        Logger.w("PolkitAuth", "Unknown message type: " + response.type);
    }
  }

  function handleSessionCreated(event) {
    Logger.d("PolkitAuth", "Session created: " + event.id + " source: " + event.source);

    if (currentSession && currentSession.id === event.id) {
      Logger.d("PolkitAuth", "Ignoring duplicate create for active session: " + event.id)
      return
    }

    if (findQueuedSessionIndex(event.id) !== -1) {
      Logger.d("PolkitAuth", "Ignoring duplicate create for queued session: " + event.id)
      return
    }

    var session = {
      id: event.id,
      source: event.source,
      message: event.context.message || "",
      actionId: event.context.actionId || "",
      user: event.context.user || "",
      details: event.context.details || {},
      requestor: event.context.requestor || {},
      keyringName: event.context.keyringName || "",
      description: event.context.description || "",
      keyinfo: event.context.keyinfo || "",
      curRetry: event.context.curRetry || 0,
      maxRetries: event.context.maxRetries || 3,
      confirmOnly: event.context.confirmOnly || false,
      repeat: event.context.repeat || false,
      error: "",
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
      const queuedIdx = findQueuedSessionIndex(event.id)
      if (queuedIdx !== -1) {
        const queued = sessionQueue[queuedIdx]
        if (event.curRetry !== undefined) {
          queued.curRetry = event.curRetry
        }
        if (event.maxRetries !== undefined) {
          queued.maxRetries = event.maxRetries
        }
        if (event.prompt) {
          queued.prompt = event.prompt
          queued.echo = event.echo !== undefined ? event.echo : true
        }
        if (event.error) {
          queued.error = event.error
        }
        sessionQueue[queuedIdx] = queued
        return
      }

      if (pendingSubmitSessionId === event.id) {
        submitPending = false
        pendingSubmitSessionId = ""
        sessionState = "prompting"
        if (event.error) {
          lastError = event.error
        }
        Logger.w("PolkitAuth", "Recovered non-current session update for pending submit: " + event.id)
        return
      }

      Logger.w("PolkitAuth", "Update for unknown session: " + event.id);
      return;
    }

    if (event.prompt) {
      currentSession.prompt = event.prompt;
      currentSession.echo = event.echo !== undefined ? event.echo : true;
    }
    if (event.curRetry !== undefined) {
      currentSession.curRetry = event.curRetry;
    }
    if (event.maxRetries !== undefined) {
      currentSession.maxRetries = event.maxRetries;
    }

    if (event.error) {
      submitPending = false
      pendingSubmitSessionId = ""
      const shouldNotifyRetry = (sessionState === "verifying" || sessionState === "submitting" || lastError !== event.error)
      currentSession.error = event.error
      lastError = event.error;
      sessionState = "prompting";
      if (shouldNotifyRetry) {
        retryCount++;
        sessionRetry();
        Logger.d("PolkitAuth", "Retry #" + retryCount + ": " + event.error);
      }
    } else if (sessionState === "verifying" || sessionState === "submitting") {
      sessionState = "prompting";
    }

    currentSessionChanged();
  }

  function handleSessionClosed(event) {
    if (!currentSession || currentSession.id !== event.id) {
      const queuedIdx = findQueuedSessionIndex(event.id)
      if (queuedIdx !== -1) {
        sessionQueue.splice(queuedIdx, 1)
        Logger.d("PolkitAuth", "Dropped closed queued session: " + event.id)
        return
      }

      if (pendingSubmitSessionId === event.id) {
        const result = (event.result || "").toString()
        const wasSuccess = result === "success"
        const wasCancelled = result === "cancelled" || result === "canceled"

        submitPending = false
        pendingSubmitSessionId = ""

        if (wasSuccess) {
          sessionState = "success"
          closeReason = "success"
          if (autoCloseOnSuccess) {
            if (closeInstantly) {
              transitionToIdle("success")
            } else if (showSuccessAnimation) {
              successTimer.restart()
            } else {
              transitionToIdle("success")
            }
          }
        } else {
          closeReason = wasCancelled ? "cancelled" : "error"
          if (!wasCancelled) {
            lastError = event.error || (pluginApi?.tr("errors.auth-failed") ?? "Authentication failed")
          }
          sessionState = "idle"
          if (wasCancelled && autoCloseOnCancel) {
            transitionToIdle("cancelled")
          }
        }

        Logger.w("PolkitAuth", "Recovered non-current session close for pending submit: " + event.id)
        return
      }

      Logger.w("PolkitAuth", "Close for unknown session: " + event.id);
      return;
    }

    const result = (event.result || "").toString()
    const wasSuccess = result === "success"
    const wasCancelled = result === "cancelled" || result === "canceled"

    submitPending = false
    pendingSubmitSessionId = ""

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
    submitPending = false
    pendingSubmitSessionId = ""
    successTimer.stop()

    const isRetry = (session.curRetry || 0) > 0
    if (!isRetry) {
      lastError = ""
    } else if (session.error) {
      lastError = session.error
    }
    retryCount = 0;
    sessionReceived();
    
    if (autoOpenPanel) {
      openPanelTimer.restart();
    }
  }

  function submitPassword(password) {
    if (!currentSession || sessionState !== "prompting" || submitPending) return;

    const sent = sendCommand({
      type: "session.respond",
      id: currentSession.id,
      response: password
    });

    if (sent) {
      submitPending = true
      pendingSubmitSessionId = currentSession.id
      sessionState = "submitting"
      lastError = ""
      return
    }

    submitPending = false
    pendingSubmitSessionId = ""
    sessionState = "prompting"
    lastError = pluginApi?.tr("errors.agent-failed") ?? "Authentication error"
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

  function findQueuedSessionIndex(id) {
    for (var i = 0; i < sessionQueue.length; i++) {
      if (sessionQueue[i].id === id) {
        return i
      }
    }
    return -1
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
      submitPending = false;
      pendingSubmitSessionId = "";
      lastError = "";
      closeReason = "";
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
      if (agentSocket.connected) {
        if (!providerRegistered) {
          registerProvider()
        }
        if (!subscribed) {
          subscribeToAgent()
        }
        sendCommand({ type: "ping" });
      } else {
        checkAgent();
      }
    }
  }

  Timer {
    id: subscribeWatchdogTimer
    interval: 1200
    repeat: true
    running: agentSocket.connected && (!providerRegistered || !subscribed)
    onTriggered: {
      if (!agentSocket.connected) return
      if (!providerRegistered) {
        registerProvider()
      }
      if (!subscribed) {
        subscribeToAgent()
      }
    }
  }

  Timer {
    id: subscribeDeadlineTimer
    interval: 6000
    repeat: false
    onTriggered: {
      if (agentSocket.connected && (!providerRegistered || !subscribed)) {
        forceReconnect("subscribe-timeout")
      }
    }
  }

  Timer {
    id: providerHeartbeatTimer
    interval: 4000
    repeat: true
    running: agentSocket.connected && providerRegistered
    onTriggered: {
      if (!agentSocket.connected || !providerRegistered) return
      sendCommand({ type: "ui.heartbeat", id: providerId })
    }
  }

  Timer {
    id: livenessTimer
    interval: 2000
    repeat: true
    running: true
    onTriggered: {
      if (!agentSocket.connected || !subscribed) return
      if (lastPongMs <= 0) return

      if ((nowMs() - lastPongMs) > 12000) {
        forceReconnect("pong-timeout")
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
    running: sessionState === "prompting" || sessionState === "submitting" || sessionState === "error" || sessionState === "verifying"
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

    onConnectionStateChanged: {
      if (connected) {
        Logger.d("PolkitAuth", "Connected to agent, subscribing...");
        reconnectTimer.stop()
        reconnectDelay = 0
        resetConnectionState()
        agentAvailable = true
        agentStatus = ""
        lastPongMs = nowMs()
        registerProvider()
        subscribeToAgent()
      } else {
        Logger.w("PolkitAuth", "Disconnected from agent");
        agentAvailable = false;
        resetConnectionState()
        agentStatus = pluginApi?.tr("status.agent-unavailable") ?? "Auth daemon not reachable"
        scheduleReconnect("socket-disconnected", 100)
      }
    }

    onError: function(error) {
      Logger.w("PolkitAuth", "Socket error: " + error)
      agentAvailable = false
      scheduleReconnect("socket-error", 150)
    }

    parser: SplitParser {
      onRead: function(line) {
        const response = (line || "").trim();
        if (!response) return;

        try {
          const parsed = JSON.parse(response);
          handleMessage(parsed);
        } catch (e) {
          parseFailureCount += 1
          Logger.e("PolkitAuth", "Failed to parse: " + e);

          if (parseFailureCount >= maxTransientFailures) {
            forceReconnect("socket-parse-failure")
          }
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
      busy: root.sessionState === "verifying" || root.sessionState === "submitting"
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
