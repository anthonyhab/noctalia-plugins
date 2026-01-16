# Noctalia API Reference

Reference for Noctalia-specific APIs and Services.

## Plugin API Properties
```qml
// Available on pluginApi:
pluginApi.pluginId        // Plugin ID string
pluginApi.pluginDir       // Full path to plugin directory
pluginApi.pluginSettings  // User settings object
pluginApi.manifest        // Plugin manifest object
pluginApi.mainInstance    // Reference to Main.qml instance
```

## Panel Management
```qml
// Open plugin panel
Button {
    text: "Open Panel"
    onClicked: {
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.openPanel(screen, this)  // 'this' for positioning
        })
    }
}

// Toggle panel
pluginApi.togglePanel(screen, buttonItem)

// Close panel
pluginApi.closePanel(screen)

// Check if panel is open
property bool isPanelOpen: pluginApi.panelOpenScreen !== null
```

## Logger
```qml
import qs.Commons

// Debug (only when NOCTALIA_DEBUG=1)
Logger.d("PluginId", "Debug message", someValue)

// Info (always visible)
Logger.i("PluginId", "Info message")

// Warning
Logger.w("PluginId", "Warning message")

// Error
Logger.e("PluginId", "Error message", error)
```

## ToastService
```qml
import qs.Services.UI

// Show notice (info)
ToastService.showNotice("Title", "Message body")

// Show error
ToastService.showError("Title", "Error description")

// With action button
ToastService.showNotice(
    "Update Available",
    "New version ready",
    "plugin",  // icon
    5000,      // duration ms
    "Update",  // button text
    function() { /* action */ }
)
```

## PanelService
```qml
import qs.Services.UI

// Get a panel by name and screen
var panel = PanelService.getPanel("settingsPanel", screen)
panel.open()
panel.close()
panel.toggle()
```

## Settings (Global)
```qml
import qs.Commons

// Access shell settings
Settings.data.bar.position      // "top", "bottom", "left", "right"
Settings.data.ui.fontDefault    // Default font family
Settings.data.general.username  // User's display name
Settings.isDebug                // Debug mode enabled
Settings.configDir              // ~/.config/noctalia/
Settings.cacheDir               // ~/.cache/noctalia/
```

## IPC (Inter-Process Communication)

### Creating an IPC Handler
Plugins can register IPC handlers to respond to external commands:
```qml
import Quickshell

IpcHandler {
    target: "myPlugin"

    function toggle() {
        // Called via: qs ipc call myPlugin toggle
        isEnabled = !isEnabled
    }

    function setValue(value: string) {
        // Called via: qs ipc call myPlugin setValue "hello"
        currentValue = value
    }

    function getData(): string {
        // Return values work too
        return JSON.stringify({ status: "ok" })
    }
}
```

### Calling IPC from Command Line
```bash
# Toggle
qs ipc call myPlugin toggle

# Call with argument
qs ipc call myPlugin setValue "new value"

# Get return value
qs ipc call myPlugin getData
```
