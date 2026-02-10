import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Non-blocking theme-set wrapper with Promise-like API
Item {
    id: root

    property string themeSetCommand: ""
    property int timeoutMs: 3000
    property bool useFastScript: false
    // Current operation tracking
    property var currentOperation: null
    property int currentOperationId: 0

    function setTheme(themeName, operationId) {
        const deferred = createDeferred();
        currentOperation = deferred;
        currentOperationId = operationId;
        if (!themeName) {
            Qt.callLater(function() {
                deferred.resolve({
                    "success": false,
                    "error": "No theme name provided",
                    "operationId": operationId
                });
            });
            return deferred.promise;
        }
        // Determine which command to use
        // Priority: 1) User-configured themeSetCommand, 2) Fast script (if explicitly enabled)
        let command = (themeSetCommand || "").trim();
        // Only try fast script if no custom command is configured and fast script is enabled
        if (!command && useFastScript) {
            const fastPath = getFastScriptPath();
            command = fastPath;
        }
        if (!command) {
            Qt.callLater(function() {
                deferred.resolve({
                    "success": false,
                    "error": "No theme-set command configured",
                    "operationId": operationId
                });
            });
            return deferred.promise;
        }
        Logger.i("AsyncThemeSetter", "Starting theme-set:", themeName);
        // Start process
        const invokeScript = "cmd=\"$1\"; theme=\"$2\"; eval \"set -- $cmd\"; \"$@\" \"$theme\"";
        themeSetProcess.command = ["sh", "-c", invokeScript, "--", command, themeName];
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
            return ;

        const result = {
            "success": success,
            "error": error,
            "operationId": currentOperationId
        };
        const deferred = currentOperation;
        currentOperation = null;
        Qt.callLater(function() {
            deferred.resolve(result);
        });
    }

    function cancelOperation() {
        if (!currentOperation)
            return ;

        Logger.d("AsyncThemeSetter", "Cancelling operation:", currentOperationId);
        timeoutTimer.stop();
        if (themeSetProcess.running)
            themeSetProcess.running = false;

        completeCurrentOperation(false, "Cancelled");
    }

    function getFastScriptPath() {
        const home = Quickshell.env("HOME") || "";
        return home + "/.local/bin/omarchy-theme-set-fast";
    }

    // Simple Promise-like implementation for QML
    function createDeferred() {
        var callbacks = [];
        var resolved = false;
        var resolvedValue = null;
        var promise = {
            "then": function(callback) {
                if (resolved)
                    Qt.callLater(function() {
                    callback(resolvedValue);
                });
                else
                    callbacks.push(callback);
                return promise;
            }
        };
        return {
            "promise": promise,
            "resolve": function(value) {
                if (resolved)
                    return ;

                resolved = true;
                resolvedValue = value;
                callbacks.forEach(function(cb) {
                    Qt.callLater(function() {
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
        onExited: function(code) {
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
