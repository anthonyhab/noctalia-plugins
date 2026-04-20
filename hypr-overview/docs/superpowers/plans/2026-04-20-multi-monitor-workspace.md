# Multi-Monitor Workspace Overview — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each monitor's overlay groups workspaces by its own active workspace, shows monitor indicator badges on workspace cells, and supports cross-monitor drag migration with visual feedback.

**Architecture:** Per-monitor active workspace derived from `HyprlandMonitor.activeWorkspace`. Monitor indicator badges computed from `windowList[].monitor` per workspace. Cross-monitor drag detects target monitor and shows migration indicator on drop target.

**Tech Stack:** QML + Qt6, Hyprland hyprctl, Noctalia plugin API

---

## File Map

| File | Responsibility |
|------|---------------|
| `Main.qml` | State owner: `getVisibleWorkspaces(monitorId)`, `workspaceMonitorBindings`, cross-monitor drop dispatch |
| `components/OverviewGrid.qml` | UI: per-monitor active workspace, monitor badge rendering, migration indicator overlay, DropArea handlers |
| `Settings.qml` | New settings: `showMonitorIndicators`, `enableCrossMonitorDrag`, `crossMonitorDragStyle` |
| `i18n/en.json` | Translation keys for new settings and badge tooltips |
| `manifest.json` | Bump version to `1.1.0`, add new default settings |

---

## Task 1: Main.qml — Per-Monitor `getVisibleWorkspaces` and `workspaceMonitorBindings`

**Files:** Modify: `Main.qml:569-618`, add property after `monitors`

- [ ] **Step 1: Read current `getVisibleWorkspaces` function**

Lines 569–618 in Main.qml. Currently ignores `monitorId` param, uses global `activeWorkspace`.

- [ ] **Step 2: Update `getVisibleWorkspaces(monitorId)` to use per-monitor active workspace**

```javascript
function getVisibleWorkspaces(monitorId) {
    var workspacesPerGroup = gridRows * gridColumns;
    // Find target monitor from monitors array
    var targetMonitor = monitors.find(function(m) { return m.id === monitorId; });
    var currentId = 1;
    if (targetMonitor && targetMonitor.activeWorkspace) {
        currentId = targetMonitor.activeWorkspace.id || 1;
    }
    if (currentId < 0) currentId = 1;
    var currentGroup = Math.floor((currentId - 1) / workspacesPerGroup);
    var minWorkspaceId = currentGroup * workspacesPerGroup + 1;
    var visible = [];
    // Normal workspaces in group
    for (var i = 0; i < workspacesPerGroup; i++) {
        var wsId = minWorkspaceId + i;
        visible.push({ "id": wsId, "type": "normal" });
    }
    // Special workspaces (unchanged from current)
    var reservedSlots = 0;
    if (showScratchpadWorkspaces) {
        reservedSlots = Math.min(specialWorkspaces.length, workspacesPerGroup);
        reservedSlots = Math.min(reservedSlots, Math.max(0, workspacesPerGroup - 1));
        for (var j = 0; j < reservedSlots; j++) {
            var special = specialWorkspaces[j];
            var targetIndex = visible.length - reservedSlots + j;
            if (targetIndex >= 0 && targetIndex < visible.length)
                visible[targetIndex] = { "id": special.id, "type": "special", "name": special.name, "rawName": special.rawName };
        }
    }
    return visible;
}
```

- [ ] **Step 3: Add `workspaceMonitorBindings` computed property after `monitors` property (line ~120)**

```qml
// Maps workspace ID → array of monitor IDs that have windows on that workspace
readonly property var workspaceMonitorBindings: {
    var bindings = {};
    var wins = windowList || [];
    for (var i = 0; i < wins.length; i++) {
        var win = wins[i];
        if (!win || !win.workspace) continue;
        var wsId = win.workspace.id;
        var monId = win.monitor;
        if (wsId === undefined || monId === undefined) continue;
        if (!bindings[wsId]) bindings[wsId] = [];
        if (bindings[wsId].indexOf(monId) === -1) bindings[wsId].push(monId);
    }
    return bindings;
}
```

- [ ] **Step 4: Add helper `getMonitorIdForWorkspace(workspaceId)` after `workspaceMonitorBindings`**

```javascript
function getMonitorIdForWorkspace(workspaceId) {
    // Returns the primary monitor ID for a workspace based on window placement
    var bindings = workspaceMonitorBindings;
    if (!bindings || !bindings[workspaceId] || bindings[workspaceId].length === 0)
        return -1;
    return bindings[workspaceId][0];
}
```

- [ ] **Step 5: Run qmllint on Main.qml**

```bash
qmllint Main.qml
```
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add Main.qml && git commit -m "feat: per-monitor getVisibleWorkspaces and workspaceMonitorBindings"
```

---

## Task 2: OverviewGrid.qml — Per-Monitor Active Workspace + Cross-Monitor Drag State

**Files:** Modify: `components/OverviewGrid.qml:35-72`, add `draggingCrossMonitor` properties, modify DropArea handlers

- [ ] **Step 1: Read existing monitor-reactive properties (lines 35–72)**

Already has `monitor` (line 35) and uses `monitor.activeWorkspace` for `isViewingSpecialWorkspace` and `workspaceGroup` (lines 38-39). Key property `_activeWsForIndicator` (line 43-51) already falls back to `monitor.activeWorkspace`.

The main change needed: ensure `_activeWsForIndicator` correctly prioritizes the per-monitor active workspace.

- [ ] **Step 2: Add cross-monitor drag state properties after `monitorData` property (line ~73)**

```qml
// Cross-monitor drag state
property bool draggingCrossMonitor: false
property int draggingTargetMonitorId: -1
property int draggingSourceMonitorId: -1
```

- [ ] **Step 3: Add `getMonitorIdForWorkspace` wrapper function after `resolveFloatingDropPosition` (~line 519)**

```qml
function getMonitorIdForWorkspace(workspaceId) {
    if (!pluginMain) return -1;
    return pluginMain.getMonitorIdForWorkspace(workspaceId);
}
```

- [ ] **Step 4: Update DropArea `onEntered` handler (line ~1241)**

Replace current `onEntered` logic to detect cross-monitor drag:

```qml
onEntered: {
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
    var targetWsId = workspace.isSpecialSlot
        ? (workspace.specialWorkspace ? workspace.specialWorkspace.id : -1)
        : workspace.workspaceValue;
    var targetMonitorId = root.getMonitorIdForWorkspace(targetWsId);
    root.draggingSourceMonitorId = root.monitor ? root.monitor.id : -1;
    if (targetMonitorId !== -1 && targetMonitorId !== root.draggingSourceMonitorId) {
        root.draggingCrossMonitor = true;
        root.draggingTargetMonitorId = targetMonitorId;
    } else {
        root.draggingCrossMonitor = false;
        root.draggingTargetMonitorId = -1;
    }
    workspace.hoveredWhileDragging = true;
}
```

- [ ] **Step 5: Update DropArea `onExited` handler (line ~1256)**

```qml
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
```

- [ ] **Step 6: Add migration indicator overlay in workspace cell**

Find the workspace cell `Rectangle` delegate (around line 1040-1100). Add a `visible` colored `Rectangle` with `border` that shows when `root.draggingCrossMonitor && root.draggingTargetWorkspace === workspace.workspaceValue`:

```qml
// Inside the workspace cell Rectangle, after the label chip
Rectangle {
    id: migrationIndicator
    anchors.fill: parent
    visible: root.draggingCrossMonitor && !workspace.isSpecialSlot && root.draggingTargetWorkspace === workspace.workspaceValue
    color: "transparent"
    border.width: 3
    border.color: {
        // Color by target monitor ID
        var monId = root.draggingTargetMonitorId;
        var monitors = pluginMain ? pluginMain.monitors : [];
        var pal = ["#4CAF50", "#2196F3", "#FF9800", "#9C27B0", "#F44336"];
        return monId >= 0 ? (pal[monId % pal.length] || "#4CAF50") : "#4CAF50";
    }
    z: 10
}
```

Position this overlay above the workspace content but below window previews (it marks the cell border).

- [ ] **Step 7: Run qmllint on OverviewGrid.qml**

```bash
qmllint components/OverviewGrid.qml
```
Expected: no errors

- [ ] **Step 8: Commit**

```bash
git add components/OverviewGrid.qml && git commit -m "feat: per-monitor active workspace and cross-monitor drag indicator"
```

---

## Task 3: Settings.qml — New Settings Controls

**Files:** Modify: `Settings.qml` (~line 1949, after `showMonitorBadge` toggle)

- [ ] **Step 1: Add new settings after `showMonitorBadge` toggle (line ~1948)**

Add under the "Badges" section or create a new "Multi-Monitor" section. Since the spec groups these with appearance, add after the badges section:

```qml
NLabel {
    text: tr("settings.appearance.section.multiMonitor", "Multi-Monitor")
    font.bold: true
}

NToggle {
    label: tr("settings.appearance.showMonitorIndicators.label", "Show monitor indicators")
    description: tr("settings.appearance.showMonitorIndicators.description", "Show monitor badges on workspace cells for workspaces bound to other monitors")
    checked: root.showMonitorIndicators
    onToggled: checked => {
        root.showMonitorIndicators = checked;
        root.saveSettings();
    }
}

NToggle {
    label: tr("settings.appearance.enableCrossMonitorDrag.label", "Cross-monitor drag")
    description: tr("settings.appearance.enableCrossMonitorDrag.description", "Enable dragging windows to workspaces on other monitors, migrating the window to that monitor")
    checked: root.enableCrossMonitorDrag
    onToggled: checked => {
        root.enableCrossMonitorDrag = checked;
        root.saveSettings();
    }
}

NComboBox {
    label: tr("settings.appearance.crossMonitorDragStyle.label", "Drag indicator style")
    model: [ "border", "arrow", "both" ]
    currentIndex: {
        var style = root.crossMonitorDragStyle || "border";
        var idx = ["border", "arrow", "both"].indexOf(style);
        return idx >= 0 ? idx : 0;
    }
    onActivated: index => {
        root.crossMonitorDragStyle = ["border", "arrow", "both"][index];
        root.saveSettings();
    }
}
```

- [ ] **Step 2: Add local property declarations at top of Settings ColumnLayout (~line 50)**

```qml
property bool showMonitorIndicators: getSetting("showMonitorIndicators", true)
property bool enableCrossMonitorDrag: getSetting("enableCrossMonitorDrag", true)
property string crossMonitorDragStyle: getSetting("crossMonitorDragStyle", "border")
```

- [ ] **Step 3: Run qmllint on Settings.qml**

```bash
qmllint Settings.qml
```
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add Settings.qml && git commit -m "feat: add multi-monitor settings controls"
```

---

## Task 4: i18n/en.json — Translation Keys

**Files:** Modify: `i18n/en.json`

- [ ] **Step 1: Add translation keys after `monitorBadge` entry (line ~245)**

```json
"showMonitorIndicators": {
    "label": "Show monitor indicators",
    "description": "Show monitor badges on workspace cells for workspaces bound to other monitors"
},
"enableCrossMonitorDrag": {
    "label": "Cross-monitor drag",
    "description": "Enable dragging windows to workspaces on other monitors, migrating the window to that monitor"
},
"crossMonitorDragStyle": {
    "label": "Drag indicator style",
    "options": {
        "border": "Border highlight",
        "arrow": "Arrow indicator",
        "both": "Border + Arrow"
    }
},
"workspaceMonitorBadge": {
    "tooltip": "Workspace on monitor %1"
},
"migrationIndicator": {
    "label": "Migrate to monitor %1"
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('i18n/en.json'))"
```
Expected: valid JSON, no output

- [ ] **Step 3: Commit**

```bash
git add i18n/en.json && git commit -m "feat: add multi-monitor i18n keys"
```

---

## Task 5: manifest.json — Version Bump + New Default Settings

**Files:** Modify: `manifest.json`

- [ ] **Step 1: Bump version from `0.2.0` to `1.1.0`**

```json
"version": "1.1.0"
```

- [ ] **Step 2: Add new default settings to `metadata.defaultSettings`**

```json
"showMonitorIndicators": true,
"enableCrossMonitorDrag": true,
"crossMonitorDragStyle": "border"
```

- [ ] **Step 3: Commit**

```bash
git add manifest.json && git commit -m "feat: bump version to 1.1.0 for multi-monitor support"
```

---

## Task 6: Integration Test

- [ ] **Step 1: Open hypr-overview in Noctalia Shell with 2+ monitors**
- [ ] **Step 2: Verify each overlay shows different workspace groups based on its monitor's active workspace**
- [ ] **Step 3: Drag a window from workspace on Monitor A to workspace on Monitor B — verify migration**
- [ ] **Step 4: With `showMonitorIndicators: true`, verify badges appear on cross-monitor workspaces**
- [ ] **Step 5: Toggle `showMonitorIndicators: false` — verify badges disappear**
- [ ] **Step 6: Test keyboard/scroll navigation independently on each overlay**

---

**Plan complete.** Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints

**Which approach?**