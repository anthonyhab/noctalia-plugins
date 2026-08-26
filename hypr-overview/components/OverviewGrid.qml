import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../helpers/DragDecision.js" as DragDecision
import "../helpers/DropIntent.js" as DropIntent
import "../helpers/HyprlandState.js" as HyprlandState
import "../helpers/LayoutStrategy.js" as LayoutStrategy
import "../helpers/RetileBlueprint.js" as RetileBlueprint
import "../helpers/WorkspaceDragMapping.js" as WorkspaceDragMapping
import "../helpers/WorkspaceGeometry.js" as WorkspaceGeometry
import "."
import qs.Commons
import qs.Commons as Commons
import qs.Widgets

Item {
  id: root

  required property var pluginMain
  required property var panelWindow
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
  readonly property int overlayCaptureRevision: pluginMain ? pluginMain.overlayCaptureRevision : 0
  readonly property var overlayCaptureRevisionsByAddress: pluginMain ? pluginMain.overlayCaptureRevisionsByAddress : ({})
  readonly property int clientRefreshRevision: pluginMain ? pluginMain.clientRefreshRevision : 0
  property var monitorData: pluginMain.monitors.find(function (m) {
    return m.id === (root.monitor && root.monitor.id);
  })
  property real cellScale: pluginMain.gridScale
  implicitWidth: surfaceWidth
  implicitHeight: surfaceHeight
  // Cross-monitor drag state
  property bool draggingCrossMonitor: false
  property int draggingTargetMonitorId: -1
  property int draggingSourceMonitorId: -1
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
  readonly property real surfacePadding: Math.max(4, root.workspaceSpacing)
  // Grid's natural size (without fit scaling)
  readonly property real gridNaturalWidth: (pluginMain ? pluginMain.gridColumns : 5) * workspaceImplicitWidth + ((pluginMain ? pluginMain.gridColumns : 5) - 1) * workspaceSpacing + surfacePadding * 2
  readonly property real gridNaturalHeight: {
    var rows = pluginMain ? pluginMain.gridRows : 2;
    var hideRows = pluginMain ? pluginMain.hideEmptyRows : false;
    var visibleRows = hideRows && rowsWithContent ? rowsWithContent.size : rows;
    if (visibleRows === 0)
      visibleRows = 1;

    // At least one row
    return visibleRows * workspaceImplicitHeight + (visibleRows - 1) * workspaceSpacing + surfacePadding * 2;
  }
  // Fit scale to ensure grid stays on screen (never upscale, only downscale if needed)
  readonly property real fitScale: Math.min(1, Math.min(availableWidth / Math.max(1, gridNaturalWidth), availableHeight / Math.max(1, gridNaturalHeight)))
  readonly property var monitorWorkArea: WorkspaceGeometry.getMonitorWorkArea(monitorData || {
                                                                                "width": (monitor && monitor.width) || 1920,
                                                                                "height": (monitor && monitor.height) || 1080,
                                                                                "scale": (monitor && monitor.scale) || 1,
                                                                                "transform": (monitorData && monitorData.transform) || 0,
                                                                                "reserved": [0, 0, 0, 0]
                                                                              })
  property real workspaceImplicitWidth: monitorWorkArea.width * root.cellScale
  property real workspaceImplicitHeight: monitorWorkArea.height * root.cellScale
  property real centeringXOffset: 0
  property real centeringYOffset: 0
  readonly property real surfaceX: scaledContainer.x + scaledContainer.width * (1 - root.fitScale) / 2
  readonly property real surfaceY: scaledContainer.y + scaledContainer.height * (1 - root.fitScale) / 2
  readonly property real surfaceWidth: scaledContainer.width * root.fitScale
  readonly property real surfaceHeight: scaledContainer.height * root.fitScale
  readonly property real surfaceRadius: root.workspaceCellRadius * root.fitScale
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
  readonly property real minimumSplitZoneRatio: 0.42
  readonly property real noopGeometryEpsilonPx: 2
  property var retilingTarget: null
  // { targetAddress, targetX/Y/W/H, direction, previewModel }
  property var retileTransitionRecords: ({})
  readonly property bool retileTransitionActive: Object.keys(retileTransitionRecords || ({})).length > 0
  property var retilePendingFinalizedAddressMap: ({})
  property var retileSettledRecaptureAddresses: []
  property var retileFinalizedAddressMap: ({})
  property int retileFinalizedPositionRevision: 0
  property string retilingDirection: ""
  property string dragInteractionState: "idle"
  // "idle", "targeting", "lockedDirection"
  property var currentDropIntent: null
  property int debugReleaseCounter: 0
  // === LAYOUT DATA (0.54+) ===
  // Map of workspaceId → layout name ("dwindle", "master", "scroll", "monocle")
  readonly property var workspaceLayouts: (pluginMain && pluginMain.workspaceLayouts) || ({})

  function getWorkspaceLayout(wsId) {
    return root.workspaceLayouts[wsId] || "dwindle";
  }

  // Scroll layout: sorted window order per workspace (delegated to LayoutStrategy).
  readonly property var scrollWindowOrder: LayoutStrategy.get("scroll").computeWindowOrder(root.windowByAddress, root.workspaceLayouts, (pluginMain && pluginMain.workspaceScrollDirections) || ({}))

  // Monocle layout: deck position per window (delegated to LayoutStrategy).
  readonly property var monocleWindowOrder: LayoutStrategy.get("monocle").computeWindowOrder(root.windowByAddress, root.workspaceLayouts, null)

  function tr(key) {
    if (!pluginMain || !pluginMain.pluginApi || !pluginMain.pluginApi.tr)
      return key;

    return pluginMain.pluginApi.tr(key);
  }

  function retileLabels() {
    return {
      "l": root.tr("dropIntent.splitLeft"),
      "r": root.tr("dropIntent.splitRight"),
      "u": root.tr("dropIntent.splitTop"),
      "d": root.tr("dropIntent.splitBottom"),
      "swap": root.tr("dropIntent.tiledSwap"),
      "draggedSlot": root.tr("dropIntent.draggedSlot"),
      "targetSlot": root.tr("dropIntent.targetSlot")
    };
  }

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

  function debugLog(tag, message) {
    Logger.i("WorkspaceOverview", "[hypr-overview-debug:" + tag + "] " + message);
  }

  function debugStringify(value) {
    try {
      return JSON.stringify(value);
    } catch (e) {
      return "" + value;
    }
  }

  function debugWindowState(win) {
    if (!win)
      return null;

    return {
      "address": win.address || "",
      "workspace": win.workspace ? {
                                     "id": win.workspace.id,
                                     "name": win.workspace.name || ""
                                   } : null,
      "monitor": win.monitor,
      "layout": win.workspace ? root.getWorkspaceLayout(win.workspace.id) : "",
      "floating": !!win.floating,
      "fullscreen": !!win.fullscreen,
      "maximized": !!win.maximized
    };
  }

  function nextDebugReleaseId() {
    debugReleaseCounter += 1;
    return debugReleaseCounter;
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

    var workArea = WorkspaceGeometry.getMonitorWorkArea(winMonitor);
    return WorkspaceGeometry.mapWindowToPreviewFrame({
                                                       "windowData": win,
                                                       "monitorData": winMonitor,
                                                       "workspaceWidth": root.workspaceImplicitWidth,
                                                       "workspaceHeight": root.workspaceImplicitHeight,
                                                       "workAreaX": workArea.x,
                                                       "workAreaY": workArea.y,
                                                       "workAreaWidth": workArea.width,
                                                       "workAreaHeight": workArea.height,
                                                       "centeringX": root.centeringXOffset,
                                                       "centeringY": root.centeringYOffset,
                                                       "hyprGapsIn": (hyprConfig && hyprConfig.gapsIn) || 0,
                                                       "hyprBorderSize": (hyprConfig && hyprConfig.borderSize) || 0,
                                                       "fallbackInset": root.workspaceExclusiveGap,
                                                       "useSimplifiedPreview": pluginMain && pluginMain.useSimplifiedPreview
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

  function resolveFloatingDropPosition(delegateItem, targetWorkspaceId) {
    if (!delegateItem || !delegateItem.windowData || !delegateItem.windowData.workspace)
      return null;

    var resolvedWorkspaceId = targetWorkspaceId !== undefined && targetWorkspaceId !== -1 ? targetWorkspaceId : delegateItem.windowData.workspace.id;
    var targetMonitorId = root.getMonitorIdForWorkspace(resolvedWorkspaceId);
    if (targetMonitorId < 0)
      targetMonitorId = delegateItem.monitorId;
    var monitorObj = ((pluginMain && pluginMain.monitors) || []).find(function (m) {
      return m.id === targetMonitorId;
    }) || delegateItem.windowMonitor || null;
    var logicalSize = WorkspaceGeometry.getMonitorWorkArea(monitorObj);
    var displayWorkspaceValue = resolvedWorkspaceId < 0 ? root.getEffectiveWorkspaceValueForWindow(delegateItem.rawWindowData || delegateItem.windowData) : resolvedWorkspaceId;
    if (displayWorkspaceValue === null)
      displayWorkspaceValue = resolvedWorkspaceId;
    var workspaceOffsets = root.getWorkspaceOffsets(displayWorkspaceValue);
    var localX = delegateItem.x - workspaceOffsets.x;
    var localY = delegateItem.y - workspaceOffsets.y;
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
                                                              "workAreaX": logicalSize.x,
                                                              "workAreaY": logicalSize.y,
                                                              "workAreaWidth": logicalSize.width,
                                                              "workAreaHeight": logicalSize.height,
                                                              "windowWidthRaw": ((delegateItem.windowData.size && delegateItem.windowData.size[0]) || 1),
                                                              "windowHeightRaw": ((delegateItem.windowData.size && delegateItem.windowData.size[1]) || 1)
                                                            });
  }

  function getMonitorIdForWorkspace(workspaceId) {
    if (!pluginMain)
      return -1;
    return pluginMain.getMonitorIdForWorkspace(workspaceId);
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

  function runHyprBatch(commands, options) {
    if (!commands || commands.length === 0)
      return;

    var opts = options || {};
    if (!opts.reason)
      opts.reason = "overview-grid";
    root.debugLog("dispatch", "commands=" + root.debugStringify(commands) + " options=" + root.debugStringify(opts));
    if (pluginMain && pluginMain.runOverviewDispatch)
      pluginMain.runOverviewDispatch(commands, opts);
  }

  function dispatchWorkspace(target) {
    if (target !== undefined && target !== null)
      runHyprBatch(["workspace " + target]);
  }

  function toggleSpecialWorkspace(name) {
    if (name !== undefined && name !== null && name !== "")
      runHyprBatch(["togglespecialworkspace " + name]);
  }

  function focusWindowAddress(address) {
    if (address !== undefined && address !== null && address !== "")
      runHyprBatch(["focuswindow address:" + address]);
  }

  function closeWindowAddress(address) {
    if (address !== undefined && address !== null && address !== "")
      runHyprBatch(["closewindow address:" + address]);
  }

  function buildDropIntentForDelegate(delegateItem, retilingOverride) {
    if (!delegateItem || !delegateItem.windowData)
      return DropIntent.resolve({});

    var targetWorkspace = root.draggingTargetWorkspace;
    var currentWsId = (delegateItem.windowData && delegateItem.windowData.workspace && delegateItem.windowData.workspace.id) || -1;
    var currentWsName = (delegateItem.windowData && delegateItem.windowData.workspace && delegateItem.windowData.workspace.name) || "";
    var windowAddress = (delegateItem.windowData && delegateItem.windowData.address) || "";
    var isFloating = (delegateItem.windowData && delegateItem.windowData.floating) || false;
    var wsLayout = root.getWorkspaceLayout(currentWsId);
    var retilingForIntent = retilingOverride || null;
    if (retilingForIntent && retilingForIntent.direction === "swap" && !root.isValidSwapTarget(retilingForIntent, windowAddress, currentWsId))
      retilingForIntent = null;
    else if (retilingForIntent && retilingForIntent.direction !== "swap" && !root.isValidSplitTarget(retilingForIntent, currentWsId))
      retilingForIntent = null;

    var floatingDropPos = isFloating ? root.resolveFloatingDropPosition(delegateItem, targetWorkspace !== -1 ? targetWorkspace : currentWsId) : null;
    return DropIntent.resolve({
                                "windowAddress": windowAddress,
                                "currentWorkspaceId": currentWsId,
                                "currentSpecialName": root.normalizeSpecialName(currentWsName),
                                "targetWorkspace": targetWorkspace,
                                "targetSpecial": root.draggingTargetSpecial,
                                "isFloating": isFloating,
                                "isFullscreen": (delegateItem.windowData && delegateItem.windowData.fullscreen) || false,
                                "isMaximized": (delegateItem.windowData && delegateItem.windowData.maximized) || false,
                                "dragPreviewMode": pluginMain.dragPreviewMode || "smart",
                                "sourceMonitorId": root.draggingSourceMonitorId,
                                "targetMonitorId": root.draggingTargetMonitorId,
                                "enableCrossMonitorDrag": pluginMain.enableCrossMonitorDrag,
                                "crossMonitorDrag": root.draggingCrossMonitor,
                                "layoutName": wsLayout,
                                "scrollDirection": (pluginMain && pluginMain.workspaceScrollDirections && pluginMain.workspaceScrollDirections[currentWsId]) || "right",
                                "dragDeltaX": delegateItem.x - delegateItem.initX,
                                "dragDeltaY": delegateItem.y - delegateItem.initY,
                                "retilingInfo": retilingForIntent,
                                "floatingDropPosition": floatingDropPos
                              });
  }

  function resetRetileState() {
    root.retilingTarget = null;
    root.retilingDirection = "";
    if (root.draggingTargetAddress !== "")
      root.dragInteractionState = "targeting";
    else
      root.dragInteractionState = "idle";
  }

  function cloneFrameRect(rect) {
    if (!rect || !isFinite(Number(rect.x)) || !isFinite(Number(rect.y)) || !isFinite(Number(rect.w)) || !isFinite(Number(rect.h)) || Number(rect.w) <= 0 || Number(rect.h) <= 0)
      return null;

    return {
      "x": Number(rect.x),
      "y": Number(rect.y),
      "w": Number(rect.w),
      "h": Number(rect.h)
    };
  }

  function clearRetileTransitionRecords() {
    retileTransitionTimeout.stop();
    root.retileTransitionRecords = ({});
    root.retilePendingFinalizedAddressMap = ({});
    root.retileSettledRecaptureAddresses = [];
  }

  function overlayCaptureRevisionForAddress(address) {
    if (!address || !root.overlayCaptureRevisionsByAddress)
      return 0;

    return Number(root.overlayCaptureRevisionsByAddress[address]) || 0;
  }

  function workspaceWindowAddresses(workspaceId) {
    var addresses = [];
    var seen = {};
    for (var addr in root.windowByAddress) {
      var win = root.windowByAddress[addr];
      if (!win || !win.workspace || win.workspace.id !== workspaceId)
        continue;

      var address = win.address || addr;
      if (address && !seen[address]) {
        seen[address] = true;
        addresses.push(address);
      }
    }
    return addresses;
  }

  function rememberRetileFinalizedAddresses(addresses) {
    if (!addresses || addresses.length === 0)
      return;

    var next = {};
    var old = root.retilePendingFinalizedAddressMap || {};
    for (var key in old)
      next[key] = true;
    for (var i = 0; i < addresses.length; i++) {
      if (addresses[i])
        next[addresses[i]] = true;
    }
    root.retilePendingFinalizedAddressMap = next;
  }

  function allRetileFinalizedAddresses(addresses) {
    var map = {};
    var old = root.retilePendingFinalizedAddressMap || {};
    for (var key in old)
      map[key] = true;
    if (addresses) {
      for (var i = 0; i < addresses.length; i++) {
        if (addresses[i])
          map[addresses[i]] = true;
      }
    }
    return Object.keys(map);
  }

  function markRetileFinalizedAddresses(addresses, reason) {
    if (!addresses || addresses.length === 0)
      return;

    var next = {};
    for (var i = 0; i < addresses.length; i++) {
      if (addresses[i])
        next[addresses[i]] = true;
    }
    root.retileFinalizedAddressMap = next;
    root.retileFinalizedPositionRevision += 1;
    root.debugLog("retile", "finalize reason=" + (reason || "") + " addresses=" + root.debugStringify(addresses) + " revision=" + root.retileFinalizedPositionRevision);
    if (pluginMain && pluginMain.requestSettledRetileOverlayRecapture)
      pluginMain.requestSettledRetileOverlayRecapture(reason || "retile-settled", root.retileSettledRecaptureAddresses.length > 0 ? root.retileSettledRecaptureAddresses : addresses);
  }

  function finishRetileTransitionRecords(addresses, reason) {
    var recaptureAddresses = root.retileSettledRecaptureAddresses;
    root.clearRetileTransitionRecords();
    root.retileSettledRecaptureAddresses = recaptureAddresses;
    root.markRetileFinalizedAddresses(addresses, reason);
    root.retileSettledRecaptureAddresses = [];
  }

  function scheduleRetileTransitionReconcile(nextWakeAt) {
    var delay = Math.max(1, Math.round(Number(nextWakeAt || 0) - Date.now()));
    if (!isFinite(delay) || delay <= 0)
      delay = 16;
    retileTransitionTimeout.interval = Math.min(450, delay);
    retileTransitionTimeout.restart();
  }

  function setRetileTransitionRecords(records, recaptureAddresses) {
    if (!records || Object.keys(records).length === 0) {
      root.clearRetileTransitionRecords();
      return;
    }

    root.retileTransitionRecords = records;
    root.retilePendingFinalizedAddressMap = ({});
    root.retileSettledRecaptureAddresses = recaptureAddresses || [];
    root.debugLog("retile", "transition start addresses=" + root.debugStringify(Object.keys(records)) + " durationMs=140 settleCapMs=450");
    root.scheduleRetileTransitionReconcile(Date.now() + 140);
  }

  function buildRetileTransitionRecords(sourceAddress, retilingInfo, releaseType) {
    return RetileBlueprint.buildTransitionRecords({
                                                    "sourceAddress": sourceAddress,
                                                    "retilingInfo": retilingInfo,
                                                    "releaseType": releaseType,
                                                    durationMs: 140,
                                                    settleTimeoutMs: 450,
                                                    nowMs: Date.now()
                                                  });
  }

  function retileTransitionFrameForDelegate(address, workspaceValue) {
    var record = root.retileTransitionRecords && root.retileTransitionRecords[address];
    if (!record || !record.toFrame)
      return null;

    var offsets = root.getWorkspaceOffsets(workspaceValue);
    return {
      "x": record.toFrame.x - offsets.x,
      "y": record.toFrame.y - offsets.y,
      "w": record.toFrame.w,
      "h": record.toFrame.h
    };
  }

  function absolutePreviewFrameForWindow(win) {
    if (!win || !win.workspace)
      return null;

    var workspaceId = win.workspace.id;
    var localFrame = root.getScaledWindowRectForWorkspace(win, workspaceId);
    if (!localFrame)
      return null;

    var offsets = root.getWorkspaceOffsets(workspaceId);
    return {
      "x": localFrame.x + offsets.x,
      "y": localFrame.y + offsets.y,
      "w": localFrame.w,
      "h": localFrame.h
    };
  }

  function reconcileRetileTransitionRecords() {
    var records = root.retileTransitionRecords || {};
    var keys = Object.keys(records);
    if (keys.length === 0)
      return;

    var actualFrames = {};
    for (var i = 0; i < keys.length; i++) {
      var address = keys[i];
      var actual = root.absolutePreviewFrameForWindow(root.windowByAddress && root.windowByAddress[address]);
      if (actual)
        actualFrames[address] = actual;
    }

    var transitionResult = RetileBlueprint.reconcileTransitionRecords({
                                                                        "records": records,
                                                                        "actualFrames": actualFrames,
                                                                        "epsilonPx": root.noopGeometryEpsilonPx,
                                                                        "nowMs": Date.now()
                                                                      });
    root.debugLog("retile", "reconcile statuses=" + root.debugStringify(transitionResult.statuses || {}) + " retargeted=" + !!transitionResult.retargeted + " cleared=" + !!transitionResult.cleared);
    if (transitionResult.cleared) {
      root.finishRetileTransitionRecords(root.allRetileFinalizedAddresses(transitionResult.finalizedAddresses || keys), "settled");
    } else {
      root.rememberRetileFinalizedAddresses(transitionResult.finalizedAddresses || []);
      root.retileTransitionRecords = transitionResult.records;
      if (transitionResult.retargeted)
        root.debugLog("retile", "retarget actual geometry addresses=" + root.debugStringify(Object.keys(transitionResult.records || {})));
      root.scheduleRetileTransitionReconcile(transitionResult.nextWakeAt || (Date.now() + 16));
    }
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
      "confidence": targetInfo.confidence === undefined ? 1 : targetInfo.confidence,
      "operationType": direction === "swap" ? "swap" : "split",
      "isNoop": !!targetInfo.isNoop,
      "noopReason": targetInfo.noopReason || "",
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
      "predictedDraggedRect": predictedDraggedRect,
      "previewModel": RetileBlueprint.buildPreviewModel(targetInfo, direction, root.retileLabels())
    };
  }

  function commitRetileCandidate(candidate) {
    if (!candidate || candidate.direction === "" || candidate.isNoop) {
      resetRetileState();
      return;
    }
    root.retilingDirection = candidate.direction;
    root.retilingTarget = candidate;
    root.dragInteractionState = "lockedDirection";
  }

  function updateRetileCandidate(candidate) {
    var dragMode = pluginMain.dragPreviewMode || "smart";
    if (dragMode === "off") {
      resetRetileState();
      return;
    }
    if (!candidate || candidate.direction === "" || candidate.isNoop) {
      root.retilingDirection = "";
      root.retilingTarget = null;
      root.dragInteractionState = root.draggingTargetAddress !== "" ? "targeting" : "idle";
      return;
    }
    if (dragMode === "basic") {
      root.retilingDirection = candidate.direction;
      root.retilingTarget = candidate;
      root.dragInteractionState = "targeting";
      return;
    }
    commitRetileCandidate(candidate);
  }

  function dragHotspotInWindowSpace(workspaceItem, drag, dragSource) {
    if (workspaceItem && drag && isFinite(Number(drag.x)) && isFinite(Number(drag.y)))
      return workspaceItem.mapToItem(windowSpace, drag.x, drag.y);

    if (dragSource)
      return {
        "x": dragSource.x + dragSource.dragOriginX,
        "y": dragSource.y + dragSource.dragOriginY
      };

    return null;
  }

  function buildRetileWindowRecords(workspaceId) {
    var records = [];
    for (var addr in root.windowByAddress) {
      var win = root.windowByAddress[addr];
      if (!win || !win.workspace)
        continue;

      var rect = win.workspace.id === workspaceId ? root.getScaledWindowRectForWorkspace(win, workspaceId) : null;
      records.push({
                     "address": win.address || addr,
                     "workspaceId": win.workspace.id,
                     "floating": !!win.floating,
                     "fullscreen": !!win.fullscreen,
                     "maximized": !!win.maximized,
                     "rect": rect
                   });
    }
    return records;
  }

  // aimX, aimY are cursor hotspot coordinates within windowSpace.
  function calculateRetileTarget(workspaceId, aimX, aimY) {
    var draggedWin = root.windowByAddress[root.draggingTargetAddress];
    var workspaceOffsets = root.getWorkspaceOffsets(workspaceId);
    return RetileBlueprint.resolveTarget({
                                           "workspaceId": workspaceId,
                                           "hotspotX": aimX,
                                           "hotspotY": aimY,
                                           "workspaceOffset": workspaceOffsets,
                                           "draggedAddress": root.draggingTargetAddress,
                                           "draggedWindow": draggedWin,
                                           "windows": root.buildRetileWindowRecords(workspaceId),
                                           "edgeRatio": root.zoneEdgeSize,
                                           "minSplitRatio": root.minimumSplitZoneRatio,
                                           "minEdgePx": 32,
                                           "deadzonePx": 6,
                                           "previousDirection": root.retilingDirection,
                                           "noopGeometryEpsilonPx": root.noopGeometryEpsilonPx,
                                           "labels": root.retileLabels()
                                         });
  }

  // Update pluginMain with the minimum fit scale across all screens (for Settings UI warning)
  onFitScaleChanged: {
    if (pluginMain && pluginMain.reportFitScale)
      pluginMain.reportFitScale(fitScale);
  }

  onClientRefreshRevisionChanged: reconcileRetileTransitionRecords()
  Timer {
    id: retileTransitionTimeout

    interval: 140
    repeat: false
    onTriggered: root.reconcileRetileTransitionRecords()
  }

  // Scaled container for fit-to-screen
  Item {
    id: scaledContainer

    anchors.centerIn: parent
    width: overviewBackground.implicitWidth
    height: overviewBackground.implicitHeight
    scale: root.fitScale

    NDropShadow {
      anchors.fill: overviewBackground
      source: overviewSurface
      shadowEnabled: true
      z: -1
    }

    Item {
      id: overviewBackground

      readonly property real padding: root.surfacePadding

      anchors.fill: parent
      implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
      implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2

      // Surface layer follows Noctalia's shell panel model without fading child content.
      Rectangle {
        id: overviewSurface

        anchors.fill: parent
        radius: root.workspaceCellRadius
        antialiasing: radius > 0
        color: Color.mSurface
        opacity: root.clamp((Color.panelBackgroundOpacity || Commons.Settings.data.ui.panelBackgroundOpacity || 0.8) * root.backgroundOpacityRatio, 0, 1)
        border.width: root.containerBorderWidth
        border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.52)
      }

      // Keep outer container shape aligned with workspace/indicator corners.

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
                color: hoveredWhileDragging ? Qt.lighter(Color.mSurfaceVariant, 1.05) : Color.mSurfaceVariant
                opacity: baseOpacity
                // Use scaled screen radius for the workspace preview
                radius: root.workspaceCellRadius
                antialiasing: radius > 0
                border.width: hoveredWhileDragging ? Math.max(1, Style.borderS) : (isActiveCell ? 0 : Math.max(1, Style.borderS))
                border.color: hoveredWhileDragging ? Qt.lighter(root.accentColor, 1.1) : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.15)

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
                      return Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, workspace.isActiveCell ? 0.3 : 0.2);

                    return Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, workspace.isActiveCell ? 0.85 : 0.5);
                  }
                  border.width: pluginMain.specialWorkspaceStyle === "plain" ? 0 : 1
                  border.color: workspace.isSpecialSlot ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, workspace.isActiveCell ? 0.8 : 0.4) : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, workspace.isActiveCell ? 0.6 : 0.2)
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

                Rectangle {
                  id: migrationIndicator

                  anchors.fill: parent
                  visible: pluginMain.enableCrossMonitorDrag && root.draggingCrossMonitor && !workspace.isSpecialSlot && root.draggingTargetWorkspace === workspace.workspaceValue
                  color: "transparent"
                  border.width: 3
                  border.color: {
                    var monId = root.draggingTargetMonitorId;
                    var monitors = pluginMain ? pluginMain.monitors : [];
                    var pal = ["#4CAF50", "#2196F3", "#FF9800", "#9C27B0", "#F44336"];
                    return monId >= 0 ? (pal[monId % pal.length] || "#4CAF50") : "#4CAF50";
                  }
                  z: 10
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

                    if (workspace.isSpecialSlot && workspace.specialWorkspace)
                      root.runHyprBatch(["togglespecialworkspace " + workspace.specialWorkspace.name], {
                                          "closeAfterDispatch": true
                                        });
                    else
                      root.runHyprBatch(["workspace " + workspace.workspaceValue], {
                                          "closeAfterDispatch": true
                                        });
                  }
                }

                // Drop target for drag-and-drop
                DropArea {
                  anchors.fill: parent
                  onEntered: {
                    var targetWsId = workspace.isSpecialSlot ? (workspace.specialWorkspace ? workspace.specialWorkspace.id : -1) : workspace.workspaceValue;
                    var targetMonitorId = root.getMonitorIdForWorkspace(targetWsId);
                    root.draggingSourceMonitorId = root.monitor ? root.monitor.id : -1;
                    var isCrossMonitorTarget = targetMonitorId !== -1 && targetMonitorId !== root.draggingSourceMonitorId;
                    if (isCrossMonitorTarget && !pluginMain.enableCrossMonitorDrag) {
                      root.draggingTargetWorkspace = -1;
                      root.draggingTargetSpecial = null;
                      root.draggingIntraWorkspace = -1;
                      root.draggingCrossMonitor = false;
                      root.draggingTargetMonitorId = -1;
                      workspace.hoveredWhileDragging = false;
                      root.resetRetileState();
                      return;
                    }

                    if (workspace.isSpecialSlot) {
                      root.draggingTargetWorkspace = -1;
                      root.draggingTargetSpecial = workspace.specialWorkspace;
                      if (!root.draggingTargetSpecial)
                        return;
                    } else {
                      root.draggingTargetWorkspace = workspace.workspaceValue;
                      root.draggingTargetSpecial = null;
                      if (root.draggingFromWorkspace == root.draggingTargetWorkspace)
                        root.draggingIntraWorkspace = root.draggingFromWorkspace;
                    }
                    // Cross-monitor detection
                    if (isCrossMonitorTarget && pluginMain.enableCrossMonitorDrag) {
                      root.draggingCrossMonitor = true;
                      root.draggingTargetMonitorId = targetMonitorId;
                    } else {
                      root.draggingCrossMonitor = false;
                      root.draggingTargetMonitorId = -1;
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
                    root.draggingCrossMonitor = false;
                    root.draggingTargetMonitorId = -1;
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
                      var hotspot = root.dragHotspotInWindowSpace(workspace, drag, dragSource);
                      var candidate = hotspot ? root.calculateRetileTarget(workspace.workspaceValue, hotspot.x, hotspot.y) : null;
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
        // Keep indicator stroke geometry identical to workspace cells while
        // WindowPreview keeps its root frame stable for input and drag math.
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
              }).map(function (toplevel) {
                var addr = "0x" + toplevel.HyprlandToplevel.address;
                return {
                  "toplevel": toplevel,
                  "win": root.windowByAddress[addr]
                };
              }).sort(function (a, b) {
                return HyprlandState.compareWindowRecords(a, b);
              }).map(function (record) {
                return record.toplevel;
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
            property var sourceWorkArea: WorkspaceGeometry.getMonitorWorkArea(windowMonitor || {
                                                                                "width": 1920,
                                                                                "height": 1080,
                                                                                "scale": 1,
                                                                                "transform": 0,
                                                                                "reserved": [0, 0, 0, 0]
                                                                              })
            property real sourceMonitorWidth: sourceWorkArea.width
            property real sourceMonitorHeight: sourceWorkArea.height
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
            workAreaX: sourceWorkArea.x
            workAreaY: sourceWorkArea.y
            workAreaWidth: sourceWorkArea.width
            workAreaHeight: sourceWorkArea.height
            availableWorkspaceWidth: root.workspaceImplicitWidth
            availableWorkspaceHeight: root.workspaceImplicitHeight
            workspaceExclusiveGap: root.workspaceExclusiveGap
            centeringX: root.centeringXOffset
            centeringY: root.centeringYOffset
            widgetMonitorId: root.monitor ? root.monitor.id : 0
            overviewOpen: root.pluginMain.overviewOpen
            captureRevision: root.overlayCaptureRevision + root.overlayCaptureRevisionForAddress(address)
            retileTransitionFrame: root.retileTransitionFrameForDelegate(address, effectiveWorkspaceValue)
            retileTransitionActive: root.retileTransitionActive
            positionResyncRevision: (root.retileFinalizedAddressMap && root.retileFinalizedAddressMap[address]) ? root.retileFinalizedPositionRevision : 0
            useSimplifiedPreview: root.pluginMain.useSimplifiedPreview
            visualMode: root.pluginMain.visualMode
            shaderPreset: root.pluginMain.shaderPreset
            shaderPresetStrength: root.pluginMain.shaderPresetStrength
            simplifiedPixelDensity: root.pluginMain.simplifiedPixelDensity
            simplifiedColorDepth: root.pluginMain.simplifiedColorDepth
            simplifiedSaturation: root.pluginMain.simplifiedSaturation
            simplifiedContrast: root.pluginMain.simplifiedContrast
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
            showMonitorBadge: root.pluginMain.showMonitorIndicators
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
            dragFeedbackOpacity: (windowDelegate.isDragging && root.retilingTarget !== null && !(windowDelegate.windowData && windowDelegate.windowData.floating)) ? 0.42 : 1

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

            // Track drag velocity for tilt effect. DragHandler owns movement so
            // scaled overview transforms do not distort manual pointer deltas.
            property real dragPreviousX: 0
            property real dragLastUpdateTime: 0
            property real dragStartItemX: 0
            property real dragStartItemY: 0
            property bool dragMoved: false
            property bool finishingDrag: false

            function beginWindowDrag(point) {
              root.clearRetileTransitionRecords();
              root.draggingFromWorkspace = ((windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1);
              root.draggingTargetAddress = (windowDelegate.windowData && windowDelegate.windowData.address) || "";
              root.dragInteractionState = "targeting";
              root.resetRetileState();
              dragStartItemX = windowDelegate.x;
              dragStartItemY = windowDelegate.y;
              dragMoved = false;
              windowDelegate.pressed = true;
              windowDelegate.isDragging = true;
              windowDelegate.dragOriginX = point ? point.x : windowDelegate.width / 2;
              windowDelegate.dragOriginY = point ? point.y : windowDelegate.height / 2;
              windowDelegate.Drag.source = windowDelegate;
              windowDelegate.Drag.hotSpot.x = windowDelegate.dragOriginX;
              windowDelegate.Drag.hotSpot.y = windowDelegate.dragOriginY;
              windowDelegate.Drag.active = true;
              dragPreviousX = windowDelegate.x;
              dragLastUpdateTime = Date.now();
            }

            function updateWindowDragFeedback() {
              if (!windowDelegate.isDragging || finishingDrag)
                return;

              if (Math.abs(windowDelegate.x - dragStartItemX) > 2 || Math.abs(windowDelegate.y - dragStartItemY) > 2)
                dragMoved = true;

              var currentTime = Date.now();
              var deltaTime = Math.max(1, currentTime - dragLastUpdateTime);
              var deltaX = windowDelegate.x - dragPreviousX;
              var velocity = deltaX / (deltaTime / 16);
              windowDelegate.dragVelocity = velocity;
              windowDelegate.dragTilt = Math.min(Math.max(velocity * 1.5, -3), 3);
              dragPreviousX = windowDelegate.x;
              dragLastUpdateTime = currentTime;
              root.currentDropIntent = root.buildDropIntentForDelegate(windowDelegate, root.retilingTarget);
            }

            function resetWindowDragState(cancelled) {
              if (cancelled)
                root.debugLog("drag", "reset/cancel address=" + ((windowDelegate.windowData && windowDelegate.windowData.address) || "") + " reason=cancelled");
              windowDelegate.pressed = false;
              windowDelegate.isDragging = false;
              windowDelegate.dragTilt = 0;
              windowDelegate.dragVelocity = 0;
              windowDelegate.Drag.active = false;
              root.draggingFromWorkspace = -1;
              root.draggingTargetWorkspace = -1;
              root.draggingTargetSpecial = null;
              root.draggingIntraWorkspace = -1;
              root.draggingTargetAddress = "";
              root.draggingCrossMonitor = false;
              root.draggingTargetMonitorId = -1;
              root.currentDropIntent = null;
              root.resetRetileState();
              if (cancelled) {
                windowDelegate.x = windowDelegate.initX;
                windowDelegate.y = windowDelegate.initY;
              }
            }

            function startRetileTransitionMotion() {
              suppressPositionAnimation = false;
              windowDelegate.x = windowDelegate.initX;
              windowDelegate.y = windowDelegate.initY;
            }

            function finishWindowDrag(cancelled) {
              if (!windowDelegate.isDragging)
                return;

              finishingDrag = true;
              var releaseId = root.nextDebugReleaseId();
              if (cancelled) {
                root.debugLog("drag", "release=" + releaseId + " cancelled before decision address=" + ((windowDelegate.windowData && windowDelegate.windowData.address) || ""));
                resetWindowDragState(true);
                finishingDrag = false;
                return;
              }

              var currentWsId = (windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1;
              var currentWsName = (windowDelegate.windowData && windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.name) || "";
              var windowAddress = (windowDelegate.windowData && windowDelegate.windowData.address) || "";
              var isFloating = (windowDelegate.windowData && windowDelegate.windowData.floating) || false;
              var sourceMonitorId = root.draggingSourceMonitorId;
              var targetMonitorId = root.draggingTargetMonitorId;
              var crossMonitorDrag = root.draggingCrossMonitor;
              var dragDeltaX = windowDelegate.x - windowDelegate.initX;
              var dragDeltaY = windowDelegate.y - windowDelegate.initY;
              var dropIntent = root.buildDropIntentForDelegate(windowDelegate, root.retilingTarget);
              var floatingDropPos = isFloating ? root.resolveFloatingDropPosition(windowDelegate, dropIntent.target.workspaceId !== -1 ? dropIntent.target.workspaceId : currentWsId) : null;
              var layoutAction = LayoutStrategy.get(dropIntent.layout.name).getDropAction(dropIntent);
              var debugRetileTargetAddress = (root.retilingTarget && root.retilingTarget.targetAddress) || "";
              var releaseDecision = DragDecision.decideRelease({
                                                                 "windowAddress": windowAddress,
                                                                 "currentWorkspaceId": currentWsId,
                                                                 "currentSpecialName": dropIntent.source.specialName,
                                                                 "targetWorkspace": dropIntent.target.workspaceId,
                                                                 "targetSpecial": dropIntent.target.special,
                                                                 "isFloating": isFloating,
                                                                 "dragPreviewMode": pluginMain.dragPreviewMode || "smart",
                                                                 "sourceMonitorId": sourceMonitorId,
                                                                 "targetMonitorId": targetMonitorId,
                                                                 "enableCrossMonitorDrag": pluginMain.enableCrossMonitorDrag,
                                                                 "crossMonitorDrag": crossMonitorDrag,
                                                                 "intent": dropIntent,
                                                                 "layoutAction": layoutAction,
                                                                 "floatingDropPosition": floatingDropPos
                                                               });
              var needsRetileTransition = releaseDecision.type === "tiledSwap" || releaseDecision.type === "tiledSplit";
              var retileTransitionRecords = root.buildRetileTransitionRecords(windowAddress, root.retilingTarget, releaseDecision.type);
              var needsOverlayRecapture = releaseDecision.type === "tiledSwap" || releaseDecision.type === "tiledSplit" || releaseDecision.type === "layoutReorder";
              var layoutRecaptureAddresses = needsOverlayRecapture ? root.workspaceWindowAddresses(currentWsId) : [];
              if (needsOverlayRecapture && layoutRecaptureAddresses.length === 0 && windowAddress !== "")
                layoutRecaptureAddresses = [windowAddress];
              root.debugLog("drag", "release=" + releaseId + " source=" + root.debugStringify(root.debugWindowState(windowDelegate.windowData)) + " targetWorkspace=" + dropIntent.target.workspaceId + " targetSpecial=" + root.debugStringify(dropIntent.target.special) + " targetMonitor=" + targetMonitorId + " sourceMonitor=" + sourceMonitorId + " crossMonitor="
                            + crossMonitorDrag + " dragDelta=" + root.debugStringify({
                                                                                       "x": dragDeltaX,
                                                                                       "y": dragDeltaY
                                                                                     }));
              root.debugLog("drag", "release=" + releaseId + " retile=" + root.debugStringify({
                                                                                                "targetAddress": root.retilingTarget && root.retilingTarget.targetAddress,
                                                                                                "direction": root.retilingTarget && root.retilingTarget.direction,
                                                                                                "isNoop": root.retilingTarget && root.retilingTarget.isNoop,
                                                                                                "noopReason": root.retilingTarget && root.retilingTarget.noopReason
                                                                                              }) + " intent=" + root.debugStringify(dropIntent) + " layoutAction=" + root.debugStringify(layoutAction) + " decision=" + root.debugStringify(releaseDecision) + " commands=" + root.debugStringify(releaseDecision.commands || []));
              resetWindowDragState(false);
              if (releaseDecision.commands && releaseDecision.commands.length > 0) {
                if (needsOverlayRecapture && pluginMain && pluginMain.beginLayoutMutationDebug)
                  pluginMain.beginLayoutMutationDebug(releaseId, releaseDecision.type, windowAddress, debugRetileTargetAddress, releaseDecision.commands);
                if (retileTransitionRecords)
                  root.setRetileTransitionRecords(retileTransitionRecords, layoutRecaptureAddresses);
                if (needsRetileTransition)
                  startRetileTransitionMotion();
                if (releaseDecision.optimisticMove && pluginMain && pluginMain.applyOptimisticWindowMove)
                  pluginMain.applyOptimisticWindowMove(windowAddress, releaseDecision.optimisticMove.x, releaseDecision.optimisticMove.y, releaseDecision.optimisticMove.workspaceId);

                root.debugLog("dispatch", "release=" + releaseId + " type=" + releaseDecision.type + " commands=" + root.debugStringify(releaseDecision.commands));
                root.runHyprBatch(releaseDecision.commands);

                if (!needsRetileTransition) {
                  updateWindowPosition.restart();
                }
                if (pluginMain && pluginMain.refreshWindows) {
                  pluginMain.refreshWindows();
                  if (needsOverlayRecapture && pluginMain.updateAll) {
                    pluginMain.updateAll();
                    if (needsRetileTransition && pluginMain.requestRetileGeometryRefresh)
                      pluginMain.requestRetileGeometryRefresh(releaseDecision.type, layoutRecaptureAddresses);
                    else if (pluginMain.requestOverlayRecapture)
                      pluginMain.requestOverlayRecapture(releaseDecision.type, layoutRecaptureAddresses);
                  }
                  if (releaseDecision.type === "workspaceMove" && sourceMonitorId !== targetMonitorId && pluginMain.updateAll)
                    pluginMain.updateAll();
                  if (releaseDecision.type === "floatingMove")
                    floatingReconcileRefresh.restart();
                }
              } else {
                root.debugLog("drag", "release=" + releaseId + " reset/no-command reason=" + (releaseDecision.reason || releaseDecision.status || dropIntent.status || releaseDecision.type || "no-commands") + " sourceWorkspace=" + currentWsId + " sourceSpecial=" + root.normalizeSpecialName(currentWsName));
                windowDelegate.x = windowDelegate.initX;
                windowDelegate.y = windowDelegate.initY;
              }
              finishingDrag = false;
            }

            onXChanged: updateWindowDragFeedback()
            onYChanged: updateWindowDragFeedback()

            HoverHandler {
              id: windowHoverHandler

              onHoveredChanged: windowDelegate.hovered = hovered
            }

            DragHandler {
              id: windowDragHandler

              target: windowDelegate
              snapMode: DragHandler.NoSnap
              dragThreshold: 0
              acceptedButtons: Qt.LeftButton
              onActiveChanged: {
                if (active)
                  windowDelegate.beginWindowDrag(windowDragHandler.centroid.position);
                else
                  windowDelegate.finishWindowDrag(false);
              }
              onCanceled: point => windowDelegate.finishWindowDrag(true)
            }

            TapHandler {
              id: windowFocusTapHandler

              acceptedButtons: Qt.LeftButton
              onTapped: (eventPoint, button) => {
                if (!windowDelegate.windowData)
                  return;

                var address = windowDelegate.windowData.address;
                var wsId = (windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.id) || -1;
                var wsName = (windowDelegate.windowData.workspace && windowDelegate.windowData.workspace.name) || "";
                Logger.i("WorkspaceOverview", "Clicked window " + address + ", dispatching guarded focus.");
                var commands = [];
                if (wsName.startsWith("special:"))
                  commands.push("togglespecialworkspace " + wsName.substring(8));
                else if (wsId >= 0)
                  commands.push("workspace " + wsId);
                commands.push("focuswindow address:" + address);
                root.runHyprBatch(commands, {
                                    "closeAfterDispatch": true
                                  });
              }
            }

            TapHandler {
              id: windowCloseTapHandler

              acceptedButtons: Qt.MiddleButton
              onTapped: (eventPoint, button) => {
                if (windowDelegate.windowData)
                  root.closeWindowAddress(windowDelegate.windowData.address);
              }
            }
          }
        }

        // === RETILE PREVIEW ===
        RetilePreview {
          id: retilingPreviewBase

          anchors.fill: parent
          z: root.windowDraggingZ - 3
          layerRole: "base"
          showPreview: root.retilingTarget !== null
          previewModel: root.retilingTarget ? root.retilingTarget.previewModel : null
          previewOpacityScale: root.clamp(pluginMain.retilePreviewOpacity || 0.55, 0.2, 0.9)
        }

        RetilePreview {
          id: retilingPreviewForeground

          anchors.fill: parent
          z: root.windowDraggingZ + 1
          layerRole: "foreground"
          showPreview: root.retilingTarget !== null
          previewModel: root.retilingTarget ? root.retilingTarget.previewModel : null
          previewOpacityScale: root.clamp(pluginMain.retilePreviewOpacity || 0.55, 0.2, 0.9)
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
        shadowColor: "#000000"
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 4
      }
    }
  }
}
