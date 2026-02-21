import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "components"
import "helpers"
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    readonly property var defaultSettings: (pluginApi && pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings) || ({
    })
    readonly property var pluginMain: pluginApi && pluginApi.mainInstance
    // Local state
    property int gridRows: 2
    property int gridColumns: 5
    property real gridScale: 0.16
    property bool hideEmptyRows: true
    property bool showScratchpadWorkspaces: false
    property int gridSpacing: 0
    property string overviewPosition: "top"
    property int barMargin: 0
    property bool useSlideAnimation: true
    property int containerBorderWidth: -1
    property int selectionBorderWidth: -1
    property string accentColorType: "secondary"
    property string visualMode: "live"
    property string shaderPreset: "classic"
    property real shaderPresetStrength: 0.7
    property bool useSimplifiedPreview: (pluginMain && pluginMain.useSimplifiedPreview) || false
    property real overviewBackgroundOpacityRatio: (pluginMain && pluginMain.overviewBackgroundOpacityRatio) || 1.0
    property bool showWindowTitleStrip: true
    property int titleStripHeight: 20
    property string titleStripMode: "auto"
    property string titleStripMeta: "class"
    property bool showWindowIcons: true
    property bool showWorkspaceLabels: true
    property string workspaceLabelMode: "number-name"
    property bool showFocusedWindowGlow: true
    property bool showUrgencyBadge: true
    property bool showFloatingBadge: true
    property bool showFullscreenBadge: false
    property bool showMonitorBadge: false
    property real dimInactiveWorkspaces: 0.35
    property real inactiveWorkspaceSaturation: 0.75
    property int hoverLiftAmount: 4
    property string previewCornerMode: "hyprland"
    property int previewFixedCornerRadius: 10
    property bool useBorderGradient: true
    property string dragPreviewMode: "smart"
    property real dragSnapThreshold: 0.33
    property real retilePreviewOpacity: 0.55
    property string animationProfile: "hyprlike"
    property int animationDurationMs: 200
    property bool showRowColumnGuides: false
    property string specialWorkspaceStyle: "pill"
    property real simplifiedPixelDensity: 0.5
    property real simplifiedColorDepth: 6
    property real simplifiedSaturation: 1.1
    property real simplifiedContrast: 1.1
    // Get primary screen info for predictive fit calculation
    readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenWidth: primaryScreen ? primaryScreen.width : 1920
    readonly property real screenHeight: primaryScreen ? primaryScreen.height : 1080
    readonly property real screenScale: primaryScreen ? (primaryScreen.scale || 1) : 1
    readonly property real barHeightEstimate: 40
    readonly property real marginXL: Style.marginXL
    readonly property real marginM: Style.marginM
    readonly property real barAwareMargin: {
        var pos = overviewPosition;
        if (pos === "top" || pos === "bottom")
            return marginXL + barHeightEstimate + marginM;

        return marginXL;
    }
    readonly property real availableWidth: (screenWidth / screenScale) - barAwareMargin * 2
    readonly property real availableHeight: (screenHeight / screenScale) - barAwareMargin * 2
    readonly property real predictedCellWidth: (screenWidth / screenScale) * gridScale
    readonly property real predictedCellHeight: (screenHeight / screenScale) * gridScale
    readonly property real workspaceSpacing: gridSpacing
    readonly property real padding: 40
    readonly property real predictedGridWidth: gridColumns * predictedCellWidth + (gridColumns - 1) * workspaceSpacing + padding
    readonly property real predictedGridHeight: gridRows * predictedCellHeight + (gridRows - 1) * workspaceSpacing + padding
    readonly property real predictedFitScale: Math.min(1, Math.min(availableWidth / Math.max(1, predictedGridWidth), availableHeight / Math.max(1, predictedGridHeight)))
    readonly property bool willRequireFitScaling: predictedFitScale < 0.999
    readonly property var previewWindows: {
        if (typeof ToplevelManager === "undefined" || !ToplevelManager || !ToplevelManager.toplevels)
            return [];

        var source = ToplevelManager.toplevels.values;
        if (!source)
            return [];

        if (Array.isArray(source))
            return source;

        if (typeof source.count === "number" && typeof source.get === "function") {
            var modelValues = [];
            for (var i = 0; i < source.count; i++) {
                var modelItem = source.get(i);
                if (modelItem)
                    modelValues.push(modelItem);

            }
            return modelValues;
        }
        if (typeof source.length === "number")
            return source;

        var mappedValues = [];
        for (var key in source) {
            if (source[key])
                mappedValues.push(source[key]);

        }
        return mappedValues;
    }
    readonly property var validPreviewWindows: {
        var result = [];
        var seen = {
        };
        for (var i = 0; i < previewWindows.length; i++) {
            var candidate = previewWindows[i];
            var key = previewWindowKey(candidate);
            if (!candidate || key === "" || seen[key])
                continue;

            seen[key] = true;
            result.push({
                "key": key,
                "toplevel": candidate
            });
        }
        return result;
    }
    property string previewWindowAddress: ""
    property string previewWorkspaceKey: ""
    readonly property var previewWindowsByKey: {
        var map = {
        };
        var list = validPreviewWindows || [];
        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            if (!item || !item.key || !item.toplevel)
                continue;

            map[item.key] = item.toplevel;
        }
        return map;
    }
    readonly property var previewWorkspaceOptions: {
        var options = [];
        var windowsMap = pluginMain && pluginMain.windowByAddress ? pluginMain.windowByAddress : {
        };
        var counts = {
        };
        var seen = {
        };
        for (var addr in windowsMap) {
            var win = windowsMap[addr];
            var wsKey = workspaceKeyForWindow(win);
            if (!wsKey)
                continue;

            counts[wsKey] = (counts[wsKey] || 0) + 1;
            if (seen[wsKey])
                continue;

            seen[wsKey] = true;
            options.push({
                "key": wsKey,
                "name": workspaceDisplayName(wsKey, counts[wsKey] || 1)
            });
        }
        var activeKey = workspaceKeyFromWorkspace(pluginMain && pluginMain.activeWorkspace);
        if (activeKey && !seen[activeKey]) {
            counts[activeKey] = counts[activeKey] || 0;
            options.push({
                "key": activeKey,
                "name": workspaceDisplayName(activeKey, counts[activeKey], true)
            });
        }
        options.sort(function(a, b) {
            var aSpecial = a.key.startsWith("special:");
            var bSpecial = b.key.startsWith("special:");
            if (aSpecial !== bSpecial)
                return aSpecial ? 1 : -1;

            if (!aSpecial) {
                var aId = parseInt(a.key.slice(3));
                var bId = parseInt(b.key.slice(3));
                return aId - bId;
            }
            return a.key.localeCompare(b.key);
        });
        for (var i = 0; i < options.length; i++) {
            var optionKey = options[i].key;
            options[i].name = workspaceDisplayName(optionKey, counts[optionKey] || 0, optionKey === activeKey);
        }
        return options;
    }
    readonly property var selectedPreviewWorkspaceOption: {
        var options = previewWorkspaceOptions || [];
        if (options.length === 0)
            return null;

        var selected = previewWorkspaceKey;
        if (!selected)
            selected = options[0].key;

        for (var i = 0; i < options.length; i++) {
            if (options[i].key === selected)
                return options[i];

        }
        return options[0];
    }
    readonly property var previewWorkspaceWindows: {
        var list = [];
        var selected = previewWorkspaceKey;
        if (!selected)
            return list;

        var windowsMap = pluginMain && pluginMain.windowByAddress ? pluginMain.windowByAddress : {
        };
        for (var addr in windowsMap) {
            var win = windowsMap[addr];
            if (!workspaceMatchesKey(win, selected))
                continue;

            var normalizedAddress = normalizePreviewAddress(win && win.address);
            var toplevel = previewWindowsByKey[normalizedAddress];
            if (!toplevel)
                continue;

            list.push({
                "address": normalizedAddress,
                "win": win,
                "toplevel": toplevel
            });
        }
        list.sort(function(a, b) {
            var winA = a.win || {
            };
            var winB = b.win || {
            };
            var pinnedA = !!winA.pinned;
            var pinnedB = !!winB.pinned;
            if (pinnedA !== pinnedB)
                return pinnedA ? 1 : -1;

            var floatingA = !!winA.floating;
            var floatingB = !!winB.floating;
            if (floatingA !== floatingB)
                return floatingA ? 1 : -1;

            return ((winB.focusHistoryID !== undefined) ? winB.focusHistoryID : 9999) - ((winA.focusHistoryID !== undefined) ? winA.focusHistoryID : 9999);
        });
        return list;
    }
    readonly property int previewMonitorId: {
        if (previewWorkspaceWindows.length > 0)
            return (previewWorkspaceWindows[0].win && previewWorkspaceWindows[0].win.monitor) || -1;

        return (pluginMain && pluginMain.activeWorkspace && pluginMain.activeWorkspace.monitorID !== undefined) ? pluginMain.activeWorkspace.monitorID : -1;
    }
    readonly property var previewMonitorData: {
        var monitors = pluginMain && pluginMain.monitors ? pluginMain.monitors : [];
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i] && monitors[i].id === previewMonitorId)
                return monitors[i];

        }
        return monitors.length > 0 ? monitors[0] : null;
    }
    readonly property real previewReservedLeft: (previewMonitorData && previewMonitorData.reserved && previewMonitorData.reserved[0]) || 0
    readonly property real previewReservedTop: (previewMonitorData && previewMonitorData.reserved && previewMonitorData.reserved[1]) || 0
    readonly property real previewReservedRight: (previewMonitorData && previewMonitorData.reserved && previewMonitorData.reserved[2]) || 0
    readonly property real previewReservedBottom: (previewMonitorData && previewMonitorData.reserved && previewMonitorData.reserved[3]) || 0
    readonly property real previewCenteringX: (previewReservedRight - previewReservedLeft) / 2
    readonly property real previewCenteringY: (previewReservedBottom - previewReservedTop) / 2
    readonly property string previewWorkspaceWatermark: {
        var ws = selectedPreviewWorkspaceOption;
        if (!ws || !ws.key)
            return "1";

        if (ws.key.startsWith("ws:"))
            return ws.key.slice(3);

        var special = ws.key.slice(8);
        return special.length > 0 ? special.charAt(0).toUpperCase() : "S";
    }
    readonly property var previewWindowOptions: {
        var options = [];
        for (var i = 0; i < validPreviewWindows.length; i++) {
            var item = validPreviewWindows[i];
            var toplevel = item.toplevel;
            var address = item.key;
            var win = pluginMain && pluginMain.windowByAddress ? pluginMain.windowByAddress[address] : null;
            var title = (win && win.title) || tr("overview.title.unknown", "Untitled");
            var cls = (win && win.class) || tr("overview.tooltip.unknown-class", "unknown");
            options.push({
                "key": address,
                "name": title + " [" + cls + "]"
            });
        }
        return options;
    }
    readonly property var selectedPreviewWindow: {
        if (validPreviewWindows.length === 0)
            return null;

        var selectedAddress = normalizePreviewAddress(previewWindowAddress);
        if (!selectedAddress)
            selectedAddress = validPreviewWindows[0].key;

        for (var i = 0; i < validPreviewWindows.length; i++) {
            var candidate = validPreviewWindows[i];
            if (candidate.key === selectedAddress)
                return candidate.toplevel;

        }
        return (validPreviewWindows[0] && validPreviewWindows[0].toplevel) || null;
    }

    function normalizePreviewAddress(address) {
        if (address === undefined || address === null)
            return "";

        var key = ("" + address).trim().toLowerCase();
        if (key === "")
            return "";

        while (key.startsWith("0x"))key = key.slice(2)
        if (key === "")
            return "";

        return "0x" + key;
    }

    function previewWindowKey(toplevel) {
        if (!toplevel)
            return "";

        var rawAddress = null;
        if (toplevel.HyprlandToplevel && toplevel.HyprlandToplevel.address !== undefined && toplevel.HyprlandToplevel.address !== null)
            rawAddress = toplevel.HyprlandToplevel.address;
        else if (toplevel.address !== undefined && toplevel.address !== null)
            rawAddress = toplevel.address;
        return normalizePreviewAddress(rawAddress);
    }

    function normalizeSpecialName(value) {
        var name = (value || "").toString().trim();
        if (name.startsWith("special:"))
            name = name.slice("special:".length);

        return name.length > 0 ? name : "special";
    }

    function workspaceKeyFromWorkspace(workspace) {
        if (!workspace || workspace.id === undefined || workspace.id === null)
            return "";

        if (workspace.id < 0)
            return "special:" + normalizeSpecialName(workspace.name || "");

        return "ws:" + workspace.id;
    }

    function workspaceKeyForWindow(win) {
        if (!win || !win.workspace)
            return "";

        if (win.workspace.id < 0)
            return "special:" + normalizeSpecialName(win.workspace.name || "");

        return "ws:" + win.workspace.id;
    }

    function workspaceMatchesKey(win, key) {
        if (!win || !win.workspace || !key)
            return false;

        if (key.startsWith("special:"))
            return win.workspace.id < 0 && normalizeSpecialName(win.workspace.name || "") === key.slice("special:".length);

        if (key.startsWith("ws:")) {
            var id = parseInt(key.slice(3));
            return win.workspace.id === id;
        }
        return false;
    }

    function workspaceDisplayName(key, count, isActive) {
        var suffix = count > 0 ? (" (" + count + " windows)") : "";
        if (key.startsWith("special:")) {
            var specialName = key.slice("special:".length);
            return "Special: " + specialName + suffix + (isActive ? " (active)" : "");
        }
        if (key.startsWith("ws:")) {
            var id = key.slice(3);
            return "Workspace " + id + suffix + (isActive ? " (active)" : "");
        }
        return key + suffix + (isActive ? " (active)" : "");
    }

    function isPreviewWindowFocused(win) {
        if (!win)
            return false;

        if (pluginMain && pluginMain.activeWindowAddress && win.address && normalizePreviewAddress(win.address) === normalizePreviewAddress(pluginMain.activeWindowAddress))
            return true;

        return !!(win.focused || win.focusHistoryID === 0);
    }

    function ensurePreviewSelection() {
        var windows = validPreviewWindows || [];
        if (!windows || typeof windows.length !== "number" || windows.length === 0) {
            previewWindowAddress = "";
            return ;
        }
        var selectedAddress = normalizePreviewAddress(previewWindowAddress);
        if (!selectedAddress) {
            previewWindowAddress = windows[0].key;
            return ;
        }
        var found = false;
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].key === selectedAddress) {
                found = true;
                break;
            }
        }
        if (!found) {
            previewWindowAddress = windows[0].key;
            return ;
        }
        if (previewWindowAddress !== selectedAddress)
            previewWindowAddress = selectedAddress;

    }

    function ensureWorkspacePreviewSelection() {
        var options = previewWorkspaceOptions || [];
        if (!options || options.length === 0) {
            previewWorkspaceKey = "";
            return ;
        }
        if (!previewWorkspaceKey) {
            previewWorkspaceKey = options[0].key;
            return ;
        }
        for (var i = 0; i < options.length; i++) {
            if (options[i].key === previewWorkspaceKey)
                return ;

        }
        previewWorkspaceKey = options[0].key;
    }

    function getSetting(key, fallback) {
        if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings[key] !== undefined)
            return pluginApi.pluginSettings[key];

        if (defaultSettings && defaultSettings[key] !== undefined)
            return defaultSettings[key];

        return fallback;
    }

    function tr(key, fallback) {
        if (!pluginApi || !pluginApi.tr)
            return fallback;

        var translated = pluginApi.tr(key);
        if (!translated)
            return fallback;

        return translated;
    }

    function parseIntSetting(value, fallback) {
        var parsed = parseInt(value);
        if (isNaN(parsed))
            return fallback;

        return parsed;
    }

    function parseFloatSetting(value, fallback) {
        var parsed = parseFloat(value);
        if (isNaN(parsed))
            return fallback;

        return parsed;
    }

    function syncFromPlugin() {
        if (!pluginApi)
            return ;

        gridRows = parseIntSetting(getSetting("rows", 2), 2);
        gridColumns = parseIntSetting(getSetting("columns", 5), 5);
        gridScale = parseFloatSetting(getSetting("scale", 0.16), 0.16);
        hideEmptyRows = !!getSetting("hideEmptyRows", true);
        showScratchpadWorkspaces = !!getSetting("showScratchpadWorkspaces", false);
        gridSpacing = parseIntSetting(getSetting("gridSpacing", 0), 0);
        overviewPosition = getSetting("position", "top") || "top";
        barMargin = parseIntSetting(getSetting("barMargin", 0), 0);
        useSlideAnimation = !!getSetting("useSlideAnimation", true);
        animationProfile = getSetting("animationProfile", "hyprlike") || "hyprlike";
        animationDurationMs = parseIntSetting(getSetting("animationDurationMs", 200), 200);
        showRowColumnGuides = !!getSetting("showRowColumnGuides", false);
        containerBorderWidth = parseIntSetting(getSetting("containerBorderWidth", -1), -1);
        selectionBorderWidth = parseIntSetting(getSetting("selectionBorderWidth", -1), -1);
        accentColorType = getSetting("accentColorType", "secondary") || "secondary";
        visualMode = getSetting("visualMode", getSetting("useSimplifiedPreview", false) ? "simplified" : "live") || "live";
        shaderPreset = getSetting("shaderPreset", "classic") || "classic";
        shaderPresetStrength = parseFloatSetting(getSetting("shaderPresetStrength", 0.7), 0.7);
        useSimplifiedPreview = visualMode !== "live";
        titleStripMode = getSetting("titleStripMode", getSetting("showWindowTitleStrip", true) ? "auto" : "off") || "auto";
        showWindowTitleStrip = titleStripMode !== "off";
        titleStripHeight = parseIntSetting(getSetting("titleStripHeight", 20), 20);
        titleStripMeta = getSetting("titleStripMeta", "class") || "class";
        showWindowIcons = !!getSetting("showWindowIcons", true);
        showWorkspaceLabels = !!getSetting("showWorkspaceLabels", true);
        workspaceLabelMode = getSetting("workspaceLabelMode", "number-name") || "number-name";
        showFocusedWindowGlow = !!getSetting("showFocusedWindowGlow", true);
        showUrgencyBadge = !!getSetting("showUrgencyBadge", true);
        showFloatingBadge = !!getSetting("showFloatingBadge", true);
        showFullscreenBadge = !!getSetting("showFullscreenBadge", false);
        showMonitorBadge = !!getSetting("showMonitorBadge", false);
        dimInactiveWorkspaces = parseFloatSetting(getSetting("dimInactiveWorkspaces", 0.35), 0.35);
        inactiveWorkspaceSaturation = parseFloatSetting(getSetting("inactiveWorkspaceSaturation", 0.75), 0.75);
        hoverLiftAmount = parseIntSetting(getSetting("hoverLiftAmount", 4), 4);
        previewCornerMode = getSetting("previewCornerMode", "hyprland") || "hyprland";
        previewFixedCornerRadius = parseIntSetting(getSetting("previewFixedCornerRadius", 10), 10);
        useBorderGradient = !!getSetting("useBorderGradient", true);
        dragPreviewMode = getSetting("dragPreviewMode", "smart") || "smart";
        dragSnapThreshold = parseFloatSetting(getSetting("dragSnapThreshold", 0.33), 0.33);
        retilePreviewOpacity = parseFloatSetting(getSetting("retilePreviewOpacity", 0.55), 0.55);
        specialWorkspaceStyle = getSetting("specialWorkspaceStyle", "pill") || "pill";
        simplifiedPixelDensity = parseFloatSetting(getSetting("simplifiedPixelDensity", 0.5), 0.5);
        simplifiedColorDepth = parseFloatSetting(getSetting("simplifiedColorDepth", 6), 6);
        simplifiedSaturation = parseFloatSetting(getSetting("simplifiedSaturation", 1.1), 1.1);
        simplifiedContrast = parseFloatSetting(getSetting("simplifiedContrast", 1.1), 1.1);
    }

    function saveSettings() {
        if (!pluginApi)
            return ;

        var settings = pluginApi.pluginSettings || {
        };
        settings.rows = gridRows;
        settings.columns = gridColumns;
        settings.scale = gridScale;
        settings.hideEmptyRows = hideEmptyRows;
        settings.showScratchpadWorkspaces = showScratchpadWorkspaces;
        settings.gridSpacing = gridSpacing;
        settings.position = overviewPosition;
        settings.barMargin = barMargin;
        settings.useSlideAnimation = useSlideAnimation;
        settings.animationProfile = animationProfile;
        settings.animationDurationMs = animationDurationMs;
        settings.showRowColumnGuides = showRowColumnGuides;
        settings.containerBorderWidth = containerBorderWidth;
        settings.selectionBorderWidth = selectionBorderWidth;
        settings.accentColorType = accentColorType;
        settings.visualMode = visualMode;
        settings.shaderPreset = shaderPreset;
        settings.shaderPresetStrength = shaderPresetStrength;
        settings.useSimplifiedPreview = visualMode !== "live";
        settings.titleStripMode = titleStripMode;
        settings.titleStripMeta = titleStripMeta;
        settings.showWindowTitleStrip = titleStripMode !== "off";
        settings.showWindowIcons = showWindowIcons;
        settings.showWorkspaceLabels = showWorkspaceLabels;
        settings.workspaceLabelMode = workspaceLabelMode;
        settings.showFocusedWindowGlow = showFocusedWindowGlow;
        settings.showUrgencyBadge = showUrgencyBadge;
        settings.showFloatingBadge = showFloatingBadge;
        settings.showFullscreenBadge = showFullscreenBadge;
        settings.showMonitorBadge = showMonitorBadge;
        settings.dimInactiveWorkspaces = dimInactiveWorkspaces;
        settings.inactiveWorkspaceSaturation = inactiveWorkspaceSaturation;
        settings.hoverLiftAmount = hoverLiftAmount;
        settings.previewCornerMode = previewCornerMode;
        settings.previewFixedCornerRadius = previewFixedCornerRadius;
        settings.useBorderGradient = useBorderGradient;
        settings.dragPreviewMode = dragPreviewMode;
        settings.dragSnapThreshold = dragSnapThreshold;
        settings.retilePreviewOpacity = retilePreviewOpacity;
        settings.specialWorkspaceStyle = specialWorkspaceStyle;
        settings.titleStripHeight = titleStripHeight;
        settings.simplifiedPixelDensity = simplifiedPixelDensity;
        settings.simplifiedColorDepth = simplifiedColorDepth;
        settings.simplifiedSaturation = simplifiedSaturation;
        settings.simplifiedContrast = simplifiedContrast;
        pluginApi.pluginSettings = settings;
        pluginApi.saveSettings();
        pluginMain && pluginMain.refresh();
    }

    spacing: Style.marginM
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: Math.round(520 * Style.uiScaleRatio)
    Layout.preferredWidth: Layout.minimumWidth
    onPluginApiChanged: syncFromPlugin()
    onPreviewWorkspaceOptionsChanged: ensureWorkspacePreviewSelection()
    Component.onCompleted: {
        syncFromPlugin();
        ensureWorkspacePreviewSelection();
    }

    // Description
    NText {
        text: tr("plugin.description", "Visual workspace overview with live window previews for Hyprland")
        wrapMode: Text.WordWrap
        color: Color.mOnSurface
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Tab Bar
    NTabBar {
        id: tabBar

        Layout.fillWidth: true
        currentIndex: 0
        distributeEvenly: true

        NTabButton {
            text: tr("settings.tabs.grid", "Grid")
            tabIndex: 0
            checked: tabBar.currentIndex === 0
        }

        NTabButton {
            text: tr("settings.tabs.behavior", "Behavior")
            tabIndex: 1
            checked: tabBar.currentIndex === 1
        }

        NTabButton {
            text: tr("settings.tabs.layout", "Layout")
            tabIndex: 2
            checked: tabBar.currentIndex === 2
        }

        NTabButton {
            text: tr("settings.tabs.appearance", "Appearance")
            tabIndex: 3
            checked: tabBar.currentIndex === 3
        }

    }

    HyprlandConfig {
        id: previewHyprConfig
    }

    // Tab Content
    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        currentIndex: tabBar.currentIndex

        // === Grid Tab ===
        ColumnLayout {
            spacing: Style.marginL
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NSpinBox {
                    Layout.fillWidth: true
                    label: tr("settings.grid.rows.label", "Rows")
                    description: tr("settings.grid.rows.description", "Number of workspace rows")
                    from: 1
                    to: 10
                    value: root.gridRows
                    onValueChanged: {
                        if (root.gridRows !== value) {
                            root.gridRows = value;
                            root.saveSettings();
                        }
                    }
                }

                NSpinBox {
                    Layout.fillWidth: true
                    label: tr("settings.grid.columns.label", "Columns")
                    description: tr("settings.grid.columns.description", "Number of workspace columns")
                    from: 1
                    to: 20
                    value: root.gridColumns
                    onValueChanged: {
                        if (root.gridColumns !== value) {
                            root.gridColumns = value;
                            root.saveSettings();
                        }
                    }
                }

            }

            NValueSlider {
                Layout.fillWidth: true
                label: tr("settings.grid.scale.label", "Scale")
                description: tr("settings.grid.scale.description", "Overview scale factor")
                from: 0.05
                to: 0.5
                stepSize: 0.01
                value: root.gridScale
                text: value.toFixed(2)
                onMoved: (value) => {
                    if (Math.abs(root.gridScale - value) > 0.001) {
                        root.gridScale = value;
                        root.saveSettings();
                    }
                }
            }

            NValueSlider {
                Layout.fillWidth: true
                label: tr("settings.grid.spacing.label", "Grid Spacing")
                description: tr("settings.grid.spacing.description", "Gap between workspace thumbnails")
                from: 0
                to: 50
                stepSize: 1
                value: root.gridSpacing
                text: value + "px"
                onMoved: (value) => {
                    if (root.gridSpacing !== value) {
                        root.gridSpacing = value;
                        root.saveSettings();
                    }
                }
            }

            NText {
                text: {
                    var total = root.gridRows * root.gridColumns;
                    return tr("settings.grid.total-workspaces", "{count} total workspaces").replace("{count}", total);
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }

            // Warning when overview would be auto-shrunk to fit (predictive)
            NText {
                visible: root.willRequireFitScaling
                text: tr("settings.grid.scale-warning", "Current settings exceed screen size. Overview will be scaled down to fit.")
                color: Color.mError
                wrapMode: Text.WordWrap
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightMedium
            }

            NComboBox {
                Layout.fillWidth: true
                label: tr("settings.grid.animationProfile.label", "Animation profile")
                description: tr("settings.grid.animationProfile.description", "How quickly workspace cards and windows animate")
                model: [{
                    "key": "none",
                    "name": tr("settings.grid.animationProfile.none", "No animation")
                }, {
                    "key": "fast",
                    "name": tr("settings.grid.animationProfile.fast", "Fast")
                }, {
                    "key": "hyprlike",
                    "name": tr("settings.grid.animationProfile.hyprlike", "Hyprlike")
                }, {
                    "key": "slow",
                    "name": tr("settings.grid.animationProfile.slow", "Slow")
                }, {
                    "key": "custom",
                    "name": tr("settings.grid.animationProfile.custom", "Custom")
                }]
                currentKey: root.animationProfile
                onSelected: (key) => {
                    root.animationProfile = key;
                    root.saveSettings();
                }
            }

            NValueSlider {
                visible: root.animationProfile === "custom"
                Layout.fillWidth: true
                label: tr("settings.grid.animationDuration.label", "Animation duration")
                description: tr("settings.grid.animationDuration.description", "Custom animation duration used by workspace and window transitions")
                from: 80
                to: 400
                stepSize: 10
                value: root.animationDurationMs
                text: value + "ms"
                onMoved: (value) => {
                    if (root.animationDurationMs !== value) {
                        root.animationDurationMs = value;
                        root.saveSettings();
                    }
                }
            }

        }

        // === Behavior Tab ===
        ColumnLayout {
            spacing: Style.marginL
            Layout.fillWidth: true

            NToggle {
                label: tr("settings.behavior.hide-empty-rows.label", "Hide empty rows")
                description: tr("settings.behavior.hide-empty-rows.description", "Automatically hide workspace rows with no windows")
                checked: root.hideEmptyRows
                onToggled: (checked) => {
                    root.hideEmptyRows = checked;
                    root.saveSettings();
                }
            }

            NToggle {
                label: tr("settings.behavior.show-scratchpad.label", "Show scratchpad windows")
                description: tr("settings.behavior.show-scratchpad.description", "Include special/scratchpad workspace windows in the overview")
                checked: root.showScratchpadWorkspaces
                onToggled: (checked) => {
                    root.showScratchpadWorkspaces = checked;
                    root.saveSettings();
                }
            }

            NComboBox {
                Layout.fillWidth: true
                label: tr("settings.behavior.dragPreviewMode.label", "Drag preview mode")
                description: tr("settings.behavior.dragPreviewMode.description", "Controls retile/split guidance while dragging a window")
                model: [{
                    "key": "off",
                    "name": tr("settings.behavior.dragPreviewMode.off", "Off")
                }, {
                    "key": "basic",
                    "name": tr("settings.behavior.dragPreviewMode.basic", "Basic")
                }, {
                    "key": "smart",
                    "name": tr("settings.behavior.dragPreviewMode.smart", "Smart")
                }]
                currentKey: root.dragPreviewMode
                onSelected: (key) => {
                    root.dragPreviewMode = key;
                    root.saveSettings();
                }
            }

            NValueSlider {
                visible: root.dragPreviewMode !== "off"
                Layout.fillWidth: true
                label: tr("settings.behavior.dragSnapThreshold.label", "Drag snap threshold")
                description: tr("settings.behavior.dragSnapThreshold.description", "How close to an edge the pointer must be before split zones commit")
                from: 0.12
                to: 0.45
                stepSize: 0.01
                value: root.dragSnapThreshold
                text: value.toFixed(2)
                onMoved: (value) => {
                    if (Math.abs(root.dragSnapThreshold - value) > 0.001) {
                        root.dragSnapThreshold = value;
                        root.saveSettings();
                    }
                }
            }

            NValueSlider {
                visible: root.dragPreviewMode !== "off"
                Layout.fillWidth: true
                label: tr("settings.behavior.retilePreviewOpacity.label", "Retile preview opacity")
                description: tr("settings.behavior.retilePreviewOpacity.description", "Opacity multiplier for split/swap guidance overlays")
                from: 0.2
                to: 0.9
                stepSize: 0.05
                value: root.retilePreviewOpacity
                text: value.toFixed(2)
                onMoved: (value) => {
                    if (Math.abs(root.retilePreviewOpacity - value) > 0.001) {
                        root.retilePreviewOpacity = value;
                        root.saveSettings();
                    }
                }
            }

        }

        // === Layout Tab ===
        ColumnLayout {
            spacing: Style.marginL
            Layout.fillWidth: true

            NComboBox {
                Layout.fillWidth: true
                label: tr("settings.layout.position.label", "Position")
                description: tr("settings.layout.position.description", "Where the overview appears on screen")
                model: [{
                    "key": "top",
                    "name": tr("settings.layout.position.top", "Top")
                }, {
                    "key": "center",
                    "name": tr("settings.layout.position.center", "Center")
                }, {
                    "key": "bottom",
                    "name": tr("settings.layout.position.bottom", "Bottom")
                }]
                currentKey: root.overviewPosition
                onSelected: (key) => {
                    root.overviewPosition = key;
                    root.saveSettings();
                }
            }

            NValueSlider {
                Layout.fillWidth: true
                label: tr("settings.layout.barMargin.label", "Bar Margin")
                description: tr("settings.layout.barMargin.description", "Additional margin between overview and bar (when positioned at same edge)")
                from: 0
                to: 100
                stepSize: 1
                value: root.barMargin
                text: value + "px"
                onMoved: (value) => {
                    if (root.barMargin !== value) {
                        root.barMargin = value;
                        root.saveSettings();
                    }
                }
            }

            NValueSlider {
                Layout.fillWidth: true
                label: tr("settings.layout.backgroundOpacity.label", "Background opacity")
                description: tr("settings.layout.backgroundOpacity.description", "Adjust the transparency of the overview backdrop")
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: root.overviewBackgroundOpacityRatio
                text: Math.round(value * 100) + "%"
                onMoved: (value) => {
                    if (Math.abs(root.overviewBackgroundOpacityRatio - value) > 0.001) {
                        root.overviewBackgroundOpacityRatio = value;
                        root.saveSettings();
                    }
                }
            }

            NToggle {
                label: tr("settings.layout.slideAnimation.label", "Slide animation")
                description: tr("settings.layout.slideAnimation.description", "Animate overview sliding in from the bar (disable for instant popup)")
                checked: root.useSlideAnimation
                onToggled: (checked) => {
                    root.useSlideAnimation = checked;
                    root.saveSettings();
                }
            }

            NToggle {
                label: tr("settings.layout.workspaceLabels.label", "Workspace labels")
                description: tr("settings.layout.workspaceLabels.description", "Show readable labels in each workspace thumbnail")
                checked: root.showWorkspaceLabels
                onToggled: (checked) => {
                    root.showWorkspaceLabels = checked;
                    root.saveSettings();
                }
            }

            NComboBox {
                visible: root.showWorkspaceLabels
                Layout.fillWidth: true
                label: tr("settings.layout.workspaceLabelMode.label", "Workspace label format")
                description: tr("settings.layout.workspaceLabelMode.description", "Choose whether labels use workspace number, name, or both")
                model: [{
                    "key": "number",
                    "name": tr("settings.layout.workspaceLabelMode.number", "Number")
                }, {
                    "key": "name",
                    "name": tr("settings.layout.workspaceLabelMode.name", "Name")
                }, {
                    "key": "number-name",
                    "name": tr("settings.layout.workspaceLabelMode.number-name", "Number + Name")
                }]
                currentKey: root.workspaceLabelMode
                onSelected: (key) => {
                    root.workspaceLabelMode = key;
                    root.saveSettings();
                }
            }

            NComboBox {
                Layout.fillWidth: true
                label: tr("settings.layout.specialWorkspaceStyle.label", "Special workspace style")
                description: tr("settings.layout.specialWorkspaceStyle.description", "How scratchpad workspace labels are rendered")
                model: [{
                    "key": "pill",
                    "name": tr("settings.layout.specialWorkspaceStyle.pill", "Pill")
                }, {
                    "key": "chip",
                    "name": tr("settings.layout.specialWorkspaceStyle.chip", "Chip")
                }, {
                    "key": "plain",
                    "name": tr("settings.layout.specialWorkspaceStyle.plain", "Plain")
                }]
                currentKey: root.specialWorkspaceStyle
                onSelected: (key) => {
                    root.specialWorkspaceStyle = key;
                    root.saveSettings();
                }
            }

            NToggle {
                label: tr("settings.layout.rowColumnGuides.label", "Row/column guides")
                description: tr("settings.layout.rowColumnGuides.description", "Show subtle center guides in each workspace cell")
                checked: root.showRowColumnGuides
                onToggled: (checked) => {
                    root.showRowColumnGuides = checked;
                    root.saveSettings();
                }
            }

        }

        // === Appearance Tab ===
        ColumnLayout {
            spacing: Style.marginM
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: workspacePreviewDock

                visible: root.previewWorkspaceOptions && root.previewWorkspaceOptions.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(190 * Style.uiScaleRatio)
                Layout.maximumHeight: Layout.preferredHeight
                radius: Style.radiusM
                color: Qt.rgba(Color.mSurfaceVariant.r, Color.mSurfaceVariant.g, Color.mSurfaceVariant.b, 0.35)
                border.width: Style.borderS
                border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NText {
                            text: tr("settings.appearance.previewWorkspace.label", "Preview workspace")
                            color: Color.mOnSurface
                            pointSize: Style.fontSizeS
                            font.weight: Style.fontWeightMedium
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        NComboBox {
                            Layout.preferredWidth: Math.max(200, workspacePreviewDock.width * 0.36)
                            model: root.previewWorkspaceOptions || []
                            currentKey: root.previewWorkspaceKey
                            onSelected: (key) => {
                                root.previewWorkspaceKey = key;
                            }
                        }

                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Style.radiusS
                            color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.85)
                            border.width: Style.borderS
                            border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
                        }

                        Item {
                            id: previewWorkspaceViewport

                            property real rawMonitorWidth: ((root.previewMonitorData && root.previewMonitorData.width) || 1920) / ((root.previewMonitorData && root.previewMonitorData.scale) || 1)
                            property real rawMonitorHeight: ((root.previewMonitorData && root.previewMonitorData.height) || 1080) / ((root.previewMonitorData && root.previewMonitorData.scale) || 1)
                            property real sourceMonitorWidth: (root.previewMonitorData && root.previewMonitorData.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
                            property real sourceMonitorHeight: (root.previewMonitorData && root.previewMonitorData.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight
                            property real aspectRatio: sourceMonitorWidth / Math.max(1, sourceMonitorHeight)

                            anchors.centerIn: parent
                            width: Math.min(parent.width - Style.marginS * 2, (parent.height - Style.marginS * 2) * aspectRatio)
                            height: width / Math.max(0.01, aspectRatio)

                            Rectangle {
                                id: previewWorkspaceSurface

                                anchors.fill: parent
                                color: Color.mSurfaceVariant
                                radius: Style.screenRadius * 0.35
                                border.width: root.selectionBorderWidth >= 0 ? root.selectionBorderWidth : Style.borderM
                                border.color: root.accentColorType === "primary" ? Color.mPrimary : Color.mSecondary

                                Rectangle {
                                    visible: root.showRowColumnGuides
                                    anchors.centerIn: parent
                                    width: parent.width * 0.8
                                    height: 1
                                    color: Qt.rgba((root.accentColorType === "primary" ? Color.mPrimary.r : Color.mSecondary.r), (root.accentColorType === "primary" ? Color.mPrimary.g : Color.mSecondary.g), (root.accentColorType === "primary" ? Color.mPrimary.b : Color.mSecondary.b), 0.2)
                                }

                                Rectangle {
                                    visible: root.showRowColumnGuides
                                    anchors.centerIn: parent
                                    width: 1
                                    height: parent.height * 0.8
                                    color: Qt.rgba((root.accentColorType === "primary" ? Color.mPrimary.r : Color.mSecondary.r), (root.accentColorType === "primary" ? Color.mPrimary.g : Color.mSecondary.g), (root.accentColorType === "primary" ? Color.mPrimary.b : Color.mSecondary.b), 0.2)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.previewWorkspaceWatermark
                                    font.family: Settings.data.ui.fontDefault
                                    font.pixelSize: Math.max(40, parent.height * 0.42)
                                    font.weight: Style.fontWeightSemiBold
                                    color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.2)
                                }

                                Rectangle {
                                    visible: root.showWorkspaceLabels && root.selectedPreviewWorkspaceOption
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.leftMargin: Math.max(6, parent.width * 0.03)
                                    anchors.topMargin: Math.max(6, parent.height * 0.03)
                                    radius: root.specialWorkspaceStyle === "pill" ? Math.max(8, height / 2) : (root.specialWorkspaceStyle === "chip" ? 8 : 0)
                                    color: root.specialWorkspaceStyle === "plain" ? "transparent" : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.72)
                                    border.width: root.specialWorkspaceStyle === "plain" ? 0 : 1
                                    border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.45)
                                    width: Math.min(parent.width * 0.78, workspaceLabelText.implicitWidth + 14)
                                    height: Math.max(20, Math.min(30, parent.height * 0.2))

                                    Text {
                                        id: workspaceLabelText

                                        anchors.centerIn: parent
                                        width: parent.width - 10
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: (root.selectedPreviewWorkspaceOption && root.selectedPreviewWorkspaceOption.name) || "Workspace"
                                        font.family: Settings.data.ui.fontDefault
                                        font.pixelSize: Math.max(10, Math.min(13, parent.height * 0.52))
                                        color: Color.mOnSurface
                                    }

                                }

                                Repeater {
                                    model: root.previewWorkspaceWindows || []

                                    delegate: WindowPreview {
                                        required property var modelData
                                        required property int index
                                        property int monitorId: ((modelData.win && modelData.win.monitor) || root.previewMonitorId)
                                        property var windowMonitor: {
                                            var monitors = root.pluginMain && root.pluginMain.monitors ? root.pluginMain.monitors : [];
                                            for (var i = 0; i < monitors.length; i++) {
                                                if (monitors[i] && monitors[i].id === monitorId)
                                                    return monitors[i];

                                            }
                                            return root.previewMonitorData;
                                        }
                                        property real rawMonitorWidth: ((windowMonitor && windowMonitor.width) || 1920) / ((windowMonitor && windowMonitor.scale) || 1)
                                        property real rawMonitorHeight: ((windowMonitor && windowMonitor.height) || 1080) / ((windowMonitor && windowMonitor.scale) || 1)
                                        property real sourceMonitorWidth: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
                                        property real sourceMonitorHeight: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight

                                        pluginMain: root.pluginMain
                                        toplevel: modelData.toplevel
                                        windowData: modelData.win
                                        monitorData: windowMonitor
                                        windowScale: Math.min(previewWorkspaceViewport.width / Math.max(1, sourceMonitorWidth), previewWorkspaceViewport.height / Math.max(1, sourceMonitorHeight))
                                        positionScaleX: previewWorkspaceViewport.width / Math.max(1, sourceMonitorWidth)
                                        positionScaleY: previewWorkspaceViewport.height / Math.max(1, sourceMonitorHeight)
                                        availableWorkspaceWidth: previewWorkspaceViewport.width
                                        availableWorkspaceHeight: previewWorkspaceViewport.height
                                        centeringX: root.previewCenteringX
                                        centeringY: root.previewCenteringY
                                        xOffset: 0
                                        yOffset: 0
                                        widgetMonitorId: root.previewMonitorId
                                        overviewOpen: true
                                        useSimplifiedPreview: root.visualMode !== "live"
                                        visualMode: root.visualMode
                                        shaderPreset: root.shaderPreset
                                        shaderPresetStrength: root.shaderPresetStrength
                                        simplifiedPixelDensity: root.simplifiedPixelDensity
                                        simplifiedColorDepth: root.simplifiedColorDepth
                                        simplifiedSaturation: root.simplifiedSaturation
                                        simplifiedContrast: root.simplifiedContrast
                                        windowBorderSize: previewHyprConfig.borderSize || 1
                                        activeBorderColor: previewHyprConfig.activeBorderColor || Color.mPrimary
                                        inactiveBorderColor: previewHyprConfig.inactiveBorderColor || Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.85)
                                        isActiveWorkspaceWindow: true
                                        isFocusedWindow: root.isPreviewWindowFocused(modelData.win)
                                        showWindowIcons: root.showWindowIcons
                                        showFocusedGlow: root.showFocusedWindowGlow
                                        showUrgencyBadge: root.showUrgencyBadge
                                        showFloatingBadge: root.showFloatingBadge
                                        showFullscreenBadge: root.showFullscreenBadge
                                        showMonitorBadge: root.showMonitorBadge
                                        inactiveWorkspaceDimAmount: root.dimInactiveWorkspaces
                                        inactiveWorkspaceSaturation: root.inactiveWorkspaceSaturation
                                        hoverLiftAmount: root.hoverLiftAmount
                                        previewCornerMode: root.previewCornerMode
                                        previewFixedCornerRadius: root.previewFixedCornerRadius
                                        useBorderGradient: root.useBorderGradient
                                        showTitleStrip: root.showWindowTitleStrip
                                        titleStripHeight: root.titleStripHeight
                                        titleStripMode: root.titleStripMode
                                        titleStripMeta: root.titleStripMeta
                                        windowRounding: previewHyprConfig.rounding || 0
                                        animationProfile: root.animationProfile
                                        animationDurationMs: root.animationDurationMs
                                        z: index + 1
                                        hovered: false
                                        pressed: false
                                    }

                                }

                                NText {
                                    anchors.centerIn: parent
                                    visible: (root.previewWorkspaceWindows || []).length === 0
                                    text: tr("settings.appearance.previewWorkspace.no-windows", "Open windows in this workspace to preview styles")
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                }

                            }

                        }

                    }

                }

            }

            Flickable {
                id: appearanceSettingsFlickable

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: appearanceSettingsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ColumnLayout {
                    id: appearanceSettingsColumn

                    width: appearanceSettingsFlickable.width
                    spacing: Style.marginL

                    NComboBox {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.visualMode.label", "Visual mode")
                        description: tr("settings.appearance.visualMode.description", "Switch between faithful live previews and stylized shader presets")
                        model: [{
                            "key": "live",
                            "name": tr("settings.appearance.visualMode.live", "Live")
                        }, {
                            "key": "simplified",
                            "name": tr("settings.appearance.visualMode.simplified", "Simplified")
                        }, {
                            "key": "cinematic",
                            "name": tr("settings.appearance.visualMode.cinematic", "Cinematic")
                        }]
                        currentKey: root.visualMode
                        onSelected: (key) => {
                            root.visualMode = key;
                            root.useSimplifiedPreview = key !== "live";
                            root.saveSettings();
                        }
                    }

                    NComboBox {
                        visible: root.visualMode !== "live"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.shaderPreset.label", "Shader preset")
                        description: tr("settings.appearance.shaderPreset.description", "Fine tune how stylized modes process window previews")
                        model: [{
                            "key": "classic",
                            "name": tr("settings.appearance.shaderPreset.classic", "Classic")
                        }, {
                            "key": "simplified",
                            "name": tr("settings.appearance.shaderPreset.simplified", "Simplified")
                        }, {
                            "key": "mac",
                            "name": tr("settings.appearance.shaderPreset.mac", "Mac OS Classic")
                        }, {
                            "key": "cinematic",
                            "name": tr("settings.appearance.shaderPreset.cinematic", "Cinematic")
                        }]
                        currentKey: root.shaderPreset
                        onSelected: (key) => {
                            root.shaderPreset = key;
                            root.saveSettings();
                        }
                    }

                    NValueSlider {
                        visible: root.visualMode !== "live"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.shaderPresetStrength.label", "Preset strength")
                        description: tr("settings.appearance.shaderPresetStrength.description", "How strongly the selected shader preset is applied")
                        from: 0
                        to: 1
                        stepSize: 0.05
                        value: root.shaderPresetStrength
                        text: value.toFixed(2)
                        onMoved: (value) => {
                            if (Math.abs(root.shaderPresetStrength - value) > 0.001) {
                                root.shaderPresetStrength = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NValueSlider {
                        visible: root.visualMode !== "live"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.pixelDensity.label", "Pixel Density")
                        description: tr("settings.appearance.pixelDensity.description", "Controls pixelation level (higher = more detail)")
                        from: 0
                        to: 1
                        stepSize: 0.05
                        value: root.simplifiedPixelDensity
                        text: value.toFixed(2)
                        onMoved: (value) => {
                            if (Math.abs(root.simplifiedPixelDensity - value) > 0.001) {
                                root.simplifiedPixelDensity = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NValueSlider {
                        visible: root.visualMode !== "live"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.colorDepth.label", "Color Depth")
                        description: tr("settings.appearance.colorDepth.description", "Bits per color channel (lower = posterized look)")
                        from: 1
                        to: 8
                        stepSize: 0.5
                        value: root.simplifiedColorDepth
                        text: value.toFixed(1) + " bits"
                        onMoved: (value) => {
                            if (Math.abs(root.simplifiedColorDepth - value) > 0.01) {
                                root.simplifiedColorDepth = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NValueSlider {
                        visible: root.visualMode !== "live"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.saturation.label", "Saturation")
                        description: tr("settings.appearance.saturation.description", "Color intensity (1.0 = normal)")
                        from: 0.5
                        to: 2
                        stepSize: 0.1
                        value: root.simplifiedSaturation
                        text: value.toFixed(1)
                        onMoved: (value) => {
                            if (Math.abs(root.simplifiedSaturation - value) > 0.01) {
                                root.simplifiedSaturation = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NValueSlider {
                        visible: root.visualMode !== "live"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.contrast.label", "Contrast")
                        description: tr("settings.appearance.contrast.description", "Contrast strength (1.0 = normal)")
                        from: 0.5
                        to: 2
                        stepSize: 0.1
                        value: root.simplifiedContrast
                        text: value.toFixed(1)
                        onMoved: (value) => {
                            if (Math.abs(root.simplifiedContrast - value) > 0.01) {
                                root.simplifiedContrast = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NComboBox {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.accentColor.label", "Accent color")
                        description: tr("settings.appearance.accentColor.description", "Color used for selection indicator and special workspaces")
                        model: [{
                            "key": "secondary",
                            "name": tr("settings.appearance.accentColor.secondary", "Secondary (default)")
                        }, {
                            "key": "primary",
                            "name": tr("settings.appearance.accentColor.primary", "Primary")
                        }]
                        currentKey: root.accentColorType
                        onSelected: (key) => {
                            root.accentColorType = key;
                            root.saveSettings();
                        }
                    }

                    NToggle {
                        label: tr("settings.appearance.windowIcons.label", "Window icons")
                        description: tr("settings.appearance.windowIcons.description", "Show app icons inside each window preview card")
                        checked: root.showWindowIcons
                        onToggled: (checked) => {
                            root.showWindowIcons = checked;
                            root.saveSettings();
                        }
                    }

                    NComboBox {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.titleStripMode.label", "Title strip mode")
                        description: tr("settings.appearance.titleStripMode.description", "Control when the bottom title strip is displayed")
                        model: [{
                            "key": "off",
                            "name": tr("settings.appearance.titleStripMode.off", "Off")
                        }, {
                            "key": "auto",
                            "name": tr("settings.appearance.titleStripMode.auto", "Auto")
                        }, {
                            "key": "always",
                            "name": tr("settings.appearance.titleStripMode.always", "Always")
                        }]
                        currentKey: root.titleStripMode
                        onSelected: (key) => {
                            root.titleStripMode = key;
                            root.showWindowTitleStrip = key !== "off";
                            root.saveSettings();
                        }
                    }

                    NValueSlider {
                        visible: root.titleStripMode !== "off"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.titleStripHeight.label", "Title strip height")
                        description: tr("settings.appearance.titleStripHeight.description", "Height of the window title strip before monitor scaling")
                        from: 12
                        to: 32
                        stepSize: 1
                        value: root.titleStripHeight
                        text: value + "px"
                        onMoved: (value) => {
                            if (root.titleStripHeight !== value) {
                                root.titleStripHeight = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NComboBox {
                        visible: root.titleStripMode !== "off"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.titleStripMeta.label", "Title strip metadata")
                        description: tr("settings.appearance.titleStripMeta.description", "Choose what extra metadata appears on the right side of the title strip")
                        model: [{
                            "key": "none",
                            "name": tr("settings.appearance.titleStripMeta.none", "None")
                        }, {
                            "key": "class",
                            "name": tr("settings.appearance.titleStripMeta.class", "Class")
                        }, {
                            "key": "class-pid",
                            "name": tr("settings.appearance.titleStripMeta.class-pid", "Class + PID")
                        }]
                        currentKey: root.titleStripMeta
                        onSelected: (key) => {
                            root.titleStripMeta = key;
                            root.saveSettings();
                        }
                    }

                    NToggle {
                        label: tr("settings.appearance.focusedGlow.label", "Focused glow")
                        description: tr("settings.appearance.focusedGlow.description", "Add a subtle glow around the focused window preview")
                        checked: root.showFocusedWindowGlow
                        onToggled: (checked) => {
                            root.showFocusedWindowGlow = checked;
                            root.saveSettings();
                        }
                    }

                    NToggle {
                        label: tr("settings.appearance.urgencyBadge.label", "Urgency badge")
                        description: tr("settings.appearance.urgencyBadge.description", "Show a red badge when a window requests urgent attention")
                        checked: root.showUrgencyBadge
                        onToggled: (checked) => {
                            root.showUrgencyBadge = checked;
                            root.saveSettings();
                        }
                    }

                    NToggle {
                        label: tr("settings.appearance.floatingBadge.label", "Floating badge")
                        description: tr("settings.appearance.floatingBadge.description", "Show a badge on windows currently floating in Hyprland")
                        checked: root.showFloatingBadge
                        onToggled: (checked) => {
                            root.showFloatingBadge = checked;
                            root.saveSettings();
                        }
                    }

                    NToggle {
                        label: tr("settings.appearance.fullscreenBadge.label", "Fullscreen badge")
                        description: tr("settings.appearance.fullscreenBadge.description", "Show a badge on fullscreen or maximized window previews")
                        checked: root.showFullscreenBadge
                        onToggled: (checked) => {
                            root.showFullscreenBadge = checked;
                            root.saveSettings();
                        }
                    }

                    NToggle {
                        label: tr("settings.appearance.monitorBadge.label", "Monitor badge")
                        description: tr("settings.appearance.monitorBadge.description", "Show monitor index badges on window previews")
                        checked: root.showMonitorBadge
                        onToggled: (checked) => {
                            root.showMonitorBadge = checked;
                            root.saveSettings();
                        }
                    }

                    NValueSlider {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.dimInactive.label", "Inactive workspace dim")
                        description: tr("settings.appearance.dimInactive.description", "How much previews are dimmed when not on the active workspace")
                        from: 0
                        to: 0.8
                        stepSize: 0.05
                        value: root.dimInactiveWorkspaces
                        text: value.toFixed(2)
                        onMoved: (value) => {
                            if (Math.abs(root.dimInactiveWorkspaces - value) > 0.001) {
                                root.dimInactiveWorkspaces = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NValueSlider {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.inactiveSaturation.label", "Inactive saturation")
                        description: tr("settings.appearance.inactiveSaturation.description", "Keep non-focused workspaces colorful or push them toward monochrome")
                        from: 0.3
                        to: 1
                        stepSize: 0.05
                        value: root.inactiveWorkspaceSaturation
                        text: value.toFixed(2)
                        onMoved: (value) => {
                            if (Math.abs(root.inactiveWorkspaceSaturation - value) > 0.001) {
                                root.inactiveWorkspaceSaturation = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NValueSlider {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.hoverLift.label", "Hover lift")
                        description: tr("settings.appearance.hoverLift.description", "How much a hovered window card lifts upward")
                        from: 0
                        to: 12
                        stepSize: 1
                        value: root.hoverLiftAmount
                        text: value + "px"
                        onMoved: (value) => {
                            if (root.hoverLiftAmount !== value) {
                                root.hoverLiftAmount = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NComboBox {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.cornerMode.label", "Corner mode")
                        description: tr("settings.appearance.cornerMode.description", "Use Hyprland rounding or force a fixed radius for previews")
                        model: [{
                            "key": "hyprland",
                            "name": tr("settings.appearance.cornerMode.hyprland", "Hyprland")
                        }, {
                            "key": "fixed",
                            "name": tr("settings.appearance.cornerMode.fixed", "Fixed")
                        }]
                        currentKey: root.previewCornerMode
                        onSelected: (key) => {
                            root.previewCornerMode = key;
                            root.saveSettings();
                        }
                    }

                    NValueSlider {
                        visible: root.previewCornerMode === "fixed"
                        Layout.fillWidth: true
                        label: tr("settings.appearance.fixedCornerRadius.label", "Fixed corner radius")
                        description: tr("settings.appearance.fixedCornerRadius.description", "Corner radius applied when corner mode is set to Fixed")
                        from: 0
                        to: 32
                        stepSize: 1
                        value: root.previewFixedCornerRadius
                        text: value + "px"
                        onMoved: (value) => {
                            if (root.previewFixedCornerRadius !== value) {
                                root.previewFixedCornerRadius = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NToggle {
                        label: tr("settings.appearance.borderGradient.label", "Border gradient")
                        description: tr("settings.appearance.borderGradient.description", "Blend active/inactive border tones for a richer border highlight")
                        checked: root.useBorderGradient
                        onToggled: (checked) => {
                            root.useBorderGradient = checked;
                            root.saveSettings();
                        }
                    }

                    NValueSlider {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.containerBorder.label", "Container border")
                        description: tr("settings.appearance.containerBorder.description", "Border thickness of the overview container (-1 for default)")
                        from: -1
                        to: 10
                        stepSize: 1
                        value: root.containerBorderWidth
                        text: value < 0 ? tr("settings.common.default", "Default") : value + "px"
                        onMoved: (value) => {
                            if (root.containerBorderWidth !== value) {
                                root.containerBorderWidth = value;
                                root.saveSettings();
                            }
                        }
                    }

                    NValueSlider {
                        Layout.fillWidth: true
                        label: tr("settings.appearance.selectionBorder.label", "Selection border")
                        description: tr("settings.appearance.selectionBorder.description", "Border thickness of the active workspace indicator (-1 for default)")
                        from: -1
                        to: 10
                        stepSize: 1
                        value: root.selectionBorderWidth
                        text: value < 0 ? tr("settings.common.default", "Default") : value + "px"
                        onMoved: (value) => {
                            if (root.selectionBorderWidth !== value) {
                                root.selectionBorderWidth = value;
                                root.saveSettings();
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.marginM
                    }

                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

            }

        }

    }

}
