.pragma library

// Shared clamp — safe for use in QML property bindings and JS helpers.
function clamp(value, minValue, maxValue) {
    if (value < minValue)
        return minValue
    if (value > maxValue)
        return maxValue
    return value
}

// Safe numeric coercion — returns fallback for NaN / non-finite values.
function toNumber(value, fallback) {
    var parsed = Number(value)
    if (!isFinite(parsed))
        return fallback
    return parsed
}

// Canonical getSetting — checks pluginSettings then manifest defaultSettings.
// Pass pluginApi as first argument so this can be shared between Main.qml and Settings.qml.
function getSetting(pluginApi, key, fallback) {
    if (!pluginApi)
        return fallback
    try {
        var val = pluginApi.pluginSettings && pluginApi.pluginSettings[key]
        if (val === undefined || val === null)
            val = pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings && pluginApi.manifest.metadata.defaultSettings[key]
        return (val === undefined || val === null) ? fallback : val
    } catch (e) {
        return fallback
    }
}
