// Settings.qml - Configuration panel for Quickshell Screenshot plugin

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
    id: root
    
    property var pluginApi: null
    
    color: "transparent"
    
    // Shortcut row component definition - must be defined before use
    component ShortcutRow: RowLayout {
        property string shortcut: ""
        property string description: ""
        
        spacing: 12
        
        Rectangle {
            color: "#2A2A2A"
            radius: 4
            height: 28
            Layout.minimumWidth: shortcutText.width + 16
            
            Text {
                id: shortcutText
                text: shortcut
                color: "#00D9FF"
                font.pixelSize: 12
                font.family: "monospace"
                anchors.centerIn: parent
            }
        }
        
        Text {
            text: description
            color: "#AAAAAA"
            font.pixelSize: 12
            Layout.fillWidth: true
        }
    }
    
    // Helper function for settings
    function getSetting(key, fallback) {
        if (!pluginApi) return fallback
        var val = pluginApi?.pluginSettings?.[key]
        if (val === undefined || val === null) {
            val = pluginApi?.manifest?.metadata?.defaultSettings?.[key]
        }
        return (val === undefined || val === null) ? fallback : val
    }
    
    function setSetting(key, value) {
        if (!pluginApi) return
        var settings = pluginApi.pluginSettings || {}
        settings[key] = value
        pluginApi.pluginSettings = settings
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16
        
        // Title
        Text {
            text: "Screenshot Compare Settings"
            font.pixelSize: 24
            font.weight: Font.Bold
            color: "#FFFFFF"
        }
        
        Text {
            text: "Configure screenshot capture behavior and keyboard shortcuts"
            font.pixelSize: 14
            color: "#888888"
            Layout.bottomMargin: 10
        }
        
        // Settings card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1E1E1E"
            radius: 12
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
                
                // Visual settings group
                Text {
                    text: "Visual Settings"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                }
                
                // Show grid toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: getSetting("showGrid", true) ? "#00D9FF" : "#333333"
                        border.color: "#00D9FF"
                        border.width: 2
                        
                        Text {
                            text: "✓"
                            color: "#000000"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            anchors.centerIn: parent
                            visible: getSetting("showGrid", true)
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setSetting("showGrid", !getSetting("showGrid", true))
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 2
                        
                        Text {
                            text: "Show Grid Overlay"
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                        
                        Text {
                            text: "Display rule-of-thirds grid in selection area"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                }
                
                // Snap to windows toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: getSetting("snapToWindows", true) ? "#00D9FF" : "#333333"
                        border.color: "#00D9FF"
                        border.width: 2
                        
                        Text {
                            text: "✓"
                            color: "#000000"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            anchors.centerIn: parent
                            visible: getSetting("snapToWindows", true)
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setSetting("snapToWindows", !getSetting("snapToWindows", true))
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 2
                        
                        Text {
                            text: "Snap to Windows"
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                        
                        Text {
                            text: "Auto-snap selection to window boundaries"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#333333"
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                }
                
                // Capture behavior group
                Text {
                    text: "Capture Behavior"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                }
                
                // Copy to clipboard toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: getSetting("copyToClipboard", true) ? "#00D9FF" : "#333333"
                        border.color: "#00D9FF"
                        border.width: 2
                        
                        Text {
                            text: "✓"
                            color: "#000000"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            anchors.centerIn: parent
                            visible: getSetting("copyToClipboard", true)
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setSetting("copyToClipboard", !getSetting("copyToClipboard", true))
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 2
                        
                        Text {
                            text: "Copy to Clipboard"
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                        
                        Text {
                            text: "Automatically copy screenshots to clipboard"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                }
                
                // Open after capture toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: getSetting("openAfterCapture", false) ? "#00D9FF" : "#333333"
                        border.color: "#00D9FF"
                        border.width: 2
                        
                        Text {
                            text: "✓"
                            color: "#000000"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            anchors.centerIn: parent
                            visible: getSetting("openAfterCapture", false)
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setSetting("openAfterCapture", !getSetting("openAfterCapture", false))
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 2
                        
                        Text {
                            text: "Open After Capture"
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                        
                        Text {
                            text: "Open screenshot in default image viewer"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                }
                
                // Reset timeout setting
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        
                        Text {
                            text: "Reset Timeout"
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                        
                        Text {
                            text: "Minutes before 'before' capture expires"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                    
                    // Simple stepper control
                    RowLayout {
                        spacing: 8
                        
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 4
                            color: mouseMinus.containsMouse ? "#444444" : "#333333"
                            
                            Text {
                                text: "-"
                                color: "#FFFFFF"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                id: mouseMinus
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var current = getSetting("resetTimeoutMinutes", 5)
                                    if (current > 1) setSetting("resetTimeoutMinutes", current - 1)
                                }
                            }
                        }
                        
                        Text {
                            text: getSetting("resetTimeoutMinutes", 5)
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            Layout.minimumWidth: 30
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 4
                            color: mousePlus.containsMouse ? "#444444" : "#333333"
                            
                            Text {
                                text: "+"
                                color: "#FFFFFF"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                id: mousePlus
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var current = getSetting("resetTimeoutMinutes", 5)
                                    if (current < 30) setSetting("resetTimeoutMinutes", current + 1)
                                }
                            }
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#333333"
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                }
                
                // Keyboard shortcuts info
                Text {
                    text: "Keyboard Shortcuts"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                }
                
                ColumnLayout {
                    spacing: 8
                    
                    ShortcutRow {
                        shortcut: "SUPER + SHIFT + PRINT"
                        description: "Quick capture (uses script or saved region)"
                    }
                    
                    ShortcutRow {
                        shortcut: "SUPER + SHIFT + ALT + PRINT"
                        description: "Open region selector (pixel-perfect adjustment)"
                    }
                    
                    ShortcutRow {
                        shortcut: "Enter / Space"
                        description: "Capture at current region"
                    }
                    
                    ShortcutRow {
                        shortcut: "Escape"
                        description: "Cancel and close selector"
                    }
                    
                    ShortcutRow {
                        shortcut: "Double-click"
                        description: "Capture at current region"
                    }
                }
                
                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
