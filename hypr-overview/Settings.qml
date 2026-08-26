import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "components"
import "helpers/HyprlandState.js" as HyprlandState
import "helpers/SettingsSchema.js" as SettingsSchema
import "helpers"
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  readonly property var pluginMain: pluginApi && pluginApi.mainInstance
  property bool isSyncing: false
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
  property string shaderPreset: "pixelated"
  property real shaderPresetStrength: 0.7
  property real simplifiedPixelDensity: 0.5
  property real simplifiedColorDepth: 6
  property real simplifiedSaturation: 1.1
  property real simplifiedContrast: 1.1
  property real overviewBackgroundOpacityRatio: (pluginMain && pluginMain.overviewBackgroundOpacityRatio) || 1
  property bool showWindowTitleStrip: true
  property int titleStripHeight: 20
  property string titleStripMode: "auto"
  property string titleStripPosition: "overlay-top"
  property string titleStripMeta: "class"
  property bool showWindowIcons: true
  property bool colorizeWindowIcons: false
  property string windowIconPlacement: "center"
  property bool showWorkspaceLabels: true
  property string workspaceLabelMode: "number-name"
  property bool showFocusedWindowGlow: true
  property bool showUrgencyBadge: true
  property bool showFloatingBadge: true
  property bool showFullscreenBadge: false
  property bool showMonitorIndicators: getSetting("showMonitorIndicators", true)
  property bool enableCrossMonitorDrag: getSetting("enableCrossMonitorDrag", true)
  property bool showLayoutBadge: true
  property real dimInactiveWorkspaces: 0.35
  property real inactiveWorkspaceSaturation: 0.75
  property int hoverLiftAmount: 4
  property string previewCornerMode: "hyprland"
  property int previewFixedCornerRadius: 10
  property bool useBorderGradient: true
  property string dragPreviewMode: "smart"
  property real dragSnapThreshold: 0.42
  property real previewWindowX: root.pluginMain && root.pluginMain.previewWindowX !== undefined ? root.pluginMain.previewWindowX : -1
  property real previewWindowY: root.pluginMain && root.pluginMain.previewWindowY !== undefined ? root.pluginMain.previewWindowY : -1
  property var previewWindowPositions: root.pluginMain && root.pluginMain.previewWindowPositions ? root.pluginMain.previewWindowPositions : ({})
  property real retilePreviewOpacity: 0.55
  property string animationProfile: "hyprlike"
  property int animationDurationMs: 200
  property bool showRowColumnGuides: false
  property string specialWorkspaceStyle: "pill"
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
    var seen = {};
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
    var map = {};
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
    var windowsMap = pluginMain && pluginMain.windowByAddress ? pluginMain.windowByAddress : {};
    var counts = {};
    var previewableCounts = {};
    var seen = {};
    for (var addr in windowsMap) {
      var win = windowsMap[addr];
      var wsKey = workspaceKeyForWindow(win);
      if (!wsKey)
        continue;

      counts[wsKey] = (counts[wsKey] || 0) + 1;
      var normalizedAddress = normalizePreviewAddress(win && win.address);
      if (normalizedAddress && previewWindowsByKey[normalizedAddress])
        previewableCounts[wsKey] = (previewableCounts[wsKey] || 0) + 1;

      if (seen[wsKey])
        continue;

      seen[wsKey] = true;
      options.push({
                     "key": wsKey,
                     "windowCount": counts[wsKey] || 0,
                     "previewableCount": previewableCounts[wsKey] || 0,
                     "name": workspaceDisplayName(wsKey, counts[wsKey] || 1)
                   });
    }
    var activeKey = workspaceKeyFromWorkspace(pluginMain && pluginMain.activeWorkspace);
    if (activeKey && !seen[activeKey]) {
      counts[activeKey] = counts[activeKey] || 0;
      previewableCounts[activeKey] = previewableCounts[activeKey] || 0;
      options.push({
                     "key": activeKey,
                     "windowCount": counts[activeKey] || 0,
                     "previewableCount": previewableCounts[activeKey] || 0,
                     "name": workspaceDisplayName(activeKey, counts[activeKey], true)
                   });
    }
    options.sort(function (a, b) {
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
      options[i].windowCount = counts[optionKey] || 0;
      options[i].previewableCount = previewableCounts[optionKey] || 0;
      options[i].name = workspaceDisplayName(optionKey, options[i].windowCount, optionKey === activeKey);
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

    var windowsMap = pluginMain && pluginMain.windowByAddress ? pluginMain.windowByAddress : {};
    for (var addr in windowsMap) {
      var win = windowsMap[addr];
      if (!workspaceMatchesKey(win, selected))
        continue;

      var normalizedAddress = normalizePreviewAddress(win && win.address);
      var toplevel = previewWindowsByKey[normalizedAddress] || null;
      list.push({
                  "address": normalizedAddress,
                  "win": win,
                  "toplevel": toplevel,
                  "hasLivePreview": !!toplevel
                });
    }
    return HyprlandState.sortWindowRecords(list);
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
  readonly property string fallbackPreviewMonitorKey: "__default__"
  readonly property string previewMonitorName: (previewMonitorData && previewMonitorData.name) ? previewMonitorData.name : ""
  readonly property string previewMonitorKey: monitorKeyForPreview()
  readonly property var previewSavedPosition: getSavedPreviewPosition(previewMonitorKey)
  readonly property var previewTargetScreen: {
    var screens = Quickshell.screens || [];
    var targetName = previewMonitorName;
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === targetName)
        return screens[i];
    }
    return screens.length > 0 ? screens[0] : null;
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
      var title = (win && win.title) || tr("overview.title.unknown");
      var cls = (win && win.class) || tr("overview.tooltip.unknown-class");
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

    while (key.startsWith("0x"))
      key = key.slice(2);
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
    var suffix = count > 0 ? (" " + tr("overview.tooltip.windows-count").replace("{count}", count)) : "";
    if (key.startsWith("special:")) {
      var specialName = key.slice("special:".length);
      var displaySpecialName = specialName === "special" ? tr("overview.tooltip.special") : specialName;
      return tr("overview.tooltip.special-prefix") + displaySpecialName + suffix + (isActive ? tr("overview.tooltip.active-suffix") : "");
    }
    if (key.startsWith("ws:")) {
      var id = key.slice(3);
      return tr("overview.tooltip.workspace-prefix") + id + suffix + (isActive ? tr("overview.tooltip.active-suffix") : "");
    }
    return key + suffix + (isActive ? tr("overview.tooltip.active-suffix") : "");
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
      return;
    }
    var selectedAddress = normalizePreviewAddress(previewWindowAddress);
    if (!selectedAddress) {
      previewWindowAddress = windows[0].key;
      return;
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
      return;
    }
    if (previewWindowAddress !== selectedAddress)
      previewWindowAddress = selectedAddress;
  }

  function ensureWorkspacePreviewSelection() {
    var options = previewWorkspaceOptions || [];
    if (!options || options.length === 0) {
      previewWorkspaceKey = "";
      return;
    }
    var activeKey = workspaceKeyFromWorkspace(pluginMain && pluginMain.activeWorkspace);
    var fallbackKey = options[0].key;
    var firstPreviewableKey = "";
    var activePreviewableKey = "";
    var firstNonEmptyKey = "";
    var activeNonEmptyKey = "";
    for (var i = 0; i < options.length; i++) {
      var option = options[i];
      if (!option || !option.key)
        continue;

      var windowCount = option.windowCount || 0;
      var previewableCount = option.previewableCount || 0;
      if (windowCount > 0 && !firstNonEmptyKey)
        firstNonEmptyKey = option.key;

      if (windowCount > 0 && option.key === activeKey)
        activeNonEmptyKey = option.key;

      if (previewableCount > 0 && !firstPreviewableKey)
        firstPreviewableKey = option.key;

      if (previewableCount > 0 && option.key === activeKey)
        activePreviewableKey = option.key;
    }
    var preferredKey = activePreviewableKey || firstPreviewableKey || activeNonEmptyKey || firstNonEmptyKey || fallbackKey;
    if (!previewWorkspaceKey) {
      previewWorkspaceKey = preferredKey;
      return;
    }
    var selectedOption = null;
    for (var i = 0; i < options.length; i++) {
      if (options[i].key === previewWorkspaceKey)
        selectedOption = options[i];
    }
    if (!selectedOption) {
      previewWorkspaceKey = preferredKey;
      return;
    }
    var selectedPreviewable = selectedOption.previewableCount || 0;
    var preferredPreviewable = 0;
    if (preferredKey && preferredKey !== previewWorkspaceKey) {
      for (var i = 0; i < options.length; i++) {
        if (options[i].key === preferredKey) {
          preferredPreviewable = options[i].previewableCount || 0;
          break;
        }
      }
    }
    if (selectedPreviewable === 0 && preferredPreviewable > 0)
      previewWorkspaceKey = preferredKey;
  }

  function getSetting(key, fallback) {
    return SettingsSchema.getSetting(pluginApi, key, fallback);
  }

  function tr(key) {
    if (!pluginApi || !pluginApi.tr)
      return key;

    return pluginApi.tr(key);
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

  function normalizeTitleStripPosition(position) {
    return SettingsSchema.normalizeTitleStripPosition(position);
  }

  function normalizePreviewPositionEntry(value) {
    if (!value || typeof value !== "object")
      return null;

    var xPos = parseFloat(value.x);
    var yPos = parseFloat(value.y);
    if (!isFinite(xPos) || !isFinite(yPos))
      return null;

    if (xPos < 0 || yPos < 0)
      return null;

    return {
      "x": xPos,
      "y": yPos
    };
  }

  function normalizePreviewPositionMap(value) {
    var normalized = {};
    if (!value || typeof value !== "object")
      return normalized;

    for (var key in value) {
      if (!key)
        continue;

      var entry = normalizePreviewPositionEntry(value[key]);
      if (!entry)
        continue;

      normalized[key] = entry;
    }
    return normalized;
  }

  function previewPositionMapHasEntries(value) {
    for (var key in value) {
      if (value[key])
        return true;
    }
    return false;
  }

  function monitorKeyForPreview() {
    if (previewMonitorName)
      return previewMonitorName;

    return fallbackPreviewMonitorKey;
  }

  function getSavedPreviewPosition(key) {
    var safeKey = key || fallbackPreviewMonitorKey;
    var normalized = normalizePreviewPositionMap(previewWindowPositions);
    var preferred = normalizePreviewPositionEntry(normalized[safeKey]);
    if (preferred)
      return {
        "x": preferred.x,
        "y": preferred.y,
        "valid": true
      };

    var fallback = normalizePreviewPositionEntry(normalized[fallbackPreviewMonitorKey]);
    if (fallback)
      return {
        "x": fallback.x,
        "y": fallback.y,
        "valid": true
      };

    var legacyX = parseFloatSetting(previewWindowX, -1);
    var legacyY = parseFloatSetting(previewWindowY, -1);
    if (legacyX >= 0 && legacyY >= 0)
      return {
        "x": legacyX,
        "y": legacyY,
        "valid": true
      };

    return {
      "x": -1,
      "y": -1,
      "valid": false
    };
  }

  function setSavedPreviewPosition(key, xPos, yPos) {
    var safeKey = key || fallbackPreviewMonitorKey;
    var normalizedX = parseFloatSetting(xPos, -1);
    var normalizedY = parseFloatSetting(yPos, -1);
    if (normalizedX < 0 || normalizedY < 0)
      return;

    var current = normalizePreviewPositionMap(previewWindowPositions);
    var next = {};
    for (var existingKey in current) {
      var entry = current[existingKey];
      if (!entry)
        continue;

      next[existingKey] = {
        "x": entry.x,
        "y": entry.y
      };
    }
    next[safeKey] = {
      "x": normalizedX,
      "y": normalizedY
    };
    if (!next[fallbackPreviewMonitorKey])
      next[fallbackPreviewMonitorKey] = {
        "x": normalizedX,
        "y": normalizedY
      };

    previewWindowPositions = next;
  }

  function syncFromPlugin() {
    if (!pluginApi)
      return;

    isSyncing = true;
    var settings = SettingsSchema.normalizeSettings(pluginApi);
    gridRows = settings.rows;
    gridColumns = settings.columns;
    gridScale = settings.scale;
    hideEmptyRows = settings.hideEmptyRows;
    showScratchpadWorkspaces = settings.showScratchpadWorkspaces;
    gridSpacing = settings.gridSpacing;
    overviewPosition = settings.position;
    barMargin = settings.barMargin;
    useSlideAnimation = settings.useSlideAnimation;
    overviewBackgroundOpacityRatio = settings.overviewBackgroundOpacityRatio;
    animationProfile = settings.animationProfile;
    animationDurationMs = settings.animationDurationMs;
    showRowColumnGuides = settings.showRowColumnGuides;
    containerBorderWidth = settings.containerBorderWidth;
    selectionBorderWidth = settings.selectionBorderWidth;
    accentColorType = settings.accentColorType;
    visualMode = settings.visualMode;
    shaderPreset = settings.shaderPreset;
    shaderPresetStrength = settings.shaderPresetStrength;
    simplifiedPixelDensity = settings.simplifiedPixelDensity;
    simplifiedColorDepth = settings.simplifiedColorDepth;
    simplifiedSaturation = settings.simplifiedSaturation;
    simplifiedContrast = settings.simplifiedContrast;
    titleStripMode = settings.titleStripMode;
    titleStripPosition = settings.titleStripPosition;
    showWindowTitleStrip = settings.showWindowTitleStrip;
    titleStripHeight = settings.titleStripHeight;
    titleStripMeta = settings.titleStripMeta;
    showWindowIcons = settings.showWindowIcons;
    colorizeWindowIcons = settings.colorizeWindowIcons;
    windowIconPlacement = settings.windowIconPlacement;
    showWorkspaceLabels = settings.showWorkspaceLabels;
    workspaceLabelMode = settings.workspaceLabelMode;
    showFocusedWindowGlow = settings.showFocusedWindowGlow;
    showUrgencyBadge = settings.showUrgencyBadge;
    showFloatingBadge = settings.showFloatingBadge;
    showFullscreenBadge = settings.showFullscreenBadge;
    showMonitorIndicators = settings.showMonitorIndicators;
    enableCrossMonitorDrag = settings.enableCrossMonitorDrag;
    showLayoutBadge = settings.showLayoutBadge;
    dimInactiveWorkspaces = settings.dimInactiveWorkspaces;
    inactiveWorkspaceSaturation = settings.inactiveWorkspaceSaturation;
    hoverLiftAmount = settings.hoverLiftAmount;
    previewCornerMode = settings.previewCornerMode;
    previewFixedCornerRadius = settings.previewFixedCornerRadius;
    useBorderGradient = settings.useBorderGradient;
    dragPreviewMode = settings.dragPreviewMode;
    dragSnapThreshold = settings.dragSnapThreshold;
    previewWindowX = settings.previewWindowX;
    previewWindowY = settings.previewWindowY;
    var previewPositionMap = normalizePreviewPositionMap(settings.previewWindowPositions);
    if (!previewPositionMapHasEntries(previewPositionMap) && previewWindowX >= 0 && previewWindowY >= 0)
      previewPositionMap[fallbackPreviewMonitorKey] = {
        "x": previewWindowX,
        "y": previewWindowY
      };

    previewWindowPositions = previewPositionMap;
    retilePreviewOpacity = settings.retilePreviewOpacity;
    specialWorkspaceStyle = settings.specialWorkspaceStyle;
    isSyncing = false;
  }

  function saveSettings() {
    if (!pluginApi || isSyncing)
      return;

    var nextSettings = {};
    nextSettings.rows = gridRows;
    nextSettings.columns = gridColumns;
    nextSettings.scale = gridScale;
    nextSettings.hideEmptyRows = hideEmptyRows;
    nextSettings.showScratchpadWorkspaces = showScratchpadWorkspaces;
    nextSettings.gridSpacing = gridSpacing;
    nextSettings.position = overviewPosition;
    nextSettings.barMargin = barMargin;
    nextSettings.useSlideAnimation = useSlideAnimation;
    nextSettings.overviewBackgroundOpacityRatio = overviewBackgroundOpacityRatio;
    nextSettings.animationProfile = animationProfile;
    nextSettings.animationDurationMs = animationDurationMs;
    var compatibilityPreviewPosition = getSavedPreviewPosition(previewMonitorKey);
    if (compatibilityPreviewPosition && compatibilityPreviewPosition.valid) {
      nextSettings.previewWindowX = compatibilityPreviewPosition.x;
      nextSettings.previewWindowY = compatibilityPreviewPosition.y;
    } else {
      nextSettings.previewWindowX = previewWindowX;
      nextSettings.previewWindowY = previewWindowY;
    }
    nextSettings.previewWindowPositions = normalizePreviewPositionMap(previewWindowPositions);
    nextSettings.showRowColumnGuides = showRowColumnGuides;
    nextSettings.containerBorderWidth = containerBorderWidth;
    nextSettings.selectionBorderWidth = selectionBorderWidth;
    nextSettings.accentColorType = accentColorType;
    nextSettings.visualMode = visualMode;
    nextSettings.shaderPreset = shaderPreset;
    nextSettings.shaderPresetStrength = shaderPresetStrength;
    nextSettings.simplifiedPixelDensity = simplifiedPixelDensity;
    nextSettings.simplifiedColorDepth = simplifiedColorDepth;
    nextSettings.simplifiedSaturation = simplifiedSaturation;
    nextSettings.simplifiedContrast = simplifiedContrast;
    nextSettings.titleStripMode = titleStripMode;
    nextSettings.titleStripPosition = normalizeTitleStripPosition(titleStripPosition);
    nextSettings.titleStripMeta = titleStripMeta;
    nextSettings.showWindowTitleStrip = showWindowTitleStrip;
    nextSettings.showWindowIcons = showWindowIcons;
    nextSettings.colorizeWindowIcons = colorizeWindowIcons;
    nextSettings.windowIconPlacement = windowIconPlacement;
    nextSettings.showWorkspaceLabels = showWorkspaceLabels;
    nextSettings.workspaceLabelMode = workspaceLabelMode;
    nextSettings.showFocusedWindowGlow = showFocusedWindowGlow;
    nextSettings.showUrgencyBadge = showUrgencyBadge;
    nextSettings.showFloatingBadge = showFloatingBadge;
    nextSettings.showFullscreenBadge = showFullscreenBadge;
    nextSettings.showMonitorIndicators = showMonitorIndicators;
    nextSettings.enableCrossMonitorDrag = enableCrossMonitorDrag;
    nextSettings.showLayoutBadge = showLayoutBadge;
    nextSettings.dimInactiveWorkspaces = dimInactiveWorkspaces;
    nextSettings.inactiveWorkspaceSaturation = inactiveWorkspaceSaturation;
    nextSettings.hoverLiftAmount = hoverLiftAmount;
    nextSettings.previewCornerMode = previewCornerMode;
    nextSettings.previewFixedCornerRadius = previewFixedCornerRadius;
    nextSettings.useBorderGradient = useBorderGradient;
    nextSettings.dragPreviewMode = dragPreviewMode;
    nextSettings.dragSnapThreshold = dragSnapThreshold;
    nextSettings.retilePreviewOpacity = retilePreviewOpacity;
    nextSettings.specialWorkspaceStyle = specialWorkspaceStyle;
    nextSettings.titleStripHeight = titleStripHeight;
    var settings = SettingsSchema.buildPersistedSettings(nextSettings);
    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();
    if (pluginMain)
      pluginMain.refresh();
  }

  spacing: Style.marginM
  Layout.fillWidth: true
  Layout.fillHeight: false
  Layout.minimumWidth: Math.round(520 * Style.uiScaleRatio)
  Layout.preferredWidth: Layout.minimumWidth
  Layout.preferredHeight: Math.round(640 * Style.uiScaleRatio)
  Layout.maximumHeight: Math.round(800 * Style.uiScaleRatio)
  onPluginApiChanged: syncFromPlugin()
  onPreviewWorkspaceOptionsChanged: ensureWorkspacePreviewSelection()
  Component.onCompleted: {
    syncFromPlugin();
    ensureWorkspacePreviewSelection();
  }

  Connections {
    target: pluginApi

    function onPluginSettingsChanged() {
      root.syncFromPlugin();
    }
  }

  // Description
  NText {
    text: tr("plugin.description")
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
    Layout.fillHeight: false
    currentIndex: 0
    distributeEvenly: true

    NTabButton {
      text: tr("settings.tabs.grid")
      tabIndex: 0
      checked: tabBar.currentIndex === 0
    }
    NTabButton {
      text: tr("settings.tabs.behavior")
      tabIndex: 1
      checked: tabBar.currentIndex === 1
    }
    NTabButton {
      text: tr("settings.tabs.layout")
      tabIndex: 2
      checked: tabBar.currentIndex === 2
    }
    NTabButton {
      text: tr("settings.tabs.appearance")
      tabIndex: 3
      checked: tabBar.currentIndex === 3
    }
  }

  HyprlandConfig {
    id: previewHyprConfig
  }

  // Tab Content
  NTabView {
    id: tabLayout

    Layout.fillWidth: true
    Layout.preferredHeight: Math.round(640 * Style.uiScaleRatio)
    currentIndex: tabBar.currentIndex

    // === Grid Tab ===
    Item {
      id: gridSettingsPage
      height: tabLayout.height
      implicitHeight: gridSettingsColumn.implicitHeight

      Flickable {
        id: gridSettingsFlickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: gridSettingsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
          id: gridSettingsColumn
          width: gridSettingsFlickable.width
          spacing: Style.marginL

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NSpinBox {
              Layout.fillWidth: true
              label: tr("settings.grid.rows.label")
              description: tr("settings.grid.rows.description")
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
              label: tr("settings.grid.columns.label")
              description: tr("settings.grid.columns.description")
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
            label: tr("settings.grid.scale.label")
            description: tr("settings.grid.scale.description")
            from: 0.05
            to: 0.5
            stepSize: 0.01
            value: root.gridScale
            text: value.toFixed(2)
            onMoved: value => {
              if (Math.abs(root.gridScale - value) > 0.001) {
                root.gridScale = value;
                root.saveSettings();
              }
            }
          }

          NValueSlider {
            Layout.fillWidth: true
            label: tr("settings.grid.spacing.label")
            description: tr("settings.grid.spacing.description")
            from: 0
            to: 50
            stepSize: 1
            value: root.gridSpacing
            text: value + "px"
            onMoved: value => {
              if (root.gridSpacing !== value) {
                root.gridSpacing = value;
                root.saveSettings();
              }
            }
          }

          NText {
            text: {
              var total = root.gridRows * root.gridColumns;
              return tr("settings.grid.total-workspaces").replace("{count}", total);
            }
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }

          // Warning when overview would be auto-shrunk to fit (predictive)
          NText {
            visible: root.willRequireFitScaling
            text: tr("settings.grid.scale-warning")
            color: Color.mError
            wrapMode: Text.WordWrap
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightMedium
          }

          NComboBox {
            Layout.fillWidth: true
            label: tr("settings.grid.animationProfile.label")
            description: tr("settings.grid.animationProfile.description")
            model: [
              {
                "key": "none",
                "name": tr("settings.grid.animationProfile.none")
              },
              {
                "key": "fast",
                "name": tr("settings.grid.animationProfile.fast")
              },
              {
                "key": "hyprlike",
                "name": tr("settings.grid.animationProfile.hyprlike")
              }
            ]
            currentKey: root.animationProfile
            onSelected: key => {
              root.animationProfile = key;
              root.saveSettings();
            }
          }
        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }
      }
    }

    // === Behavior Tab ===
    Item {
      id: behaviorSettingsPage
      height: tabLayout.height
      implicitHeight: behaviorSettingsColumn.implicitHeight

      Flickable {
        id: behaviorSettingsFlickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: behaviorSettingsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
          id: behaviorSettingsColumn
          width: behaviorSettingsFlickable.width
          spacing: Style.marginL

          NToggle {
            label: tr("settings.behavior.hide-empty-rows.label")
            description: tr("settings.behavior.hide-empty-rows.description")
            checked: root.hideEmptyRows
            onToggled: checked => {
              root.hideEmptyRows = checked;
              root.saveSettings();
            }
          }

          NToggle {
            label: tr("settings.behavior.show-scratchpad.label")
            description: tr("settings.behavior.show-scratchpad.description")
            checked: root.showScratchpadWorkspaces
            onToggled: checked => {
              root.showScratchpadWorkspaces = checked;
              root.saveSettings();
            }
          }

          NComboBox {
            Layout.fillWidth: true
            label: tr("settings.behavior.dragPreviewMode.label")
            description: tr("settings.behavior.dragPreviewMode.description")
            model: [
              {
                "key": "off",
                "name": tr("settings.behavior.dragPreviewMode.off")
              },
              {
                "key": "basic",
                "name": tr("settings.behavior.dragPreviewMode.basic")
              },
              {
                "key": "smart",
                "name": tr("settings.behavior.dragPreviewMode.smart")
              }
            ]
            currentKey: root.dragPreviewMode
            onSelected: key => {
              root.dragPreviewMode = key;
              root.saveSettings();
            }
          }

          NValueSlider {
            visible: root.dragPreviewMode !== "off"
            Layout.fillWidth: true
            label: tr("settings.behavior.retilePreviewOpacity.label")
            description: tr("settings.behavior.retilePreviewOpacity.description")
            from: 0.2
            to: 0.9
            stepSize: 0.05
            value: root.retilePreviewOpacity
            text: value.toFixed(2)
            onMoved: value => {
              if (Math.abs(root.retilePreviewOpacity - value) > 0.001) {
                root.retilePreviewOpacity = value;
                root.saveSettings();
              }
            }
          }

          NCollapsible {
            label: tr("settings.behavior.advanced.label")
            description: tr("settings.behavior.advanced.description")
            expanded: false
            Layout.fillWidth: true

            NValueSlider {
              Layout.fillWidth: true
              label: tr("settings.behavior.dragSnapThreshold.label")
              description: tr("settings.behavior.dragSnapThreshold.description")
              from: 0.42
              to: 0.49
              stepSize: 0.01
              value: root.dragSnapThreshold
              text: value.toFixed(2)
              onMoved: value => {
                if (Math.abs(root.dragSnapThreshold - value) > 0.001) {
                  root.dragSnapThreshold = value;
                  root.saveSettings();
                }
              }
            }
          }
        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }
      }
    }

    // === Layout Tab ===
    Item {
      id: layoutSettingsPage
      height: tabLayout.height
      implicitHeight: layoutSettingsColumn.implicitHeight

      Flickable {
        id: layoutSettingsFlickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: layoutSettingsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
          id: layoutSettingsColumn
          width: layoutSettingsFlickable.width
          spacing: Style.marginL

          NComboBox {
            Layout.fillWidth: true
            label: tr("settings.layout.position.label")
            description: tr("settings.layout.position.description")
            model: [
              {
                "key": "top",
                "name": tr("settings.layout.position.top")
              },
              {
                "key": "center",
                "name": tr("settings.layout.position.center")
              },
              {
                "key": "bottom",
                "name": tr("settings.layout.position.bottom")
              }
            ]
            currentKey: root.overviewPosition
            onSelected: key => {
              root.overviewPosition = key;
              root.saveSettings();
            }
          }

          NValueSlider {
            Layout.fillWidth: true
            label: tr("settings.layout.barMargin.label")
            description: tr("settings.layout.barMargin.description")
            from: 0
            to: 100
            stepSize: 1
            value: root.barMargin
            text: value + "px"
            onMoved: value => {
              if (root.barMargin !== value) {
                root.barMargin = value;
                root.saveSettings();
              }
            }
          }

          NValueSlider {
            Layout.fillWidth: true
            label: tr("settings.layout.backgroundOpacity.label")
            description: tr("settings.layout.backgroundOpacity.description")
            from: 0
            to: 1
            stepSize: 0.05
            value: root.overviewBackgroundOpacityRatio
            text: Math.round(value * 100) + "%"
            onMoved: value => {
              if (Math.abs(root.overviewBackgroundOpacityRatio - value) > 0.001) {
                root.overviewBackgroundOpacityRatio = value;
                root.saveSettings();
              }
            }
          }

          NToggle {
            label: tr("settings.layout.slideAnimation.label")
            description: tr("settings.layout.slideAnimation.description")
            checked: root.useSlideAnimation
            onToggled: checked => {
              root.useSlideAnimation = checked;
              root.saveSettings();
            }
          }

          NToggle {
            label: tr("settings.layout.workspaceLabels.label")
            description: tr("settings.layout.workspaceLabels.description")
            checked: root.showWorkspaceLabels
            onToggled: checked => {
              root.showWorkspaceLabels = checked;
              root.saveSettings();
            }
          }

          NComboBox {
            visible: root.showWorkspaceLabels
            Layout.fillWidth: true
            label: tr("settings.layout.workspaceLabelMode.label")
            description: tr("settings.layout.workspaceLabelMode.description")
            model: [
              {
                "key": "number",
                "name": tr("settings.layout.workspaceLabelMode.number")
              },
              {
                "key": "name",
                "name": tr("settings.layout.workspaceLabelMode.name")
              },
              {
                "key": "number-name",
                "name": tr("settings.layout.workspaceLabelMode.number-name")
              }
            ]
            currentKey: root.workspaceLabelMode
            onSelected: key => {
              root.workspaceLabelMode = key;
              root.saveSettings();
            }
          }

          NComboBox {
            Layout.fillWidth: true
            label: tr("settings.layout.specialWorkspaceStyle.label")
            description: tr("settings.layout.specialWorkspaceStyle.description")
            model: [
              {
                "key": "pill",
                "name": tr("settings.layout.specialWorkspaceStyle.pill")
              },
              {
                "key": "chip",
                "name": tr("settings.layout.specialWorkspaceStyle.chip")
              },
              {
                "key": "plain",
                "name": tr("settings.layout.specialWorkspaceStyle.plain")
              }
            ]
            currentKey: root.specialWorkspaceStyle
            onSelected: key => {
              root.specialWorkspaceStyle = key;
              root.saveSettings();
            }
          }

          NCollapsible {
            label: tr("settings.layout.advanced.label")
            description: tr("settings.layout.advanced.description")
            expanded: false
            Layout.fillWidth: true

            NToggle {
              label: tr("settings.layout.showLayoutBadge.label")
              description: tr("settings.layout.showLayoutBadge.description")
              checked: root.showLayoutBadge
              onToggled: checked => {
                root.showLayoutBadge = checked;
                root.saveSettings();
              }
            }

            NToggle {
              label: tr("settings.layout.showRowColumnGuides.label")
              description: tr("settings.layout.showRowColumnGuides.description")
              checked: root.showRowColumnGuides
              onToggled: checked => {
                root.showRowColumnGuides = checked;
                root.saveSettings();
              }
            }
          }
        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }
      }
    }

    // === Appearance Tab ===
    Item {
      id: appearanceSettingsPage
      height: tabLayout.height
      implicitHeight: appearanceSettingsColumn.implicitHeight

      Flickable {
        id: appearanceSettingsFlickable

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: appearanceSettingsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
          id: appearanceSettingsColumn

          width: appearanceSettingsFlickable.width
          spacing: Style.marginM

          // --- Preview Style ---
          NCollapsible {
            label: tr("settings.appearance.section.visualMode")
            description: tr("settings.appearance.sectionDescriptions.visualMode")
            expanded: true
            Layout.fillWidth: true

            NComboBox {
              Layout.fillWidth: true
              label: tr("settings.appearance.visualMode.label")
              description: tr("settings.appearance.visualMode.description")
              model: [
                {
                  "key": "live",
                  "name": tr("settings.appearance.visualMode.live")
                },
                {
                  "key": "simplified",
                  "name": tr("settings.appearance.visualMode.simplified")
                },
                {
                  "key": "off",
                  "name": tr("settings.appearance.visualMode.off")
                }
              ]
              currentKey: root.visualMode
              onSelected: key => {
                root.visualMode = key;
                root.saveSettings();
              }
            }

            NComboBox {
              visible: root.visualMode === "simplified"
              Layout.fillWidth: true
              label: tr("settings.appearance.shaderPreset.label")
              description: tr("settings.appearance.shaderPreset.description")
              model: [
                {
                  "key": "pixelated",
                  "name": tr("settings.appearance.shaderPreset.pixelated")
                },
                {
                  "key": "mac",
                  "name": tr("settings.appearance.shaderPreset.mac")
                }
              ]
              currentKey: root.shaderPreset
              onSelected: key => {
                root.shaderPreset = key;
                root.saveSettings();
              }
            }

            NValueSlider {
              visible: root.visualMode === "simplified"
              Layout.fillWidth: true
              label: tr("settings.appearance.pixelDensity.label")
              description: tr("settings.appearance.pixelDensity.description")
              from: 0.1
              to: 1
              stepSize: 0.05
              value: root.simplifiedPixelDensity
              text: value.toFixed(2)
              onMoved: value => {
                if (Math.abs(root.simplifiedPixelDensity - value) > 0.001) {
                  root.simplifiedPixelDensity = value;
                  root.saveSettings();
                }
              }
            }

            NValueSlider {
              visible: root.visualMode === "simplified"
              Layout.fillWidth: true
              label: tr("settings.appearance.shaderPresetStrength.label")
              description: tr("settings.appearance.shaderPresetStrength.description")
              from: 0
              to: 1
              stepSize: 0.05
              value: root.shaderPresetStrength
              text: value.toFixed(2)
              onMoved: value => {
                if (Math.abs(root.shaderPresetStrength - value) > 0.001) {
                  root.shaderPresetStrength = value;
                  root.saveSettings();
                }
              }
            }
          }

          // --- Window Icons ---
          NCollapsible {
            label: tr("settings.appearance.section.windowIcons")
            description: tr("settings.appearance.sectionDescriptions.windowIcons")
            expanded: true
            Layout.fillWidth: true

            NToggle {
              label: tr("settings.appearance.windowIcons.label")
              description: tr("settings.appearance.windowIcons.description")
              checked: root.showWindowIcons
              onToggled: checked => {
                root.showWindowIcons = checked;
                root.saveSettings();
              }
            }

            NToggle {
              label: tr("settings.appearance.colorizeWindowIcons.label")
              description: tr("settings.appearance.colorizeWindowIcons.description")
              checked: root.colorizeWindowIcons
              onToggled: checked => {
                root.colorizeWindowIcons = checked;
                root.saveSettings();
              }
            }

            NComboBox {
              visible: root.showWindowIcons
              Layout.fillWidth: true
              label: tr("settings.appearance.windowIconPlacement.label")
              description: tr("settings.appearance.windowIconPlacement.description")
              model: [
                {
                  "key": "center",
                  "name": tr("settings.appearance.windowIconPlacement.center")
                },
                {
                  "key": "corner",
                  "name": tr("settings.appearance.windowIconPlacement.corner")
                }
              ]
              currentKey: root.windowIconPlacement
              onSelected: key => {
                root.windowIconPlacement = key;
                root.saveSettings();
              }
            }
          }

          // --- Title Strip ---
          NCollapsible {
            label: tr("settings.appearance.section.titleStrip")
            description: tr("settings.appearance.sectionDescriptions.titleStrip")
            expanded: true
            Layout.fillWidth: true

            NComboBox {
              Layout.fillWidth: true
              label: tr("settings.appearance.titleStripMode.label")
              description: tr("settings.appearance.titleStripMode.description")
              model: [
                {
                  "key": "off",
                  "name": tr("settings.appearance.titleStripMode.off")
                },
                {
                  "key": "auto",
                  "name": tr("settings.appearance.titleStripMode.auto")
                },
                {
                  "key": "always",
                  "name": tr("settings.appearance.titleStripMode.always")
                }
              ]
              currentKey: root.titleStripMode
              onSelected: key => {
                root.titleStripMode = key;
                root.showWindowTitleStrip = key !== "off";
                root.saveSettings();
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.maximumHeight: root.titleStripMode !== "off" ? implicitHeight : 0
              implicitHeight: titleStripOptionsColumn.implicitHeight
              opacity: root.titleStripMode !== "off" ? 1.0 : 0.0
              visible: opacity > 0
              clip: true

              Behavior on Layout.maximumHeight {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutCubic
                }
              }

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutCubic
                }
              }

              ColumnLayout {
                id: titleStripOptionsColumn

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Style.marginL

                NComboBox {
                  Layout.fillWidth: true
                  label: tr("settings.appearance.titleStripPosition.label")
                  description: tr("settings.appearance.titleStripPosition.description")
                  model: [
                    {
                      "key": "overlay-top",
                      "name": tr("settings.appearance.titleStripPosition.overlay-top")
                    },
                    {
                      "key": "overlay-bottom",
                      "name": tr("settings.appearance.titleStripPosition.overlay-bottom")
                    }
                  ]
                  currentKey: root.titleStripPosition
                  onSelected: key => {
                    root.titleStripPosition = root.normalizeTitleStripPosition(key);
                    root.saveSettings();
                  }
                }

                NValueSlider {
                  Layout.fillWidth: true
                  label: tr("settings.appearance.titleStripHeight.label")
                  description: tr("settings.appearance.titleStripHeight.description")
                  from: 12
                  to: 32
                  stepSize: 1
                  value: root.titleStripHeight
                  text: value + "px"
                  onMoved: value => {
                    if (root.titleStripHeight !== value) {
                      root.titleStripHeight = value;
                      root.saveSettings();
                    }
                  }
                }

                NComboBox {
                  Layout.fillWidth: true
                  label: tr("settings.appearance.titleStripMeta.label")
                  description: tr("settings.appearance.titleStripMeta.description")
                  model: [
                    {
                      "key": "none",
                      "name": tr("settings.appearance.titleStripMeta.none")
                    },
                    {
                      "key": "class",
                      "name": tr("settings.appearance.titleStripMeta.class")
                    },
                    {
                      "key": "class-pid",
                      "name": tr("settings.appearance.titleStripMeta.class-pid")
                    }
                  ]
                  currentKey: root.titleStripMeta
                  onSelected: key => {
                    root.titleStripMeta = key;
                    root.saveSettings();
                  }
                }
              }
            }
          }

          // --- Window Badges ---
          NCollapsible {
            label: tr("settings.appearance.section.windowBadges")
            description: tr("settings.appearance.sectionDescriptions.windowBadges")
            expanded: true
            Layout.fillWidth: true

            NToggle {
              label: tr("settings.appearance.urgencyBadge.label")
              description: tr("settings.appearance.urgencyBadge.description")
              checked: root.showUrgencyBadge
              onToggled: checked => {
                root.showUrgencyBadge = checked;
                root.saveSettings();
              }
            }

            NToggle {
              label: tr("settings.appearance.floatingBadge.label")
              description: tr("settings.appearance.floatingBadge.description")
              checked: root.showFloatingBadge
              onToggled: checked => {
                root.showFloatingBadge = checked;
                root.saveSettings();
              }
            }

            NToggle {
              label: tr("settings.appearance.fullscreenBadge.label")
              description: tr("settings.appearance.fullscreenBadge.description")
              checked: root.showFullscreenBadge
              onToggled: checked => {
                root.showFullscreenBadge = checked;
                root.saveSettings();
              }
            }

            NText {
              text: tr("settings.appearance.section.multiMonitor")
              font.weight: Font.Bold
            }

            NToggle {
              label: tr("settings.appearance.showMonitorIndicators.label")
              description: tr("settings.appearance.showMonitorIndicators.description")
              checked: root.showMonitorIndicators
              onToggled: checked => {
                root.showMonitorIndicators = checked;
                root.saveSettings();
              }
            }

            NToggle {
              label: tr("settings.appearance.enableCrossMonitorDrag.label")
              description: tr("settings.appearance.enableCrossMonitorDrag.description")
              checked: root.enableCrossMonitorDrag
              onToggled: checked => {
                root.enableCrossMonitorDrag = checked;
                root.saveSettings();
              }
            }
          }

          // --- Dimming & Focus ---
          NCollapsible {
            label: tr("settings.appearance.section.dimmingFocus")
            description: tr("settings.appearance.sectionDescriptions.dimmingFocus")
            expanded: true
            Layout.fillWidth: true

            NValueSlider {
              Layout.fillWidth: true
              label: tr("settings.appearance.dimInactive.label")
              description: tr("settings.appearance.dimInactive.description")
              from: 0
              to: 0.8
              stepSize: 0.05
              value: root.dimInactiveWorkspaces
              text: value.toFixed(2)
              onMoved: value => {
                if (Math.abs(root.dimInactiveWorkspaces - value) > 0.001) {
                  root.dimInactiveWorkspaces = value;
                  root.saveSettings();
                }
              }
            }

            NValueSlider {
              Layout.fillWidth: true
              label: tr("settings.appearance.inactiveSaturation.label")
              description: tr("settings.appearance.inactiveSaturation.description")
              from: 0.3
              to: 1
              stepSize: 0.05
              value: root.inactiveWorkspaceSaturation
              text: value.toFixed(2)
              onMoved: value => {
                if (Math.abs(root.inactiveWorkspaceSaturation - value) > 0.001) {
                  root.inactiveWorkspaceSaturation = value;
                  root.saveSettings();
                }
              }
            }

            NValueSlider {
              Layout.fillWidth: true
              label: tr("settings.appearance.hoverLift.label")
              description: tr("settings.appearance.hoverLift.description")
              from: 0
              to: 12
              stepSize: 1
              value: root.hoverLiftAmount
              text: value + "px"
              onMoved: value => {
                if (root.hoverLiftAmount !== value) {
                  root.hoverLiftAmount = value;
                  root.saveSettings();
                }
              }
            }
          }

          // --- Borders & Corners ---
          NCollapsible {
            label: tr("settings.appearance.section.bordersCorners")
            description: tr("settings.appearance.sectionDescriptions.bordersCorners")
            expanded: true
            Layout.fillWidth: true

            NComboBox {
              Layout.fillWidth: true
              label: tr("settings.appearance.cornerMode.label")
              description: tr("settings.appearance.cornerMode.description")
              model: [
                {
                  "key": "hyprland",
                  "name": tr("settings.appearance.cornerMode.hyprland")
                },
                {
                  "key": "fixed",
                  "name": tr("settings.appearance.cornerMode.fixed")
                }
              ]
              currentKey: root.previewCornerMode
              onSelected: key => {
                root.previewCornerMode = key;
                root.saveSettings();
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.maximumHeight: root.previewCornerMode === "fixed" ? implicitHeight : 0
              implicitHeight: cornerRadiusSlider.implicitHeight
              opacity: root.previewCornerMode === "fixed" ? 1.0 : 0.0
              visible: opacity > 0
              clip: true

              Behavior on Layout.maximumHeight {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutCubic
                }
              }

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutCubic
                }
              }

              NValueSlider {
                id: cornerRadiusSlider

                anchors.left: parent.left
                anchors.right: parent.right
                label: tr("settings.appearance.fixedCornerRadius.label")
                description: tr("settings.appearance.fixedCornerRadius.description")
                from: 0
                to: 32
                stepSize: 1
                value: root.previewFixedCornerRadius
                text: value + "px"
                onMoved: value => {
                  if (root.previewFixedCornerRadius !== value) {
                    root.previewFixedCornerRadius = value;
                    root.saveSettings();
                  }
                }
              }
            }

            NToggle {
              label: tr("settings.appearance.useBorderGradient.label")
              description: tr("settings.appearance.useBorderGradient.description")
              checked: root.useBorderGradient
              onToggled: checked => {
                root.useBorderGradient = checked;
                root.saveSettings();
              }
            }

            NValueSlider {
              Layout.fillWidth: true
              label: tr("settings.appearance.containerBorderWidth.label")
              description: tr("settings.appearance.containerBorderWidth.description")
              from: -1
              to: 6
              stepSize: 1
              value: root.containerBorderWidth
              text: value < 0 ? tr("settings.common.default") : value + "px"
              onMoved: value => {
                if (root.containerBorderWidth !== value) {
                  root.containerBorderWidth = value;
                  root.saveSettings();
                }
              }
            }

            NValueSlider {
              Layout.fillWidth: true
              label: tr("settings.appearance.selectionBorderWidth.label")
              description: tr("settings.appearance.selectionBorderWidth.description")
              from: -1
              to: 8
              stepSize: 1
              value: root.selectionBorderWidth
              text: value < 0 ? tr("settings.common.default") : value + "px"
              onMoved: value => {
                if (root.selectionBorderWidth !== value) {
                  root.selectionBorderWidth = value;
                  root.saveSettings();
                }
              }
            }
          }

          NComboBox {
            Layout.fillWidth: true
            label: tr("settings.appearance.accentColor.label")
            description: tr("settings.appearance.accentColor.description")
            model: [
              {
                "key": "secondary",
                "name": tr("settings.appearance.accentColor.secondary")
              },
              {
                "key": "primary",
                "name": tr("settings.appearance.accentColor.primary")
              }
            ]
            currentKey: root.accentColorType
            onSelected: key => {
              root.accentColorType = key;
              root.saveSettings();
            }
          }
        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }
      }
    }
  }

  SettingsPreviewWindow {
    id: settingsPreviewWindow

    // Context
    pluginMain: root.pluginMain
    previewWorkspaceOptions: root.previewWorkspaceOptions
    previewWorkspaceKey: root.previewWorkspaceKey
    previewWorkspaceWindows: root.previewWorkspaceWindows
    previewMonitorData: root.previewMonitorData
    previewMonitorId: root.previewMonitorId
    monitorKey: root.previewMonitorKey
    targetScreen: root.previewTargetScreen
    previewHyprConfig: previewHyprConfig
    previewCenteringX: root.previewCenteringX
    previewCenteringY: root.previewCenteringY
    previewWorkspaceWatermark: root.previewWorkspaceWatermark
    // Persistent Memory
    pluginWindowX: root.previewSavedPosition.valid ? root.previewSavedPosition.x : -1
    pluginWindowY: root.previewSavedPosition.valid ? root.previewSavedPosition.y : -1
    onPositionSaved: (monitorKey, xPos, yPos) => {
      root.setSavedPreviewPosition(monitorKey, xPos, yPos);
      root.previewWindowX = xPos;
      root.previewWindowY = yPos;
      root.saveSettings();
    }
    // Bindings to active UI state to allow live previewing of un-saved tweaks
    visualMode: root.visualMode
    shaderPreset: root.shaderPreset
    shaderPresetStrength: root.shaderPresetStrength
    simplifiedPixelDensity: root.simplifiedPixelDensity
    simplifiedColorDepth: root.simplifiedColorDepth
    simplifiedSaturation: root.simplifiedSaturation
    simplifiedContrast: root.simplifiedContrast
    accentColorType: root.accentColorType
    showWindowIcons: root.showWindowIcons
    colorizeWindowIcons: root.colorizeWindowIcons
    windowIconPlacement: root.windowIconPlacement
    showFocusedWindowGlow: root.showFocusedWindowGlow
    showUrgencyBadge: root.showUrgencyBadge
    showFloatingBadge: root.showFloatingBadge
    showFullscreenBadge: root.showFullscreenBadge
    showMonitorBadge: root.showMonitorIndicators
    dimInactiveWorkspaces: root.dimInactiveWorkspaces
    inactiveWorkspaceSaturation: root.inactiveWorkspaceSaturation
    hoverLiftAmount: root.hoverLiftAmount
    previewCornerMode: root.previewCornerMode
    previewFixedCornerRadius: root.previewFixedCornerRadius
    useBorderGradient: root.useBorderGradient
    showWindowTitleStrip: root.showWindowTitleStrip
    titleStripPosition: root.normalizeTitleStripPosition(root.titleStripPosition)
    titleStripHeight: root.titleStripHeight
    titleStripMode: root.titleStripMode
    titleStripMeta: root.titleStripMeta
    selectionBorderWidth: root.selectionBorderWidth
    showRowColumnGuides: root.showRowColumnGuides
    showWorkspaceLabels: root.showWorkspaceLabels
    specialWorkspaceStyle: root.specialWorkspaceStyle
    animationProfile: root.animationProfile
    animationDurationMs: root.animationDurationMs
  }
}
