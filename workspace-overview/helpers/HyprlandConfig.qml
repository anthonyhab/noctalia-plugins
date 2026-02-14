import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    // Correct default values based on typical configs
    property int gapsIn: 5
    property int gapsOut: 20
    property int gapsWorkspaces: 0
    property int rounding: 10
    property int borderSize: 2

    // Helper functions need to be carefully structured because Qml doesn't support
    // dynamically creating objects with methods inside property strings easily without import issues.
    // Instead we'll use a single Process component and reuse it or just a repeater if needed.
    // Actually, simple sequential execution is safer.

    function updateConfig() {
        if (!Hyprland.valid) return;
        
        // Batch requests if possible, or just fire them off
        fetchOption("general:gaps_in", (v) => root.gapsIn = v)
        fetchOption("general:gaps_out", (v) => root.gapsOut = v)
        fetchOption("general:gaps_workspaces", (v) => root.gapsWorkspaces = v)
        fetchOption("decoration:rounding", (v) => root.rounding = v)
        fetchOption("general:border_size", (v) => root.borderSize = v)
    }

    function fetchOption(optionName, callback) {
        var proc = processComponent.createObject(root, { "option": optionName });
        proc.result.connect(callback);
        proc.running = true;
    }

    Component {
        id: processComponent
        Process {
            property string option: ""
            signal result(var value)

            command: ["hyprctl", "-j", "getoption", option]
            
            stdout: SplitParser {
                onRead: function(data) {
                    try {
                        var json = JSON.parse(data);
                        // Hyprland returns: { "option": "...", "set": true, "str": "...", "int": 10, "float": 0.0, "data": "..." }
                        if (json.int !== undefined) result(json.int);
                        else if (json.float !== undefined) result(json.float);
                    } catch (e) {
                       // ignore
                    }
                }
            }
            // Self-destruct after running
            onRunningChanged: if (!running) destroy()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                updateConfig();
            }
        }
    }


    Component.onCompleted: updateConfig()
}
