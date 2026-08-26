// qmllint disable signal-handler-parameters
import QtQuick
import Quickshell.Io
import "OmarchyCommands.js" as OmarchyCommands
import qs.Commons

// Non-blocking theme-set wrapper with Promise-like API
Item {
  id: root

  property string themeSetCommand: ""
  property string legacyThemeSetCommand: ""
  property string omarchyPath: ""
  property int timeoutMs: 3000
  // Current operation tracking
  property var currentOperation: null
  property int currentOperationId: 0

  function setTheme(themeName, operationId) {
    const deferred = createDeferred();
    currentOperation = deferred;
    currentOperationId = operationId;
    if (!themeName) {
      Qt.callLater(function () {
        deferred.resolve({
                           "success": false,
                           "error": "No theme name provided",
                           "operationId": operationId
                         });
      });
      return deferred.promise;
    }
    // Determine which command to use.
    // themeSetCommand is treated as an executable path, not a shell snippet.
    // Priority: 1) user-configured themeSetCommand, 2) Omarchy dispatcher,
    // 3) legacy direct binary fallback.
    const command = (themeSetCommand || "").trim();
    Logger.i("AsyncThemeSetter", "Starting theme-set:", themeName);
    if (command) {
      // Start process by invoking the configured executable directly and passing the
      // selected theme name as the final argument.
      themeSetProcess.command = [command, themeName];
    } else {
      const legacyCommand = (legacyThemeSetCommand || "").trim();
      themeSetProcess.command = OmarchyCommands.themeSetFallbackCommand(themeName, omarchyPath, legacyCommand);
    }
    themeSetProcess.running = true;
    // Start timeout timer
    timeoutTimer.start();
    return deferred.promise;
  }

  function handleProcessExit(code) {
    timeoutTimer.stop();
    const success = (code === 0);
    const error = success ? "" : "Process exited with code: " + code;
    Logger.i("AsyncThemeSetter", "Process exited:", code, "success:", success);
    completeCurrentOperation(success, error);
  }

  function completeCurrentOperation(success, error) {
    if (!currentOperation)
      return;

    const result = {
      "success": success,
      "error": error,
      "operationId": currentOperationId
    };
    const deferred = currentOperation;
    currentOperation = null;
    Qt.callLater(function () {
      deferred.resolve(result);
    });
  }

  function cancelOperation() {
    if (!currentOperation)
      return;

    Logger.d("AsyncThemeSetter", "Cancelling operation:", currentOperationId);
    timeoutTimer.stop();
    if (themeSetProcess.running)
      themeSetProcess.running = false;

    completeCurrentOperation(false, "Cancelled");
  }

  // Simple Promise-like implementation for QML
  function createDeferred() {
    var callbacks = [];
    var resolved = false;
    var resolvedValue = null;
    var promise = {
      "then": function (callback) {
        if (resolved)
          Qt.callLater(function () {
            callback(resolvedValue);
          });
        else
          callbacks.push(callback);
        return promise;
      }
    };
    return {
      "promise": promise,
      "resolve": function (value) {
        if (resolved)
          return;

        resolved = true;
        resolvedValue = value;
        callbacks.forEach(function (cb) {
          Qt.callLater(function () {
            cb(value);
          });
        });
      }
    };
  }

  // Internal process
  Process {
    id: themeSetProcess

    running: false
    onExited: function (code) {
      handleProcessExit(code);
    }
  }

  Timer {
    id: timeoutTimer

    interval: timeoutMs
    repeat: false
    onTriggered: {
      Logger.w("AsyncThemeSetter", "Theme-set timeout, killing process");
      if (themeSetProcess.running)
        themeSetProcess.running = false;

      completeCurrentOperation(false, "Timeout after " + timeoutMs + "ms");
    }
  }
}
