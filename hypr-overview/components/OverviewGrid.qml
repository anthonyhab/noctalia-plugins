import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../helpers/LayoutStrategy.js" as LayoutStrategy
import "../helpers/WorkspaceDragMapping.js" as WorkspaceDragMapping
import "../helpers/WorkspaceGeometry.js" as WorkspaceGeometry
import "../helpers"
import "."
import qs.Commons
import qs.Commons as Commons
import qs.Services.Power
import qs.Widgets

Item {
  // 20px padding each side

  id: root

  required property var pluginMain
  required property var panelWindow
  property real simplifiedPixelDensity: (pluginMain && pluginMain.simplifiedPixelDensity) || 0.5
  property real simplifiedColorDepth: (pluginMain && pluginMain.simplifiedColorDepth) || 6
  property real simplifiedSaturation: (pluginMain && pluginMain.simplifiedSaturation) || 1.1
  property real simplifiedContrast: (pluginMain && pluginMain.simplifiedContrast) || 1.1
  property string visualMode: (pluginMain && pluginMain.visualMode) || "live"
  property string shaderPreset: (pluginMain && pluginMain.shaderPreset) || "classic"
  property real shaderPresetStrength: (pluginMain && pluginMain.shaderPresetStrength) || 0.7
  property bool useSimplifiedPreview: (pluginMain && pluginMain.useSimplifiedPreview) || false
  property real backgroundOpacityRatio: 1
  property var hyprConfig
  readonly property HyprlandMonitor monitor: (panelWindow && panelWindow.screen) ? Hyprland.monitorFor(panelWindow.screen) : null
  readonly property var toplevels: typeof ToplevelManager !== "undefined" ? ToplevelManager.toplevels : null
  readonly property int workspacesShown: pluginMain ? (pluginMain.gridRows * pluginMain.gridColumns) : 10
  readonly property bool isViewingSpecialWorkspace: (monitor && monitor.activeWorkspace && monitor.activeWorkspace.id) < 0
  readonly property int workspaceGroup: isViewingSpecialWorkspace ? 0 : Math.floor((((monitor && monitor.activeWorkspace && monitor.activeWorkspace.id) || 1) - 1) / workspacesShown)
  readonly property var specialWorkspaces: (pluginMain && pluginMain.specialWorkspaces) || []
  // Property to track active workspace for indicator updates
  // Uses activeSpecialWorkspaceName to handle special workspaces that hyprctl doesn't report correctly
  property var _activeWsForIndicator: {
    // If we have an active special workspace name from navigation, use it
    if (pluginMain.activeSpecialWorkspaceName && pluginMain.activeSpecialWorkspaceName !== "")
      return {
        "id": -1,
        "name": "special:" + pluginMain.activeSpecialWorkspaceName
      };

    return pluginMain.activeWorkspace || (monitor && monitor.activeWorkspace);
  }
  readonly property int reservedSpecialSlots: {
    if (!pluginMain.showScratchpadWorkspaces)
      return 0;

    var reserved = Math.min(root.specialWorkspaces.length, root.workspacesShown);
    reserved = Math.min(reserved, Math.max(0, root.workspacesShown - 1));
    return reserved;
  }
  // Baseline overflow behavior: only show the first N special workspaces (A→Z) that fit.
  // Extension point: page/scroll `visibleSpecialWorkspaces` by applying an offset.
  readonly property var visibleSpecialWorkspaces: root.specialWorkspaces.slice(0, root.reservedSpecialSlots)
  readonly property int groupFirstWorkspaceId: root.workspaceGroup * root.workspacesShown + 1
  readonly property int groupLastWorkspaceId: root.groupFirstWorkspaceId + root.workspacesShown - 1
  readonly property int lastNumericWorkspaceId: root.groupLastWorkspaceId - root.reservedSpecialSlots
  property bool monitorIsFocused: (Hyprland && Hyprland.focusedMonitor && monitor && Hyprland.focusedMonitor.name === monitor.name)
  property var windows: pluginMain.windowList
  property var windowByAddress: pluginMain.windowByAddress
  property var windowAddresses: pluginMain.addresses
  property var monitorData: pluginMain.monitors.find(function (m) {
    return m.id === (root.monitor && root.monitor.id);
  })
  property real cellScale: pluginMain.gridScale
  // === THEME CUSTOMIZATION ===
  readonly property int containerBorderWidth: (pluginMain && pluginMain.containerBorderWidth >= 0) ? pluginMain.containerBorderWidth : Style.borderM
  readonly property int selectionBorderWidth: (pluginMain && pluginMain.selectionBorderWidth >= 0) ? pluginMain.selectionBorderWidth : Style.borderL
  readonly property color accentColor: (pluginMain && pluginMain.accentColorType === "primary") ? Color.mPrimary : Color.mSecondary
  // === FIT-TO-SCREEN LOGIC ===
  // Available space calculation (accounting for margins based on position)
  readonly property real marginXL: Style.marginXL
  readonly property real marginM: Style.marginM
  readonly property real barAwareMargin: {
    // Get bar info from parent context (passed via property or calculated)
    var sn = (panelWindow && panelWindow.screen) ? panelWindow.screen.name : "";
    var barHeight = sn ? Style.getBarHeightForScreen(sn) : 0;
    var barPos = sn ? Commons.Settings.getBarPositionForScreen(sn) : "bottom";
    var pos = pluginMain ? pluginMain.overviewPosition : "top";
    if (pos === "top" && barPos === "top")
      return marginXL + barHeight + marginM;

    if (pos === "bottom" && barPos === "bottom")
      return marginXL + barHeight + marginM;

    return marginXL;
  }
  readonly property real availableWidth: (monitorData && monitorData.transform % 2 === 1) ? ((monitor && monitor.height ? monitor.height : 1080) / (monitor && monitor.scale ? monitor.scale : 1)) - barAwareMargin * 2 : ((monitor && monitor.width ? monitor.width : 1920) / (monitor && monitor.scale ? monitor.scale : 1)) - barAwareMargin * 2
  readonly property real availableHeight: (monitorData && monitorData.transform % 2 === 1) ? ((monitor && monitor.width ? monitor.width : 1920) / (monitor && monitor.scale ? monitor.scale : 1)) - barAwareMargin * 2 : ((monitor && monitor.height ? monitor.height : 1080) / (monitor && monitor.scale ? monitor.scale : 1)) - barAwareMargin * 2
  // Grid's natural size (without fit scaling)
  readonly property real gridNaturalWidth: (pluginMain ? pluginMain.gridColumns : 5) * workspaceImplicitWidth + ((pluginMain ? pluginMain.gridColumns : 5) - 1) * workspaceSpacing + 40
  // 20px padding each side
  readonly property real gridNaturalHeight: {
    var rows = pluginMain ? pluginMain.gridRows : 2;
    var hideRows = pluginMain ? pluginMain.hideEmptyRows : false;
    var visibleRows = hideRows && rowsWithContent ? rowsWithContent.size : rows;
    if (visibleRows === 0)
      visibleRows = 1;

    // At least one row
    return visibleRows * workspaceImplicitHeight + (visibleRows - 1) * workspaceSpacing + 40;
  }
  // Fit scale to ensure grid stays on screen (never upscale, only downscale if needed)
  readonly property real fitScale: Math.min(1, Math.min(availableWidth / Math.max(1, gridNaturalWidth), availableHeight / Math.max(1, gridNaturalHeight)))
  // Workspace cell dimensions (accounting for rotated monitors)
  property real workspaceImplicitWidth: (monitorData && monitorData.transform % 2 === 1) ? ((monitor && monitor.height ? monitor.height : 1080) / (monitor && monitor.scale ? monitor.scale : 1) * root.cellScale) : ((monitor && monitor.width ? monitor.width : 1920) / (monitor && monitor.scale ? monitor.scale : 1) * root.cellScale)
  property real workspaceImplicitHeight: (monitorData && monitorData.transform % 2 === 1) ? ((monitor && monitor.width ? monitor.width : 1920) / (monitor && monitor.scale ? monitor.scale : 1) * root.cellScale) : ((monitor && monitor.height ? monitor.height : 1080) / (monitor && monitor.scale ? monitor.scale : 1) * root.cellScale)
  // Calculate centering offsets to "split the difference" of reserved space (bars)
  // reserved: [left, top, right, bottom]
  property real reservedLeft: (monitorData && monitorData.reserved && monitorData.reserved[0]) || 0
  property real reservedTop: (monitorData && monitorData.reserved && monitorData.reserved[1]) || 0
  property real reservedRight: (monitorData && monitorData.reserved && monitorData.reserved[2]) || 0
  property real reservedBottom: (monitorData && monitorData.reserved && monitorData.reserved[3]) || 0
  // Offset to apply to window positions to center the work area
  property real centeringXOffset: (reservedRight - reservedLeft) / 2
  property real centeringYOffset: (reservedBottom - reservedTop) / 2
  // Z-ordering
  property int workspaceZ: 0
  property int windowZ: 1
  property int windowDraggingZ: 99999
  property real workspaceSpacing: (hyprConfig && hyprConfig.gapsWorkspaces || 0) + (pluginMain.gridSpacing || 0)
  readonly property real workspaceCellRadius: {
    var screenScaledRadius = Style.screenRadius * root.cellScale;
    var containerRadius = Style.radiusL;
    // Snap tiny/fractional radii down to 0 so "square" settings stay visually crisp.
    var combinedRadius = Math.min(screenScaledRadius, containerRadius);
    var snappedRadius = Math.floor(combinedRadius);
    if (containerRadius <= 0 || screenScaledRadius < 1 || snappedRadius <= 1)
      return 0;

    return snappedRadius;
  }
  // Drag state
  property int draggingFromWorkspace: -1
  property int draggingTargetWorkspace: -1
  property var draggingTargetSpecial: null // For special workspace drag targets
  // Intra-workspace drag state
  property int draggingIntraWorkspace: -1
  // Workspace ID when dragging within same workspace
  property string draggingTargetAddress: ""
  // Address of window being dragged
  readonly property real zoneEdgeSize: Math.max(0.15, Math.min(0.5, pluginMain.dragSnapThreshold || 0.33))
  readonly property real zoneDeadzone: 0.04
  readonly property real directionSwitchConfidenceMargin: 0.12
  readonly property real directionFastCommitConfidence: 0.85
  readonly property real noopGeometryEpsilonPx: 2
  // iOS-style retiling state
  property var retilingTarget: null
  property var pendingRetileTarget: null
  // { targetAddress, targetX/Y/W/H, previewX/Y/W/H, targetNewX/Y/W/H, direction, confidence }
  property string retilingDirection: ""
  property real retilingConfidence: 0
  property string dragInteractionState: "idle"
  // "idle", "targeting", "lockedDirection"
  property string pendingRetileDirection: ""
  property real pendingRetileConfidence: 0
  readonly property int floatingDropMaxOffsetSteps: 6
  readonly property real floatingDropMinStepPx: 28
  readonly property real floatingOverlapThresholdRatio: 0.32
  readonly property real floatingDropSnapBasePx: 42
  readonly property real floatingDropSnapRatio: 0.1
  // === LAYOUT DATA (0.54+) ===
  // Map of workspaceId → layout name ("dwindle", "master", "scroll", "monocle")
  readonly property var workspaceLayouts: (pluginMain && pluginMain.workspaceLayouts) || ({})

  function getWorkspaceLayout(wsId) {
    return root.workspaceLayouts[wsId] || "dwindle";
  }

  // === GLASS EFFECT HELPERS ===
  function applyGlassEffect(baseColor, isHovered) {
    if (!pluginMain || !pluginMain.enableGlassMode)
      return baseColor;

    var tint = pluginMain.glassTintStrength || 0.55;
    var bg = isHovered ? Color.mix(baseColor, Color.mLayer0, 0.46) : baseColor;
    return Color.applyAlpha(bg, 1 - tint);
  }

  function applyGlassBorderOpacity(baseOpacity) {
    if (!pluginMain || !pluginMain.enableGlassMode)
      return baseOpacity;

    var glassOpacity = pluginMain.glassBorderOpacity || 0.75;
    return baseOpacity * glassOpacity;
  }

  // Scroll layout: sorted window order per workspace (delegated to LayoutStrategy).
  readonly property var scrollWindowOrder: LayoutStrategy.get("scroll").computeWindowOrder(root.windowByAddress, root.workspaceLayouts, (pluginMain && pluginMain.workspaceScrollDirections) || ({}))

  // Monocle layout: deck position per window (delegated to LayoutStrategy).
  readonly property var monocleWindowOrder: LayoutStrategy.get("monocle").computeWindowOrder(root.windowByAddress, root.workspaceLayouts, null)

  // Reserve a minimum inset so window borders don't visually merge with workspace borders.
  // Use half the indicator stroke, since the indicator border is drawn fully inside the workspace cell.
  readonly property real workspaceFrameReserveInset: root.clamp(Math.max(Math.max(1, Style.borderS), Math.ceil(Math.max(2, root.selectionBorderWidth) * 0.5) + 1), 2, 8)
  // Mirror Hyprland's gaps/border in preview pixels for physical-grid fidelity.
  readonly property real workspaceExclusiveGap: WorkspaceGeometry.getHyprlandPreviewInset({
                                                                                            "hyprGapsIn": (hyprConfig && hyprConfig.gapsIn) || 0,
                                                                                            "hyprBorderSize": (hyprConfig && hyprConfig.borderSize) || 0,
                                                                                            "positionScaleX": root.cellScale,
                                                                                            "positionScaleY": root.cellScale,
                                                                                            "fallbackInset": root.workspaceFrameReserveInset
                                                                                          })
  // Rows that have windows or contain the active workspace slot.
  property var rowsWithContent: {
    if (!pluginMain || !pluginMain.hideEmptyRows)
      return null;

    var rows = new Set();
    var groupFirst = root.groupFirstWorkspaceId;
    var groupLast = root.groupLastWorkspaceId;
    var activeValue = root.getActiveWorkspaceValueForGrid();
    if (activeValue !== null && activeValue >= groupFirst && activeValue <= groupLast) {
      var activeInGroup = activeValue - (root.workspaceGroup * root.workspacesShown);
      rows.add(Math.floor((activeInGroup - 1) / pluginMain.gridColumns));
    }
    for (var addr in windowByAddress) {
      var win = windowByAddress[addr];
      var effectiveValue = root.getEffectiveWorkspaceValueForWindow(win);
      if (effectiveValue === null)
        continue;

      if (effectiveValue < groupFirst || effectiveValue > groupLast)
        continue;

      var inGroup = effectiveValue - (root.workspaceGroup * root.workspacesShown);
      var rowIndex = Math.floor((inGroup - 1) / pluginMain.gridColumns);
      rows.add(rowIndex);
    }
    return rows;
  }

  function clamp(value, minValue, maxValue) {
    if (value < minValue)
      return minValue;

    if (value > maxValue)
      return maxValue;

    return value;
  }

  // === SPECIAL WORKSPACES ===
  // We discover special workspaces from `hyprctl workspaces -j` (pluginMain.workspaces)
  // so they appear even when empty.
  // === SPECIAL WORKSPACES ===
  function normalizeSpecialName(wsName) {
    return pluginMain.normalizeSpecialName(wsName);
  }

  // Get label for a special workspace (first letter of first window's class/title, or first letter of name)
  function getSpecialWorkspaceLabel(specialWs) {
    if (!specialWs || !specialWs.name)
      return "S";

    if (!specialWs.windows || specialWs.windows.length === 0)
      return specialWs.name.charAt(0).toUpperCase();

    var firstWin = specialWs.windows[0] || {};
    var cls = firstWin.class || "";
    var title = firstWin.title || "";
    var labelSource = cls.length > 0 ? cls : title;
    if (labelSource.length > 0)
      return labelSource.charAt(0).toUpperCase();

    return specialWs.name.charAt(0).toUpperCase();
  }

  function getNormalWorkspaceName(workspaceValue) {
    var list = pluginMain.workspaces || [];
    for (var i = 0; i < list.length; i++) {
      var ws = list[i];
      if (!ws || ws.id !== workspaceValue)
        continue;

      var name = (ws.name || "").toString();
      if (name.startsWith("special:"))
        continue;

      if (name === "" || name === ("" + workspaceValue))
        return "";

      return name;
    }
    return "";
  }

  function getWorkspaceDisplayLabel(workspaceValue, isSpecialSlot, specialWorkspace) {
    var labelMode = pluginMain.workspaceLabelMode || "number-name";
    if (isSpecialSlot) {
      var specialName = (specialWorkspace && specialWorkspace.name) || "special";
      if (labelMode === "name")
        return specialName;

      if (labelMode === "number-name")
        return "S - " + specialName;

      return getSpecialWorkspaceLabel(specialWorkspace);
    }
    var numeric = "" + workspaceValue;
    if (labelMode === "number")
      return numeric;

    var customName = getNormalWorkspaceName(workspaceValue);
    if (!customName)
      return numeric;

    if (labelMode === "name")
      return customName;

    return numeric + " - " + customName;
  }

  function getVisibleSpecialWorkspaceIndex(normalizedName) {
    if (!normalizedName)
      return -1;

    for (var i = 0; i < root.visibleSpecialWorkspaces.length; i++) {
      if (root.visibleSpecialWorkspaces[i].name === normalizedName)
        return i;
    }
    return -1;
  }

  function getEffectiveWorkspaceValueForWindow(windowData) {
    if (!windowData || !windowData.workspace)
      return null;

    var wsId = windowData.workspace.id;
    if (wsId < 0) {
      if (root.reservedSpecialSlots <= 0)
        return null;

      var normalizedName = normalizeSpecialName(windowData.workspace.name || "");
      var idx = getVisibleSpecialWorkspaceIndex(normalizedName);
      if (idx < 0)
        return null;

      return root.lastNumericWorkspaceId + 1 + idx;
    }
    if (wsId < root.groupFirstWorkspaceId || wsId > root.lastNumericWorkspaceId)
      return null;

    return wsId;
  }

  function workspaceHasWindows(workspaceId) {
    if (!windowByAddress)
      return false;

    for (var addr in windowByAddress) {
      var win = windowByAddress[addr];
      if (win && win.workspace && win.workspace.id === workspaceId)
        return true;
    }
    return false;
  }

  function getWallpaperSource(workspaceId) {
    if (!pluginMain || !pluginMain.showEmptyWorkspaceWallpaper)
      return "";

    // Use special wallpaper path for special workspaces
    var isSpecial = workspaceId < 0 || workspaceId > root.lastNumericWorkspaceId;
    var path = isSpecial ? pluginMain.specialEmptyWorkspaceWallpaperPath : "";

    // Fall back to regular path or detected wallpaper
    if (!path || path === "")
      path = pluginMain.emptyWorkspaceWallpaperPath || pluginMain.detectedWallpaper || "";

    if (!path || path === "")
      return "";

    // Ensure proper file:// prefix
    if (path.startsWith("/"))
      return "file://" + path;

    return path;
  }

  function getActiveWorkspaceValueForGrid() {
    // Use the _activeWs property from the indicator to ensure proper binding updates
    var ws = root._activeWsForIndicator || pluginMain.activeWorkspace || (monitor && monitor.activeWorkspace);
    if (!ws)
      return null;

    if (ws.id < 0) {
      if (root.reservedSpecialSlots <= 0)
        return null;

      var normalizedName = normalizeSpecialName(ws.name || "");
      var idx = getVisibleSpecialWorkspaceIndex(normalizedName);
      if (idx >= 0)
        return root.lastNumericWorkspaceId + 1 + idx;

      // Special workspace not visible due to overflow: clamp indicator to last slot.
      return root.groupLastWorkspaceId;
    }
    if (ws.id < root.groupFirstWorkspaceId || ws.id > root.lastNumericWorkspaceId)
      return null;

    return ws.id;
  }

  function isWindowInActiveWorkspace(windowData) {
    if (!windowData || !windowData.workspace)
      return false;

    var ws = root._activeWsForIndicator || pluginMain.activeWorkspace || (monitor && monitor.activeWorkspace);
    if (!ws || ws.id === undefined || ws.id === null)
      return false;

    if (windowData.workspace.id < 0 || ws.id < 0)
      return normalizeSpecialName(windowData.workspace.name || "") === normalizeSpecialName(ws.name || "");

    return windowData.workspace.id === ws.id;
  }

  function isWindowFocused(windowAddress, windowData) {
    if (!windowAddress)
      return false;

    if (pluginMain.activeWindowAddress && pluginMain.activeWindowAddress === windowAddress)
      return true;

    return !!(windowData && (windowData.focused || windowData.focusHistoryID === 0));
  }

  function getVisualYOffset(rowIndex) {
    if (!pluginMain || !pluginMain.hideEmptyRows)
      return rowIndex * (root.workspaceImplicitHeight + root.workspaceSpacing);

    var visualIndex = 0;
    for (var i = 0; i < rowIndex; i++) {
      if (root.rowsWithContent && root.rowsWithContent.has(i))
        visualIndex++;
    }
    return visualIndex * (root.workspaceImplicitHeight + root.workspaceSpacing);
  }

  function getWorkspaceOffsets(workspaceId) {
    var workspaceColIndex = 0;
    var workspaceRowIndex = 0;
    if (workspaceId > 0) {
      var workspaceInGroup = workspaceId - (root.workspaceGroup * root.workspacesShown);
      workspaceColIndex = Math.max(0, (workspaceInGroup - 1) % pluginMain.gridColumns);
      workspaceRowIndex = Math.max(0, Math.floor((workspaceInGroup - 1) / pluginMain.gridColumns));
    }
    return {
      "x": (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColIndex,
      "y": root.getVisualYOffset(workspaceRowIndex)
    };
  }

  function getScaledWindowFrameRect(win, winMonitor) {
    if (!win || !winMonitor)
      return null;

    return WorkspaceGeometry.mapWindowToPreviewFrame({
                                                       "windowData": win,
                                                       "monitorData": winMonitor,
                                                       "workspaceWidth": root.workspaceImplicitWidth,
                                                       "workspaceHeight": root.workspaceImplicitHeight,
                                                       "centeringX": root.centeringXOffset,
                                                       "centeringY": root.centeringYOffset,
                                                       "hyprGapsIn": (hyprConfig && hyprConfig.gapsIn) || 0,
                                                       "hyprBorderSize": (hyprConfig && hyprConfig.borderSize) || 0,
                                                       "fallbackInset": root.workspaceExclusiveGap,
                                                       "useSimplifiedPreview": root.useSimplifiedPreview
                                                     });
  }

  function getScaledWindowRectForWorkspace(win, workspaceId) {
    if (!win || !win.workspace || win.workspace.id !== workspaceId)
      return null;

    var winMonitorId = win.monitor || 0;
    var winMonitor = pluginMain.monitors.find(function (m) {
      return m.id === winMonitorId;
    });
    if (!winMonitor)
      return null;

    return root.getScaledWindowFrameRect(win, winMonitor);
  }

  function resolveFloatingDropPosition(delegateItem) {
    if (!delegateItem || !delegateItem.windowData || !delegateItem.windowData.workspace)
      return null;

    var monitorObj = delegateItem.windowMonitor || null;
    var logicalSize = WorkspaceGeometry.getMonitorLogicalSize(monitorObj);
    var localX = delegateItem.x - delegateItem.xOffset;
    var localY = delegateItem.y - delegateItem.yOffset;
    return WorkspaceDragMapping.resolveFloatingDropPosition({
                                                              "frameX": localX,
                                                              "frameY": localY,
                                                              "frameWidth": delegateItem.width,
                                                              "frameHeight": delegateItem.height,
                                                              "workspaceWidth": delegateItem.availableWorkspaceWidth,
                                                              "workspaceHeight": delegateItem.availableWorkspaceHeight,
                                                              "inset": delegateItem.workspaceInset || 0,
                                                              "effectivePositionScaleX": delegateItem.effectivePositionScaleX,
                                                              "effectivePositionScaleY": delegateItem.effectivePositionScaleY,
                                                              "positionScaleX": delegateItem.positionScaleX,
                                                              "positionScaleY": delegateItem.positionScaleY,
                                                              "centeringX": delegateItem.centeringX,
                                                              "centeringY": delegateItem.centeringY,
                                                              "monitorX": (monitorObj && monitorObj.x) || 0,
                                                              "monitorY": (monitorObj && monitorObj.y) || 0,
                                                              "monitorLogicalWidth": logicalSize.width,
                                                              "monitorLogicalHeight": logicalSize.height,
                                                              "windowWidthRaw": ((delegateItem.windowData.size && delegateItem.windowData.size[0]) || 1),
                                                              "windowHeightRaw": ((delegateItem.windowData.size && delegateItem.windowData.size[1]) || 1),
                                                              "workspaceId": delegateItem.windowData.workspace.id,
                                                              "monitorId": ((delegateItem.windowData && delegateItem.windowData.monitor) || -1),
                                                              "draggedAddress": delegateItem.address,
                                                              "windowByAddress": root.windowByAddress,
                                                              "overlapThresholdRatio": root.floatingOverlapThresholdRatio,
                                                              "snapBasePx": root.floatingDropSnapBasePx,
                                                              "snapRatio": root.floatingDropSnapRatio,
                                                              "minStepPx": root.floatingDropMinStepPx,
                                                              "maxOffsetSteps": root.floatingDropMaxOffsetSteps
                                                            });
  }

  function rectNearlyEqual(a, b, epsilonPx) {
    if (!a || !b)
      return false;

    return Math.abs(a.x - b.x) <= epsilonPx && Math.abs(a.y - b.y) <= epsilonPx && Math.abs(a.w - b.w) <= epsilonPx && Math.abs(a.h - b.h) <= epsilonPx;
  }

  function isSplitNoop(direction, draggedRect, targetRect, epsilonPx) {
    if (!draggedRect || !targetRect)
      return false;

    if (direction === "l")
      return Math.abs((draggedRect.x + draggedRect.w) - targetRect.x) <= epsilonPx && Math.abs(draggedRect.y - targetRect.y) <= epsilonPx && Math.abs(draggedRect.h - targetRect.h) <= epsilonPx;

    if (direction === "r")
      return Math.abs(draggedRect.x - (targetRect.x + targetRect.w)) <= epsilonPx && Math.abs(draggedRect.y - targetRect.y) <= epsilonPx && Math.abs(draggedRect.h - targetRect.h) <= epsilonPx;

    if (direction === "u")
      return Math.abs((draggedRect.y + draggedRect.h) - targetRect.y) <= epsilonPx && Math.abs(draggedRect.x - targetRect.x) <= epsilonPx && Math.abs(draggedRect.w - targetRect.w) <= epsilonPx;

    if (direction === "d")
      return Math.abs(draggedRect.y - (targetRect.y + targetRect.h)) <= epsilonPx && Math.abs(draggedRect.x - targetRect.x) <= epsilonPx && Math.abs(draggedRect.w - targetRect.w) <= epsilonPx;

    return false;
  }

  function isValidSwapTarget(retilingInfo, draggedAddress, currentWorkspaceId) {
    if (!retilingInfo || retilingInfo.direction !== "swap")
      return false;

    if (!retilingInfo.targetAddress || retilingInfo.targetAddress === draggedAddress)
      return false;

    var targetWin = root.windowByAddress[retilingInfo.targetAddress];
    if (!targetWin || !targetWin.workspace || targetWin.workspace.id !== currentWorkspaceId)
      return false;

    if (targetWin.floating || targetWin.fullscreen || targetWin.maximized)
      return false;

    return true;
  }

  function isValidSplitTarget(retilingInfo, currentWorkspaceId) {
    if (!retilingInfo || retilingInfo.direction === "" || retilingInfo.direction === "swap")
      return false;

    if (!retilingInfo.targetAddress)
      return false;

    var targetWin = root.windowByAddress[retilingInfo.targetAddress];
    if (!targetWin || !targetWin.workspace || targetWin.workspace.id !== currentWorkspaceId)
      return false;

    if (targetWin.floating || targetWin.fullscreen || targetWin.maximized)
      return false;

    return true;
  }

  function runHyprBatch(commands) {
    if (!commands || commands.length === 0)
      return;

    var payload = "";
    for (var i = 0; i < commands.length; i++) {
      if (i > 0)
        payload += "; ";

      payload += "dispatch " + commands[i];
    }
    hyprBatchDispatch.payload = payload;
    hyprBatchDispatch.running = true;
  }

  function resetRetileState() {
    directionDebounce.stop();
    root.retilingTarget = null;
    root.pendingRetileTarget = null;
    root.retilingDirection = "";
    root.retilingConfidence = 0;
    root.pendingRetileDirection = "";
    root.pendingRetileConfidence = 0;
    if (root.draggingTargetAddress !== "")
      root.dragInteractionState = "targeting";
    else
      root.dragInteractionState = "idle";
  }

  function retileTargetWithDirection(targetInfo, direction) {
    if (!targetInfo)
      return null;

    var targetX = targetInfo.targetX;
    var targetY = targetInfo.targetY;
    var targetW = targetInfo.targetW;
    var targetH = targetInfo.targetH;
    var previewX = targetX;
    var previewY = targetY;
    var previewW = targetW;
    var previewH = targetH;
    var targetNewX = targetX;
    var targetNewY = targetY;
    var targetNewW = targetW;
    var targetNewH = targetH;
    if (direction === "l") {
      previewW = targetW / 2;
      targetNewX = targetX + targetW / 2;
      targetNewW = targetW / 2;
    } else if (direction === "r") {
      previewX = targetX + targetW / 2;
      previewW = targetW / 2;
      targetNewW = targetW / 2;
    } else if (direction === "u") {
      previewH = targetH / 2;
      targetNewY = targetY + targetH / 2;
      targetNewH = targetH / 2;
    } else if (direction === "d") {
      previewY = targetY + targetH / 2;
      previewH = targetH / 2;
      targetNewH = targetH / 2;
    }
    var draggedCurrentRect = targetInfo.draggedCurrentRect || null;
    var predictedDraggedRect = null;
    if (draggedCurrentRect && direction !== "" && direction !== "swap")
      predictedDraggedRect = {
        "x": previewX,
        "y": previewY,
        "w": previewW,
        "h": previewH
      };

    return {
      "targetAddress": targetInfo.targetAddress,
      "direction": direction,
      "operationType": direction === "swap" ? "swap" : "split",
      "isNoop": !!targetInfo.isNoop,
      "noopReason": targetInfo.noopReason || "",
      "confidence": targetInfo.confidence || 0,
      "targetX": targetX,
      "targetY": targetY,
      "targetW": targetW,
      "targetH": targetH,
      "previewX": previewX,
      "previewY": previewY,
      "previewW": previewW,
      "previewH": previewH,
      "targetNewX": targetNewX,
      "targetNewY": targetNewY,
      "targetNewW": targetNewW,
      "targetNewH": targetNewH,
      "draggedCurrentRect": draggedCurrentRect,
      "predictedDraggedRect": predictedDraggedRect
    };
  }

  function commitRetileCandidate(candidate) {
    if (!candidate || candidate.direction === "" || candidate.isNoop) {
      resetRetileState();
      return;
    }
    directionDebounce.stop();
    root.retilingDirection = candidate.direction;
    root.retilingConfidence = candidate.confidence || 0;
    root.retilingTarget = root.retileTargetWithDirection(candidate, candidate.direction);
    root.pendingRetileDirection = "";
    root.pendingRetileConfidence = 0;
    root.pendingRetileTarget = null;
    root.dragInteractionState = "lockedDirection";
  }

  function updateRetileCandidate(candidate) {
    var dragMode = pluginMain.dragPreviewMode || "smart";
    if (dragMode === "off") {
      resetRetileState();
      return;
    }
    if (!candidate || candidate.direction === "" || candidate.isNoop) {
      if (root.retilingDirection !== "") {
        root.pendingRetileDirection = "";
        root.pendingRetileConfidence = 0;
        root.pendingRetileTarget = null;
        directionDebounce.stop();
        root.retilingDirection = "";
        root.retilingConfidence = 0;
        root.retilingTarget = null;
        root.dragInteractionState = "targeting";
      } else {
        root.retilingTarget = null;
      }
      return;
    }
    if (dragMode === "basic") {
      directionDebounce.stop();
      root.retilingDirection = candidate.direction;
      root.retilingConfidence = candidate.confidence || 0;
      root.retilingTarget = root.retileTargetWithDirection(candidate, candidate.direction);
      root.pendingRetileDirection = "";
      root.pendingRetileConfidence = 0;
      root.pendingRetileTarget = null;
      root.dragInteractionState = "targeting";
      return;
    }
    root.dragInteractionState = "targeting";
    // First candidate or same direction: update immediately for a responsive feel.
    if (root.retilingDirection === "" || candidate.direction === root.retilingDirection) {
      commitRetileCandidate(candidate);
      return;
    }
    // New direction: switch only if confidence meaningfully beats current.
    if ((candidate.confidence || 0) >= root.directionFastCommitConfidence) {
      commitRetileCandidate(candidate);
      return;
    }
    if ((candidate.confidence || 0) >= (root.retilingConfidence + root.directionSwitchConfidenceMargin)) {
      root.pendingRetileDirection = candidate.direction;
      root.pendingRetileConfidence = candidate.confidence || 0;
      root.pendingRetileTarget = candidate;
      directionDebounce.restart();
      return;
    }
    // Keep locked direction but update geometry when hovering a different target.
    root.retilingTarget = root.retileTargetWithDirection(candidate, root.retilingDirection);
  }

  // iOS-style spatial target detection - finds target window and determines split direction
  // Returns: { targetAddress, direction, targetX, targetY, targetW, targetH, previewX, previewY, previewW, previewH, targetNewX, targetNewY, targetNewW, targetNewH }
  // dragX, dragY are coordinates within windowSpace (already include workspace offset)
  function calculateRetileTarget(workspaceId, dragX, dragY, dragWidth, dragHeight) {
    // Guard: don't process if dragged window is fullscreen/maximized
    var draggedWin = root.windowByAddress[root.draggingTargetAddress];
    if (draggedWin && (draggedWin.fullscreen || draggedWin.maximized))
      return null;

    var dragCenterX = dragX + dragWidth / 2;
    var dragCenterY = dragY + dragHeight / 2;
    var workspaceOffsets = root.getWorkspaceOffsets(workspaceId);
    var wsOffsetX = workspaceOffsets.x;
    var wsOffsetY = workspaceOffsets.y;
    // Convert drag center to local workspace coordinates (0,0 at top-left of workspace cell)
    var localDragX = dragCenterX - wsOffsetX;
    var localDragY = dragCenterY - wsOffsetY;
    var draggedRectLocal = root.getScaledWindowRectForWorkspace(draggedWin, workspaceId);
    var draggedRectAbsolute = draggedRectLocal ? {
                                                   "x": draggedRectLocal.x + wsOffsetX,
                                                   "y": draggedRectLocal.y + wsOffsetY,
                                                   "w": draggedRectLocal.w,
                                                   "h": draggedRectLocal.h
                                                 } : null;
    // Collect candidates with distance scoring
    var candidates = [];
    for (var addr in root.windowByAddress) {
      var win = root.windowByAddress[addr];
      if (!win || !win.workspace || win.workspace.id !== workspaceId)
        continue;

      if (win.address === root.draggingTargetAddress)
        continue;

      if (win.floating)
        continue;

      var rect = root.getScaledWindowRectForWorkspace(win, workspaceId);
      if (!rect)
        continue;

      var scaledPosX = rect.x;
      var scaledPosY = rect.y;
      var winW = rect.w;
      var winH = rect.h;
      // Calculate distance from drag center to window center
      var winCenterX = scaledPosX + winW / 2;
      var winCenterY = scaledPosY + winH / 2;
      var distance = Math.sqrt(Math.pow(localDragX - winCenterX, 2) + Math.pow(localDragY - winCenterY, 2));
      // Check if in bounds or within 14px proximity
      var inBounds = (localDragX >= scaledPosX && localDragX <= scaledPosX + winW && localDragY >= scaledPosY && localDragY <= scaledPosY + winH);
      var proximityBuffer = 28 * root.cellScale;
      var inProximity = distance < Math.max(winW, winH) / 2 + proximityBuffer;
      if (inBounds || inProximity)
        candidates.push({
                          "address": win.address,
                          "x": scaledPosX,
                          "y": scaledPosY,
                          "w": winW,
                          "h": winH,
                          "distance": distance,
                          "inBounds": inBounds,
                          "currentRect": rect,
                          "score": inBounds ? 0 : distance
                        });
    }
    // Sort by score (lower = better)
    candidates.sort(function (a, b) {
      return a.score - b.score;
    });
    if (candidates.length === 0)
      return null;

    var target = candidates[0];
    // Calculate relative position within target window
    var relX = (localDragX - target.x) / target.w;
    var relY = (localDragY - target.y) / target.h;
    // Clamp to [0, 1]
    relX = Math.max(0, Math.min(1, relX));
    relY = Math.max(0, Math.min(1, relY));
    // Minimum absolute zone sizes
    var minEdgeZone = 32;
    // pixels
    var minCenterZone = 20;
    // pixels
    // Calculate effective zone boundaries (ensuring minimum sizes)
    var effectiveLeftZone = Math.max(zoneEdgeSize, minEdgeZone / target.w);
    var effectiveRightZone = Math.max(zoneEdgeSize, minEdgeZone / target.w);
    var effectiveTopZone = Math.max(zoneEdgeSize, minEdgeZone / target.h);
    var effectiveBottomZone = Math.max(zoneEdgeSize, minEdgeZone / target.h);
    // Determine which zone we're in
    var direction = "";
    var confidence = 0;
    var inLeftZone = relX < effectiveLeftZone;
    var inRightZone = relX > (1 - effectiveRightZone);
    var inTopZone = relY < effectiveTopZone;
    var inBottomZone = relY > (1 - effectiveBottomZone);
    var inCenterZone = !inLeftZone && !inRightZone && !inTopZone && !inBottomZone;
    // Check if center zone meets minimum size requirement
    var centerZoneW = target.w * (1 - effectiveLeftZone - effectiveRightZone);
    var centerZoneH = target.h * (1 - effectiveTopZone - effectiveBottomZone);
    var centerTooSmall = centerZoneW < minCenterZone || centerZoneH < minCenterZone;
    if (inCenterZone && !centerTooSmall) {
      var centerBoundaryX = Math.min(relX - effectiveLeftZone, (1 - effectiveRightZone) - relX);
      var centerBoundaryY = Math.min(relY - effectiveTopZone, (1 - effectiveBottomZone) - relY);
      var centerBoundaryDistance = Math.max(0, Math.min(centerBoundaryX, centerBoundaryY));
      if (centerBoundaryDistance > root.zoneDeadzone) {
        direction = "swap";
        var centerDistanceX = Math.abs(relX - 0.5) / 0.5;
        var centerDistanceY = Math.abs(relY - 0.5) / 0.5;
        var centerDistance = Math.sqrt(centerDistanceX * centerDistanceX + centerDistanceY * centerDistanceY);
        confidence = Math.max(0.3, 1 - Math.min(1, centerDistance));
      }
    } else {
      // Corner case: in multiple zones - pick closest edge
      var edges = [];
      if (inLeftZone)
        edges.push({
                     "dir": "l",
                     "dist": relX,
                     "depth": effectiveLeftZone
                   });

      if (inRightZone)
        edges.push({
                     "dir": "r",
                     "dist": 1 - relX,
                     "depth": effectiveRightZone
                   });

      if (inTopZone)
        edges.push({
                     "dir": "u",
                     "dist": relY,
                     "depth": effectiveTopZone
                   });

      if (inBottomZone)
        edges.push({
                     "dir": "d",
                     "dist": 1 - relY,
                     "depth": effectiveBottomZone
                   });

      edges.sort(function (a, b) {
        return a.dist - b.dist;
      });
      if (edges.length > 0) {
        var best = edges[0];
        var boundaryDistance = Math.max(0, best.depth - best.dist);
        if (boundaryDistance > root.zoneDeadzone) {
          direction = best.dir;
          confidence = Math.max(0.1, 1 - Math.min(1, best.dist / Math.max(0.001, best.depth)));
        }
      }
    }
    var targetRectLocal = {
      "x": target.x,
      "y": target.y,
      "w": target.w,
      "h": target.h
    };
    var isNoop = false;
    var noopReason = "";
    if (direction !== "" && direction !== "swap" && draggedRectLocal) {
      isNoop = root.isSplitNoop(direction, draggedRectLocal, targetRectLocal, root.noopGeometryEpsilonPx);
      if (isNoop)
        noopReason = "split-already-matches";
    }
    var targetInfo = {
      "targetAddress": target.address,
      "targetX": target.x + wsOffsetX,
      "targetY": target.y + wsOffsetY,
      "targetW": target.w,
      "targetH": target.h,
      "direction": direction,
      "confidence": confidence,
      "operationType": direction === "swap" ? "swap" : "split",
      "isNoop": isNoop,
      "noopReason": noopReason,
      "draggedCurrentRect": draggedRectAbsolute
    };
    var resolvedTarget = root.retileTargetWithDirection(targetInfo, direction);
    if (!resolvedTarget)
      return null;

    if (resolvedTarget.direction !== "" && resolvedTarget.direction !== "swap" && resolvedTarget.draggedCurrentRect && resolvedTarget.predictedDraggedRect) {
      var currentTargetRect = {
        "x": resolvedTarget.targetX,
        "y": resolvedTarget.targetY,
        "w": resolvedTarget.targetW,
        "h": resolvedTarget.targetH
      };
      var predictedTargetRect = {
        "x": resolvedTarget.targetNewX,
        "y": resolvedTarget.targetNewY,
        "w": resolvedTarget.targetNewW,
        "h": resolvedTarget.targetNewH
      };
      var draggedUnchanged = root.rectNearlyEqual(resolvedTarget.draggedCurrentRect, resolvedTarget.predictedDraggedRect, root.noopGeometryEpsilonPx);
      var targetUnchanged = root.rectNearlyEqual(currentTargetRect, predictedTargetRect, root.noopGeometryEpsilonPx);
      if (draggedUnchanged && targetUnchanged) {
        resolvedTarget.isNoop = true;
        if (!resolvedTarget.noopReason || resolvedTarget.noopReason === "")
          resolvedTarget.noopReason = "geometry-identical";
      }
    }
    return resolvedTarget;
  }

  // Update pluginMain with the minimum fit scale across all screens (for Settings UI warning)
  onFitScaleChanged: {
    if (pluginMain && pluginMain.reportFitScale)
      pluginMain.reportFitScale(fitScale);
  }
  implicitWidth: (overviewBackground.implicitWidth + 20) * fitScale
  implicitHeight: (overviewBackground.implicitHeight + 20) * fitScale

  Timer {
    id: directionDebounce

    interval: 85
    repeat: false
    onTriggered: {
      if (!root.pendingRetileTarget || root.pendingRetileDirection === "")
        return;

      root.retilingDirection = root.pendingRetileDirection;
      root.retilingConfidence = root.pendingRetileConfidence;
      root.retilingTarget = root.retileTargetWithDirection(root.pendingRetileTarget, root.retilingDirection);
      root.dragInteractionState = "lockedDirection";
      root.pendingRetileDirection = "";
      root.pendingRetileConfidence = 0;
      root.pendingRetileTarget = null;
    }
  }

  Process {
    id: hyprBatchDispatch

    property string payload: ""

    command: ["hyprctl", "--batch", payload]
  }

  // Scaled container for fit-to-screen
  Item {
    id: scaledContainer

    anchors.centerIn: parent
    width: overviewBackground.implicitWidth + 20
    height: overviewBackground.implicitHeight + 20
    scale: root.fitScale

    // Background container properly styled directly
    Rectangle {
      id: overviewBackground

      property real padding: Math.max(0, root.workspaceSpacing)

      anchors.fill: parent
      anchors.margins: 10
      implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
      implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
      // Keep outer container shape aligned with workspace/indicator corners.
      radius: root.workspaceCellRadius
      antialiasing: radius > 0
      color: Qt.alpha(Color.mSurface, (pluginMain && pluginMain.enableGlassMode ? 0.65 : (Commons.Settings.data.ui.panelBackgroundOpacity || 0.8)))
      border.width: root.containerBorderWidth
      border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, root.applyGlassBorderOpacity(0.52))
      layer.enabled: Commons.Settings.data.general.enableShadows && !PowerProfileService.noctaliaPerformanceMode

      // === WORKSPACE GRID ===
      ColumnLayout {
        id: workspaceColumnLayout

        z: root.workspaceZ
        anchors.centerIn: parent
        spacing: workspaceSpacing

        Repeater {
          model: pluginMain.gridRows

          delegate: RowLayout {
            id: row

            property int rowIndex: index
            property bool rowVisible: !pluginMain || !pluginMain.hideEmptyRows || (root.rowsWithContent && root.rowsWithContent.has(rowIndex))

            spacing: workspaceSpacing
            visible: rowVisible

            Repeater {
              model: pluginMain.gridColumns

              delegate: Rectangle {
                id: workspace

                property int colIndex: index
                property int workspaceValue: root.workspaceGroup * root.workspacesShown + rowIndex * pluginMain.gridColumns + colIndex + 1
                property bool isSpecialSlot: root.reservedSpecialSlots > 0 && workspaceValue > root.lastNumericWorkspaceId
                property int specialIndex: isSpecialSlot ? (workspaceValue - (root.lastNumericWorkspaceId + 1)) : -1
                property var specialWorkspace: (isSpecialSlot && specialIndex >= 0 && specialIndex < root.visibleSpecialWorkspaces.length) ? root.visibleSpecialWorkspaces[specialIndex] : null
                property string displayLabel: root.getWorkspaceDisplayLabel(workspaceValue, isSpecialSlot, specialWorkspace)
                property string watermarkLabel: isSpecialSlot && specialWorkspace ? root.getSpecialWorkspaceLabel(specialWorkspace) : ("" + workspaceValue)
                property bool isActiveCell: root.getActiveWorkspaceValueForGrid() === workspaceValue
                property real inactiveDimAmount: root.clamp(pluginMain.dimInactiveWorkspaces || 0.35, 0, 0.8)
                property real baseOpacity: hoveredWhileDragging ? 1 : (isActiveCell ? 1 : (1 - inactiveDimAmount))
                property bool hoveredWhileDragging: false

                implicitWidth: root.workspaceImplicitWidth
                implicitHeight: root.workspaceImplicitHeight
                color: root.applyGlassEffect(hoveredWhileDragging ? Qt.lighter(Color.mSurfaceVariant, 1.05) : Color.mSurfaceVariant, hoveredWhileDragging)
                opacity: baseOpacity
                // Use scaled screen radius for the workspace preview
                radius: root.workspaceCellRadius
                antialiasing: radius > 0
                border.width: hoveredWhileDragging ? Math.max(1, Style.borderS) : (isActiveCell ? 0 : Math.max(1, Style.borderS))
                border.color: hoveredWhileDragging ? Qt.lighter(root.accentColor, 1.1) : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, root.applyGlassBorderOpacity(0.15))

                // Wallpaper image (only shown when enabled and no windows)
                Image {
                  id: workspaceWallpaper

                  property string wallpaperSource: root.getWallpaperSource(workspace.workspaceValue)

                  visible: pluginMain.showEmptyWorkspaceWallpaper && !root.workspaceHasWindows(workspace.workspaceValue) && wallpaperSource !== ""
                  anchors.fill: parent
                  source: wallpaperSource
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                  smooth: true
                  mipmap: true

                  // Overlay to tint the wallpaper
                  Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(workspace.color, pluginMain.emptyWorkspaceWallpaperOpacity)
                    radius: parent.radius
                  }
                }

                Rectangle {
                  visible: pluginMain.showRowColumnGuides
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.verticalCenter
                  width: 1
                  height: parent.height * 0.78
                  color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14)
                }

                Rectangle {
                  visible: pluginMain.showRowColumnGuides
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width * 0.78
                  height: 1
                  color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14)
                }

                // Watermark number/letter - Disabled per user feedback
                Text {
                  visible: false
                  anchors.centerIn: parent
                  text: workspace.watermarkLabel
                  font.family: Settings.data.ui.fontDefault
                  font.pixelSize: 250 * root.cellScale * ((monitor && monitor.scale) || 1)
                  font.weight: Font.Black
                  color: workspace.isSpecialSlot ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15) : Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, workspace.isActiveCell ? 0.15 : 0.08)
                  style: Text.Outline
                  styleColor: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.6)
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                  id: workspaceLabelChip

                  visible: pluginMain.showWorkspaceLabels
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.leftMargin: Math.max(8, parent.width * 0.04)
                  anchors.topMargin: Math.max(8, parent.height * 0.04)
                  radius: pluginMain.specialWorkspaceStyle === "pill" ? height / 2 : (pluginMain.specialWorkspaceStyle === "chip" ? Style.radiusS : 0)
                  color: {
                    if (pluginMain.specialWorkspaceStyle === "plain")
                      return "transparent";

                    if (workspace.isSpecialSlot)
                      return root.applyGlassEffect(Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, workspace.isActiveCell ? 0.3 : 0.2), false);

                    return root.applyGlassEffect(Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, workspace.isActiveCell ? 0.85 : 0.5), false);
                  }
                  border.width: pluginMain.specialWorkspaceStyle === "plain" ? 0 : 1
                  border.color: workspace.isSpecialSlot ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, workspace.isActiveCell ? 0.8 : 0.4) : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, root.applyGlassBorderOpacity(workspace.isActiveCell ? 0.6 : 0.2))
                  width: Math.min(parent.width * 0.86, labelText.implicitWidth + 16)
                  height: Math.max(20, Math.min(30, parent.height * 0.2))

                  Text {
                    id: labelText

                    anchors.centerIn: parent
                    width: parent.width - 10
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: workspace.displayLabel
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Math.max(10, Math.min(13, parent.height * 0.52))
                    font.weight: workspace.isActiveCell ? Style.fontWeightSemiBold : Style.fontWeightMedium
                    color: workspace.isSpecialSlot ? root.accentColor : Color.mOnSurface
                  }
                }

                LayoutSwitcher {
                  id: layoutBadge

                  property string wsLayout: workspace.isSpecialSlot ? "dwindle" : root.getWorkspaceLayout(workspace.workspaceValue)

                  anchors.fill: parent
                  pluginMain: root.pluginMain
                  workspaceId: workspace.workspaceValue
                  currentLayout: wsLayout
                  showBadge: (pluginMain && pluginMain.showLayoutBadge) || false
                  isSpecialSlot: workspace.isSpecialSlot
                  isActiveCell: workspace.isActiveCell
                  accentColor: root.accentColor
                  z: 10

                  onBadgeClicked: (wsId, layout, gx, gy, bw, bh) => {
                                    if (layoutSwitcherPopup.visible && layoutSwitcherPopup.targetWorkspaceId === wsId) {
                                      layoutSwitcherPopup.visible = false;
                                    } else {
                                      var pos = layoutBadge.mapToItem(overviewBackground, gx, gy);
                                      var px = Math.min(pos.x + bw - layoutSwitcherPopup.width, overviewBackground.width - layoutSwitcherPopup.width - 4);
                                      var py = Math.min(pos.y, overviewBackground.height - layoutSwitcherPopup.height - 4);
                                      layoutSwitcherPopup.x = Math.max(4, px);
                                      layoutSwitcherPopup.y = Math.max(4, py);
                                      layoutSwitcherPopup.targetWorkspaceId = wsId;
                                      layoutSwitcherPopup.currentLayout = layout;
                                      layoutSwitcherPopup.targetSwitcher = layoutBadge;
                                      layoutSwitcherPopup.visible = true;
                                    }
                                  }
                }

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton
                  onClicked: {
                    if (root.draggingTargetWorkspace !== -1 || root.draggingTargetSpecial)
                      return;

                    if (layoutSwitcherPopup.visible) {
                      layoutSwitcherPopup.visible = false;
                      return;
                    }

                    pluginMain.close();
                    if (workspace.isSpecialSlot && workspace.specialWorkspace)
                      Hyprland.dispatch("togglespecialworkspace " + workspace.specialWorkspace.name);
                    else
                      Hyprland.dispatch("workspace " + workspace.workspaceValue);
                  }
                }

                // Drop target for drag-and-drop
                DropArea {
                  anchors.fill: parent
                  onEntered: {
                    if (workspace.isSpecialSlot) {
                      root.draggingTargetWorkspace = -1;
                      root.draggingTargetSpecial = workspace.specialWorkspace;
                      if (!root.draggingTargetSpecial)
                        return;
                    } else {
                      root.draggingTargetWorkspace = workspace.workspaceValue;
                      root.draggingTargetSpecial = null;
                      // Check if dragging within same workspace
                      if (root.draggingFromWorkspace == root.draggingTargetWorkspace)
                        root.draggingIntraWorkspace = root.draggingFromWorkspace;
                    }
                    workspace.hoveredWhileDragging = true;
                  }
                  onExited: {
                    workspace.hoveredWhileDragging = false;
                    if (workspace.isSpecialSlot) {
                      if (root.draggingTargetSpecial === workspace.specialWorkspace)
                        root.draggingTargetSpecial = null;
                    } else {
                      if (root.draggingTargetWorkspace == workspace.workspaceValue)
                        root.draggingTargetWorkspace = -1;
                    }
                    root.draggingIntraWorkspace = -1;
                    root.resetRetileState();
                  }
                  onPositionChanged: drag => {
                                       if (workspace.isSpecialSlot || root.draggingFromWorkspace != workspace.workspaceValue)
                                       return;

                                       if ((pluginMain.dragPreviewMode || "smart") === "off") {
                                         root.resetRetileState();
                                         return;
                                       }
                                       var draggedWin = root.windowByAddress[root.draggingTargetAddress];
                                       if (draggedWin && draggedWin.floating) {
                                         root.resetRetileState();
                                         return;
                                       }
                                       // Only show retile preview for layouts that support it (dwindle)
                                       var wsLayout = root.getWorkspaceLayout(workspace.workspaceValue);
                                       var strategy = LayoutStrategy.get(wsLayout);
                                       if (!strategy.supportsRetilePreview) {
                                         root.resetRetileState();
                                         return;
                                       }
                                       var dragSource = drag.source;
                                       if (dragSource) {
                                         var candidate = root.calculateRetileTarget(workspace.workspaceValue, dragSource.x, dragSource.y, dragSource.width, dragSource.height);
                                         root.updateRetileCandidate(candidate);
                                       }
                                     }
                }
              }
            }
          }
        }
      }

      // === WINDOWS AND ACTIVE WORKSPACE INDICATOR ===
      Item {
        id: windowSpace

        anchors.centerIn: parent
        implicitWidth: workspaceColumnLayout.implicitWidth
        implicitHeight: workspaceColumnLayout.implicitHeight
        width: implicitWidth
        height: implicitHeight
        // Keep indicator stroke geometry identical to workspace cells (no edge clipping).
        // Window previews remain clipped per-item in WindowPreview.qml.
        clip: false

        // Window repeater
        Repeater {

          model: ScriptModel {
            values: {
              return ToplevelManager.toplevels.values.filter(function (toplevel) {
                var address = "0x" + toplevel.HyprlandToplevel.address;
                var win = root.windowByAddress[address];
                if (!win)
                  return false;

                var effectiveValue = root.getEffectiveWorkspaceValueForWindow(win);
                if (effectiveValue === null)
                  return false;

                return effectiveValue >= root.groupFirstWorkspaceId && effectiveValue <= root.groupLastWorkspaceId;
              }).sort(function (a, b) {
                var addrA = "0x" + a.HyprlandToplevel.address;
                var addrB = "0x" + b.HyprlandToplevel.address;
                var winA = root.windowByAddress[addrA];
                var winB = root.windowByAddress[addrB];
                // Pinned windows always on top
                if ((winA && winA.pinned) !== (winB && winB.pinned))
                  return (winA && winA.pinned) ? 1 : -1;

                // Floating windows above tiled
                if ((winA && winA.floating) !== (winB && winB.floating))
                  return (winA && winA.floating) ? 1 : -1;

                // Sort by focus history (lower = more recent = higher)
                return ((winB && winB.focusHistoryID) || 0) - ((winA && winA.focusHistoryID) || 0);
              });
            }
          }

          delegate: WindowPreview {
            id: windowDelegate

            required property var modelData
            required property int index
            // rawWindowData: the true Hyprland window data, used for monitor/workspace detection.
            // windowData (WindowPreview property) is bound to effectiveWindowData which may be synthetic.
            property var rawWindowData: root.windowByAddress["0x" + modelData.HyprlandToplevel.address]
            property int monitorId: ((rawWindowData && rawWindowData.monitor) || -1)
            property var windowMonitor: pluginMain.monitors.find(function (m) {
              return m.id === monitorId;
            })
            property var address: "0x" + modelData.HyprlandToplevel.address
            // Monitor dimensions (physical resolution / scale)
            property real rawMonitorWidth: ((windowMonitor && windowMonitor.width) || 1920) / ((windowMonitor && windowMonitor.scale) || 1)
            property real rawMonitorHeight: ((windowMonitor && windowMonitor.height) || 1080) / ((windowMonitor && windowMonitor.scale) || 1)
            // For transformed monitors, swap dimensions
            property real sourceMonitorWidth: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorHeight : rawMonitorWidth
            property real sourceMonitorHeight: (windowMonitor && windowMonitor.transform % 2 === 1) ? rawMonitorWidth : rawMonitorHeight
            // Available area (minus reserved/bars) - for positioning windows correctly
            property real availableMonitorWidth: sourceMonitorWidth - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[0]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[2]) || 0)
            property real availableMonitorHeight: sourceMonitorHeight - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[1]) || 0) - ((windowMonitor && windowMonitor.reserved && windowMonitor.reserved[3]) || 0)
            property bool atInitPosition: (initX == x && initY == y)
            property int rawWorkspaceId: (rawWindowData && rawWindowData.workspace && rawWindowData.workspace.id) || 1
            property int effectiveWorkspaceValue: root.getEffectiveWorkspaceValueForWindow(rawWindowData) || root.groupFirstWorkspaceId
            property int workspaceInGroup: effectiveWorkspaceValue - (root.workspaceGroup * root.workspacesShown)
            // Position calculation
            property int workspaceColIndex: Math.max(0, (workspaceInGroup - 1) % pluginMain.gridColumns)
            property int workspaceRowIndex: Math.max(0, Math.floor((workspaceInGroup - 1) / pluginMain.gridColumns))
            // === LAYOUT-SPECIFIC RENDERING (0.54+) ===
            // Layout of the workspace this window belongs to
            property string wsLayout: root.getWorkspaceLayout(rawWorkspaceId)
            // Scroll layout: sorted position info (index in tape, total windows, direction)
            property var scrollInfo: (wsLayout === "scroll" && rawWindowData && !rawWindowData.floating) ? root.scrollWindowOrder[rawWindowData.address] : null
            // Monocle layout: deck position (0=active/top, 1+=behind)
            property var monocleInfo: (wsLayout === "monocle" && rawWindowData && !rawWindowData.floating) ? root.monocleWindowOrder[rawWindowData.address] : null
            // Monitor origin in global space (used for synthetic scroll coordinates)
            property real monX: (windowMonitor && windowMonitor.x) || 0
            property real monY: (windowMonitor && windowMonitor.y) || 0
            // Layout-aware effective window data (strategy pattern).
            // Scroll layout synthesizes tape-strip coordinates; others pass through.
            property var effectiveWindowData: {
              if (!rawWindowData)
                return rawWindowData;

              var strategy = LayoutStrategy.get(wsLayout);
              var transformed = strategy.transformWindowData(rawWindowData, {
                                                               scrollInfo: scrollInfo,
                                                               sourceMonitorWidth: sourceMonitorWidth,
                                                               sourceMonitorHeight: sourceMonitorHeight,
                                                               monX: monX,
                                                               monY: monY
                                                             });
              return transformed || rawWindowData;
            }

            pluginMain: root.pluginMain
            // Bind WindowPreview's windowData to effective data (synthetic for scroll layout)
            windowData: effectiveWindowData
            toplevel: modelData
            monitorData: windowMonitor
            windowScale: Math.min(root.workspaceImplicitWidth / sourceMonitorWidth, root.workspaceImplicitHeight / sourceMonitorHeight)
            positionScaleX: root.workspaceImplicitWidth / sourceMonitorWidth
            positionScaleY: root.workspaceImplicitHeight / sourceMonitorHeight
            availableWorkspaceWidth: root.workspaceImplicitWidth
            availableWorkspaceHeight: root.workspaceImplicitHeight
            workspaceExclusiveGap: root.workspaceExclusiveGap
            centeringX: root.centeringXOffset
            centeringY: root.centeringYOffset
            widgetMonitorId: root.monitor ? root.monitor.id : 0
            overviewOpen: root.pluginMain.overviewOpen
            useSimplifiedPreview: root.useSimplifiedPreview
            visualMode: root.visualMode
            shaderPreset: root.shaderPreset
            shaderPresetStrength: root.shaderPresetStrength
            simplifiedPixelDensity: root.simplifiedPixelDensity
            simplifiedColorDepth: root.simplifiedColorDepth
            simplifiedSaturation: root.simplifiedSaturation
            simplifiedContrast: root.simplifiedContrast
            hyprGapsIn: (hyprConfig && hyprConfig.gapsIn) || 0
            hyprBorderSize: (hyprConfig && hyprConfig.borderSize) || 2
            windowBorderSize: (hyprConfig && hyprConfig.borderSize) || 2
            activeBorderColor: (hyprConfig && hyprConfig.activeBorderColor) || Color.mPrimary
            inactiveBorderColor: (hyprConfig && hyprConfig.inactiveBorderColor) || Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 1)
            isActiveWorkspaceWindow: root.isWindowInActiveWorkspace(rawWindowData)
            isFocusedWindow: root.isWindowFocused(address, rawWindowData)
            showWindowIcons: root.pluginMain.showWindowIcons
            colorizeWindowIcons: root.pluginMain.colorizeWindowIcons
            windowIconPlacement: root.pluginMain.windowIconPlacement
            showFocusedGlow: root.pluginMain.showFocusedWindowGlow
            showUrgencyBadge: root.pluginMain.showUrgencyBadge
            showFloatingBadge: root.pluginMain.showFloatingBadge
            showFullscreenBadge: root.pluginMain.showFullscreenBadge
            showMonitorBadge: root.pluginMain.showMonitorBadge
            inactiveWorkspaceDimAmount: root.pluginMain.dimInactiveWorkspaces
            inactiveWorkspaceSaturation: root.pluginMain.inactiveWorkspaceSaturation
            hoverLiftAmount: root.pluginMain.hoverLiftAmount
            previewCornerMode: root.pluginMain.previewCornerMode
            previewFixedCornerRadius: root.pluginMain.previewFixedCornerRadius
            useBorderGradient: root.pluginMain.useBorderGradient
            showTitleStrip: root.pluginMain.showWindowTitleStrip
            titleStripPosition: root.pluginMain.titleStripPosition
            titleStripHeight: root.pluginMain.titleStripHeight
            titleStripMode: root.pluginMain.titleStripMode
            titleStripMeta: root.pluginMain.titleStripMeta
            animationProfile: root.pluginMain.animationProfile
            animationDurationMs: root.pluginMain.animationDurationMs
            // Position within the grid slot.
            // Monocle: non-active cards are shifted slightly (deck effect behind the active card).
            xOffset: (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColIndex + (monocleInfo ? monocleInfo.deckPos * -2 : 0)
            yOffset: root.getVisualYOffset(workspaceRowIndex) + (monocleInfo ? monocleInfo.deckPos * 3 : 0)
            // Monocle: only show top 4 cards (deckPos 0–3); hide deeper cards to keep it clean
            visible: !monocleInfo || monocleInfo.deckPos <= 3
            z: windowDelegate.isDragging ? root.windowDraggingZ : (windowDelegate.hovered ? (root.windowDraggingZ - 1) : (atInitPosition ? (root.windowZ + index) : (root.windowDraggingZ - 2)))
            windowRounding: (hyprConfig && hyprConfig.rounding) || 0
            Drag.hotSpot.x: targetWindowWidth / 2
            Drag.hotSpot.y: targetWindowHeight / 2
            // Retiling state for iOS-style shift animation
            ownAddress: address
            retilingTarget: root.retilingTarget
            isRetileTarget: root.retilingTarget && root.retilingTarget.targetAddress === address
            retilingDirection: root.retilingDirection

            Timer {
              id: updateWindowPosition

              interval: 16
              repeat: false
              running: false
              onTriggered: {
                windowDelegate.suppressPositionAnimation = true;
                // Keep post-dispatch reconciliation aligned with WindowPreview's
                // decoration-aware frame math (title strip/border/inset/fullscreen gap).
                windowDelegate.x = Math.round(windowDelegate.initX);
                windowDelegate.y = Math.round(windowDelegate.initY);
                releasePositionAnimation.restart();
              }
            }

            Timer {
              id: releasePositionAnimation

              interval: 0
              repeat: false
              running: false
              onTriggered: {
                windowDelegate.suppressPositionAnimation = false;
              }
            }

            Timer {
              id: floatingReconcileRefresh

              interval: 120
              repeat: false
              running: false
              onTriggered: {
                if (pluginMain && pluginMain.refreshWindows)
                  pluginMain.refreshWindows();
              }
            }

            MouseArea {
              // Skip no-op previews/commits to avoid misleading split hints.

              id: dragArea

              // Track drag velocity for tilt effect
              property real previousX: 0
              property real lastUpdateTime: 0

              anchors.fill: parent
              hoverEnabled: true
              onEntered: windowDelegate.hovered = true
              onExited: windowDelegate.hovered = false
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton
              drag.target: parent
              drag.threshold: 0
              drag.smoothed: false
              onPressed: mouse => {
                           root.draggingFromWorkspace = ((windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1);
                           root.draggingTargetAddress = (windowDelegate.windowData && windowDelegate.windowData.address) || "";
                           root.dragInteractionState = "targeting";
                           root.resetRetileState();
                           windowDelegate.pressed = true;
                           windowDelegate.isDragging = true;
                           windowDelegate.Drag.active = true;
                           windowDelegate.Drag.source = windowDelegate;
                           windowDelegate.Drag.hotSpot.x = mouse.x;
                           windowDelegate.Drag.hotSpot.y = mouse.y;
                           previousX = parent.x;
                           lastUpdateTime = Date.now();
                         }
              onPositionChanged: {
                if (!windowDelegate.isDragging)
                  return;

                var currentTime = Date.now();
                var deltaTime = Math.max(1, currentTime - lastUpdateTime);
                var deltaX = parent.x - previousX;
                var velocity = deltaX / (deltaTime / 16);
                windowDelegate.dragVelocity = velocity;
                windowDelegate.dragTilt = Math.min(Math.max(velocity * 1.5, -3), 3);
                previousX = parent.x;
                lastUpdateTime = currentTime;
              }
              onReleased: {
                var targetWorkspace = root.draggingTargetWorkspace;
                var targetSpecial = root.draggingTargetSpecial;
                var retilingInfo = root.retilingTarget;
                windowDelegate.pressed = false;
                windowDelegate.isDragging = false;
                windowDelegate.dragTilt = 0;
                windowDelegate.Drag.active = false;
                var currentWsId = (windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1;
                var currentWsName = (windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.name) || "";
                var currentSpecialName = root.normalizeSpecialName(currentWsName);
                var windowAddress = (windowDelegate.windowData && windowDelegate.windowData.address) || "";
                var isFloating = (windowDelegate.windowData && windowDelegate.windowData.floating) || false;
                root.draggingFromWorkspace = -1;
                root.draggingTargetWorkspace = -1;
                root.draggingTargetSpecial = null;
                root.draggingIntraWorkspace = -1;
                root.draggingTargetAddress = "";
                root.resetRetileState();
                if (targetSpecial) {
                  if (currentWsId >= 0 || currentSpecialName !== targetSpecial.name) {
                    Hyprland.dispatch("movetoworkspacesilent special:" + targetSpecial.name + ", address:" + windowAddress);
                    updateWindowPosition.restart();
                  } else {
                    windowDelegate.x = windowDelegate.initX;
                    windowDelegate.y = windowDelegate.initY;
                  }
                } else if (targetWorkspace !== -1 && targetWorkspace !== currentWsId) {
                  Hyprland.dispatch("movetoworkspacesilent " + targetWorkspace + ", address:" + windowAddress);
                  updateWindowPosition.restart();
                } else if (targetWorkspace !== -1 && targetWorkspace === currentWsId && !isFloating && (pluginMain.dragPreviewMode || "smart") !== "off") {
                  // Layout-aware intra-workspace drag via strategy pattern
                  var wsLayout = root.getWorkspaceLayout(currentWsId);
                  var strategy = LayoutStrategy.get(wsLayout);

                  if (strategy.supportsRetilePreview && retilingInfo && retilingInfo.targetAddress) {
                    // Dwindle: directional split / swap (uses retile preview data)
                    if (retilingInfo.isNoop) {
                      // no-op
                    } else if (retilingInfo.direction === "swap") {
                      if (root.isValidSwapTarget(retilingInfo, windowAddress, currentWsId))
                        root.runHyprBatch(strategy.getDropAction({
                                                                   sourceAddress: windowAddress,
                                                                   retilingInfo: {
                                                                     targetAddress: retilingInfo.targetAddress,
                                                                     direction: "swap",
                                                                     isNoop: false
                                                                   },
                                                                   wsId: currentWsId
                                                                 }).commands);
                    } else if (root.isValidSplitTarget(retilingInfo, currentWsId)) {
                      root.runHyprBatch(strategy.getDropAction({
                                                                 sourceAddress: windowAddress,
                                                                 retilingInfo: retilingInfo,
                                                                 wsId: currentWsId
                                                               }).commands);
                    }
                  } else if (!strategy.supportsRetilePreview) {
                    // Non-dwindle layouts: use strategy drop action based on drag delta
                    var action = strategy.getDropAction({
                                                          sourceAddress: windowAddress,
                                                          retilingInfo: retilingInfo,
                                                          wsId: currentWsId,
                                                          dragDeltaX: windowDelegate.x - windowDelegate.initX,
                                                          dragDeltaY: windowDelegate.y - windowDelegate.initY,
                                                          scrollDirection: (pluginMain && pluginMain.workspaceScrollDirections && pluginMain.workspaceScrollDirections[currentWsId]) || "right"
                                                        });
                    if (action.type !== "noop" && action.commands.length > 0)
                      root.runHyprBatch(action.commands);
                  }

                  windowDelegate.x = windowDelegate.initX;
                  windowDelegate.y = windowDelegate.initY;
                  updateWindowPosition.restart();
                  if (pluginMain && pluginMain.refreshWindows)
                    pluginMain.refreshWindows();
                } else if (isFloating) {
                  var dropPos = root.resolveFloatingDropPosition(windowDelegate);
                  if (dropPos && windowAddress !== "") {
                    if (pluginMain && pluginMain.applyOptimisticWindowMove)
                      pluginMain.applyOptimisticWindowMove(windowAddress, dropPos.x, dropPos.y, currentWsId);

                    root.runHyprBatch(["movewindowpixel exact " + dropPos.x + " " + dropPos.y + ",address:" + windowAddress]);
                    updateWindowPosition.restart();
                    if (pluginMain && pluginMain.refreshWindows) {
                      pluginMain.refreshWindows();
                      floatingReconcileRefresh.restart();
                    }
                  } else {
                    windowDelegate.x = windowDelegate.initX;
                    windowDelegate.y = windowDelegate.initY;
                  }
                } else {
                  windowDelegate.x = windowDelegate.initX;
                  windowDelegate.y = windowDelegate.initY;
                }
              }
              onCanceled: {
                windowDelegate.pressed = false;
                windowDelegate.isDragging = false;
                windowDelegate.dragTilt = 0;
                windowDelegate.Drag.active = false;
                root.draggingFromWorkspace = -1;
                root.draggingTargetWorkspace = -1;
                root.draggingTargetSpecial = null;
                root.draggingIntraWorkspace = -1;
                root.draggingTargetAddress = "";
                root.resetRetileState();
                windowDelegate.x = windowDelegate.initX;
                windowDelegate.y = windowDelegate.initY;
              }
              onClicked: event => {
                           if (!windowDelegate.windowData)
                           return;

                           if (event.button === Qt.LeftButton) {
                             var address = windowDelegate.windowData.address;
                             var wsId = (windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1;
                             var wsName = (windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.name) || "";
                             Logger.i("WorkspaceOverview", "Clicked window " + address + ", dispatching close then focus.");
                             if (pluginMain)
                             pluginMain.close();

                             if (wsName.startsWith("special:"))
                             Hyprland.dispatch("togglespecialworkspace " + wsName.substring(8));
                             else if (wsId >= 0)
                             Hyprland.dispatch("workspace " + wsId);
                             Hyprland.dispatch("focuswindow address:" + address);
                             event.accepted = true;
                           } else if (event.button === Qt.MiddleButton) {
                             Hyprland.dispatch("closewindow address:" + windowDelegate.windowData.address);
                             event.accepted = true;
                           }
                         }
            }
          }
        }

        // === RETILE PREVIEW ===
        RetilePreview {
          id: retilingPreview

          showPreview: root.retilingTarget !== null
          activeDirection: root.retilingDirection
          directionConfidence: root.retilingConfidence
          directionLocked: root.dragInteractionState === "lockedDirection"
          pendingDirection: root.pendingRetileDirection
          previewOpacityScale: root.clamp(pluginMain.retilePreviewOpacity || 0.55, 0.2, 0.9)
          // Zone visualization (target window bounds)
          targetX: root.retilingTarget ? root.retilingTarget.targetX : 0
          targetY: root.retilingTarget ? root.retilingTarget.targetY : 0
          targetW: root.retilingTarget ? root.retilingTarget.targetW : 0
          targetH: root.retilingTarget ? root.retilingTarget.targetH : 0
          // Result preview (where dragged window lands)
          previewX: root.retilingTarget ? root.retilingTarget.previewX : 0
          previewY: root.retilingTarget ? root.retilingTarget.previewY : 0
          previewWidth: root.retilingTarget ? root.retilingTarget.previewW : 0
          previewHeight: root.retilingTarget ? root.retilingTarget.previewH : 0
          // Target shrink preview (where target window shrinks to)
          targetNewX: root.retilingTarget ? root.retilingTarget.targetNewX : 0
          targetNewY: root.retilingTarget ? root.retilingTarget.targetNewY : 0
          targetNewW: root.retilingTarget ? root.retilingTarget.targetNewW : 0
          targetNewH: root.retilingTarget ? root.retilingTarget.targetNewH : 0
        }

        // === ACTIVE WORKSPACE INDICATOR ===
        Rectangle {
          id: focusedWorkspaceIndicator

          property var activeWorkspaceValue: root.getActiveWorkspaceValueForGrid()
          property bool indicatorVisible: activeWorkspaceValue !== null
          property int activeWorkspaceInGroup: indicatorVisible ? (activeWorkspaceValue - (root.workspaceGroup * root.workspacesShown)) : 1
          property int activeWorkspaceRowIndex: Math.floor((activeWorkspaceInGroup - 1) / pluginMain.gridColumns)
          property int activeWorkspaceColIndex: (activeWorkspaceInGroup - 1) % pluginMain.gridColumns
          readonly property real indicatorStroke: Math.max(2, Math.round(root.selectionBorderWidth))

          visible: indicatorVisible
          x: (root.workspaceImplicitWidth + root.workspaceSpacing) * activeWorkspaceColIndex
          y: root.getVisualYOffset(activeWorkspaceRowIndex)
          z: root.windowZ
          width: root.workspaceImplicitWidth
          height: root.workspaceImplicitHeight
          color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.025)
          radius: root.workspaceCellRadius
          antialiasing: radius > 0
          border.width: indicatorStroke
          border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.95)

          Behavior on x {
            enabled: !pluginMain.getAnimationDuration || pluginMain.getAnimationDuration("normal") > 0

            NumberAnimation {
              duration: pluginMain.getAnimationDuration ? pluginMain.getAnimationDuration("normal") : 200
              easing.type: Easing.OutCubic
            }
          }

          Behavior on y {
            enabled: !pluginMain.getAnimationDuration || pluginMain.getAnimationDuration("normal") > 0

            NumberAnimation {
              duration: pluginMain.getAnimationDuration ? pluginMain.getAnimationDuration("normal") : 200
              easing.type: Easing.OutCubic
            }
          }
        }
      }

      // === LAYOUT SWITCHER POPUP (shared, floats above all window previews and workspace cells) ===
      MouseArea {
        id: layoutPopupDismiss

        anchors.fill: parent
        visible: layoutSwitcherPopup.visible
        z: layoutSwitcherPopup.z - 1
        onClicked: layoutSwitcherPopup.visible = false
      }

      Rectangle {
        id: layoutSwitcherPopup

        property int targetWorkspaceId: -1
        property string currentLayout: "dwindle"
        // Reference to the LayoutSwitcher component for the target workspace.
        // Set by the badge click handler so the popup can delegate switching.
        property var targetSwitcher: null

        visible: false
        z: root.windowDraggingZ + 10
        width: 110
        height: optionColumn.implicitHeight + 12
        radius: Style.radiusM
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.35)

        // Consume background clicks — prevents dismiss backdrop from firing on margin/border clicks
        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        Column {
          id: optionColumn

          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 6
          }
          spacing: 3

          Repeater {
            model: LayoutStrategy.allLayouts

            delegate: Rectangle {
              required property string modelData
              required property int index

              readonly property bool isCurrent: layoutSwitcherPopup.currentLayout === modelData

              width: parent.width
              height: 22
              radius: Style.radiusS
              color: isCurrent ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.0)

              Row {
                anchors {
                  left: parent.left
                  leftMargin: 6
                  verticalCenter: parent.verticalCenter
                }
                spacing: 5

                Rectangle {
                  width: 14
                  height: 14
                  radius: 3
                  color: isCurrent ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.08)

                  Text {
                    anchors.centerIn: parent
                    text: LayoutStrategy.allBadgeLabels[modelData] || "?"
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: 8
                    color: isCurrent ? root.accentColor : Color.mOnSurfaceVariant
                  }
                }

                Text {
                  text: LayoutStrategy.allDisplayNames[modelData] || modelData
                  font.family: Settings.data.ui.fontDefault
                  font.pixelSize: 10
                  font.weight: isCurrent ? Style.fontWeightSemiBold : Style.fontWeightRegular
                  color: isCurrent ? Color.mOnSurface : Color.mOnSurfaceVariant
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.color = Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.08)
                onExited: parent.color = isCurrent ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.0)
                onClicked: {
                  if (layoutSwitcherPopup.targetSwitcher)
                    layoutSwitcherPopup.targetSwitcher.switchLayout(layoutSwitcherPopup.targetWorkspaceId, modelData);
                  layoutSwitcherPopup.visible = false;
                }
              }
            }
          }
        }
      }

      layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: Style.shadowBlurMax
        shadowBlur: Style.shadowBlur * 1.5
        shadowOpacity: Style.shadowOpacity
        shadowColor: Color.mBackground
        shadowHorizontalOffset: Commons.Settings.data.general.shadowOffsetX || 0
        shadowVerticalOffset: Commons.Settings.data.general.shadowOffsetY || 4
      }
    }
  }
}
