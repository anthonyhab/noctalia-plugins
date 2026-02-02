import QtQuick
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
  property var pendingRequests: ({})

  // Entity state
  property var mediaPlayers: []
  property string selectedMediaPlayer: defaultMediaPlayer
  property var currentState: null
  property bool cacheHydrated: false
  property bool settingsReady: false
  // Keys we persist to cache for offline/fast startup UI
  readonly property var cachedAttributeKeys: ["media_title", "media_artist", "media_album_name", "entity_picture", "media_duration", "media_position", "media_position_updated_at", "volume_level", "is_volume_muted", "shuffle", "repeat", "friendly_name", "preMuteVolumeLevel"]

  // Keys we allow to "stick" across refreshes when missing.
  // Keep this list conservative to avoid stale media metadata when a new item doesn't provide all fields.
  readonly property var mergeStickyAttributeKeys: ["volume_level", "is_volume_muted", "shuffle", "repeat", "friendly_name"]
  property var volumeOverrides: ({})
  property real preMuteVolumeLevel: -1

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
    interval: 5000  // Poll every 5 seconds
    repeat: true
    running: connected
    onTriggered: fetchStates()
  }

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
          Logger.d("HomeAssistant", "Connection test successful");
          fetchStates();
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
          if (xhr.status === 200 && xhr.responseText) {
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

  function fetchStates() {
    Logger.d("HomeAssistant", "Fetching states...");
    sendHttpRequest("GET", "/api/states", null, function (status, response) {
      if (status === 200 && response) {
        Logger.d("HomeAssistant", "States fetched successfully, processing", response.length, "entities");
        processStates(response);
      } else {
        Logger.w("HomeAssistant", "Failed to fetch states:", status);
      }
    });
  }

  // HTTP requests handle responses in callbacks, so this function is no longer needed
  function handleResult(msg) {
    // Legacy function - no longer used with HTTP API
  }

  function processStates(states) {
    const previousState = currentState || {};
    const newState = {};
    const players = [];

    for (const entity of states) {
      if (entity.entity_id.startsWith("media_player.")) {
        const mergedEntity = Object.assign({}, entity);
        mergedEntity.attributes = mergePlayerAttributes(previousState, entity.entity_id, entity.attributes);
        maybeStoreVolumeOverride(entity.entity_id, mergedEntity.attributes);
        newState[entity.entity_id] = mergedEntity;
        players.push({
                       entity_id: entity.entity_id,
                       friendly_name: entity.attributes?.friendly_name || entity.entity_id,
                       state: entity.state
                     });
      }
    }

    currentState = newState;
    mediaPlayers = players;

    Logger.d("HomeAssistant", "Processed", players.length, "media players");
    if (players.length > 0) {
      Logger.d("HomeAssistant", "Selected player:", selectedMediaPlayer, "state:", selectedPlayerState?.state);
    }

    // Auto-select first player if none selected
    if (!selectedMediaPlayer && players.length > 0) {
      selectedMediaPlayer = defaultMediaPlayer || players[0].entity_id;
    }

    Logger.d("HomeAssistant", "Found", players.length, "media players");
    saveCachedState();
  }

  function handleStateChange(data) {
    if (!data.entity_id?.startsWith("media_player."))
      return;

    const newState = Object.assign({}, currentState);
    if (data.new_state) {
      const mergedState = Object.assign({}, data.new_state);
      mergedState.attributes = mergePlayerAttributes(currentState, data.entity_id, data.new_state?.attributes);
      maybeStoreVolumeOverride(data.entity_id, mergedState.attributes);
      newState[data.entity_id] = mergedState;
    } else {
      newState[data.entity_id] = data.new_state;
    }
    currentState = newState;

    // Update media players list if this is a new entity
    const existing = mediaPlayers.find(p => p.entity_id === data.entity_id);
    if (!existing && data.new_state) {
      mediaPlayers = [...mediaPlayers,
                      {
                        entity_id: data.entity_id,
                        friendly_name: data.new_state.attributes?.friendly_name || data.entity_id,
                        state: data.new_state.state
                      }
          ];
    } else if (existing && data.new_state) {
      mediaPlayers = mediaPlayers.map(p => {
                                        if (p.entity_id === data.entity_id) {
                                          return {
                                            entity_id: data.entity_id,
                                            friendly_name: data.new_state.attributes?.friendly_name || data.entity_id,
                                            state: data.new_state.state
                                          };
                                        }
                                        return p;
                                      });
    }
    saveCachedState();
  }

  function callService(domain, service, entityId, serviceData) {
    const data = Object.assign({
                                 entity_id: entityId
                               }, serviceData || {});
    const endpoint = `/api/services/${domain}/${service}`;

    sendHttpRequest("POST", endpoint, data, function (status, response) {
      if (status !== 200) {
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
      return;

    const newState = Object.assign({}, currentState);
    let updatedCount = 0;

    for (const entity of entities) {
      if (!entity.entity_id)
        continue;
      // Only process media_player entities
      if (!entity.entity_id.startsWith("media_player."))
        continue;

      const mergedEntity = Object.assign({}, entity);
      mergedEntity.attributes = mergePlayerAttributes(currentState, entity.entity_id, entity.attributes);
      maybeStoreVolumeOverride(entity.entity_id, mergedEntity.attributes);
      newState[entity.entity_id] = mergedEntity;
      updatedCount++;

      // Update mediaPlayers list if needed
      const existingIndex = mediaPlayers.findIndex(p => p.entity_id === entity.entity_id);
      if (existingIndex >= 0) {
        mediaPlayers[existingIndex] = {
          entity_id: entity.entity_id,
          friendly_name: entity.attributes?.friendly_name || entity.entity_id,
          state: entity.state
        };
      }
    }

    if (updatedCount > 0) {
      currentState = newState;
      // Trigger reactivity by reassigning mediaPlayers
      mediaPlayers = [...mediaPlayers];
      saveCachedState();
      Logger.d("HomeAssistant", "Merged", updatedCount, "entities from service response");
    }
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
    for (const key in updates) {
      if (updates.hasOwnProperty(key)) {
        newPlayerState.attributes[key] = updates[key];
      }
    }
    newState[selectedMediaPlayer] = newPlayerState;
    currentState = newState;
    saveCachedState();
  }

  function setVolume(level) {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "volume_set", selectedMediaPlayer, {
                  volume_level: level
                });
    maybeStoreVolumeOverride(selectedMediaPlayer, {
                               volume_level: level
                             });
    updateSelectedPlayerAttribute("volume_level", level);
  }

  function volumeUp() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "volume_up", selectedMediaPlayer);
  }

  function volumeDown() {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "volume_down", selectedMediaPlayer);
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
    selectedMediaPlayer = entityId;
    saveCachedState();
  }

  function disconnect() {
    connected = false;
    connecting = false;
    pollTimer.stop();
  }

  function reconnect() {
    disconnect();
    Qt.callLater(() => {
                   testConnection();
                 });
  }

  function refresh() {
    if (connected) {
      fetchStates();
    } else {
      reconnect();
    }
  }

  function loadCachedStateIfAvailable() {
    if (cacheHydrated)
      return;
    if (!pluginApi || !pluginApi.pluginSettings)
      return;
    settingsReady = true;
    const cache = pluginApi.pluginSettings.stateCache;
    if (cache) {
      const cachedEntities = cache.entities || cache.currentState;
      if (cachedEntities)
        currentState = cachedEntities;
      if (cache.mediaPlayers)
        mediaPlayers = cache.mediaPlayers;
      if (cache.selectedMediaPlayer)
        selectedMediaPlayer = cache.selectedMediaPlayer;
      Logger.d("HomeAssistant", "Loaded cached Home Assistant player state from settings");
    }
    if (pluginApi.pluginSettings.volumeOverrides)
      volumeOverrides = pluginApi.pluginSettings.volumeOverrides;
    if (pluginApi.pluginSettings.preMuteVolumeLevel !== undefined)
      preMuteVolumeLevel = pluginApi.pluginSettings.preMuteVolumeLevel;
    cacheHydrated = true;
  }

  function saveCachedState() {
    if (!settingsReady || !pluginApi)
      return;
    if (!pluginApi.pluginSettings) {
      pluginApi.pluginSettings = {};
    }
    pluginApi.pluginSettings.stateCache = {
      entities: buildCachedEntities(),
      mediaPlayers: mediaPlayers,
      selectedMediaPlayer: selectedMediaPlayer,
      timestamp: Date.now()
    };
    pluginApi.pluginSettings.volumeOverrides = volumeOverrides || {};
    pluginApi.pluginSettings.preMuteVolumeLevel = preMuteVolumeLevel;
    pluginApi.saveSettings();
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
    if (haUrl && haToken) {
      testConnection();
    }
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
    const cache = {};
    if (!currentState)
      return cache;
    for (const entityId in currentState) {
      if (!Object.prototype.hasOwnProperty.call(currentState, entityId))
        continue;
      const entity = currentState[entityId];
      if (!entity)
        continue;
      cache[entityId] = {
        entity_id: entity.entity_id || entityId,
        state: entity.state || "unknown",
        attributes: pickCachedAttributes(entity.attributes || {})
      };
    }
    return cache;
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
}
