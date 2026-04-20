# Multi-Monitor Aware Workspace Overview — Design Spec

**Date:** 2026-04-20
**Project:** hypr-overview
**Target:** Hyprland git (v0.54.3+) + Noctalia Shell plugins

---

## 1. Problem Statement

All hypr-overview overlays currently show the same workspace group (based on the globally focused monitor's active workspace). Each monitor runs independent workspaces, but the overview doesn't reflect this — no monitor indicators, no cross-monitor drag migration.

### Goals

1. Each overlay groups workspaces by its own monitor's active workspace
2. Monitor indicator badges on workspace cells for workspaces bound to other monitors
3. Visual migration indicator during cross-monitor drag
4. Window migrates to target monitor on drop
5. All existing drag features preserved

---

## 2. Architecture: Per-Monitor Grouping + Monitor Badges

### 2.1 Per-Monitor Active Workspace

**Source:** `hyprctl monitors -j` provides `activeWorkspace: { id, name }` per monitor. `HyprlandMonitor` QML object exposes this reactively as `monitor.activeWorkspace`.

**Change in `OverviewGrid.qml`:**

```qml
// Replace global pluginMain.activeWorkspace with per-monitor value
readonly property var monitorActiveWorkspace: monitor ? monitor.activeWorkspace : null
readonly property int monitorActiveWorkspaceId: (monitorActiveWorkspace && monitorActiveWorkspace.id) || 1
readonly property bool isViewingSpecialWorkspace: monitorActiveWorkspaceId < 0
readonly property int workspaceGroup: isViewingSpecialWorkspace
    ? 0
    : Math.floor((monitorActiveWorkspaceId - 1) / root.workspacesShown)
```

This drives: pagination, active highlight, keyboard/scroll navigation.

### 2.2 `getVisibleWorkspaces` Per-Monitor

`Main.qml`'s `getVisibleWorkspaces(monitorId)` already accepts a `monitorId` param but ignores it. Update it to use that monitor's active workspace for group computation:

```javascript
function getVisibleWorkspaces(monitorId) {
    var targetMonitor = monitors.find(m => m.id === monitorId)
    var currentId = targetMonitor?.activeWorkspace?.id || 1
    if (currentId < 0) currentId = 1
    var currentGroup = Math.floor((currentId - 1) / workspacesPerGroup)
    // ... rest unchanged
}
```

### 2.3 Monitor Indicator Badges

**New setting:** `showMonitorIndicators: bool` (default: `true`)

Badge shows on workspace cells that have windows on a monitor **other than** the overlay's own. Computed from `windowList[].monitor` per workspace.

**Implementation:** `Main.qml` adds `workspaceMonitorBindings: [{wsId: 3, monitorIds: [0, 1]}, ...]`. `OverviewGrid.qml` renders badge via inline `Rectangle` + label in workspace delegate.

### 2.4 Cross-Monitor Drag

**During hover** — `DropArea.onEntered` in `OverviewGrid.qml`:

```qml
var targetMonitorId = root.getMonitorIdForWorkspace(targetWsId)
if (targetMonitorId !== -1 && targetMonitorId !== root.monitor.id) {
    root.draggingCrossMonitor = true
    root.draggingTargetMonitorId = targetMonitorId
    // Show colored border overlay on target cell
}
```

**On drop** — `OverviewGrid.qml`:

```qml
// Cross-monitor migration (verified for Hyprland 0.54.3)
Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowAddress}`)
// movetoworkspacesilent implicitly migrates window to target monitor
```

### 2.5 New Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `showMonitorIndicators` | bool | `true` | Show monitor badges on workspace cells |
| `enableCrossMonitorDrag` | bool | `true` | Enable window migration across monitors via drag |
| `crossMonitorDragStyle` | enum | `"border"` | Feedback style: `"border"` / `"arrow"` / `"both"` |

---

## 3. Verified Hyprland Bindings (v0.54.3 / git)

| Command | Status | Notes |
|---------|--------|-------|
| `hyprctl dispatch movetoworkspacesilent "N,address:0x..."` | ✅ Works | Accepts workspace number + `,address:` suffix |
| `hyprctl dispatch focusmonitor "DP-2"` | ✅ Works | Monitor name, not ID |
| `hyprctl clients -j` → `monitor` as integer ID | ✅ Available | Maps to `monitors[n].id` |
| `hyprctl monitors -j` → `activeWorkspace.id` per monitor | ✅ Available | Per-monitor reactive data |
| `movewindoworworkspace` | ❌ Does not exist | Do not use |

---

## 4. Files to Modify

| File | Changes |
|------|---------|
| `Main.qml` | 1. Update `getVisibleWorkspaces(monitorId)` to use per-monitor active WS 2. Add `workspaceMonitorBindings` computed property 3. Update drop dispatch for cross-monitor |
| `components/OverviewGrid.qml` | 1. Replace `pluginMain.activeWorkspace` with `monitorActiveWorkspace` (lines ~35–51) 2. Add `draggingCrossMonitor`, `draggingTargetMonitorId` properties 3. Add monitor badge rendering in workspace delegate 4. Add migration indicator overlay during drag hover |
| `Settings.qml` | Add `showMonitorIndicators`, `enableCrossMonitorDrag`, `crossMonitorDragStyle` controls |
| `i18n/en.json` | Add translation keys for new settings and badge tooltips |
| `manifest.json` | Bump version to `1.x.0` |

---

## 5. Testing Checklist

- [ ] Each overlay independently navigates based on its own monitor's active workspace
- [ ] Monitor badges appear correctly on workspaces bound to other monitors
- [ ] Drag from workspace on Monitor A → workspace on Monitor B migrates window
- [ ] Migration indicator visible during cross-monitor drag hover
- [ ] Keyboard/scroll navigation works per-overlay independently
- [ ] Works with 3+ monitors
- [ ] Single monitor behavior unchanged
- [ ] `showMonitorIndicators: false` hides badges
- [ ] `enableCrossMonitorDrag: false` prevents migration on drop
- [ ] No regression in existing drag features (inter-workspace move, intra-workspace retile, floating snap)