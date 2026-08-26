.pragma library

var TITLE_STRIP_POSITIONS = ["overlay-top", "overlay-bottom"]
var VISUAL_MODES = ["live", "simplified", "off"]
var SHADER_PRESETS = ["pixelated", "mac"]
var OBSOLETE_SETTINGS = [
    "previewMode",
    "useSimplifiedPreview",
    "showEmptyWorkspaceWallpaper",
    "emptyWorkspaceWallpaperPath",
    "specialEmptyWorkspaceWallpaperPath",
    "emptyWorkspaceWallpaperOpacity",
    "enableGlassMode",
    "glassTintStrength",
    "glassBorderOpacity",
    "enableBlur",
    "crossMonitorDragStyle"
]
var SUPPORTED_SETTINGS = [
    "rows",
    "columns",
    "scale",
    "hideEmptyRows",
    "showScratchpadWorkspaces",
    "gridSpacing",
    "position",
    "barMargin",
    "useSlideAnimation",
    "containerBorderWidth",
    "selectionBorderWidth",
    "accentColorType",
    "visualMode",
    "shaderPreset",
    "shaderPresetStrength",
    "simplifiedPixelDensity",
    "simplifiedColorDepth",
    "simplifiedSaturation",
    "simplifiedContrast",
    "showWindowTitleStrip",
    "titleStripHeight",
    "titleStripMode",
    "titleStripPosition",
    "titleStripMeta",
    "showWindowIcons",
    "colorizeWindowIcons",
    "windowIconPlacement",
    "showWorkspaceLabels",
    "workspaceLabelMode",
    "showFocusedWindowGlow",
    "showUrgencyBadge",
    "showFloatingBadge",
    "showFullscreenBadge",
    "showMonitorIndicators",
    "enableCrossMonitorDrag",
    "dimInactiveWorkspaces",
    "inactiveWorkspaceSaturation",
    "hoverLiftAmount",
    "previewCornerMode",
    "previewFixedCornerRadius",
    "useBorderGradient",
    "dragPreviewMode",
    "dragSnapThreshold",
    "retilePreviewOpacity",
    "previewWindowX",
    "previewWindowY",
    "previewWindowPositions",
    "showRowColumnGuides",
    "specialWorkspaceStyle",
    "animationProfile",
    "animationDurationMs",
    "overviewBackgroundOpacityRatio",
    "showLayoutBadge"
]

function hasOwn(obj, key) {
    return !!obj && Object.prototype.hasOwnProperty.call(obj, key)
}

function toNumber(value, fallback) {
    var parsed = Number(value)
    return isFinite(parsed) ? parsed : fallback
}

function clampNumber(value, fallback, min, max) {
    var parsed = toNumber(value, fallback)
    if (parsed < min)
        return min
    if (parsed > max)
        return max
    return parsed
}

function toInt(value, fallback) {
    var parsed = parseInt(value)
    return isNaN(parsed) ? fallback : parsed
}

function toBool(value, fallback) {
    if (value === undefined || value === null)
        return fallback

    return !!value
}

function normalizeTitleStripPosition(position) {
    var value = (position || "overlay-top").toString()
    if (value === "external")
        return "overlay-top"

    return TITLE_STRIP_POSITIONS.indexOf(value) >= 0 ? value : "overlay-top"
}

function normalizeVisualMode(mode) {
    var value = (mode || "live").toString()
    if (value === "event")
        return "simplified"

    return VISUAL_MODES.indexOf(value) >= 0 ? value : "live"
}

function normalizeShaderPreset(preset) {
    var value = (preset || "pixelated").toString()
    if (value === "classic")
        return "pixelated"
    if (value === "mac-classic")
        return "mac"

    return SHADER_PRESETS.indexOf(value) >= 0 ? value : "pixelated"
}

function removeObsoleteSettings(pluginApi) {
    if (!pluginApi || !pluginApi.pluginSettings)
        return false

    var removed = false
    if (!hasOwn(pluginApi.pluginSettings, "visualMode") && (hasOwn(pluginApi.pluginSettings, "previewMode") || hasOwn(pluginApi.pluginSettings, "useSimplifiedPreview"))) {
        pluginApi.pluginSettings.visualMode = normalizeVisualMode(getSetting(pluginApi, "previewMode", getSetting(pluginApi, "useSimplifiedPreview", false) ? "simplified" : "live"))
        removed = true
    }
    if (hasOwn(pluginApi.pluginSettings, "shaderPreset")) {
        var normalizedPreset = normalizeShaderPreset(pluginApi.pluginSettings.shaderPreset)
        if (pluginApi.pluginSettings.shaderPreset !== normalizedPreset) {
            pluginApi.pluginSettings.shaderPreset = normalizedPreset
            removed = true
        }
    }

    for (var i = 0; i < OBSOLETE_SETTINGS.length; i++) {
        var key = OBSOLETE_SETTINGS[i]
        if (hasOwn(pluginApi.pluginSettings, key)) {
            delete pluginApi.pluginSettings[key]
            removed = true
        }
    }
    return removed
}

function buildPersistedSettings(source) {
    source = source || {}
    var settings = {}
    for (var i = 0; i < SUPPORTED_SETTINGS.length; i++) {
        var key = SUPPORTED_SETTINGS[i]
        if (hasOwn(source, key) && source[key] !== undefined)
            settings[key] = source[key]
    }
    return settings
}

function getSetting(pluginApi, key, fallback) {
    if (!pluginApi)
        return fallback

    var settings = pluginApi.pluginSettings || {}
    if (hasOwn(settings, key) && settings[key] !== undefined && settings[key] !== null)
        return settings[key]

    var defaults = pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings
    if (hasOwn(defaults, key) && defaults[key] !== undefined && defaults[key] !== null)
        return defaults[key]

    return fallback
}

function normalizeSettings(pluginApi) {
    var rawVisualMode = getSetting(pluginApi, "visualMode", getSetting(pluginApi, "previewMode", getSetting(pluginApi, "useSimplifiedPreview", false) ? "simplified" : "live"))
    var visualMode = normalizeVisualMode(rawVisualMode)
    var titleStripMode = getSetting(pluginApi, "titleStripMode", getSetting(pluginApi, "showWindowTitleStrip", true) ? "auto" : "off") || "auto"
    var showMonitorIndicators = toBool(getSetting(pluginApi, "showMonitorIndicators", getSetting(pluginApi, "showMonitorBadge", false)), false)

    return {
        "rows": toInt(getSetting(pluginApi, "rows", 2), 2),
        "columns": toInt(getSetting(pluginApi, "columns", 5), 5),
        "scale": toNumber(getSetting(pluginApi, "scale", 0.16), 0.16),
        "hideEmptyRows": toBool(getSetting(pluginApi, "hideEmptyRows", true), true),
        "showScratchpadWorkspaces": toBool(getSetting(pluginApi, "showScratchpadWorkspaces", false), false),
        "gridSpacing": toInt(getSetting(pluginApi, "gridSpacing", 0), 0),
        "position": getSetting(pluginApi, "position", "top") || "top",
        "barMargin": toInt(getSetting(pluginApi, "barMargin", 0), 0),
        "useSlideAnimation": toBool(getSetting(pluginApi, "useSlideAnimation", true), true),
        "containerBorderWidth": toInt(getSetting(pluginApi, "containerBorderWidth", -1), -1),
        "selectionBorderWidth": toInt(getSetting(pluginApi, "selectionBorderWidth", -1), -1),
        "accentColorType": getSetting(pluginApi, "accentColorType", "secondary") || "secondary",
        "visualMode": visualMode,
        "shaderPreset": normalizeShaderPreset(getSetting(pluginApi, "shaderPreset", "pixelated")),
        "shaderPresetStrength": toNumber(getSetting(pluginApi, "shaderPresetStrength", 0.7), 0.7),
        "useSimplifiedPreview": visualMode === "simplified",
        "simplifiedPixelDensity": toNumber(getSetting(pluginApi, "simplifiedPixelDensity", 0.5), 0.5),
        "simplifiedColorDepth": toNumber(getSetting(pluginApi, "simplifiedColorDepth", 6), 6),
        "simplifiedSaturation": toNumber(getSetting(pluginApi, "simplifiedSaturation", 1.1), 1.1),
        "simplifiedContrast": toNumber(getSetting(pluginApi, "simplifiedContrast", 1.1), 1.1),
        "showWindowTitleStrip": titleStripMode !== "off",
        "titleStripHeight": toInt(getSetting(pluginApi, "titleStripHeight", 20), 20),
        "titleStripMode": titleStripMode,
        "titleStripPosition": normalizeTitleStripPosition(getSetting(pluginApi, "titleStripPosition", "overlay-top")),
        "titleStripMeta": getSetting(pluginApi, "titleStripMeta", "class") || "class",
        "showWindowIcons": toBool(getSetting(pluginApi, "showWindowIcons", true), true),
        "colorizeWindowIcons": toBool(getSetting(pluginApi, "colorizeWindowIcons", false), false),
        "windowIconPlacement": getSetting(pluginApi, "windowIconPlacement", "center") || "center",
        "showWorkspaceLabels": toBool(getSetting(pluginApi, "showWorkspaceLabels", true), true),
        "workspaceLabelMode": getSetting(pluginApi, "workspaceLabelMode", "number-name") || "number-name",
        "showFocusedWindowGlow": toBool(getSetting(pluginApi, "showFocusedWindowGlow", true), true),
        "showUrgencyBadge": toBool(getSetting(pluginApi, "showUrgencyBadge", true), true),
        "showFloatingBadge": toBool(getSetting(pluginApi, "showFloatingBadge", true), true),
        "showFullscreenBadge": toBool(getSetting(pluginApi, "showFullscreenBadge", false), false),
        "showMonitorIndicators": showMonitorIndicators,
        "enableCrossMonitorDrag": toBool(getSetting(pluginApi, "enableCrossMonitorDrag", true), true),
        "dimInactiveWorkspaces": toNumber(getSetting(pluginApi, "dimInactiveWorkspaces", 0.35), 0.35),
        "inactiveWorkspaceSaturation": toNumber(getSetting(pluginApi, "inactiveWorkspaceSaturation", 0.75), 0.75),
        "hoverLiftAmount": toInt(getSetting(pluginApi, "hoverLiftAmount", 4), 4),
        "previewCornerMode": getSetting(pluginApi, "previewCornerMode", "hyprland") || "hyprland",
        "previewFixedCornerRadius": toInt(getSetting(pluginApi, "previewFixedCornerRadius", 10), 10),
        "useBorderGradient": toBool(getSetting(pluginApi, "useBorderGradient", true), true),
        "dragPreviewMode": getSetting(pluginApi, "dragPreviewMode", "smart") || "smart",
        "dragSnapThreshold": clampNumber(getSetting(pluginApi, "dragSnapThreshold", 0.42), 0.42, 0.42, 0.49),
        "retilePreviewOpacity": toNumber(getSetting(pluginApi, "retilePreviewOpacity", 0.55), 0.55),
        "previewWindowX": toNumber(getSetting(pluginApi, "previewWindowX", -1), -1),
        "previewWindowY": toNumber(getSetting(pluginApi, "previewWindowY", -1), -1),
        "previewWindowPositions": getSetting(pluginApi, "previewWindowPositions", ({})) || ({}),
        "showRowColumnGuides": toBool(getSetting(pluginApi, "showRowColumnGuides", false), false),
        "specialWorkspaceStyle": getSetting(pluginApi, "specialWorkspaceStyle", "pill") || "pill",
        "animationProfile": getSetting(pluginApi, "animationProfile", "hyprlike") || "hyprlike",
        "animationDurationMs": toInt(getSetting(pluginApi, "animationDurationMs", 200), 200),
        "overviewBackgroundOpacityRatio": toNumber(getSetting(pluginApi, "overviewBackgroundOpacityRatio", 1), 1),
        "showLayoutBadge": toBool(getSetting(pluginApi, "showLayoutBadge", true), true)
    }
}
