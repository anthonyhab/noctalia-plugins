import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "DispatchCompat.js" as DispatchCompat
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
  property bool originalWarpOnChangeWorkspace: false
  property bool originalWarpOnToggleSpecial: false
  property bool originalAlwaysFollowOnDnd: false
  property bool hasFetchedOriginals: false
  property int originalFetchPending: 0
  // Scroll layout direction per workspace id (populated from hyprctl workspacerules -j)
  property var workspaceScrollDirections: ({})

  function enableDragMode() {
    runKeyword("input:follow_mouse 0");
    runKeyword("cursor:no_warps 1");
    runKeyword("cursor:warp_on_change_workspace 0");
    runKeyword("cursor:warp_on_toggle_special 0");
    runKeyword("misc:always_follow_on_dnd 0");
  }

  function disableDragMode() {
    runKeyword("input:follow_mouse " + root.originalFollowMouse);
    runKeyword("cursor:no_warps " + (root.originalNoWarps ? "1" : "0"));
    runKeyword("cursor:warp_on_change_workspace " + (root.originalWarpOnChangeWorkspace ? "1" : "0"));
    runKeyword("cursor:warp_on_toggle_special " + (root.originalWarpOnToggleSpecial ? "1" : "0"));
    runKeyword("misc:always_follow_on_dnd " + (root.originalAlwaysFollowOnDnd ? "1" : "0"));
  }

  function runKeyword(keyword) {
    var luaConfig = DispatchCompat.keywordToLuaConfig("keyword " + keyword);
    if (luaConfig === "")
      return;
    keywordProcessComponent.createObject(root, {
                                           "command": ["hyprctl", "eval", luaConfig]
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
    captureOriginalPointerOptions();
  }

  function captureOriginalPointerOptions() {
    if (hasFetchedOriginals || originalFetchPending > 0)
      return;

    originalFetchPending = 5;
    fetchOptionWithDefault("input:follow_mouse", 1, v => {
      root.originalFollowMouse = v;
      root.completeOriginalFetch("input:follow_mouse");
    });
    fetchOptionWithDefault("cursor:no_warps", false, v => {
      root.originalNoWarps = !!v;
      root.completeOriginalFetch("cursor:no_warps");
    });
    fetchOptionWithDefault("cursor:warp_on_change_workspace", false, v => {
      root.originalWarpOnChangeWorkspace = !!v;
      root.completeOriginalFetch("cursor:warp_on_change_workspace");
    });
    fetchOptionWithDefault("cursor:warp_on_toggle_special", false, v => {
      root.originalWarpOnToggleSpecial = !!v;
      root.completeOriginalFetch("cursor:warp_on_toggle_special");
    });
    fetchOptionWithDefault("misc:always_follow_on_dnd", false, v => {
      root.originalAlwaysFollowOnDnd = !!v;
      root.completeOriginalFetch("misc:always_follow_on_dnd");
    });
  }

  function completeOriginalFetch(optionName) {
    originalFetchPending = Math.max(0, originalFetchPending - 1);
    if (originalFetchPending === 0) {
      hasFetchedOriginals = true;
      Logger.d("HyprOverview", "Captured pointer options after " + optionName);
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

  function fetchOptionWithDefault(optionName, fallbackValue, callback) {
    var proc = processComponent.createObject(root, {
                                               "option": optionName,
                                               "fallbackValue": fallbackValue
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
      property var fallbackValue: null
      property bool hasValue: false

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
          if (!hasValue && fallbackValue !== null) {
            hasValue = true;
            result(fallbackValue);
          }
          destroy();
        }
      }

      stdout: SplitParser {
        onRead: function (data) {
          try {
            var json = JSON.parse(data);
            // Hyprland returns: { "option": "...", "set": true, "str": "...", "int": 10, "float": 0.0, "data": "..." }
            if (json.str !== undefined && json.str !== "") {
              hasValue = true;
              result(json.str);
            } else if (json.bool !== undefined) {
              hasValue = true;
              result(json.bool);
            } else if (json.int !== undefined) {
              hasValue = true;
              result(json.int);
            } else if (json.float !== undefined) {
              hasValue = true;
              result(json.float);
            }
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
