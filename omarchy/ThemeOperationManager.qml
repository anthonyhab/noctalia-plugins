import QtQuick
import Quickshell
import qs.Commons

// Central coordinator for theme operations with state machine
Item {
    id: root

    // State machine enum
    enum State {
        Idle,
        Initiating,
        SettingTheme,
        ApplyingScheme,
        Complete,
        Error
    }

    // Current operation state
    property int state: ThemeOperationManager.State.Idle
    property string currentThemeName: ""
    property string targetThemeName: ""
    property int operationId: 0
    property bool hasError: false
    property string errorMessage: ""
    // Timing metrics
    property var operationStartTime: null
    property var operationEndTime: null

    // Signals
    signal operationStarted(string themeName)
    signal operationCompleted(string themeName)
    signal operationFailed(string themeName, string error)
    signal stateChanged(int newState)

    function startThemeChange(themeName, asyncSetter, schemeApplier, callback) {
        // Continue anyway - theme-set will handle it

        if (state !== ThemeOperationManager.State.Idle) {
            Logger.w("ThemeOperationManager", "Operation already in progress, queueing");
            // Debounce: cancel previous and start new
            cancelCurrentOperation();
        }
        const opId = ++operationId;
        targetThemeName = themeName;
        hasError = false;
        errorMessage = "";
        operationStartTime = Date.now();
        setState(ThemeOperationManager.State.Initiating);
        operationStarted(themeName);
        // Phase 1: UI updates (instant)
        currentThemeName = themeName;
        // Phase 2: Parallel operations
        setState(ThemeOperationManager.State.SettingTheme);
        // Start async theme-set (fire and forget)
        const themeSetPromise = asyncSetter.setTheme(themeName, opId);
        // Apply scheme instantly from cache
        setState(ThemeOperationManager.State.ApplyingScheme);
        const schemeResult = schemeApplier.applyScheme(themeName);
        if (!schemeResult.success)
            Logger.w("ThemeOperationManager", "Cache miss for theme:", themeName);

        // Phase 3: Handle completion
        themeSetPromise.then(function(result) {
            if (result.operationId !== operationId) {
                Logger.d("ThemeOperationManager", "Stale operation completion ignored");
                return ;
            }
            operationEndTime = Date.now();
            const duration = operationEndTime - operationStartTime;
            Logger.i("ThemeOperationManager", "Operation completed in", duration, "ms");
            if (result.success) {
                setState(ThemeOperationManager.State.Complete);
                operationCompleted(themeName);
            } else {
                setState(ThemeOperationManager.State.Error);
                hasError = true;
                errorMessage = result.error || "Unknown error";
                operationFailed(themeName, errorMessage);
            }
            // Reset after brief delay
            Qt.callLater(function() {
                if (state === ThemeOperationManager.State.Complete || state === ThemeOperationManager.State.Error)
                    setState(ThemeOperationManager.State.Idle);

            });
            if (callback)
                callback(result.success);

        });
    }

    function cancelCurrentOperation() {
        if (state === ThemeOperationManager.State.Idle)
            return ;

        Logger.i("ThemeOperationManager", "Cancelling current operation");
        operationId++; // Invalidate current operation
        setState(ThemeOperationManager.State.Idle);
        currentThemeName = "";
        targetThemeName = "";
    }

    function setState(newState) {
        if (state !== newState) {
            state = newState;
            stateChanged(newState);
            Logger.d("ThemeOperationManager", "State:", stateToString(newState));
        }
    }

    function stateToString(s) {
        switch (s) {
        case ThemeOperationManager.State.Idle:
            return "Idle";
        case ThemeOperationManager.State.Initiating:
            return "Initiating";
        case ThemeOperationManager.State.SettingTheme:
            return "SettingTheme";
        case ThemeOperationManager.State.ApplyingScheme:
            return "ApplyingScheme";
        case ThemeOperationManager.State.Complete:
            return "Complete";
        case ThemeOperationManager.State.Error:
            return "Error";
        default:
            return "Unknown";
        }
    }

    function isOperationInProgress() {
        return state !== ThemeOperationManager.State.Idle && state !== ThemeOperationManager.State.Complete && state !== ThemeOperationManager.State.Error;
    }

}
