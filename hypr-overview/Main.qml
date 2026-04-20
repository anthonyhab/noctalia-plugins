import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "components"
import "helpers/Utils.js" as Utils
import "helpers"
import qs.Commons
import qs.Commons as Commons

Item {
  // Check hideEmptyRows logic if needed.
  // This is complex because OverviewGrid calculates content based on windows.
  // Repplicating that here might be expensive.
  // For navigation, maybe we just iterate ALL valid slots in the grid and skip if hidden?
  // Simplification: Just include them all for now, or fetch from OverviewGrid if possible? No, can't access easily.
  // Let's just include all numeric IDs. If hideEmptyRows is on, we might jump to an empty one that is hidden?
  // Ideally we shouldn't.
  // Let's implement a simplified "hasContent" check here:
  // content = (activeWorkspace == wsId) OR (windows exist on wsId)

  id: root

  property var pluginApi: null
  // === OVERVIEW SETTINGS ===
  property int gridRows: getSetting("rows", 2)
  property int gridColumns: getSetting("columns", 5)
  property real gridScale: getSetting("scale", 0.16)
  property bool hideEmptyRows: getSetting("hideEmptyRows", true)
  property bool showScratchpadWorkspaces: getSetting("showScratchpadWorkspaces", false)
  property int gridSpacing: getSetting("gridSpacing", 0)
  property string overviewPosition: getSetting("position", "top")
  property int barMargin: getSetting("barMargin", 0)
  property bool useSlideAnimation: getSetting("useSlideAnimation", true)
  property int containerBorderWidth: getSetting("containerBorderWidth", -1)
  property int selectionBorderWidth: getSetting("selectionBorderWidth", -1)
  property string accentColorType: getSetting("accentColorType", "secondary")
  property string visualMode: getSetting("visualMode", getSetting("useSimplifiedPreview", false) ? "simplified" : "live")
  property string previewMode: getSetting("previewMode", "live")
  property string shaderPreset: getSetting("shaderPreset", "classic")
  property real shaderPresetStrength: getSetting("shaderPresetStrength", 0.7)
  property bool useSimplifiedPreview: visualMode !== "live"
  property bool showWindowTitleStrip: getSetting("showWindowTitleStrip", true)
  property int titleStripHeight: getSetting("titleStripHeight", 20)
  property string titleStripMode: getSetting("titleStripMode", "auto")
  property string titleStripPosition: normalizeTitleStripPosition(getSetting("titleStripPosition", "overlay-top"))
  property string titleStripMeta: getSetting("titleStripMeta", "class")
  property bool showWindowIcons: getSetting("showWindowIcons", true)
  property bool colorizeWindowIcons: getSetting("colorizeWindowIcons", false)
  property string windowIconPlacement: getSetting("windowIconPlacement", "center")
  property bool showWorkspaceLabels: getSetting("showWorkspaceLabels", true)
  property string workspaceLabelMode: getSetting("workspaceLabelMode", "number-name")
  property bool showFocusedWindowGlow: getSetting("showFocusedWindowGlow", true)
  property bool showUrgencyBadge: getSetting("showUrgencyBadge", true)
  property bool showFloatingBadge: getSetting("showFloatingBadge", true)
  property bool showFullscreenBadge: getSetting("showFullscreenBadge", false)
  property bool showMonitorBadge: getSetting("showMonitorBadge", false)
  property real dimInactiveWorkspaces: getSetting("dimInactiveWorkspaces", 0.35)
  property real inactiveWorkspaceSaturation: getSetting("inactiveWorkspaceSaturation", 0.75)
  property int hoverLiftAmount: getSetting("hoverLiftAmount", 4)
  property string previewCornerMode: getSetting("previewCornerMode", "hyprland")
  property int previewFixedCornerRadius: getSetting("previewFixedCornerRadius", 10)
  property bool useBorderGradient: getSetting("useBorderGradient", true)
  property string dragPreviewMode: getSetting("dragPreviewMode", "smart")
  property real dragSnapThreshold: getSetting("dragSnapThreshold", 0.33)
  property real retilePreviewOpacity: getSetting("retilePreviewOpacity", 0.55)
  property real previewWindowX: getSetting("previewWindowX", -1)
  property real previewWindowY: getSetting("previewWindowY", -1)
  property var previewWindowPositions: getSetting("previewWindowPositions", ({}))
  property bool showRowColumnGuides: getSetting("showRowColumnGuides", false)
  property string specialWorkspaceStyle: getSetting("specialWorkspaceStyle", "pill")
  property string animationProfile: getSetting("animationProfile", "hyprlike")
  property int animationDurationMs: getSetting("animationDurationMs", 200)
  property real simplifiedPixelDensity: getSetting("simplifiedPixelDensity", 0.5)
  property real simplifiedColorDepth: getSetting("simplifiedColorDepth", 6)
  property real simplifiedSaturation: getSetting("simplifiedSaturation", 1.1)
  property real simplifiedContrast: getSetting("simplifiedContrast", 1.1)
  property real overviewBackgroundOpacityRatio: getSetting("overviewBackgroundOpacityRatio", 1)
  property bool showLayoutBadge: getSetting("showLayoutBadge", true)
  // === GLASS/BLUR SETTINGS ===
  property bool enableGlassMode: getSetting("enableGlassMode", false)
  property real glassTintStrength: getSetting("glassTintStrength", 0.55)
  property real glassBorderOpacity: getSetting("glassBorderOpacity", 0.75)
  property bool enableBlur: getSetting("enableBlur", false)
  // === WALLPAPER SETTINGS ===
  property bool showEmptyWorkspaceWallpaper: getSetting("showEmptyWorkspaceWallpaper", false)
  property string emptyWorkspaceWallpaperPath: getSetting("emptyWorkspaceWallpaperPath", "")
  property string specialEmptyWorkspaceWallpaperPath: getSetting("specialEmptyWorkspaceWallpaperPath", "")
  property real emptyWorkspaceWallpaperOpacity: getSetting("emptyWorkspaceWallpaperOpacity", 0.18)
  property string detectedWallpaper: ""
  // === LAYOUT DATA ===
  property var workspaceLayouts: ({})
  property var _pendingLayouts: ({})   // wsId → expected layoutName

  function setPendingLayout(wsId, layoutName) {
    var p = {};
    var old = _pendingLayouts || {};
    for (var k in old)
      p[k] = old[k];
    p[wsId] = layoutName;
    _pendingLayouts = p;
  }

  property var workspaceScrollDirections: (hyprConfig && hyprConfig.workspaceScrollDirections) || ({})
  // === OVERVIEW STATE ===
  property bool overviewOpen: false
  // Track the last navigated index for smooth keyboard/mouse navigation
  // This is needed because activeWorkspace might not update immediately after dispatch
  property int lastNavigatedIndex: -1
  // Track the currently active special workspace name (for indicator)
  // This is needed because hyprctl activeworkspace may not report special workspaces correctly
  property string activeSpecialWorkspaceName: ""
  // === HYPRLAND DATA ===
  property var windowList: []
  property var addresses: []
  property var windowByAddress: ({})
  property var monitors: []
  readonly property var workspaceMonitorBindings: {
    var bindings = {};
    var wins = windowList || [];
    for (var i = 0; i < wins.length; i++) {
      var win = wins[i];
      if (!win || !win.workspace)
        continue;
      var wsId = win.workspace.id;
      var monId = win.monitor;
      if (wsId === undefined || monId === undefined)
        continue;
      if (!bindings[wsId])
        bindings[wsId] = [];
      if (bindings[wsId].indexOf(monId) === -1)
        bindings[wsId].push(monId);
    }
    return bindings;
  }
  property var activeWorkspace: null
  property string activeWindowAddress: ""
  property var workspaces: []
  property bool pendingWindowListRefresh: false
  property bool pendingMonitorRefresh: false
  property bool pendingWorkspaceRefresh: false
  property bool pendingActiveWindowRefresh: false
  readonly property var specialWorkspaces: {
    if (!showScratchpadWorkspaces)
      return [];

    var byName = {};
    // From hyprctl workspaces
    var workspaceList = root.workspaces || [];
    for (var i = 0; i < workspaceList.length; i++) {
      var ws = workspaceList[i];
      if (!ws)
        continue;

      var rawName = ws.name || "";
      var isSpecial = (ws.id < 0) || (rawName && rawName.toString().startsWith("special:")) || rawName === "special";
      if (!isSpecial)
        continue;

      var normalizedName = normalizeSpecialName(rawName);
      if (!byName[normalizedName])
        byName[normalizedName] = {
          "id": ws.id,
          "rawName": rawName,
          "name": normalizedName,
          "windows": []
        };
    }
    // From windows (fallback for unlisted workspaces)
    for (var addr in windowByAddress) {
      var win = windowByAddress[addr];
      if (win && win.workspace && win.workspace.id < 0) {
        var rawWinName = win.workspace.name || "";
        var normalizedWinName = normalizeSpecialName(rawWinName);
        if (!byName[normalizedWinName])
          byName[normalizedWinName] = {
            "id": win.workspace.id,
            "rawName": rawWinName,
            "name": normalizedWinName,
            "windows": []
          };
      }
    }
    // Attach windows
    for (var addr2 in windowByAddress) {
      var win2 = windowByAddress[addr2];
      if (win2 && win2.workspace && win2.workspace.id < 0) {
        var rawWinName2 = win2.workspace.name || "";
        var normalizedWinName2 = normalizeSpecialName(rawWinName2);
        if (byName[normalizedWinName2])
          byName[normalizedWinName2].windows.push(win2);
      }
    }
    var result = [];
    for (var key in byName)
      result.push(byName[key]);
    result.sort(function (a, b) {
      return a.name.localeCompare(b.name);
    });
    return result;
  }

  // === SETTINGS HELPERS ===
  function getSetting(key, fallback) {
    return Utils.getSetting(pluginApi, key, fallback);
  }

  function clamp(value, minValue, maxValue) {
    return Utils.clamp(value, minValue, maxValue);
  }

  function normalizeTitleStripPosition(position) {
    var value = (position || "overlay-top").toString();
    if (value === "external")
      return "overlay-top";

    if (value !== "overlay-top" && value !== "overlay-bottom")
      return "overlay-top";

    return value;
  }

  function getAnimationDuration(kind) {
    var profile = animationProfile || "hyprlike";
    if (profile === "none")
      return 0;

    if (profile === "custom")
      return clamp(animationDurationMs, 80, 400);

    if (profile === "fast")
      return kind === "fast" ? 90 : 140;

    if (profile === "slow")
      return kind === "fast" ? 190 : 300;

    // hyprlike default
    return kind === "fast" ? 120 : 200;
  }

  function toggle() {
    if (overviewOpen)
      close();
    else
      open();
  }

  function open() {
    if (!overviewOpen) {
      overviewOpen = true;
      lastNavigatedIndex = -1;
      activeSpecialWorkspaceName = "";
      updateAll();
    }
  }

  function close() {
    if (overviewOpen) {
      overviewOpen = false;
      lastNavigatedIndex = -1;
      activeSpecialWorkspaceName = "";
    }
  }

  function refresh() {
    gridRows = getSetting("rows", 2);
    gridColumns = getSetting("columns", 5);
    gridScale = getSetting("scale", 0.16);
    hideEmptyRows = getSetting("hideEmptyRows", true);
    showScratchpadWorkspaces = getSetting("showScratchpadWorkspaces", false);
    gridSpacing = getSetting("gridSpacing", 0);
    overviewPosition = getSetting("position", "top");
    barMargin = getSetting("barMargin", 0);
    useSlideAnimation = getSetting("useSlideAnimation", true);
    animationProfile = getSetting("animationProfile", "hyprlike");
    animationDurationMs = getSetting("animationDurationMs", 200);
    showRowColumnGuides = getSetting("showRowColumnGuides", false);
    containerBorderWidth = getSetting("containerBorderWidth", -1);
    selectionBorderWidth = getSetting("selectionBorderWidth", -1);
    accentColorType = getSetting("accentColorType", "secondary");
    visualMode = getSetting("visualMode", getSetting("useSimplifiedPreview", false) ? "simplified" : "live");
    previewMode = getSetting("previewMode", "live");
    shaderPreset = getSetting("shaderPreset", "classic");
    shaderPresetStrength = getSetting("shaderPresetStrength", 0.7);
    showWindowTitleStrip = getSetting("showWindowTitleStrip", true);
    titleStripHeight = getSetting("titleStripHeight", 20);
    titleStripMode = getSetting("titleStripMode", "auto");
    titleStripPosition = normalizeTitleStripPosition(getSetting("titleStripPosition", "overlay-top"));
    titleStripMeta = getSetting("titleStripMeta", "class");
    showWindowIcons = getSetting("showWindowIcons", true);
    colorizeWindowIcons = getSetting("colorizeWindowIcons", false);
    windowIconPlacement = getSetting("windowIconPlacement", "center");
    showWorkspaceLabels = getSetting("showWorkspaceLabels", true);
    workspaceLabelMode = getSetting("workspaceLabelMode", "number-name");
    showFocusedWindowGlow = getSetting("showFocusedWindowGlow", true);
    showUrgencyBadge = getSetting("showUrgencyBadge", true);
    showFloatingBadge = getSetting("showFloatingBadge", true);
    showFullscreenBadge = getSetting("showFullscreenBadge", false);
    showMonitorBadge = getSetting("showMonitorBadge", false);
    dimInactiveWorkspaces = getSetting("dimInactiveWorkspaces", 0.35);
    inactiveWorkspaceSaturation = getSetting("inactiveWorkspaceSaturation", 0.75);
    hoverLiftAmount = getSetting("hoverLiftAmount", 4);
    previewCornerMode = getSetting("previewCornerMode", "hyprland");
    previewFixedCornerRadius = getSetting("previewFixedCornerRadius", 10);
    useBorderGradient = getSetting("useBorderGradient", true);
    dragPreviewMode = getSetting("dragPreviewMode", "smart");
    dragSnapThreshold = getSetting("dragSnapThreshold", 0.33);
    retilePreviewOpacity = getSetting("retilePreviewOpacity", 0.55);
    previewWindowX = getSetting("previewWindowX", -1);
    previewWindowY = getSetting("previewWindowY", -1);
    previewWindowPositions = getSetting("previewWindowPositions", ({}));
    specialWorkspaceStyle = getSetting("specialWorkspaceStyle", "pill");
    simplifiedPixelDensity = getSetting("simplifiedPixelDensity", 0.5);
    simplifiedColorDepth = getSetting("simplifiedColorDepth", 6);
    simplifiedSaturation = getSetting("simplifiedSaturation", 1.1);
    simplifiedContrast = getSetting("simplifiedContrast", 1.1);
    overviewBackgroundOpacityRatio = getSetting("overviewBackgroundOpacityRatio", 1);
    showLayoutBadge = getSetting("showLayoutBadge", true);
    enableGlassMode = getSetting("enableGlassMode", false);
    glassTintStrength = getSetting("glassTintStrength", 0.55);
    glassBorderOpacity = getSetting("glassBorderOpacity", 0.75);
    enableBlur = getSetting("enableBlur", false);
    showEmptyWorkspaceWallpaper = getSetting("showEmptyWorkspaceWallpaper", false);
    emptyWorkspaceWallpaperPath = getSetting("emptyWorkspaceWallpaperPath", "");
    specialEmptyWorkspaceWallpaperPath = getSetting("specialEmptyWorkspaceWallpaperPath", "");
    emptyWorkspaceWallpaperOpacity = getSetting("emptyWorkspaceWallpaperOpacity", 0.18);
  }

  function updateWindowList() {
    getClients.running = true;
  }

  function updateMonitors() {
    getMonitors.running = true;
  }

  function updateWorkspaces() {
    getActiveWorkspace.running = true;
    getWorkspaces.running = true;
  }

  function updateActiveWindow() {
    getActiveWindow.running = true;
  }

  function updateAll() {
    updateWindowList();
    updateMonitors();
    updateWorkspaces();
    updateActiveWindow();
  }

  function updateWorkspaceLayouts() {
    var map = {};
    var workspaceList = workspaces || [];
    for (var i = 0; i < workspaceList.length; i++) {
      var ws = workspaceList[i];
      if (ws && ws.id !== undefined) {
        var layout = ws.tiledLayout || "dwindle";
        if (layout === "scrolling")
          layout = "scroll";
        map[ws.id] = layout;
      }
    }
    // Preserve pending optimistic values until Hyprland confirms them.
    var pending = _pendingLayouts || {};
    var confirmed = {};
    for (var wsKey in pending) {
      if (map[wsKey] === pending[wsKey]) {
        // Hyprland now agrees — clear this pending entry
        confirmed[wsKey] = true;
      } else if (map[wsKey] !== undefined) {
        // Hyprland disagrees (still stale) — keep optimistic value
        map[wsKey] = pending[wsKey];
      }
    }
    // Remove confirmed pending entries
    var remaining = {};
    for (var k in pending) {
      if (!confirmed[k])
        remaining[k] = pending[k];
    }
    _pendingLayouts = remaining;
    workspaceLayouts = map;
  }

  function copyObject(source) {
    var target = {};
    if (!source)
      return target;

    for (var key in source)
      target[key] = source[key];
    return target;
  }

  function queueRefresh(windowListRefresh, monitorRefresh, workspaceRefresh, activeWindowRefresh, immediate) {
    if (windowListRefresh)
      pendingWindowListRefresh = true;

    if (monitorRefresh)
      pendingMonitorRefresh = true;

    if (workspaceRefresh)
      pendingWorkspaceRefresh = true;

    if (activeWindowRefresh)
      pendingActiveWindowRefresh = true;

    if (immediate) {
      eventRefreshDebounce.stop();
      flushQueuedRefresh();
      return;
    }
    eventRefreshDebounce.restart();
  }

  function flushQueuedRefresh() {
    var shouldRefreshWindows = pendingWindowListRefresh;
    var shouldRefreshMonitors = pendingMonitorRefresh;
    var shouldRefreshWorkspaces = pendingWorkspaceRefresh;
    var shouldRefreshActiveWindow = pendingActiveWindowRefresh;
    pendingWindowListRefresh = false;
    pendingMonitorRefresh = false;
    pendingWorkspaceRefresh = false;
    pendingActiveWindowRefresh = false;
    if (shouldRefreshWindows)
      updateWindowList();

    if (shouldRefreshMonitors)
      updateMonitors();

    if (shouldRefreshWorkspaces)
      updateWorkspaces();

    if (shouldRefreshActiveWindow)
      updateActiveWindow();
  }

  function queueRefreshForEvent(eventName) {
    var name = (eventName || "").toString();
    if (name === "") {
      queueRefresh(true, true, true, true, false);
      return;
    }
    var windowRefresh = name.startsWith("openwindow") || name.startsWith("closewindow") || name.startsWith("movewindow") || name.startsWith("windowtitle") || name.startsWith("changefloatingmode") || name.startsWith("fullscreen") || name.startsWith("pin") || name.startsWith("minimize") || name.startsWith("urgent");
    var workspaceRefresh = name.startsWith("workspace") || name.startsWith("workspacev2") || name.startsWith("moveworkspace") || name.startsWith("createworkspace") || name.startsWith("destroyworkspace") || name.startsWith("renameworkspace") || name.startsWith("activespecial");
    var monitorRefresh = name.startsWith("monitoradded") || name.startsWith("monitorremoved") || name.startsWith("focusedmon");
    var activeWindowRefresh = name.startsWith("activewindow") || name.startsWith("activewindowv2");
    if (!windowRefresh && !workspaceRefresh && !monitorRefresh && !activeWindowRefresh)
      queueRefresh(true, false, true, true, false);
    else
      queueRefresh(windowRefresh, monitorRefresh, workspaceRefresh, activeWindowRefresh, false);
  }

  function refreshWindows(immediate) {
    queueRefresh(true, false, false, false, !!immediate);
  }

  function applyOptimisticWindowMove(address, x, y, workspaceId) {
    if (!address || !windowByAddress || !windowByAddress[address])
      return false;

    var nextByAddress = copyObject(windowByAddress);
    var currentWindow = nextByAddress[address];
    var nextWindow = copyObject(currentWindow);
    nextWindow.at = [Math.round(x), Math.round(y)];
    if (workspaceId !== undefined && workspaceId !== null) {
      var nextWorkspace = copyObject(currentWindow && currentWindow.workspace);
      nextWorkspace.id = workspaceId;
      if (!nextWorkspace.name && workspaceId >= 0)
        nextWorkspace.name = "" + workspaceId;

      nextWindow.workspace = nextWorkspace;
    }
    nextByAddress[address] = nextWindow;
    windowByAddress = nextByAddress;
    var nextWindowList = [];
    for (var i = 0; i < windowList.length; i++) {
      var win = windowList[i];
      if (win && win.address === address)
        nextWindowList.push(nextWindow);
      else
        nextWindowList.push(win);
    }
    windowList = nextWindowList;
    return true;
  }

  // === SPECIAL WORKSPACE LOGIC ===
  function normalizeSpecialName(wsName) {
    var name = (wsName || "").toString().trim();
    if (name.startsWith("special:"))
      name = name.slice("special:".length);

    name = name.trim();
    return name.length > 0 ? name : "special";
  }

  function getVisibleWorkspaces(monitorId) {
    var workspacesPerGroup = gridRows * gridColumns;
    var targetMonitor = monitors.find(function (m) {
      return String(m.id) === String(monitorId);
    });
    if (!targetMonitor)
      return [];
    var currentId = 1;
    if (targetMonitor && targetMonitor.activeWorkspace) {
      currentId = targetMonitor.activeWorkspace.id || 1;
    }
    if (currentId < 0)
      currentId = 1;
    var currentGroup = Math.floor((currentId - 1) / workspacesPerGroup);
    var minWorkspaceId = currentGroup * workspacesPerGroup + 1;
    var visible = [];
    for (var i = 0; i < workspacesPerGroup; i++) {
      var wsId = minWorkspaceId + i;
      visible.push({
                     "id": wsId,
                     "type": "normal"
                   });
    }
    var reservedSlots = 0;
    if (showScratchpadWorkspaces) {
      reservedSlots = Math.min(specialWorkspaces.length, workspacesPerGroup);
      reservedSlots = Math.min(reservedSlots, Math.max(0, workspacesPerGroup - 1));
      for (var j = 0; j < reservedSlots; j++) {
        var special = specialWorkspaces[j];
        var targetIndex = visible.length - reservedSlots + j;
        if (targetIndex >= 0 && targetIndex < visible.length)
          visible[targetIndex] = {
            "id": special.id,
            "type": "special",
            "name": special.name,
            "rawName": special.rawName
          };
      }
    }
    return visible;
  }

  function getMonitorIdForWorkspace(workspaceId) {
    var bindings = workspaceMonitorBindings;
    if (!bindings || !bindings[workspaceId] || bindings[workspaceId].length === 0)
      return -1;
    return bindings[workspaceId][0];
  }

  onOverviewOpenChanged: {
    if (overviewOpen)
      hyprConfig.enableDragMode();
    else
      hyprConfig.disableDragMode();
    if (!overviewOpen) {
      eventRefreshDebounce.stop();
      pendingWindowListRefresh = false;
      pendingMonitorRefresh = false;
      pendingWorkspaceRefresh = false;
      pendingActiveWindowRefresh = false;
    }
  }
  Component.onCompleted: {
    updateAll();
    detectWallpaperProcess.running = true;
  }

  Timer {
    id: eventRefreshDebounce

    interval: 40
    repeat: false
    onTriggered: {
      if (!root.overviewOpen)
        return;

      root.flushQueuedRefresh();
    }
  }

  Timer {
    // Hyprland does not always emit resize-oriented events for every geometry change.
    // Keep preview geometry in sync while overview is visible.
    id: geometrySyncRefresh

    interval: 500
    repeat: true
    running: root.overviewOpen
    onTriggered: {
      if (!root.overviewOpen || getClients.running)
        return;

      root.updateWindowList();
    }
  }

  Connections {
    function onRawEvent(event) {
      if (!root.overviewOpen)
        return;

      root.queueRefreshForEvent(event && event.name);
    }

    target: Hyprland
  }

  // Settings change listener
  Connections {
    function onPluginSettingsChanged() {
      refresh();
    }

    target: pluginApi
  }

  Process {
    id: getClients

    command: ["hyprctl", "clients", "-j"]

    stdout: StdioCollector {
      id: clientsCollector

      onStreamFinished: {
        try {
          root.windowList = JSON.parse(clientsCollector.text);
          var tempWinByAddress = {};
          for (var i = 0; i < root.windowList.length; ++i) {
            var win = root.windowList[i];
            tempWinByAddress[win.address] = win;
          }
          root.windowByAddress = tempWinByAddress;
          root.addresses = root.windowList.map(function (win) {
            return win.address;
          });
          var focused = root.windowList.find(function (win) {
            return !!win.focused || win.focusHistoryID === 0;
          });
          if (focused && focused.address)
            root.activeWindowAddress = focused.address;
        } catch (e) {
          Logger.e("WorkspaceOverview", "Failed to parse clients: " + e);
        }
      }
    }
  }

  Process {
    id: getMonitors

    command: ["hyprctl", "monitors", "-j"]

    stdout: StdioCollector {
      id: monitorsCollector

      onStreamFinished: {
        try {
          root.monitors = JSON.parse(monitorsCollector.text);
        } catch (e) {
          Logger.e("WorkspaceOverview", "Failed to parse monitors: " + e);
        }
      }
    }
  }

  Process {
    id: getActiveWorkspace

    command: ["hyprctl", "activeworkspace", "-j"]

    stdout: StdioCollector {
      id: activeWorkspaceCollector

      onStreamFinished: {
        try {
          root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
        } catch (e) {
          Logger.e("WorkspaceOverview", "Failed to parse active workspace: " + e);
        }
      }
    }
  }

  Process {
    id: getWorkspaces

    command: ["hyprctl", "workspaces", "-j"]

    stdout: StdioCollector {
      id: workspacesCollector

      onStreamFinished: {
        try {
          root.workspaces = JSON.parse(workspacesCollector.text);
          root.updateWorkspaceLayouts();
        } catch (e) {
          Logger.e("WorkspaceOverview", "Failed to parse workspaces: " + e);
        }
      }
    }
  }

  Process {
    id: getActiveWindow

    command: ["hyprctl", "activewindow", "-j"]

    stdout: StdioCollector {
      id: activeWindowCollector

      onStreamFinished: {
        try {
          var activeWindow = JSON.parse(activeWindowCollector.text);
          root.activeWindowAddress = (activeWindow && activeWindow.address) || "";
        } catch (e) {
          Logger.e("WorkspaceOverview", "Failed to parse active window: " + e);
        }
      }
    }
  }

  Process {
    id: detectWallpaperProcess

    command: ["hyprctl", "hyprpaper", "listactive"]

    stdout: StdioCollector {
      id: wallpaperCollector

      onStreamFinished: {
        try {
          var lines = wallpaperCollector.text.split('\n');
          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line || line === "")
              continue;

            // Parse output like "eDP-1 = /path/to/wallpaper.png"
            var match = line.match(/=\s*(.+)/);
            if (match && match[1]) {
              root.detectedWallpaper = match[1].trim();
              break;
            }
          }
        } catch (e) {
          Logger.w("WorkspaceOverview", "Failed to detect wallpaper: " + e);
        }
      }
    }
  }

  IpcHandler {
    function toggle() {
      root.toggle();
    }

    function togglePanel() {
      root.toggle();
    }

    function close() {
      root.close();
    }

    function closePanel() {
      root.close();
    }

    function open() {
      root.open();
    }

    function openPanel() {
      root.open();
    }

    target: "plugin:hypr-overview"
  }
  // === OVERLAY WINDOWS (one per screen) ===

  Variants {
    id: overviewVariants

    model: Quickshell.screens

    PanelWindow {
      id: overlayWindow

      required property var modelData
      readonly property HyprlandMonitor monitor: Hyprland.monitorFor(overlayWindow.screen)
      property bool monitorIsFocused: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.id) == (monitor && monitor.id)

      screen: modelData
      visible: root.overviewOpen
      WlrLayershell.namespace: enableBlur ? "noctalia:hypr-overview-blur" : "noctalia:hypr-overview"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.exclusiveZone: -1
      color: "transparent"

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      // === FOCUS GRAB ===
      HyprlandFocusGrab {
        id: grab

        property bool canBeActive: overlayWindow.monitorIsFocused

        windows: [overlayWindow]
        active: false
        onCleared: () => {
                     if (!active)
                     root.overviewOpen = false;
                   }
      }

      Connections {
        function onOverviewOpenChanged() {
          if (root.overviewOpen)
            delayedGrabTimer.start();
        }

        target: root
      }

      Timer {
        id: delayedGrabTimer

        interval: 150
        repeat: false
        onTriggered: {
          if (!grab.canBeActive)
            return;

          grab.active = root.overviewOpen;
        }
      }

      // === INPUT HANDLER (keyboard + scroll) ===
      Item {
        id: keyHandler

        anchors.fill: parent
        visible: root.overviewOpen
        focus: root.overviewOpen
        // --- Keyboard navigation ---
        Keys.onPressed: event => {
                          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
                            root.close();
                            event.accepted = true;
                            return;
                          }
                          var visible = root.getVisibleWorkspaces(overlayWindow.monitor.id);
                          if (visible.length === 0)
                          return;

                          // Determine current index: use lastNavigatedIndex if valid, otherwise find from activeWorkspace
                          var currentIndex = -1;
                          if (root.lastNavigatedIndex >= 0 && root.lastNavigatedIndex < visible.length) {
                            currentIndex = root.lastNavigatedIndex;
                          } else {
                            // Find current workspace in visible list from activeWorkspace
                            var currentWs = root.activeWorkspace;
                            var currentWsId = (currentWs && currentWs.id) || 1;
                            var currentWsName = (currentWs && currentWs.name) || "";
                            for (var i = 0; i < visible.length; i++) {
                              if (visible[i].type === "special") {
                                // For special workspaces, match by name
                                var normalizedCurrentName = root.normalizeSpecialName(currentWsName);
                                if (visible[i].name === normalizedCurrentName) {
                                  currentIndex = i;
                                  break;
                                }
                              } else {
                                // For normal workspaces, match by id
                                if (visible[i].id === currentWsId) {
                                  currentIndex = i;
                                  break;
                                }
                              }
                            }
                            if (currentIndex === -1)
                            currentIndex = 0;
                          }
                          var targetIndex = currentIndex;
                          var cols = root.gridColumns;
                          if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                            targetIndex--;
                            if (targetIndex < 0)
                            targetIndex = visible.length - 1;
                          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                            targetIndex++;
                            if (targetIndex >= visible.length)
                            targetIndex = 0;
                          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                            targetIndex -= cols;
                            if (targetIndex < 0)
                            targetIndex += visible.length;
                          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                            targetIndex += cols;
                            if (targetIndex >= visible.length)
                            targetIndex -= visible.length;
                          } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                            // Direct indexing (1-9)
                            // This maps to the first 9 visible slots
                            var position = event.key - Qt.Key_0;
                            if (position <= visible.length)
                            targetIndex = position - 1;
                          } else if (event.key === Qt.Key_0) {
                            // Map to 10th slot if exists
                            if (visible.length >= 10)
                            targetIndex = 9;
                          }
                          if (targetIndex !== currentIndex && visible[targetIndex]) {
                            var target = visible[targetIndex];
                            root.lastNavigatedIndex = targetIndex;
                            if (target.type === "special") {
                              root.activeSpecialWorkspaceName = target.name;
                              Hyprland.dispatch("togglespecialworkspace " + target.name);
                            } else {
                              root.activeSpecialWorkspaceName = "";
                              Hyprland.dispatch("workspace " + target.id);
                            }
                            event.accepted = true;
                          } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                            // Number key was pressed but didn't change workspace (e.g., pressed 5 but only 3 workspaces)
                            event.accepted = true;
                          }
                        }

        // --- Scroll wheel navigation ---
        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: event => {
                     var visible = root.getVisibleWorkspaces(overlayWindow.monitor.id);
                     if (visible.length === 0)
                     return;

                     // Determine current index: use lastNavigatedIndex if valid, otherwise find from activeWorkspace
                     var currentIndex = -1;
                     if (root.lastNavigatedIndex >= 0 && root.lastNavigatedIndex < visible.length) {
                       currentIndex = root.lastNavigatedIndex;
                     } else {
                       // Find current workspace in visible list from activeWorkspace
                       var currentWs = root.activeWorkspace;
                       var currentWsId = (currentWs && currentWs.id) || 1;
                       var currentWsName = (currentWs && currentWs.name) || "";
                       for (var i = 0; i < visible.length; i++) {
                         if (visible[i].type === "special") {
                           // For special workspaces, match by name
                           var normalizedCurrentName = root.normalizeSpecialName(currentWsName);
                           if (visible[i].name === normalizedCurrentName) {
                             currentIndex = i;
                             break;
                           }
                         } else {
                           // For normal workspaces, match by id
                           if (visible[i].id === currentWsId) {
                             currentIndex = i;
                             break;
                           }
                         }
                       }
                       // If not found (e.g., on a different group's workspace), default to first
                       if (currentIndex === -1)
                       currentIndex = 0;
                     }
                     var targetIndex = currentIndex;
                     if (event.angleDelta.y > 0) {
                       // Scroll up → previous workspace (wrapping)
                       targetIndex = currentIndex - 1;
                       if (targetIndex < 0)
                       targetIndex = visible.length - 1;
                     } else if (event.angleDelta.y < 0) {
                       // Scroll down → next workspace (wrapping)
                       targetIndex = currentIndex + 1;
                       if (targetIndex >= visible.length)
                       targetIndex = 0;
                     }
                     if (targetIndex !== currentIndex && visible[targetIndex]) {
                       var target = visible[targetIndex];
                       root.lastNavigatedIndex = targetIndex;
                       if (target.type === "special") {
                         root.activeSpecialWorkspaceName = target.name;
                         Hyprland.dispatch("togglespecialworkspace " + target.name);
                       } else {
                         root.activeSpecialWorkspaceName = "";
                         Hyprland.dispatch("workspace " + target.id);
                       }
                     }
                   }
        }
      }

      // === OVERVIEW CONTENT ===
      Item {
        id: contentContainer

        // Calculate effective margin based on bar position + height
        readonly property real barHeight: Style.getBarHeightForScreen(overlayWindow.screen.name)
        readonly property string barPosition: Commons.Settings.getBarPositionForScreen(overlayWindow.screen.name)
        // Margin: bar height + user-configurable additional margin
        readonly property real baseMargin: {
          if (root.overviewPosition === "top" && barPosition === "top")
            return barHeight + root.barMargin;

          if (root.overviewPosition === "bottom" && barPosition === "bottom")
            return barHeight + root.barMargin;

          return Style.marginM + root.barMargin;
        }
        // Position the content based on setting
        readonly property real contentY: {
          if (root.overviewPosition === "top")
            return baseMargin;

          if (root.overviewPosition === "bottom")
            return parent.height - contentColumn.height - baseMargin;

          return (parent.height - contentColumn.height) / 2; // center
        }

        anchors.fill: parent

        // Full screen dimming backdrop to improve a11y contrast
        Rectangle {
          anchors.fill: parent
          color: Qt.rgba((Color.mBackground?.r ?? 0), (Color.mBackground?.g ?? 0), (Color.mBackground?.b ?? 0), 1)
          opacity: root.overviewOpen ? 0.75 : 0

          Behavior on opacity {
            NumberAnimation {
              duration: root.getAnimationDuration("normal")
              easing.type: Easing.OutCubic
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            root.close();
          }
        }

        Column {
          id: contentColumn

          visible: root.overviewOpen
          x: (parent.width - width) / 2
          y: contentContainer.contentY
          opacity: root.overviewOpen ? 1 : 0

          Loader {
            id: overviewLoader

            active: root.overviewOpen

            sourceComponent: OverviewGrid {
              pluginMain: root
              hyprConfig: hyprConfig
              panelWindow: overlayWindow
              visible: true
              simplifiedPixelDensity: root.simplifiedPixelDensity
              simplifiedColorDepth: root.simplifiedColorDepth
              simplifiedSaturation: root.simplifiedSaturation
              simplifiedContrast: root.simplifiedContrast
              backgroundOpacityRatio: root.overviewBackgroundOpacityRatio
            }
          }

          Behavior on y {
            enabled: root.useSlideAnimation && root.getAnimationDuration("normal") > 0

            NumberAnimation {
              duration: root.getAnimationDuration("normal")
              easing.type: Easing.OutCubic
            }
          }

          Behavior on opacity {
            enabled: root.useSlideAnimation && root.getAnimationDuration("fast") > 0

            NumberAnimation {
              duration: root.getAnimationDuration("fast")
            }
          }
        }
      }

      mask: Region {
        item: root.overviewOpen ? keyHandler : null
      }
    }
  }

  HyprlandConfig {
    id: hyprConfig
  }
}
