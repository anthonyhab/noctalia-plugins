# QML Fundamentals Reference

This document covers core QML syntax and concepts used in Noctalia plugins.

## Imports
```qml
import QtQuick           // Core QML types (Item, Rectangle, Text, etc.)
import QtQuick.Controls  // UI controls (Button, TextField, etc.)
import QtQuick.Layouts   // Layout managers (RowLayout, ColumnLayout, etc.)
import Quickshell        // Quickshell framework
import Quickshell.Io     // Process, FileView, etc.
```

## Property Bindings
Properties in QML are reactive - when dependencies change, expressions automatically re-evaluate:
```qml
Item {
    property int baseSize: 10
    property int scaledSize: baseSize * 2  // Auto-updates when baseSize changes

    width: scaledSize
    height: scaledSize * 1.5
}
```

## Property Definitions
```qml
// Basic property
property string name: "default"

// Required property (must be set by parent)
required property var pluginApi

// Readonly property
readonly property int count: listModel.count

// Typed properties
property int number: 42
property real decimal: 3.14
property bool enabled: true
property color bgColor: "#ffffff"
property var anyType: null
property list<string> items: []
```

## Signals and Handlers
```qml
Item {
    // Define a signal
    signal clicked(string message)
    signal dataChanged()

    // Handle property changes
    onWidthChanged: console.log("Width changed to:", width)

    // Handle custom signals
    onClicked: function(msg) {
        console.log("Clicked with message:", msg)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: parent.clicked("Hello!")
    }
}
```

## Functions
```qml
Item {
    function calculate(a, b) {
        return a + b
    }

    // Arrow functions
    property var double: (n) => n * 2

    // Async pattern with callbacks
    function loadData(callback) {
        // ... async operation
        callback(result)
    }
}
```

## Component Lifecycle
```qml
Item {
    Component.onCompleted: {
        // Called after component is fully created
        console.log("Component ready")
        initializePlugin()
    }

    Component.onDestruction: {
        // Called before component is destroyed
        cleanup()
    }
}
```

## Common Visual Types

```qml
// Rectangle - basic container with background
Rectangle {
    width: 100
    height: 50
    color: "#3498db"
    radius: 8
    border.width: 1
    border.color: "#2980b9"
}

// Text - display text
Text {
    text: "Hello World"
    font.pixelSize: 14
    font.bold: true
    color: "#333"
    elide: Text.ElideRight
    wrapMode: Text.WordWrap
}

// Image
Image {
    source: "icon.png"
    sourceSize: Qt.size(24, 24)
    fillMode: Image.PreserveAspectFit
}

// MouseArea - clickable region
MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: doSomething()
    onEntered: hovering = true
    onExited: hovering = false
}
```

## Layouts

```qml
// Column layout
ColumnLayout {
    spacing: 8

    Text { text: "Item 1" }
    Text { text: "Item 2" }
    Text {
        text: "Stretched"
        Layout.fillWidth: true
    }
}

// Row layout
RowLayout {
    spacing: 8

    Button { text: "Left" }
    Item { Layout.fillWidth: true }  // Spacer
    Button { text: "Right" }
}

// Repeater - create multiple items from model
Repeater {
    model: ["Apple", "Banana", "Cherry"]

    delegate: Text {
        text: modelData
    }
}
```

## Loaders and Dynamic Components

```qml
// Lazy loading
Loader {
    active: shouldLoad
    sourceComponent: HeavyComponent {}

    onLoaded: {
        item.initialize()
    }
}

// Dynamic creation
Component {
    id: dynamicComponent
    Rectangle { color: "red" }
}

function createItem() {
    var obj = dynamicComponent.createObject(parent, { width: 100 })
    // Remember to destroy when done: obj.destroy()
}
```
