import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons

Item {
  // Helper functions need to be carefully structured because Qml doesn't support
  // dynamically creating objects with methods inside property strings easily without import issues.
  // Instead we'll use a single Process component and reuse it or just a repeater if needed.
  // Actually, simple sequential execution is safer.

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
  // Scroll layout direction per workspace id (populated from hyprctl workspacerules -j)
  property var workspaceScrollDirections: ({})

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
      if (args[i] !== "")
        cmd.push(args[i]);
    }
    keywordProcessComponent.createObject(root, {
                                           "command": cmd
                                         }).running = true;
  }

  function parseHyprColor(str) {
    if (!str)
      return "transparent";

    var value = str.toString().trim();
    // Hyprland active borders can be gradients, e.g.
    // "rgba(cba6f7ff) rgba(89b4faff) 45deg". We resolve the first stop.
    var rgbaMatch = value.match(/rgba\(([0-9a-fA-F]{8})\)/);
    if (rgbaMatch && rgbaMatch[1])
      return "#" + rgbaMatch[1];

    var rgbMatch = value.match(/rgb\(([0-9a-fA-F]{6})\)/);
    if (rgbMatch && rgbMatch[1])
      return "#" + rgbMatch[1];

    var zeroXMatch = value.match(/0x([0-9a-fA-F]{6,8})/);
    if (zeroXMatch && zeroXMatch[1])
      return "#" + zeroXMatch[1];

    var hashMatch = value.match(/#([0-9a-fA-F]{6,8})/);
    if (hashMatch && hashMatch[1])
      return "#" + hashMatch[1];

    var token = value.split(/\s+/)[0];
    if (token && token !== "")
      return token;

    return "transparent";
  }

  function updateConfig() {
    if (!Hyprland.valid)
      return;

    // Batch requests if possible, or just fire them off
    fetchOption("general:gaps_in", v => {
                  return root.gapsIn = v;
                });
    fetchOption("general:gaps_out", v => {
                  return root.gapsOut = v;
                });
    fetchOption("general:gaps_workspaces", v => {
                  return root.gapsWorkspaces = v;
                });
    fetchOption("decoration:rounding", v => {
                  return root.rounding = v;
                });
    fetchOption("general:border_size", v => {
                  return root.borderSize = v;
                });
    fetchOption("general:col.active_border", v => {
                  return root.activeBorderColor = parseHyprColor(v);
                });
    fetchOption("general:col.inactive_border", v => {
                  return root.inactiveBorderColor = parseHyprColor(v);
                });
    // Capture originals once
    if (!hasFetchedOriginals) {
      fetchOption("input:follow_mouse", v => {
                    root.originalFollowMouse = v;
                    root.hasFetchedOriginals = true;
                  });
      fetchOption("cursor:no_warps", v => {
                    root.originalNoWarps = !!v;
                  });
    }
  }

  function fetchScrollDirections() {
    var proc = workspaceRulesComponent.createObject(root);
    var timer = fetchTimeoutComponent.createObject(root, {
                                                     "proc": proc
                                                   });
    proc.timeoutTimer = timer;
    proc.running = true;
  }

  function fetchOption(optionName, callback) {
    var proc = processComponent.createObject(root, {
                                               "option": optionName
                                             });
    var timer = fetchTimeoutComponent.createObject(root, {
                                                     "proc": proc
                                                   });
    proc.timeoutTimer = timer;
    proc.result.connect(callback);
    proc.running = true;
  }

  Component.onCompleted: {
    updateConfig();
    fetchScrollDirections();
  }

  Component {
    id: keywordProcessComponent

    Process {
      onRunningChanged: {
        if (!running) {
          destroy();
        }
      }
    }
  }

  // Timeout guard — created alongside each fetchOption process.
  // Holds a reference to the process and kills it if hyprctl doesn't respond within 3s.
  Component {
    id: fetchTimeoutComponent

    Timer {
      property var proc: null

      interval: 3000
      repeat: false
      running: false
      onTriggered: {
        if (proc && proc.running)
          proc.running = false;
        destroy();
      }
    }
  }

  Component {
    id: processComponent

    Process {
      property string option: ""
      property var timeoutTimer: null

      signal result(var value)

      command: ["hyprctl", "-j", "getoption", option]
      onRunningChanged: {
        if (running) {
          if (timeoutTimer)
            timeoutTimer.start();
        } else {
          if (timeoutTimer) {
            timeoutTimer.stop();
            timeoutTimer.destroy();
            timeoutTimer = null;
          }
          destroy();
        }
      }

      stdout: SplitParser {
        onRead: function (data) {
          try {
            var json = JSON.parse(data);
            // Hyprland returns: { "option": "...", "set": true, "str": "...", "int": 10, "float": 0.0, "data": "..." }
            if (json.str !== undefined && json.str !== "")
              result(json.str);
            else if (json.int !== undefined)
              result(json.int);
            else if (json.float !== undefined)
              result(json.float);
          } catch (e) {
            Logger.w("HyprOverview", "fetchOption parse error:", e);
          }
        }
      }
    }
  }

  // Parses hyprctl workspacerules -j to extract scroll direction per workspace id.
  Component {
    id: workspaceRulesComponent

    Process {
      property var timeoutTimer: null

      command: ["hyprctl", "workspacerules", "-j"]
      onRunningChanged: {
        if (running) {
          if (timeoutTimer)
            timeoutTimer.start();
        } else {
          if (timeoutTimer) {
            timeoutTimer.stop();
            timeoutTimer.destroy();
            timeoutTimer = null;
          }
          destroy();
        }
      }

      stdout: StdioCollector {
        id: rulesCollector

        onStreamFinished: {
          try {
            var rules = JSON.parse(rulesCollector.text);
            var dirMap = {};
            for (var i = 0; i < rules.length; i++) {
              var rule = rules[i];
              // workspaceString may be "1", "2", or "w[3]" bracket notation.
              var wsStr = (rule.workspaceString || rule.workspace || "").toString();
              var bracketMatch = wsStr.match(/w\[(\d+)\]/);
              var wsId = parseInt(bracketMatch ? bracketMatch[1] : wsStr);
              // Fallback chain for scroll direction field name across Hyprland versions.
              var dir = (rule.layoutopts && rule.layoutopts["scroll:direction"]) || rule.direction || rule.scrollDirection || "";
              if (!isNaN(wsId) && wsId > 0 && dir !== "")
                dirMap[wsId] = dir;
            }
            root.workspaceScrollDirections = dirMap;
          } catch (e) {
            Logger.w("HyprOverview", "scroll directions parse error:", e);
          }
        }
      }
    }
  }

  Connections {
    function onRawEvent(event) {
      if (event.name === "configreloaded") {
        updateConfig();
        fetchScrollDirections();
      }
    }

    target: Hyprland
  }
}
