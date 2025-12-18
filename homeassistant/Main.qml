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

  // Computed properties for current media player
  readonly property var selectedPlayerState: {
    if (!selectedMediaPlayer || !currentState)
      return null;
    return currentState[selectedMediaPlayer] || null;
  }

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
        try {
          const response = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
          if (callback)
            callback(xhr.status, response);
        } catch (e) {
          Logger.e("HomeAssistant", "Failed to parse response:", e);
          if (callback)
            callback(xhr.status, null);
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
    const newState = {};
    const players = [];

    for (const entity of states) {
      if (entity.entity_id.startsWith("media_player.")) {
        newState[entity.entity_id] = entity;
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
  }

  function handleStateChange(data) {
    if (!data.entity_id?.startsWith("media_player."))
      return;

    const newState = Object.assign({}, currentState);
    newState[data.entity_id] = data.new_state;
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
  }

  function callService(domain, service, entityId, serviceData) {
    const data = Object.assign({
                                 entity_id: entityId
                               }, serviceData || {});
    const endpoint = `/api/services/${domain}/${service}`;

    sendHttpRequest("POST", endpoint, data, function (status, response) {
      if (status !== 200) {
        Logger.e("HomeAssistant", "Service call failed:", domain, service, status);
        ToastService.show(pluginApi?.tr("errors.service-failed") || "Service call failed", "error");
      } else {
        Logger.d("HomeAssistant", "Service call successful:", domain, service);
      }
    });
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

  function updateSelectedPlayerAttribute(attrName, value) {
    if (!selectedMediaPlayer || !currentState)
      return;
    const playerState = currentState[selectedMediaPlayer];
    if (!playerState)
      return;

    const newState = Object.assign({}, currentState);
    const newPlayerState = Object.assign({}, playerState);
    newPlayerState.attributes = Object.assign({}, playerState.attributes || {});
    newPlayerState.attributes[attrName] = value;
    newState[selectedMediaPlayer] = newPlayerState;
    currentState = newState;
  }

  function setVolume(level) {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "volume_set", selectedMediaPlayer, {
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
    callService("media_player", "volume_mute", selectedMediaPlayer, {
                  is_volume_muted: !isVolumeMuted
                });
    updateSelectedPlayerAttribute("is_volume_muted", !isVolumeMuted);
  }

  function seek(position) {
    if (!selectedMediaPlayer)
      return;
    callService("media_player", "media_seek", selectedMediaPlayer, {
                  seek_position: position
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

  Component.onCompleted: {
    if (haUrl && haToken) {
      testConnection();
    }
  }
}
