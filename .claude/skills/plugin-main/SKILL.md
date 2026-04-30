---
name: plugin-main
description: Reference for implementing Main.qml as the plugin state owner with IPC handlers and service integration. Use when adding background logic, timers, process execution, or shared plugin state.
---

# Noctalia Main.qml (Backend/State) Development

Main.qml handles background logic, IPC handlers, state management, and service integration.

## Required Imports

```qml
import QtQuick
import Quickshell
import Quickshell.Io    // For Process and IpcHandler
import qs.Commons
import qs.Services.UI
```

## Base Structure

```qml
Item {
  id: root

  // Required: Plugin API injection
  property var pluginApi: null

  // Connection state
  property bool connected: false
  property bool connecting: false
  property string connectionError: ""

  // Data state (accessed by widgets/panels)
  property var items: []
  property var currentState: null

  // Polling timer
  Timer {
    id: pollTimer
    interval: refreshInterval
    repeat: true
    running: connected
    onTriggered: fetchData()
  }

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("MyPlugin", "Main component loaded")
      initialize()
    }
  }

  // Called when pluginApi becomes available
  onPluginApiChanged: {
    if (pluginApi) {
      initialize()
    }
  }
}
```

## IPC Handler Setup

```qml
import Quickshell.Io

IpcHandler {
  target: "plugin:your-plugin-id"  // Must match manifest id with "plugin:" prefix

  // Simple command
  function refresh() {
    Logger.i("MyPlugin", "IPC refresh called")
    root.fetchData()
  }

  // Command with parameter
  function setValue(value: string) {
    if (!pluginApi) return

    const numValue = parseFloat(value)
    if (Number.isNaN(numValue)) {
      Logger.w("MyPlugin", "Invalid value:", value)
      ToastService.showError("Invalid value")
      return
    }

    pluginApi.pluginSettings.value = numValue
    pluginApi.saveSettings()
    ToastService.showNotice("Value updated")
  }

  // Toggle command
  function toggle() {
    if (!pluginApi) return

    const newState = !pluginApi.pluginSettings.enabled
    pluginApi.pluginSettings.enabled = newState
    pluginApi.saveSettings()

    const status = newState ? "enabled" : "disabled"
    ToastService.showNotice("Plugin " + status)
  }

  // Open panel
  function openPanel() {
    if (!pluginApi) return
    pluginApi.withCurrentScreen(screen => {
      pluginApi.openPanel(screen)
    })
  }
}
```

## Settings Access

```qml
// Settings with fallback chain
readonly property string apiUrl:
  pluginApi?.pluginSettings?.apiUrl ??
  pluginApi?.manifest?.metadata?.defaultSettings?.apiUrl ??
  ""

readonly property string apiToken:
  pluginApi?.pluginSettings?.apiToken ?? ""

readonly property int refreshInterval:
  pluginApi?.pluginSettings?.refreshInterval ??
  pluginApi?.manifest?.metadata?.defaultSettings?.refreshInterval ??
  5000

readonly property bool autoStart:
  pluginApi?.pluginSettings?.autoStart ?? true
```

## Settings Change Handling

```qml
Connections {
  target: pluginApi

  function onPluginSettingsChanged() {
    Logger.i("MyPlugin", "Settings changed, reinitializing...")
    initialize()
  }
}
```

## Process/Helper Integration

```qml
// Process for running helper scripts
Process {
  id: helperProcess
  running: false

  onExited: (exitCode, exitStatus) => {
    if (exitCode === 0) {
      const output = stdout.readAll()
      processHelperOutput(output)
    } else {
      Logger.e("MyPlugin", "Helper failed:", exitCode)
    }
  }
}

function runHelper(command, args) {
  if (!pluginApi) return

  const helperPath = pluginApi.pluginDir + "/helper/my-helper.sh"
  helperProcess.command = [helperPath, command, ...args]
  helperProcess.running = true
}
```

## HTTP/REST API Pattern

```qml
function makeRequest(method, endpoint, data, callback) {
  if (!connected && method !== "test") return

  const xhr = new XMLHttpRequest()

  xhr.onreadystatechange = () => {
    if (xhr.readyState === XMLHttpRequest.DONE) {
      let response = null
      try {
        if (xhr.status >= 200 && xhr.status < 300 && xhr.responseText) {
          response = JSON.parse(xhr.responseText)
        }
      } catch (e) {
        Logger.e("MyPlugin", "JSON parse error:", e)
      }

      if (callback) {
        callback(xhr.status, response)
      }
    }
  }

  xhr.onerror = () => {
    Logger.e("MyPlugin", "Request failed:", endpoint)
    if (callback) callback(0, null)
  }

  xhr.open(method, apiUrl + endpoint)
  xhr.setRequestHeader("Authorization", "Bearer " + apiToken)
  xhr.setRequestHeader("Content-Type", "application/json")
  xhr.timeout = 10000

  if (data) {
    xhr.send(JSON.stringify(data))
  } else {
    xhr.send()
  }
}

function fetchData() {
  makeRequest("GET", "/api/status", null, (status, data) => {
    if (status === 200 && data) {
      items = data.items || []
      currentState = data.state
    } else {
      Logger.w("MyPlugin", "Fetch failed:", status)
    }
  })
}
```

## Polling with Exponential Backoff

```qml
property int consecutiveFailures: 0
readonly property int baseInterval: 5000
readonly property int maxInterval: 60000

function calculateInterval() {
  const backoff = Math.min(
    baseInterval * Math.pow(2, Math.min(consecutiveFailures, 4)),
    maxInterval
  )
  return Math.max(baseInterval, backoff)
}

function onFetchSuccess() {
  consecutiveFailures = 0
  pollTimer.interval = calculateInterval()
}

function onFetchFailure() {
  consecutiveFailures++
  pollTimer.interval = calculateInterval()
}
```

## Connection Lifecycle

```qml
function initialize() {
  if (!apiUrl || !apiToken) {
    connected = false
    connectionError = "Not configured"
    return
  }

  testConnection()
}

function testConnection() {
  if (!apiUrl || !apiToken) return

  connecting = true
  connectionError = ""

  makeRequest("GET", "/api/ping", null, (status, data) => {
    connecting = false
    if (status === 200) {
      connected = true
      connectionError = ""
      fetchData()
    } else if (status === 401) {
      connected = false
      connectionError = "Authentication failed"
    } else {
      connected = false
      connectionError = "Connection failed: " + status
      // Retry after delay
      reconnectTimer.start()
    }
  })
}

Timer {
  id: reconnectTimer
  interval: 5000
  repeat: false
  onTriggered: testConnection()
}
```

## Optimistic Updates Pattern

```qml
// Update UI immediately, sync with backend after
function setVolume(level) {
  // Optimistic update
  currentVolume = level

  // Sync to backend
  makeRequest("POST", "/api/volume", { level }, (status) => {
    if (status !== 200) {
      // Revert on failure
      currentVolume = previousVolume
      ToastService.showError("Failed to set volume")
    }
  })
}
```
