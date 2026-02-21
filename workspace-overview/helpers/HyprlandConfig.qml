import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons

Item {
    id: root

    // Correct default values based on typical configs
    property int gapsIn: 5
    property int gapsOut: 20
    property int gapsWorkspaces: 0
    property int rounding: 10
    property int borderSize: 2
    property color activeBorderColor: Color.mPrimary
    property color inactiveBorderColor: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.85)

    // Config persistence
    property int originalFollowMouse: 1
    property bool originalNoWarps: false
    property bool hasFetchedOriginals: false

    function enableDragMode() {
        runKeyword("input:follow_mouse 0");
        runKeyword("cursor:no_warps 1");
    }

    function disableDragMode() {
        runKeyword("input:follow_mouse " + root.originalFollowMouse);
        runKeyword("cursor:no_warps " + (root.originalNoWarps ? "1" : "0"));
    }

    function runKeyword(keyword) {
        var args = keyword.split(" ");
        var cmd = ["hyprctl", "keyword"];
        for (var i = 0; i < args.length; i++) {
            if (args[i] !== "") cmd.push(args[i]);
        }
        keywordProcessComponent.createObject(root, { "command": cmd }).running = true;
    }

    Component {
        id: keywordProcessComponent
        Process {
            onRunningChanged: if (!running) destroy()
        }
    }

    function parseHyprColor(str) {
        if (!str) return "transparent";
        str = str.toString().trim();
        
        // Handle rgba(RRGGBBAA) -> #AARRGGBB
        if (str.startsWith("rgba(")) {
            var hex = str.substring(5, str.length - 1);
            if (hex.length === 8) {
                // Hyprland uses RRGGBBAA in rgba() but Qt wants AARRGGBB or #RRGGBBAA?
                // Actually #RRGGBBAA is RRGGBBAA in some contexts, but let's be safe.
                // Qt's #RRGGBBAA is actually RRGGBBAA.
                return "#" + hex;
            }
            return "#" + hex;
        }

        // Handle rgb(RRGGBB) -> #RRGGBB
        if (str.startsWith("rgb(")) {
            return "#" + str.substring(4, str.length - 1);
        }

        // Handle 0x...
        if (str.startsWith("0x") || str.startsWith("0X")) {
            var hex = str.substring(2);
            return "#" + hex;
        }
        return str;
    }

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
        fetchOption("general:col.active_border", (v) => root.activeBorderColor = parseHyprColor(v))
        fetchOption("general:col.inactive_border", (v) => root.inactiveBorderColor = parseHyprColor(v))

        // Capture originals once
        if (!hasFetchedOriginals) {
            fetchOption("input:follow_mouse", (v) => {
                root.originalFollowMouse = v;
                root.hasFetchedOriginals = true;
            })
            fetchOption("cursor:no_warps", (v) => {
                root.originalNoWarps = !!v;
            })
        }
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
                        if (json.str !== undefined && json.str !== "") result(json.str);
                        else if (json.int !== undefined) result(json.int);
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
