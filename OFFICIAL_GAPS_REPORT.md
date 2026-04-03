# Official Noctalia Plugins - Gap Analysis Report

## Executive Summary

Your custom plugins have several implementation gaps compared to official noctalia-dev plugin standards. The most critical gaps relate to:

1. **Missing Entry Points** - Not using controlCenterWidget, launcherProvider, desktopWidget
2. **BarWidget Pattern Mismatch** - Using custom BarPill vs standard NIconButton/NIcon patterns  
3. **Settings Persistence Pattern** - Some plugins modify pluginSettings directly in bindings
4. **Translation Gaps** - Hardcoded strings vs pluginApi?.tr() pattern
5. **Registry Status** - (scrolling-overview removed - hypr-overview is superior)

---

## Critical Gaps (Must Fix for Official Submission)

### 1. BarWidget Implementation Pattern

**Official Pattern (Required for PR):**
```qml
// Uses NIconButton (not BarPill)
NIconButton {
  icon: "my-icon"
  onClicked: pluginApi?.togglePanel(screen, this)
}
```

**Your Current Pattern:**
```qml
// Uses BarPill (custom component)
BarPill {
  icon: "layout-dashboard"
  onClicked: pluginApi?.mainInstance?.toggle()
}
```

**Gap Impact:** HIGH - Official plugins use NIcon/NIconButton consistently

**Affected Plugins:** hypr-overview, scrolling-overview, swww-picker, omarchy, homeassistant

### 2. ControlCenterWidget Entry Point

**Gap:** None of your plugins implement `controlCenterWidget` entry point

**Official Standard:** Multi-surface plugins should provide:
- barWidget (bar pill)
- controlCenterWidget (control center button) 
- panel (main UI)

**Example from official/arch-updater:**
```json
"entryPoints": {
  "barWidget": "BarWidget.qml",
  "controlCenterWidget": "ControlCenterWidget.qml",
  "panel": "Panel.qml",
  "launcherProvider": "LauncherProvider.qml"
}
```

**Gap Impact:** MEDIUM - Limits plugin discoverability

### 3. Translation Pattern Violations

**Official Pattern (Strict):**
```qml
// No fallback after tr() - system handles it
text: pluginApi?.tr("widget.label")

// i18n/en.json provides fallbacks
{
  "widget": { "label": "My Widget" }
}
```

**Your Pattern (Inconsistent):**
```qml
// Some use fallback (anti-pattern)
text: pluginApi?.tr("key") ?? "Fallback"

// Some hardcoded strings (not allowed)
tooltipText: "Close Overview"
```

**Official AGENTS.md Rule:** 
> "Do **not** add fallback text after `tr()` calls — the translation system handles missing keys"

**Gap Impact:** HIGH - Breaks i18n consistency

### 4. Settings Access Pattern

**Official Pattern (Required):**
```qml
property var cfg: pluginApi?.pluginSettings || ({})
property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
property string message: cfg.message ?? defaults.message ?? "fallback"
```

**Your Pattern (Mixed):**
```qml
// hypr-overview: getSetting() JS helper
property int gridRows: getSetting("rows", 2)

// swww-picker: ?? chaining  
readonly property var currentMode: pluginApi?.pluginSettings?.mode ?? "static"

// quickshell-screenshot: Custom setSetting helper (non-standard)
function setSetting(key, value) { /* custom logic */ }
```

**Gap Impact:** MEDIUM - Inconsistent but functional

### 5. Settings Persistence Anti-Pattern

**Official Pattern (Required):**
```qml
// Settings.qml
property string editMessage: cfg.message ?? defaults.message ?? ""

NTextInput {
  text: root.editMessage
  onTextChanged: root.editMessage = text  // Buffer locally
}

function saveSettings() {  // Called by shell
  pluginApi.pluginSettings.message = root.editMessage;
  pluginApi.saveSettings();
}
```

**Your Anti-Pattern (scrolling-overview):**
```qml
// Modifies pluginSettings directly in bindings
NSwitch {
  checked: localEnabled
  onCheckedChanged: {
    localEnabled = checked
    pluginApi.pluginSettings["enabled"] = checked  // BAD!
    pluginApi.saveSettings()  // Called on every toggle!
  }
}
```

**Gap Impact:** CRITICAL - Violates official pattern, causes excessive I/O

---

## Medium Priority Gaps

### 6. launcherProvider Entry Point

**Gap:** No plugins implement launcher search provider capability

**Use Case:** Plugins like swww-picker could provide wallpaper search via launcher

**Gap Impact:** LOW - Enhancement opportunity

### 7. IPC Handler Return Types

**Official Pattern:**
```qml
IpcHandler {
  function toggle() { /* void or typed return */ }
  function setMode(mode: string): bool { return success; }
}
```

**Your Pattern:** Most don't specify return types

**Gap Impact:** LOW - Functional but less explicit

### 8. manifest.json Issues

| Issue | Your Plugins | Official Standard |
|-------|-------------|-------------------|
| `official` field | Missing | `"official": true` |
| `id` vs folder | May not match | Must match exactly |
| `repository` URL | Points to anthonyhab | Should be noctalia-dev for PRs |
| Tag usage | Custom tags | Standard tag set only |
| `allowUserSettings` | Present in some | Not in official schema |

**Gap Impact:** HIGH - Blocks official PR acceptance

### 9. Hardcoded Values vs Style Constants

**Official Pattern:**
```qml
anchors.margins: Style.marginL
spacing: Style.marginL
color: Color.mPrimary
```

**Your Pattern (quickshell-screenshot):**
```qml
// Custom Rectangle with hardcoded values
Rectangle {
  color: "#1a1a1a"  // Hardcoded color!
  border.color: "#333"  // Hardcoded!
}
```

**Gap Impact:** MEDIUM - Breaks theming consistency

### 10. Widget ID Tracking

**Official BarWidget Properties (Injected):**
```qml
property var pluginApi: null
property ShellScreen screen
property string widgetId: ""           // MISSING in yours
property string section: ""          // MISSING in yours  
property int sectionWidgetIndex: -1    // MISSING in yours
property int sectionWidgetsCount: 0    // MISSING in yours
```

**Gap Impact:** LOW - May affect multi-widget scenarios

---

## Minor/Style Gaps

### 11. Import Order

**Official:** Consistent import order enforced
```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets
```

### 12. Logging

**Official:** Logger only, never console.log
```qml
Logger.i("PluginId", "Message")
Logger.d("PluginId", "Debug", value)
```

**Your Pattern:** Some console.log usage (quickshell-screenshot)

### 13. Preview Images

**Official Requirement:** 960×540 preview.png for registry

**Your Status:** Not verified if present

---

## Registry Status

| Plugin | In registry.json | Missing Files |
|--------|-----------------|---------------|
| hypr-overview | Yes | preview.png? |
| omarchy | Yes | - |
| bb-auth | Yes | - |
| swww-picker | Yes | - |
| homeassistant | Yes | - |
| scrolling-overview | **NO** | preview.png, needs registry entry |
| quickshell-screenshot | No (utility) | - |
| waybar-converter | No (standalone) | - |

---

## Recommendations by Plugin

### hypr-overview
1. Replace BarPill with NIconButton pattern
2. Add controlCenterWidget entry point
3. Fix hardcoded tooltip strings
4. Verify all strings use pluginApi?.tr()
5. Add missing BarWidget properties (widgetId, section, etc.)

### scrolling-overview
1. **Add to registry.json** (complete but unpublished)
2. Fix Settings.qml direct pluginSettings modification
3. Use official BarWidget pattern
4. Add i18n/en.json translations

### quickshell-screenshot
1. Replace custom Rectangle UI with N* widgets
2. Remove hardcoded colors, use Color.mPrimary
3. Use official settings pattern
4. Replace console.log with Logger
5. Add proper translations

### omarchy
1. Change repository URL to noctalia-dev for PR
2. Verify i18n coverage
3. Add controlCenterWidget

### swww-picker
1. Add launcherProvider for wallpaper search
2. Fix BarWidget pattern
3. Verify translation coverage

### bb-auth
1. Standardize BarWidget pattern
2. Add controlCenterWidget for auth status

### homeassistant
1. Simplify BarWidget (very complex custom scrolling)
2. Standardize to N* widgets

---

## Official Testing Checklist

Before submitting to noctalia-dev/noctalia-plugins:

- [ ] Plugin loads with `qs -c noctalia-shell`
- [ ] Tested with light and dark themes
- [ ] Tested on target compositors (Hyprland)
- [ ] Settings persist across restarts
- [ ] `manifest.json` valid with all required fields
- [ ] `id` matches folder name
- [ ] No `registry.json` in PR (auto-generated)
- [ ] All strings use `pluginApi?.tr()`
- [ ] `saveSettings()` function exposed
- [ ] No hallucinated APIs
- [ ] No `console.log` — use Logger
- [ ] Uses N* widgets, not raw Qt types
- [ ] `preview.png` included (960×540)
- [ ] `README.md` with description and features

---

## Key Official Resources

1. **Study These Official Plugins:**
   - `hello-world` - minimal reference implementation
   - `timer` - complex example with shared state
   - `arch-updater` - comprehensive entry points
   - `screenshot` - clean Settings.qml pattern

2. **Key Documentation:**
   - Official AGENTS.md: https://github.com/noctalia-dev/noctalia-plugins/blob/main/AGENTS.md
   - Plugin docs: https://docs.noctalia.dev/development/plugins/overview/
   - Widget reference: https://github.com/noctalia-dev/noctalia-shell/tree/main/Widgets

---

## Summary: What Needs Immediate Attention

| Priority | Issue | Plugin(s) | Fix Complexity |
|----------|-------|-----------|----------------|
| **CRITICAL** | Settings anti-pattern | scrolling-overview | Easy |
| **HIGH** | Missing registry entry | scrolling-overview | Easy |
| **HIGH** | Translation gaps | All | Medium |
| **HIGH** | BarWidget pattern | All except waybar-converter | Medium |
| **MEDIUM** | controlCenterWidget | All | Medium |
| **MEDIUM** | Hardcoded colors | quickshell-screenshot | Easy |
| **LOW** | Missing widgetId properties | All | Easy |

---

*Report generated: 2026-04-03*
