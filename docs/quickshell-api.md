# Quickshell API Reference

Reference for the Quickshell framework components used in Noctalia.

## ShellRoot
The root component for Quickshell applications:
```qml
import Quickshell

ShellRoot {
    // Your shell components here
}
```

## Singletons
Create singleton services accessible throughout the shell:
```qml
pragma Singleton

import Quickshell

Singleton {
    id: root

    property int counter: 0

    function increment() {
        counter++
    }
}
```

## Process Execution
```qml
import Quickshell.Io

Process {
    id: myProcess
    command: ["ls", "-la", "/home"]
    stdout: StdioCollector {}

    onExited: function(exitCode) {
        if (exitCode === 0) {
            console.log("Output:", stdout.text)
        }
    }
}

// Start the process
Component.onCompleted: myProcess.running = true

// Or use execDetached for fire-and-forget
Quickshell.execDetached(["notify-send", "Hello"])
```

## FileView
Read and watch files:
```qml
import Quickshell.Io

FileView {
    id: configFile
    path: "/path/to/config.json"
    watchChanges: true

    onLoaded: {
        var data = JSON.parse(text())
        console.log("Loaded:", data)
    }

    onFileChanged: {
        reload()
    }
}
```

## Environment Variables
```qml
// Read environment variable
var home = Quickshell.env("HOME")
var debug = Quickshell.env("NOCTALIA_DEBUG") === "1"
```
