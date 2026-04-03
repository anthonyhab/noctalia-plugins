# Noctalia Shell Plugin Development - Agent Guidelines

> **Agent-specific reference for developing Noctalia shell plugins.** This document combines project conventions, Qt6/QML best practices, Quickshell patterns, and anti-patterns to avoid.
> 
> **See also:** [docs/REFERENCE.md](docs/REFERENCE.md) for comprehensive API documentation.

---

## Table of Contents

1. [Architecture Principles](#architecture-principles)
2. [Manifest Requirements](#manifest-requirements)
3. [Qt6 QML Best Practices](#qt6-qml-best-practices)
4. [Quickshell Patterns](#quickshell-patterns)
5. [Noctalia-Specific Patterns](#noctalia-specific-patterns)
6. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
7. [Performance Guidelines](#performance-guidelines)
8. [Testing & Verification](#testing--verification)
9. [Commit Discipline](#commit-discipline)

---

## Architecture Principles

### Service-First Design
Noctalia plugins should follow a **service-driven architecture**:

- **Push logic into services**, keep UI declarative
- **Reuse existing `N*` widgets** before creating new ones
- **Never use `Qt5Compat`** — prefer Qt6-native modules like `QtQuick.Effects` with `MultiEffect`

### Plugin Structure
Each plugin is a self-contained directory with:

```
my-plugin/
├── manifest.json          # Plugin metadata (REQUIRED)
├── Main.qml               # Entry point / background logic
├── BarWidget.qml          # Bar widget component (optional)
├── Panel.qml              # Panel component (optional)
├── Settings.qml           # Settings UI (optional)
├── README.md              # Documentation (required for official repo)
├── preview.png            # Preview image (required for official repo)
├── i18n/
│   └── en.json            # English fallback translations
├── components/            # Reusable sub-components
└── helpers/               # Helper QML files and JS libraries
```

### File Purposes

| File | Purpose | Required |
|------|---------|----------|
| `manifest.json` | Plugin metadata, entry points, defaults | **Yes** |
| `Main.qml` | IPC handlers, background logic, state management | No |
| `BarWidget.qml` | Bar display with `BarPill` pattern | No |
| `Panel.qml` | Popup panel UI | No |
| `Settings.qml` | Configuration interface with `NBox` | No |

---

## Manifest Requirements

### Complete Example

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "minNoctaliaVersion": "3.6.0",
  "author": "habibe",
  "license": "MIT",
  "repository": "https://github.com/anthonyhab/noctalia-plugins",
  "description": "Brief explanation (< 100 chars) of functionality.",
  "tags": ["Bar", "System", "Productivity"],
  "entryPoints": {
    "main": "Main.qml",
    "panel": "Panel.qml",
    "barWidget": "BarWidget.qml",
    "settings": "Settings.qml"
  },
  "dependencies": {
    "plugins": []
  },
  "metadata": {
    "defaultSettings": {
      "settingKey": "defaultValue",
      "numericSetting": 42,
      "booleanSetting": true
    }
  }
}
```

### Field Requirements

| Field | Description | Rules |
|-------|-------------|-------|
| `id` | Unique identifier | Lowercase, hyphens only, no spaces |
| `version` | Semantic version | Start at `1.0.0`, follow semver |
| `minNoctaliaVersion` | Compatibility | Use `"3.6.0"` minimum |
| `tags` | Categories | See tag categories below |

### Tag Categories

**Widget Types:** `Bar`, `Desktop`, `Panel`, `Launcher`

**Functional:** `Productivity`, `System`, `Audio`, `Network`, `Privacy`, `Development`, `Fun`, `Gaming`, `Indicator`, `Hyprland`

---

## Qt6 QML Best Practices

### Declarative Over Imperative

**DO:** Use property bindings
```qml
// Good: Declarative binding
Rectangle {
    width: parent.width * 0.5
    height: parent.height * 0.3
    color: enabled ? "green" : "gray"
}
```

**DON'T:** Use imperative property setting in `onCompleted`
```qml
// Bad: Imperative assignment
Component.onCompleted: {
    rect.width = parent.width * 0.5  // Breaks reactivity
}
```

### Prefer Specific Property Types

**DO:** Use concrete types for better engine optimization
```qml
// Good: Concrete types
property int count: 0
property real scale: 1.0
property bool visible: true
property string title: ""
property color bgColor: "#ffffff"
```

**DON'T:** Use `var` for primitive types
```qml
// Bad: var prevents optimization
property var count: 0
property var scale: 1.0
```

### QML Syntax Rules

**NO SEMICOLONS** on property declarations:
```qml
// Correct
property int value: 42

// Incorrect
property int value: 42;
```

**NO CONVERSION ONE-LINERS:** Avoid collapsing complex objects into single lines.

### Component Lifecycle

**DO:** Use `Component.onCompleted` for initialization, `Component.onDestruction` for cleanup
```qml
Item {
    Component.onCompleted: {
        Logger.i("MyPlugin", "Component initialized")
        refreshData()
    }
    
    Component.onDestruction: {
        // Cleanup timers, connections, etc.
        refreshTimer.stop()
    }
}
```

### Signal Handlers

**DO:** Use specific interaction signals
```qml
// Good: Only triggers on user interaction
Slider {
    onMoved: value => { /* handle change */ }
}

// Avoid: Triggers on any value change including programmatic
Slider {
    onValueChanged: { /* might fire unexpectedly */ }
}
```

---

## Quickshell Patterns

### Process Execution

**Pattern: Shell Command with Output**
```qml
import Quickshell.Io

Process {
    id: hyprctlProcess
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {}
    
    onExited: exitCode => {
        if (exitCode === 0) {
            var data = JSON.parse(stdout.text)
            // Process data
        }
    }
}

// Trigger execution
function refreshData() {
    hyprctlProcess.running = true
}
```

**Pattern: Fire-and-Forget Command**
```qml
// No need for Process component
function sendCommand() {
    Quickshell.execDetached(["notify-send", "Hello", "World"])
}
```

**Pattern: Debounced Refresh**
```qml
Timer {
    id: debounceTimer
    interval: 40  // 40ms debounce
    onTriggered: executeRefresh()
}

function queueRefresh() {
    debounceTimer.restart()
}
```

### File Monitoring

```qml
import Quickshell.Io

FileView {
    id: configFile
    path: `${Quickshell.env("HOME")}/.config/myapp/config.json`
    watchChanges: true
    
    onLoaded: {
        var data = JSON.parse(text())
        root.config = data
    }
    
    onFileChanged: reload()
}
```

### Hyprland Integration

**Reactive Data Model (Preferred):**
```qml
import Quickshell.Hyprland

Item {
    // These are live models that update automatically
    property var monitors: Hyprland.monitors
    property var workspaces: Hyprland.workspaces
    property var windows: Hyprland.toplevels
    
    // Dispatch commands
    function switchToWorkspace(id) {
        Hyprland.dispatch(`workspace ${id}`)
    }
}
```

**Manual Hyprctl (When Needed):**
```qml
// For data not available in reactive models
Process {
    id: hyprctl
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {}
    
    onExited: exitCode => {
        if (exitCode === 0) {
            root.activeWindow = JSON.parse(stdout.text)
        }
    }
}
```

### IPC Handler Registration

```qml
import Quickshell

IpcHandler {
    target: `plugin:${pluginApi?.manifest?.id || "my-plugin"}`
    
    function toggle(): string {
        root.open ? close() : open()
        return "ok"
    }
    
    function setValue(key: string, value: string): string {
        root.settings[key] = value
        return "ok"
    }
    
    function getState(): string {
        return JSON.stringify({
            open: root.open,
            count: root.itemCount
        })
    }
}
```

### Window/Panel Management

```qml
PanelWindow {
    anchor: Edges.Top | Edges.Left | Edges.Right | Edges.Bottom
    exclusionMode: ExclusionMode.Ignore
    
    // Full-screen overlay
    width: screen.width
    height: screen.height
    
    // Close on escape
    Keyboard {
        focusItem: root
        onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close()
            }
        }
    }
}
```

---

## Noctalia-Specific Patterns

### pluginApi Contract

All entry points receive `pluginApi` injection:

```qml
Item {
    property var pluginApi: null  // Must be declared first
    
    // Safe access pattern
    readonly property var mySetting: {
        if (!pluginApi?.pluginSettings) return defaultValue
        return pluginApi.pluginSettings["myKey"] ?? defaultValue
    }
}
```

### Settings Access Pattern

**Centralized Getter Function:**
```qml
// In Main.qml or shared helper
function getSetting(key, fallback = null) {
    if (!pluginApi?.pluginSettings) return fallback
    var val = pluginApi.pluginSettings[key]
    return (val === undefined || val === null) ? fallback : val
}

// Usage
property int gridRows: getSetting("rows", 2)
property real gridScale: getSetting("scale", 0.16)
```

### BarWidget Pattern

Uses `NIconButton` (not `BarPill`) with required injected properties:

```qml
import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    
    readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
    
    implicitWidth: isVertical ? capsuleHeight : button.implicitWidth
    implicitHeight: isVertical ? contentHeight : capsuleHeight
    
    NIconButton {
        id: button
        anchors.centerIn: parent
        implicitWidth: capsuleHeight
        implicitHeight: capsuleHeight
        icon: "layout-dashboard"
        tooltipText: pluginApi?.tr("widget.tooltip")  // NO FALLBACK - use i18n/en.json
        onClicked: pluginApi?.togglePanel(root.screen, button)
    }
}
```

#### NIconButton Properties (Common Pitfalls)

| Property | Type | Purpose | Common Error |
|----------|------|---------|--------------|
| `icon` | string | Tabler icon name | - |
| `tooltipText` | string | Hover tooltip | Using `??` fallback (DON'T) |
| `colorFg` | color | Icon color | Using `iconColor` (WRONG - doesn't exist) |
| `colorBg` | color | Background color | - |
| `onClicked` | function | Click handler | - |
| `onRightClicked` | function | Right-click handler | Use for context menu |

**CRITICAL:** The property is `colorFg` NOT `iconColor`. Subagents often hallucinate `iconColor` which causes:
```
ERROR: Cannot assign to non-existent property "iconColor"
```

**CRITICAL:** Do NOT use fallbacks with `tr()`:
```qml
// WRONG - fallback defeats translation system
tooltipText: pluginApi?.tr("widget.tooltip") ?? "Fallback"

// CORRECT - translation system handles missing keys
tooltipText: pluginApi?.tr("widget.tooltip")
```
### Settings UI Pattern

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    property var pluginApi: null
    
    // Local state (buffered)
    property int localRows: 2
    property bool localEnabled: true
    
    // Sync from plugin on load
    function syncFromPlugin() {
        var settings = pluginApi?.pluginSettings ?? {}
        var defaults = pluginApi?.manifest?.metadata?.defaultSettings ?? {}
        
        localRows = settings["rows"] ?? defaults["rows"] ?? 2
        localEnabled = settings["enabled"] ?? defaults["enabled"] ?? true
    }
    
    // Save to plugin
    function saveSettings() {
        if (!pluginApi) return
        
        pluginApi.pluginSettings["rows"] = localRows
        pluginApi.pluginSettings["enabled"] = localEnabled
        pluginApi.saveSettings()
        
        Logger.i("MyPlugin", "Settings saved")
    }
    
    Component.onCompleted: syncFromPlugin()
    
    // UI Components
    NBox {
        Layout.fillWidth: true
        title: "Grid Configuration"
        
        content: ColumnLayout {
            NSpinBox {
                label: "Rows"
                value: localRows
                onValueModified: val => localRows = val
            }
            
            NSwitch {
                label: "Enabled"
                checked: localEnabled
                onCheckedChanged: localEnabled = checked
            }
        }
    }
    
    NButton {
        text: "Save"
        onClicked: saveSettings()
    }
}
```

### Translation Pattern

```qml
// Always provide fallback
property string labelText: pluginApi?.tr("settings.rows.label") ?? "Rows"
property string tooltipText: pluginApi?.tr("settings.rows.tooltip") ?? "Number of rows in grid"

// i18n/en.json
{
  "settings": {
    "rows": {
      "label": "Rows",
      "tooltip": "Number of rows in the grid layout"
    }
  }
}
```

### Logging Pattern

```qml
import qs.Commons

Logger.d("MyPlugin", "Debug message", someValue)     // Debug only with NOCTALIA_DEBUG=1
Logger.i("MyPlugin", "Info message")                 // Always visible
Logger.w("MyPlugin", "Warning message")                // Warnings
Logger.e("MyPlugin", "Error occurred", error)        // Errors
```

### Drag and Drop Pattern

```qml
// Draggable item
Rectangle {
    id: dragItem
    
    MouseArea {
        anchors.fill: parent
        drag.target: dragHandle
        
        onPressed: {
            root.draggingWindowAddress = windowAddress
            root.draggingFromWorkspace = workspaceId
        }
        
        onReleased: {
            if (root.draggingToWorkspace !== -1) {
                moveWindowToWorkspace(windowAddress, root.draggingToWorkspace)
            }
            root.draggingWindowAddress = ""
            root.draggingFromWorkspace = -1
            root.draggingToWorkspace = -1
        }
    }
    
    Drag.active: mouseArea.drag.active
    Drag.hotSpot: Qt.point(width / 2, height / 2)
}

// Drop target
Rectangle {
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        
        onEntered: {
            if (root.draggingWindowAddress !== "") {
                root.draggingToWorkspace = workspaceId
            }
        }
    }
}
```

---

## Anti-Patterns to Avoid

### 1. Storing State in Delegates

**DON'T:** Store per-item state in ListView/GridView delegates
```qml
// Bad: State lost on delegate recycling
ListView {
    model: myModel
    delegate: Rectangle {
        property bool isExpanded: false  // Lost on scroll!
        
        MouseArea {
            onClicked: isExpanded = !isExpanded
        }
    }
}
```

**DO:** Store state in the model
```qml
// Good: State persisted in model
ListView {
    model: myModel  // Each item has isExpanded property
    delegate: Rectangle {
        property bool expanded: model.isExpanded
        
        MouseArea {
            onClicked: model.isExpanded = !model.isExpanded
        }
    }
}
```

### 2. Manual Event Loops

**NEVER** call `QCoreApplication::processEvents()` or create `QEventLoop` in QML.

### 3. Heavy Delegates

**DON'T:** Create complex layouts in ListView/GridView delegates
```qml
// Bad: Heavy delegate kills scroll performance
ListView {
    delegate: ColumnLayout {  // Nested layouts per item
        RowLayout {
            Rectangle { /* ... */ }
            Rectangle { /* ... */ }
        }
        Loader { /* ... */ }    // Loaders inside delegates
    }
}
```

**DO:** Keep delegates lightweight, use simple items
```qml
// Good: Simple delegate
ListView {
    delegate: Rectangle {
        width: ListView.view.width
        height: 40
        Text { text: model.title }
    }
}
```

### 4. Duplicate Bindings

**DON'T:** Attach multiple bindings to the same property
```qml
// Bad: Multiple bindings on same property
Rectangle {
    width: condition1 ? 100 : 200
    width: condition2 ? 150 : 250  // Overwrites previous!
}
```

**DO:** Use single comprehensive binding
```qml
// Good: Single binding with all conditions
Rectangle {
    width: {
        if (condition2) return 150
        if (condition1) return 100
        return 200
    }
}
```

### 5. Race Conditions with Settings

**DON'T:** Assume settings are available immediately
```qml
// Bad: Might be undefined
Component.onCompleted: {
    var val = pluginApi.pluginSettings["key"]  // Could be undefined!
    useValue(val)  // Might crash
}
```

**DO:** Use defensive checks and defaults
```qml
// Good: Safe access with fallback
Component.onCompleted: {
    var val = pluginApi?.pluginSettings?.["key"] ?? defaultValue
    useValue(val)
}
```

### 6. Arbitrary Delays

**DON'T:** Use arbitrary timers for race conditions
```qml
// Bad: Race condition "fix"
Timer {
    interval: 100  // "Should be enough"
    onTriggered: initialize()
}
```

**DO:** Use proper signals
```qml
// Good: Wait for actual ready signal
Connections {
    target: pluginApi
    function onReadyChanged() {
        if (pluginApi.ready) initialize()
    }
}
```

### 7. Undefined Property Access

**DON'T:** Chain property access without null checks
```qml
// Bad: Throws if any property is null
property var value: root.pluginApi.pluginSettings.key
```

**DO:** Use optional chaining and fallbacks
```qml
// Good: Safe property access
property var value: root.pluginApi?.pluginSettings?.key ?? defaultValue
```

---

## Performance Guidelines

### Frame Budget

Target **60 FPS (16ms per frame)**. Any work taking longer drops frames.

### Lazy Loading

Use `Loader` for components not immediately visible:

```qml
// Lazy load heavy panel content
Loader {
    active: root.panelOpen
    sourceComponent: PanelContent {
        // Heavy UI here only loaded when needed
    }
}
```

### Timer Intervals

Common intervals and their purposes:

| Interval | Use Case |
|----------|----------|
| 16-33ms | Animations (60-30 FPS) |
| 40ms | UI refresh debounce |
| 100-200ms | Rapid data polling |
| 1000ms+ | Infrequent updates |

### Process Execution

**DO:** Debounce rapid hyprctl calls
```qml
property bool pendingRefresh: false

function queueRefresh() {
    if (pendingRefresh) return
    pendingRefresh = true
    refreshTimer.start()
}

Timer {
    id: refreshTimer
    interval: 40
    onTriggered: {
        pendingRefresh = false
        executeRefresh()
    }
}
```

**DON'T:** Run unbounded timers
```qml
// Bad: Timer runs forever
Timer {
    running: true
    repeat: true
    interval: 16  // Every frame - expensive!
}
```

---

## Testing & Verification

### Pre-Commit Checklist

Before committing any plugin changes:

1. **Visual test** the UI in Noctalia Shell
2. Verify **manifest** has all required fields
3. Check `registry.json` is updated if version was bumped
4. Run through all affected user flows
5. Test **settings persistence** and defaults
6. Verify **translations** load correctly

### Linting

Always run on modified QML files:

```bash
qmllint path/to/file.qml
qmlformat -i path/to/file.qml  # Auto-format
```

### Testing Commands

```bash
# Test IPC handler
qs ipc call plugin:my-plugin toggle

# Debug mode
NOCTALIA_DEBUG=1 qs -c noctalia-shell

# Hot reload during development
NOCTALIA_DEBUG=1 qs -c noctalia-shell --no-duplicate
```

---

## Commit Discipline

### Version Bumping

Version numbers follow semantic versioning:

- **Patch (0.0.x)**: Bug fixes, UI/alignment fixes, typos
- **Minor (0.x.0)**: New features, new settings, behavior changes
- **Major (x.0.0)**: Breaking API changes

**Critical Rules:**
- **Only bump versions when pushing** - not during development
- Commits get squashed before release, so bump once at the end
- Never skip version numbers (0.1.0 → 0.1.1, not 0.1.2)
- Always update `registry.json` when bumping manifest version
- Version bump should be part of the final squashed commit

### Commit Message Rules

- **NEVER push before I tell you to** - wait for explicit approval
- Keep commits tight and manageable for verification
- Never mention which agent is being used in commit messages
- One logical change per commit
- Test before commit to avoid rapid-fire fix commits
- If fixing a fix within minutes, squash or amend instead

---

## Quick Reference

### Common Imports

```qml
// Qt6 Core
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Quickshell
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

// Noctalia
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
```

### Standard Properties

```qml
// All entry points must declare
property var pluginApi: null

// BarWidget specific
property ShellScreen screen
property string widgetId: ""

// Settings specific
property string section: ""
property int sectionWidgetIndex: -1
property int sectionWidgetsCount: 0
```

### Entry Point Signatures

```qml
// Main.qml - Root item with IPC
Item {
    property var pluginApi: null
    
    IpcHandler {
        target: `plugin:${pluginApi?.manifest?.id || "default"}`
        function toggle(): string { /* ... */ }
    }
}

// BarWidget.qml - Bar display
Item {
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    
    implicitWidth: pill.width
    implicitHeight: pill.height
}

// Settings.qml - Configuration UI
ColumnLayout {
    property var pluginApi: null
    // ... settings controls
}
```

---

## Common AI Mistakes

These are the most frequent issues in AI-generated plugin code:

### 1. Hallucinated NIconButton Properties

**WRONG:** Using `iconColor`
```qml
NIconButton {
    iconColor: Color.mPrimary  // ERROR: property doesn't exist!
}
```

**CORRECT:** Use `colorFg`
```qml
NIconButton {
    colorFg: Color.mPrimary  // Correct property name
}
```

### 2. Translation Fallback Anti-Pattern

**WRONG:** Adding fallback after `tr()`
```qml
tooltipText: pluginApi?.tr("widget.tooltip") ?? "Fallback"
```

**CORRECT:** Let translation system handle it
```qml
tooltipText: pluginApi?.tr("widget.tooltip")  // System returns key if missing
```

### 3. Using Deprecated BarPill Component

**WRONG:** Using custom BarPill
```qml
BarPill {  // Old custom component
    icon: "..."
}
```

**CORRECT:** Use NIconButton
```qml
NIconButton {  // Official widget
    icon: "..."
}
```

### 4. Missing BarWidget Properties

**WRONG:** Incomplete property list
```qml
Item {
    property var pluginApi: null
    property ShellScreen screen
    // Missing: widgetId, section, sectionWidgetIndex, sectionWidgetsCount!
}
```

**CORRECT:** All required properties
```qml
Item {
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
}
```

### 5. Hardcoded Strings

**WRONG:** Direct text in UI
```qml
tooltipText: "Close Overview"  // Not translatable!
```

**CORRECT:** Use translation keys
```qml
tooltipText: pluginApi?.tr("actions.close")
```

### 6. Console Instead of Logger

**WRONG:** Using console.log
```qml
console.log("Debug message")  // Don't use!
```

**CORRECT:** Use Logger
```qml
Logger.d("PluginId", "Debug message")  // Correct
```

---

## Resources

- **Noctalia Documentation:** https://docs.noctalia.dev/development/guideline/
- **Qt6 QML Best Practices:** https://doc.qt.io/qt-6/qtquick-bestpractices.html
- **Quickshell Documentation:** https://quickshell.org/
- **Project docs:** [docs/REFERENCE.md](docs/REFERENCE.md)

---

*Last updated: 2026-04-03*