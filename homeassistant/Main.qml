import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // Connection settings (from pluginSettings)
  readonly property string haUrl: pluginApi?.pluginSettings?.haUrl || ""
  readonly property string haToken: pluginApi?.pluginSettings?.haToken || ""
  readonly property string defaultMediaPlayer: pluginApi?.pluginSettings?.defaultMediaPlayer || ""

  // Connection state
  property bool connected: false
  property bool connecting: false
  property string connectionError: ""

  // HTTP request tracking
  property int requestId: 0
  property bool stateFetchInFlight: false
  property bool discoveryFetchInFlight: false
  property int consecutiveStateFetchFailures: 0
  readonly property int pollIntervalPlayingMs: 5000
  readonly property int pollIntervalIdleMs: 15000
  readonly property int pollIntervalMaxBackoffMs: 30000
  readonly property int discoveryPollIntervalMs: 90000
  property int currentPollIntervalMs: pollIntervalIdleMs
  property double lastSuccessfulFetchAtMs: 0
  property double lastDiscoveryFetchAtMs: 0

  // Entity state
  property var mediaPlayers: []
  property string selectedMediaPlayer: defaultMediaPlayer
  property var currentState: null
  property bool cacheHydrated: false
  property bool settingsReady: false
  // Keys we persist to cache for offline/fast startup UI
  readonly property var cachedAttributeKeys: ["media_title", "media_artist", "media_album_name", "entity_picture", "media_duration", "volume_level", "is_volume_muted", "shuffle", "repeat", "friendly_name"]

  // Keys we allow to "stick" across refreshes when missing.
  // Keep this list conservative to avoid stale media metadata when a new item doesn't provide all fields.
  readonly property var mergeStickyAttributeKeys: ["volume_level", "is_volume_muted", "shuffle", "repeat", "friendly_name"]
  property var volumeOverrides: ({})
  property real preMuteVolumeLevel: -1
  readonly property real wheelVolumeStep: 0.05
  property real queuedVolumeTarget: -1
  property string queuedVolumeEntityId: ""

  // Computed properties for current media player
  readonly property var selectedPlayerState: {
    if (!selectedMediaPlayer || !currentState)
      return null;
    return currentState[selectedMediaPlayer] || null;
  }

  readonly property int supportedFeatures: selectedPlayerState?.attributes?.supported_features || 0
  readonly property bool canPause: !!(supportedFeatures & 1)
  readonly property bool canSeek: !!(supportedFeatures & 2)
  readonly property bool canVolumeSet: !!(supportedFeatures & 4)
  readonly property bool canVolumeMute: !!(supportedFeatures & 8) || hasValidAttribute(selectedPlayerState?.attributes, "is_volume_muted")
  readonly property bool canPrevious: !!(supportedFeatures & 16)
  readonly property bool canNext: !!(supportedFeatures & 32)
  readonly property bool canTurnOn: !!(supportedFeatures & 128)
  readonly property bool canTurnOff: !!(supportedFeatures & 256)
  readonly property bool canVolumeStep: !!(supportedFeatures & 1024)
  readonly property bool canStop: !!(supportedFeatures & 4096)
  readonly property bool canPlay: !!(supportedFeatures & 16384)
  readonly property bool canShuffle: !!(supportedFeatures & 32768)
  readonly property bool canRepeat: !!(supportedFeatures & 262144)

  readonly property string playbackState: selectedPlayerState?.state || "unavailable"
  readonly property bool isPlaying: playbackState === "playing"
  readonly property bool isPaused: playbackState === "paused"
  readonly property bool isIdle: playbackState === "idle" || playbackState === "off"

  readonly property string mediaTitle: selectedPlayerState?.attributes?.media_title || ""
  readonly property string mediaArtist: selectedPlayerState?.attributes?.media_artist || ""
  readonly property string mediaAlbum: selectedPlayerState?.attributes?.media_album_name || ""
  readonly property string friendlyName: selectedPlayerState?.attributes?.friendly_name || selectedMediaPlayer
  readonly property real mediaDuration: selectedPlayerState?.attributes?.media_duration || 0
  readonly property real mediaPosition: selectedPlayerState?.attributes?.media_position || 0
  readonly property string mediaPositionUpdatedAt: selectedPlayerState?.attributes?.media_position_updated_at || ""
  readonly property real volumeLevel: selectedPlayerState?.attributes?.volume_level || 0
  readonly property bool isVolumeMuted: selectedPlayerState?.attributes?.is_volume_muted || false
  readonly property bool shuffleEnabled: selectedPlayerState?.attributes?.shuffle || false
  readonly property string repeatMode: selectedPlayerState?.attributes?.repeat || "off"
  readonly property string entityPicture: {
    const pic = selectedPlayerState?.attributes?.entity_picture;
    if (!pic)
      return "";
    if (pic.startsWith("http"))
      return pic;
    return haUrl + pic;
  }

  // Polling timer for state updates
  Timer {
    id: pollTimer
    interval: currentPollIntervalMs
    repeat: true
    running: connected
    onTriggered: fetchStates(false)
  }

  Timer {
    id: cacheSaveTimer
    interval: 2500
    repeat: false
    onTriggered: flushCachedState()
  }

  Timer {
    id: volumeQueueTimer
    interval: 120
    repeat: false
    onTriggered: flushQueuedVolumeStep()
  }

  property bool cacheDirty: false
  property string lastSavedCacheSnapshot: ""

  // Connection test timer
  Timer {
    id: reconnectTimer
    interval: 5000
    repeat: false
    onTriggered: {
      if (!connected && haUrl && haToken) {
        Logger.d("HomeAssistant", "Attempting reconnection...");
        testConnection();
      }
    }
  }

  function testConnection() {
    if (!haUrl || !haToken) {
      connected = false;
      connecting = false;
      connectionError = "No URL or token configured";
      return;
    }

    connecting = true;
    connectionError = "";

    const xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        connecting = false;
        if (xhr.status === 200) {
          connected = true;
          connectionError = "";
          consecutiveStateFetchFailures = 0;
          updatePollInterval();
          Logger.d("HomeAssistant", "Connection test successful");
          fetchStates(true);
        } else if (xhr.status === 401) {
          connected = false;
          connectionError = pluginApi?.tr("errors.auth-invalid") || "Invalid access token";
          Logger.e("HomeAssistant", "Authentication failed");
        } else {
          connected = false;
          connectionError = "Connection failed: " + xhr.status;
          Logger.e("HomeAssistant", "Connection test failed:", xhr.status);
          reconnectTimer.start();
        }
      }
    };

    xhr.onerror = function () {
      connecting = false;
      connected = false;
      connectionError = "Connection error";
      Logger.e("HomeAssistant", "Connection test error");
      reconnectTimer.start();
    };

    xhr.open("GET", haUrl + "/api/");
    xhr.setRequestHeader("Authorization", "Bearer " + haToken);
    xhr.timeout = 10000;
    xhr.send();
  }

  function sendHttpRequest(method, endpoint, data, callback) {
    if (!connected) {
      Logger.w("HomeAssistant", "Cannot send request, not connected");
      return -1;
    }

    requestId++;
    const xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        let response = null;
        try {
          if (xhr.status >= 200 && xhr.status < 300 && xhr.responseText) {
            response = JSON.parse(xhr.responseText);
          }
        } catch (e) {
          Logger.e("HomeAssistant", "Failed to parse JSON response:", e);
        }

        if (callback) {
          callback(xhr.status, response);
        }
      }
    };

    xhr.onerror = function () {
      Logger.e("HomeAssistant", "HTTP request error for", endpoint);
      if (callback)
        callback(0, null);
    };

    const url = haUrl + endpoint;
    xhr.open(method, url);
    xhr.setRequestHeader("Authorization", "Bearer " + haToken);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.timeout = 10000;

    if (data) {
      xhr.send(JSON.stringify(data));
    } else {
      xhr.send();
    }

    return requestId;
  }

  function updatePollInterval() {
    let nextInterval = isPlaying ? pollIntervalPlayingMs : pollIntervalIdleMs;
    if (consecutiveStateFetchFailures > 0) {
      const backoff = Math.min(pollIntervalPlayingMs * Math.pow(2, Math.min(consecutiveStateFetchFailures, 3)), pollIntervalMaxBackoffMs);
      nextInterval = Math.max(nextInterval, backoff);
    }
    if (currentPollIntervalMs !== nextInterval) {
      currentPollIntervalMs = nextInterval;
    }
  }

  function markStateFetchResult(success) {
    if (success) {
      consecutiveStateFetchFailures = 0;
    } else {
      consecutiveStateFetchFailures++;
    }
    updatePollInterval();
  }

  function shouldRunDiscoveryPoll(forceDiscovery) {
    if (forceDiscovery)
      return true
    if (!lastDiscoveryFetchAtMs)
      return true
    if (!selectedMediaPlayer)
      return true
    if (mediaPlayers.length === 0)
      return true
    if (!currentState || !currentState[selectedMediaPlayer])
      return true
    return (Date.now() - lastDiscoveryFetchAtMs) >= discoveryPollIntervalMs
  }

  function fetchStates(forceDiscovery) {
    if (!connected)
      return
    if (forceDiscovery) {
      fetchMediaPlayersDiscovery(true)
      fetchSelectedPlayerState()
      return
    }
    fetchSelectedPlayerState()
    if (shouldRunDiscoveryPoll(false)) {
      fetchMediaPlayersDiscovery(false)
    }
  }

  function fetchSelectedPlayerState() {
    if (!connected)
      return
    if (!selectedMediaPlayer)
      return
    if (stateFetchInFlight || discoveryFetchInFlight)
      return

    stateFetchInFlight = true
    const entityId = selectedMediaPlayer
    sendHttpRequest("GET", "/api/states/" + encodeURIComponent(entityId), null, function (status, response) {
      stateFetchInFlight = false
      if (status === 200 && response && response.entity_id) {
        processSelectedPlayerState(response)
        lastSuccessfulFetchAtMs = Date.now()
        markStateFetchResult(true)
      } else {
        Logger.w("HomeAssistant", "Failed to fetch selected player state:", entityId, status)
        markStateFetchResult(false)
        if (status === 404) {
          fetchMediaPlayersDiscovery(true)
        }
      }
    })
  }

  function fetchMediaPlayersDiscovery(forceDiscovery) {
    if (!connected)
      return
    if (!shouldRunDiscoveryPoll(!!forceDiscovery))
      return
    if (discoveryFetchInFlight || stateFetchInFlight)
      return

    discoveryFetchInFlight = true
    sendHttpRequest("GET", "/api/states", null, function (status, response) {
      discoveryFetchInFlight = false
      if (status === 200 && response && Array.isArray(response)) {
        processDiscoveryStates(response)
        lastDiscoveryFetchAtMs = Date.now()
        lastSuccessfulFetchAtMs = lastDiscoveryFetchAtMs
        markStateFetchResult(true)
      } else {
        Logger.w("HomeAssistant", "Failed discovery fetch:", status)
        markStateFetchResult(false)
      }
    })
  }

  function processSelectedPlayerState(entity) {
    if (!entity || !entity.entity_id || !entity.entity_id.startsWith("media_player."))
      return

    const previousState = currentState || {}
    const previousEntity = previousState[entity.entity_id] || null
    const mergedEntity = Object.assign({}, entity)
    mergedEntity.attributes = mergePlayerAttributes(previousState, entity.entity_id, entity.attributes)
    maybeStoreVolumeOverride(entity.entity_id, mergedEntity.attributes)

    const stateChanged = !areEntityStatesEqual(previousEntity, mergedEntity)
    if (stateChanged) {
      const nextState = Object.assign({}, previousState)
      nextState[entity.entity_id] = mergedEntity
      currentState = nextState
    }

    let selectionChanged = false
    if (!selectedMediaPlayer) {
      selectedMediaPlayer = entity.entity_id
      selectionChanged = true
    }

    const playersChanged = upsertMediaPlayerEntryFromEntity(mergedEntity)
    const cacheChanged = didEntityChangeForCache(previousEntity, mergedEntity)

    if (cacheChanged || playersChanged || selectionChanged)
      scheduleCachedStateSave()
  }

  function processDiscoveryStates(states) {
    const previousState = currentState || {}
    const discoveredState = {}
    const players = []

    for (const entity of states) {
      if (!entity || !entity.entity_id || !entity.entity_id.startsWith("media_player."))
        continue
      const mergedEntity = Object.assign({}, entity)
      mergedEntity.attributes = mergePlayerAttributes(previousState, entity.entity_id, entity.attributes)
      maybeStoreVolumeOverride(entity.entity_id, mergedEntity.attributes)
      discoveredState[entity.entity_id] = mergedEntity
      players.push({
                     entity_id: entity.entity_id,
                     friendly_name: entity.attributes?.friendly_name || entity.entity_id,
                     state: entity.state
                   })
    }

    players.sort((a, b) => a.entity_id.localeCompare(b.entity_id))

    const stateChanged = !areEntityMapsEqual(previousState, discoveredState)
    const playersChanged = !areMediaPlayerListsEqual(mediaPlayers, players)

    if (stateChanged)
      currentState = discoveredState
    if (playersChanged)
      mediaPlayers = players

    let selectionChanged = false
    if (players.length === 0) {
      if (selectedMediaPlayer !== "") {
        selectedMediaPlayer = ""
        selectionChanged = true
      }
    } else if (!selectedMediaPlayer || !discoveredState[selectedMediaPlayer]) {
      const preferred = (defaultMediaPlayer && discoveredState[defaultMediaPlayer]) ? defaultMediaPlayer : players[0].entity_id
      if (selectedMediaPlayer !== preferred) {
        selectedMediaPlayer = preferred
        selectionChanged = true
      }
    }

    if (selectionChanged)
      Qt.callLater(fetchSelectedPlayerState)

    const cacheChanged = !areCachedEntityMapsEqual(previousState, discoveredState)
    if (cacheChanged || playersChanged || selectionChanged)
      scheduleCachedStateSave()
  }

  function processStates(states) {
    processDiscoveryStates(states)
  }

  function handleStateChange(data) {
    if (!data.entity_id?.startsWith("media_player."))
      return

    if (data.new_state) {
      processSelectedPlayerState(data.new_state)
      return
    }

    if (!currentState || !currentState[data.entity_id])
      return

    const nextState = Object.assign({}, currentState)
    delete nextState[data.entity_id]
    currentState = nextState

    const nextPlayers = mediaPlayers.filter(p => p.entity_id !== data.entity_id)
    if (!areMediaPlayerListsEqual(mediaPlayers, nextPlayers))
      mediaPlayers = nextPlayers

    if (selectedMediaPlayer === data.entity_id) {
      selectedMediaPlayer = nextPlayers.length > 0 ? nextPlayers[0].entity_id : ""
    }
    scheduleCachedStateSave()
  }

  function callService(domain, service, entityId, serviceData) {
    const data = Object.assign({
                                 entity_id: entityId
                               }, serviceData || {});
    const endpoint = `/api/services/${domain}/${service}`;

    sendHttpRequest("POST", endpoint, data, function (status, response) {
      if (status < 200 || status >= 300) {
        Logger.e("HomeAssistant", "Service call failed:", domain, service, status);
        ToastService.showError(friendlyName, pluginApi?.tr("errors.service-failed") || "Service call failed");
      } else {
        Logger.d("HomeAssistant", "Service call successful:", domain, service);
        // REST service calls return updated entity states - merge them immediately
        if (response && Array.isArray(response)) {
          mergeServiceResponseStates(response);
        }
      }
    });
  }

  // Merge states returned from service calls (instant UI updates)
  function mergeServiceResponseStates(entities) {
    if (!entities || !Array.isArray(entities) || entities.length === 0)
      return

    const previousState = currentState || {}
    let nextState = previousState
    let stateChanged = false
    let playersChanged = false
    let cacheChanged = false
    let updatedCount = 0

    for (const entity of entities) {
      if (!entity || !entity.entity_id || !entity.entity_id.startsWith("media_player."))
        continue

      const previousEntity = (stateChanged ? nextState : previousState)[entity.entity_id] || null
      const mergedEntity = Object.assign({}, entity)
      mergedEntity.attributes = mergePlayerAttributes(previousState, entity.entity_id, entity.attributes)
      maybeStoreVolumeOverride(entity.entity_id, mergedEntity.attributes)

      if (!areEntityStatesEqual(previousEntity, mergedEntity)) {
        if (!stateChanged) {
          nextState = Object.assign({}, previousState)
        }
        nextState[entity.entity_id] = mergedEntity
        stateChanged = true
      }

      if (didEntityChangeForCache(previousEntity, mergedEntity))
        cacheChanged = true
      if (upsertMediaPlayerEntryFromEntity(mergedEntity))
        playersChanged = true
      updatedCount++
    }

    if (stateChanged)
      currentState = nextState
    if (cacheChanged || playersChanged)
      scheduleCachedStateSave()
    if (updatedCount > 0)
      Logger.d("HomeAssistant", "Merged", updatedCount, "entities from service response")
  }

  // Media player control functions
  function mediaPlay() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_play", selectedMediaPlayer);
  }

  function mediaPause() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_pause", selectedMediaPlayer);
  }

  function mediaPlayPause() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_play_pause", selectedMediaPlayer);
  }

  function mediaStop() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_stop", selectedMediaPlayer);
  }

  function mediaNext() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_next_track", selectedMediaPlayer);
  }

  function mediaPrevious() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_previous_track", selectedMediaPlayer);
  }

  function updateSelectedPlayerAttribute(attrNameOrMap, value) {
    if (!selectedMediaPlayer || !currentState)
      return;
    const playerState = currentState[selectedMediaPlayer];
    if (!playerState)
      return;

    const newState = Object.assign({}, currentState);
    const newPlayerState = Object.assign({}, playerState);
    newPlayerState.attributes = Object.assign({}, playerState.attributes || {});
    let updates = {};
    if (attrNameOrMap && typeof attrNameOrMap === "object") {
      updates = attrNameOrMap;
    } else if (typeof attrNameOrMap === "string") {
      updates[attrNameOrMap] = value;
    }
    let changed = false
    for (const key in updates) {
      if (updates.hasOwnProperty(key)) {
        if (newPlayerState.attributes[key] !== updates[key]) {
          newPlayerState.attributes[key] = updates[key]
          changed = true
        }
      }
    }
    if (!changed)
      return
    newState[selectedMediaPlayer] = newPlayerState;
    currentState = newState;
    scheduleCachedStateSave();
  }

  function clampVolume(level) {
    if (level < 0)
      return 0
    if (level > 1)
      return 1
    return level
  }

  function sendVolumeSet(entityId, level) {
    if (!entityId)
      return
    callService("media_player", "volume_set", entityId, {
                  volume_level: level
                })
  }

  function applyVolumeLocally(entityId, level) {
    maybeStoreVolumeOverride(entityId, {
                               volume_level: level
                             })
    if (entityId === selectedMediaPlayer)
      updateSelectedPlayerAttribute("volume_level", level)
  }

  function setVolume(level) {
    if (!selectedMediaPlayer)
      return
    const clamped = clampVolume(level)
    queuedVolumeEntityId = ""
    queuedVolumeTarget = -1
    volumeQueueTimer.stop()
    applyVolumeLocally(selectedMediaPlayer, clamped)
    sendVolumeSet(selectedMediaPlayer, clamped)
  }

  function volumeUp() {
    queueVolumeStep(wheelVolumeStep)
  }

  function volumeDown() {
    queueVolumeStep(-wheelVolumeStep)
  }

  function queueVolumeStep(step) {
    if (!selectedMediaPlayer)
      return
    if (!canVolumeSet)
      return

    if (queuedVolumeEntityId !== selectedMediaPlayer) {
      queuedVolumeEntityId = selectedMediaPlayer
      queuedVolumeTarget = clampVolume(volumeLevel)
    }

    queuedVolumeTarget = clampVolume(queuedVolumeTarget + step)
    applyVolumeLocally(queuedVolumeEntityId, queuedVolumeTarget)
    volumeQueueTimer.restart()
  }

  function flushQueuedVolumeStep() {
    if (!queuedVolumeEntityId || queuedVolumeTarget < 0)
      return

    const entityId = queuedVolumeEntityId
    const target = clampVolume(queuedVolumeTarget)
    queuedVolumeEntityId = ""
    queuedVolumeTarget = -1
    sendVolumeSet(entityId, target)
  }

  function toggleMute() {
    if (!selectedMediaPlayer)
      return;
    if (volumeLevel > 0) {
      preMuteVolumeLevel = volumeLevel;
      setVolume(0);
    } else if (preMuteVolumeLevel > 0) {
      setVolume(preMuteVolumeLevel);
      preMuteVolumeLevel = -1;
    } else {
      setVolume(0.5);
    }
  }

  function seek(position) {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_seek", selectedMediaPlayer, {
                  seek_position: position
                });
    updateSelectedPlayerAttribute({
                                    "media_position": position,
                                    "media_position_updated_at": new Date().toISOString()
                                  });
  }

  function toggleShuffle() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "shuffle_set", selectedMediaPlayer, {
                  shuffle: !shuffleEnabled
                });
    updateSelectedPlayerAttribute("shuffle", !shuffleEnabled);
  }

  function cycleRepeat() {
    if (!selectedMediaPlayer)
      return;
    const modes = ["off", "all", "one"];
    const currentIndex = modes.indexOf(repeatMode);
    const nextMode = modes[(currentIndex + 1) % modes.length];
    callService("media_player", "repeat_set", selectedMediaPlayer, {
                  repeat: nextMode
                });
    updateSelectedPlayerAttribute("repeat", nextMode);
  }

  function selectMediaPlayer(entityId) {
    if (selectedMediaPlayer === entityId)
      return
    queuedVolumeEntityId = ""
    queuedVolumeTarget = -1
    volumeQueueTimer.stop()
    selectedMediaPlayer = entityId
    scheduleCachedStateSave()
    Qt.callLater(fetchSelectedPlayerState)
  }

  function disconnect() {
    flushCachedState()
    connected = false
    connecting = false
    stateFetchInFlight = false
    discoveryFetchInFlight = false
    queuedVolumeEntityId = ""
    queuedVolumeTarget = -1
    volumeQueueTimer.stop()
    pollTimer.stop()
  }

  function reconnect() {
    disconnect()
    Qt.callLater(() => {
                   testConnection()
                 })
  }

  function refresh() {
    if (connected) {
      fetchStates(true)
    } else {
      reconnect()
    }
  }

  function refreshIfStale(maxAgeMs) {
    const threshold = (maxAgeMs === undefined || maxAgeMs === null) ? 4000 : maxAgeMs
    if (!connected) {
      reconnect()
      return
    }
    if (!lastSuccessfulFetchAtMs || (Date.now() - lastSuccessfulFetchAtMs) >= threshold) {
      fetchStates(false)
    }
  }

  function loadCachedStateIfAvailable() {
    if (cacheHydrated)
      return
    if (!pluginApi || !pluginApi.pluginSettings)
      return
    settingsReady = true
    const cache = pluginApi.pluginSettings.stateCache
    if (cache) {
      const cachedEntities = cache.entities || cache.currentState
      if (cachedEntities)
        currentState = cachedEntities
      if (cache.mediaPlayers)
        mediaPlayers = [...cache.mediaPlayers].sort((a, b) => a.entity_id.localeCompare(b.entity_id))
      if (cache.selectedMediaPlayer)
        selectedMediaPlayer = cache.selectedMediaPlayer
      Logger.d("HomeAssistant", "Loaded cached Home Assistant player state from settings")
    }
    if (pluginApi.pluginSettings.volumeOverrides)
      volumeOverrides = pluginApi.pluginSettings.volumeOverrides
    else if (cache?.volumeOverrides)
      volumeOverrides = cache.volumeOverrides
    if (pluginApi.pluginSettings.preMuteVolumeLevel !== undefined)
      preMuteVolumeLevel = pluginApi.pluginSettings.preMuteVolumeLevel
    else if (cache && cache.preMuteVolumeLevel !== undefined)
      preMuteVolumeLevel = cache.preMuteVolumeLevel
    lastSavedCacheSnapshot = JSON.stringify(buildCachePayload())
    cacheDirty = false
    cacheHydrated = true
  }

  function buildCachePayload() {
    return {
      entities: buildCachedEntities(),
      mediaPlayers: mediaPlayers,
      selectedMediaPlayer: selectedMediaPlayer,
      volumeOverrides: buildSortedObject(volumeOverrides),
      preMuteVolumeLevel: preMuteVolumeLevel
    }
  }

  function scheduleCachedStateSave() {
    if (!settingsReady || !pluginApi) {
      cacheDirty = true
      return
    }
    const snapshot = JSON.stringify(buildCachePayload())
    if (snapshot === lastSavedCacheSnapshot) {
      cacheDirty = false
      return
    }
    cacheDirty = true
    cacheSaveTimer.restart()
  }

  function flushCachedState() {
    if (!settingsReady || !pluginApi)
      return
    if (!cacheDirty)
      return
    if (!pluginApi.pluginSettings) {
      pluginApi.pluginSettings = {}
    }
    const payload = buildCachePayload()
    const snapshot = JSON.stringify(payload)
    if (snapshot === lastSavedCacheSnapshot) {
      cacheDirty = false
      return
    }

    pluginApi.pluginSettings.stateCache = Object.assign({}, payload, {
      timestamp: Date.now()
    })
    pluginApi.pluginSettings.volumeOverrides = volumeOverrides || {}
    pluginApi.pluginSettings.preMuteVolumeLevel = preMuteVolumeLevel
    pluginApi.saveSettings()
    lastSavedCacheSnapshot = snapshot
    cacheDirty = false
  }

  // Auto-connect when URL/token are configured
  onHaUrlChanged: {
    if (haUrl && haToken) {
      testConnection();
    } else {
      disconnect();
    }
  }

  onHaTokenChanged: {
    if (haUrl && haToken) {
      testConnection();
    } else {
      disconnect();
    }
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      loadCachedStateIfAvailable();
    }
  }

  Component.onCompleted: {
    loadCachedStateIfAvailable();
    updatePollInterval();
    if (haUrl && haToken) {
      testConnection();
    }
  }

  Component.onDestruction: flushCachedState()

  onIsPlayingChanged: updatePollInterval()
  onConnectedChanged: updatePollInterval()

  function buildMediaPlayerEntry(entity) {
    return {
      entity_id: entity.entity_id,
      friendly_name: entity.attributes?.friendly_name || entity.entity_id,
      state: entity.state
    }
  }

  function areMediaPlayerEntriesEqual(left, right) {
    if (!left || !right)
      return false
    return left.entity_id === right.entity_id
        && left.friendly_name === right.friendly_name
        && left.state === right.state
  }

  function areMediaPlayerListsEqual(left, right) {
    const leftList = left || []
    const rightList = right || []
    if (leftList.length !== rightList.length)
      return false
    for (let i = 0; i < leftList.length; i++) {
      if (!areMediaPlayerEntriesEqual(leftList[i], rightList[i]))
        return false
    }
    return true
  }

  function upsertMediaPlayerEntryFromEntity(entity) {
    if (!entity || !entity.entity_id)
      return false
    const nextEntry = buildMediaPlayerEntry(entity)
    const index = mediaPlayers.findIndex(p => p.entity_id === nextEntry.entity_id)
    if (index < 0) {
      const nextPlayers = [...mediaPlayers, nextEntry]
      nextPlayers.sort((a, b) => a.entity_id.localeCompare(b.entity_id))
      mediaPlayers = nextPlayers
      return true
    }

    const previous = mediaPlayers[index]
    if (areMediaPlayerEntriesEqual(previous, nextEntry))
      return false

    const nextPlayers = [...mediaPlayers]
    nextPlayers[index] = nextEntry
    mediaPlayers = nextPlayers
    return true
  }

  function areEntityStatesEqual(left, right) {
    if (left === right)
      return true
    if (!left || !right)
      return false
    if (left.entity_id !== right.entity_id)
      return false
    if (left.state !== right.state)
      return false
    return JSON.stringify(left.attributes || {}) === JSON.stringify(right.attributes || {})
  }

  function areEntityMapsEqual(leftMap, rightMap) {
    const left = leftMap || {}
    const right = rightMap || {}
    const leftKeys = Object.keys(left)
    const rightKeys = Object.keys(right)
    if (leftKeys.length !== rightKeys.length)
      return false
    for (let i = 0; i < leftKeys.length; i++) {
      const key = leftKeys[i]
      if (!Object.prototype.hasOwnProperty.call(right, key))
        return false
      if (!areEntityStatesEqual(left[key], right[key]))
        return false
    }
    return true
  }

  function buildCachedEntitiesFromState(stateMap) {
    const cache = {}
    if (!stateMap)
      return cache
    const entityIds = Object.keys(stateMap).sort()
    for (let i = 0; i < entityIds.length; i++) {
      const entityId = entityIds[i]
      const entity = stateMap[entityId]
      if (!entity)
        continue
      cache[entityId] = {
        entity_id: entity.entity_id || entityId,
        state: entity.state || "unknown",
        attributes: pickCachedAttributes(entity.attributes || {})
      }
    }
    return cache
  }

  function buildSortedObject(source) {
    const sorted = {}
    const keys = Object.keys(source || {}).sort()
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i]
      sorted[key] = source[key]
    }
    return sorted
  }

  function areCachedEntityMapsEqual(leftMap, rightMap) {
    const left = buildCachedEntitiesFromState(leftMap)
    const right = buildCachedEntitiesFromState(rightMap)
    const leftKeys = Object.keys(left).sort()
    const rightKeys = Object.keys(right).sort()
    if (leftKeys.length !== rightKeys.length)
      return false
    for (let i = 0; i < leftKeys.length; i++) {
      if (leftKeys[i] !== rightKeys[i])
        return false
      const key = leftKeys[i]
      if (JSON.stringify(left[key]) !== JSON.stringify(right[key]))
        return false
    }
    return true
  }

  function didEntityChangeForCache(previousEntity, nextEntity) {
    const previousPayload = previousEntity ? {
      entity_id: previousEntity.entity_id || "",
      state: previousEntity.state || "unknown",
      attributes: pickCachedAttributes(previousEntity.attributes || {})
    } : null
    const nextPayload = nextEntity ? {
      entity_id: nextEntity.entity_id || "",
      state: nextEntity.state || "unknown",
      attributes: pickCachedAttributes(nextEntity.attributes || {})
    } : null
    return JSON.stringify(previousPayload) !== JSON.stringify(nextPayload)
  }

  function hasValidAttribute(attributes, key) {
    if (!attributes)
      return false;
    if (!Object.prototype.hasOwnProperty.call(attributes, key))
      return false;
    const value = attributes[key];
    return value !== null && value !== undefined;
  }

  function mergePlayerAttributes(previousState, entityId, incomingAttributes) {
    const merged = Object.assign({}, incomingAttributes || {});
    const priorState = previousState && previousState[entityId] ? previousState[entityId] : null;
    const priorAttributes = priorState?.attributes || {};
    for (let i = 0; i < mergeStickyAttributeKeys.length; i++) {
      const key = mergeStickyAttributeKeys[i];
      if (!hasValidAttribute(merged, key) && hasValidAttribute(priorAttributes, key)) {
        merged[key] = priorAttributes[key];
      }
    }
    if (!hasValidAttribute(merged, "volume_level")) {
      const override = getVolumeOverride(entityId);
      if (override !== null && override !== undefined) {
        merged.volume_level = override;
      }
    }
    return merged;
  }

  function pickCachedAttributes(attributes) {
    const picked = {};
    if (!attributes)
      return picked;
    for (let i = 0; i < cachedAttributeKeys.length; i++) {
      const key = cachedAttributeKeys[i];
      if (hasValidAttribute(attributes, key)) {
        picked[key] = attributes[key];
      }
    }
    return picked;
  }

  function buildCachedEntities() {
    return buildCachedEntitiesFromState(currentState)
  }

  function getVolumeOverride(entityId) {
    if (!volumeOverrides || !entityId)
      return undefined;
    return volumeOverrides[entityId];
  }

  function maybeStoreVolumeOverride(entityId, attributes) {
    if (!entityId || !attributes)
      return;
    const level = attributes.volume_level;
    if (level === null || level === undefined)
      return;
    if (!volumeOverrides)
      volumeOverrides = {};
    if (volumeOverrides[entityId] === level)
      return;
    const overrides = Object.assign({}, volumeOverrides);
    overrides[entityId] = level;
    volumeOverrides = overrides;
  }

  IpcHandler {
    target: "homeassistant"
    function volumeUp()                  { root.volumeUp() }
    function volumeDown()                { root.volumeDown() }
    function setVolume(level: string)    { root.setVolume(parseFloat(level)) }
    function toggleMute()                { root.toggleMute() }
    function playPause()                 { root.mediaPlayPause() }
    function next()                      { root.mediaNext() }
    function previous()                  { root.mediaPrevious() }
    function stop()                      { root.mediaStop() }
    function toggleShuffle()             { root.toggleShuffle() }
    function cycleRepeat()               { root.cycleRepeat() }
    function selectPlayer(id: string)    { root.selectMediaPlayer(id) }
    function refresh()                   { root.refresh() }
    function togglePanel() {
      if (!pluginApi) return
      pluginApi.withCurrentScreen(screen => {
        if (pluginApi.panelOpenScreen)
          pluginApi.closePanel(pluginApi.panelOpenScreen)
        else
          pluginApi.openPanel(screen)
      })
    }
  }

  IpcHandler {
    target: "plugin:homeassistant"
    function volumeUp()                  { root.volumeUp() }
    function volumeDown()                { root.volumeDown() }
    function setVolume(level: string)    { root.setVolume(parseFloat(level)) }
    function toggleMute()                { root.toggleMute() }
    function playPause()                 { root.mediaPlayPause() }
    function next()                      { root.mediaNext() }
    function previous()                  { root.mediaPrevious() }
    function stop()                      { root.mediaStop() }
    function toggleShuffle()             { root.toggleShuffle() }
    function cycleRepeat()               { root.cycleRepeat() }
    function selectPlayer(id: string)    { root.selectMediaPlayer(id) }
    function refresh()                   { root.refresh() }
    function togglePanel() {
      if (!pluginApi) return
      pluginApi.withCurrentScreen(screen => {
        if (pluginApi.panelOpenScreen)
          pluginApi.closePanel(pluginApi.panelOpenScreen)
        else
          pluginApi.openPanel(screen)
      })
    }
  }
}
