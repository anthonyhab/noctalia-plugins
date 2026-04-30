# Plugin Consistency Audit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **Phase order is STRICT.** Do not begin Phase N+1 until Phase N is fully complete and committed.

**Goal:** Eliminate anti-patterns, hardcoded strings, and inconsistent settings patterns across all 6 plugins so they behave as a cohesive family aligned with Noctalia upstream best practices.

**Architecture:**
- Phase 1 fixes runtime anti-patterns (Logger misuse, translation fallback bugs, missing reactive sync).
- Phase 2 centralizes i18n by removing hardcoded English strings and updating `en.json` fallbacks.
- Phase 3 standardizes Settings.qml layout math and state-sync patterns.
- Phase 4 polishes BarWidget vertical-bar support and settings save UX.

**Tech Stack:** QML (Quickshell / Qt6), Noctalia Shell plugin APIs, JSON i18n

**Plugins affected:** `bb-auth`, `homeassistant`, `hypr-overview`, `omarchy`, `quickshell-screenshot`, `swww-picker`

---

## Phase 1: Critical Anti-Patterns

> **Pre-condition:** Run `qmllint` on all modified files after each task.
> **Commit rule:** One commit per task. No batching.

### Task 1.1: Replace `console.*` with `Logger` in `hypr-overview`

**Files:**
- Modify: `hypr-overview/components/LayoutSwitcher.qml:107`
- Modify: `hypr-overview/components/LayoutSwitcher.qml:114`
- Modify: `hypr-overview/helpers/HyprlandConfig.qml:216`
- Modify: `hypr-overview/helpers/HyprlandConfig.qml:268`

**Context:** `Logger` is available via `import qs.Commons` in all Noctalia plugins. `console.log` and `console.warn` bypass the shell's log filtering.

- [ ] **Step 1: Fix LayoutSwitcher.qml**

  Replace:
  ```qml
  console.warn("WorkspaceOverview switchLayout stderr:", text.trim());
  ```
  with:
  ```qml
  Logger.w("HyprOverview", "switchLayout stderr:", text.trim())
  ```

  Replace:
  ```qml
  console.log("WorkspaceOverview switchLayout:", text.trim());
  ```
  with:
  ```qml
  Logger.i("HyprOverview", "switchLayout:", text.trim())
  ```

- [ ] **Step 2: Fix HyprlandConfig.qml**

  Replace:
  ```qml
  console.warn("HyprlandConfig: fetchOption parse error", e);
  ```
  with:
  ```qml
  Logger.w("HyprOverview", "fetchOption parse error:", e)
  ```

  Replace:
  ```qml
  console.warn("HyprlandConfig: scroll directions parse error", e);
  ```
  with:
  ```qml
  Logger.w("HyprOverview", "scroll directions parse error:", e)
  ```

- [ ] **Step 3: Verify**

  Run: `qmllint hypr-overview/components/LayoutSwitcher.qml && qmllint hypr-overview/helpers/HyprlandConfig.qml`
  Expected: No errors.

- [ ] **Step 4: Commit**

  ```bash
  git add hypr-overview/components/LayoutSwitcher.qml hypr-overview/helpers/HyprlandConfig.qml
  git commit -m "fix(hypr-overview): replace console.* with Logger per AGENTS.md"
  ```

---

### Task 1.2: Remove `|| "fallback"` anti-pattern from `homeassistant` Settings.qml

**Files:**
- Modify: `homeassistant/Settings.qml` (multiple lines)

**Context:** Per AGENTS.md: "Do NOT use fallbacks with `tr()`." The translation system returns the key itself if missing, making `||` redundant and masking missing keys.

**Lines to change:**
- Line 64: `|| "Please configure URL and token"`
- Line 79: `|| "Connected successfully"`
- Line 82: `|| "Invalid access token"`
- Line 85, 93: `|| "Connection failed"`
- Line 112: `|| "Appearance"`
- Line 118: `|| "Connection"`
- Line 137: `|| "Bar widget"`
- Line 145: `|| "Adjust how the bar widget displays long titles."`
- Line 153: `|| "Maximum width"`
- Line 154: `|| "Sets the maximum horizontal size..."`
- Line 163: `|| "Use fixed width"`
- Line 164: `|| "When enabled, the widget will always..."`
- Line 171: `|| "Scrolling mode"`
- Line 172: `|| "Control when text scrolling is enabled..."`
- Line 177: `|| "Always scroll"`
- Line 181: `|| "Scroll on hover"`
- Line 185: `|| "Never scroll"`
- Line 198: `|| "Panel settings"`
- Line 206: `|| "Show volume percentage"`
- Line 207: `|| "Display the volume percentage..."`
- Line 220: `|| "Connect to your Home Assistant..."`
- Line 227: `|| "Create a Long-Lived Access Token..."`
- Line 235: `|| "Home Assistant URL"`
- Line 236: `|| "http://homeassistant.local:8123"`
- Line 245: `|| "Access Token"`
- Line 260: `|| "Connecting..."` and `|| "Test Connection"`
- Line 265: `|| "No media players found"`
- Line 279: `|| "Default Media Player"`
- Line 285: `|| "Select the media player to control by default."`
- Line 303: `|| "No media players found"` (inside model)

- [ ] **Step 1: Remove all `|| "..."` fallbacks after `tr()` calls**

  Pattern: change `pluginApi?.tr("key") || "Fallback"` → `pluginApi?.tr("key")`

  For model arrays (lines 174-186), change:
  ```qml
  { "key": "always", "name": pluginApi?.tr("options.scrolling-modes.always") || "Always scroll" }
  ```
  to:
  ```qml
  { "key": "always", "name": pluginApi?.tr("options.scrolling-modes.always") }
  ```

- [ ] **Step 2: Verify**

  Run: `qmllint homeassistant/Settings.qml`
  Expected: No errors.

- [ ] **Step 3: Commit**

  ```bash
  git add homeassistant/Settings.qml
  git commit -m "fix(homeassistant): remove translation fallback anti-pattern per AGENTS.md"
  ```

---

### Task 1.3: Remove `|| "fallback"` anti-pattern from `swww-picker` Settings.qml

**Files:**
- Modify: `swww-picker/Settings.qml` (multiple lines)

**Lines to change:**
- Line 87: `|| "Configure wallpaper cycling with awww."`
- Line 94: `|| "Wallpapers directory"`
- Line 95: `|| "Path to the directory containing..."`
- Line 107: `|| "Auto-cycle"`
- Line 114: `|| "Enable auto-cycling"`
- Line 115: `|| "Automatically change wallpaper..."`
- Line 121: `|| "Interval (minutes)"`
- Line 122: `|| "How often to change the wallpaper..."`
- Line 131: `|| "Shuffle mode"`
- Line 132: `|| "Pick random wallpapers instead..."`
- Line 143: `|| "Transitions"`
- Line 151: `|| "Transition type"`
- Line 176: `|| "Duration (seconds)"`
- Line 185: `|| "FPS"`
- Line 194: `|| "Step"`
- Line 208: `|| "Easing Curve"`
- Line 215: `|| "Controls animation acceleration..."`
- Line 227: `|| "Snappy"`
- Line 233: `|| "Natural"`
- Line 239: `|| "Linear"`
- Line 247: `|| "Custom bezier"`
- Line 248: `|| "Animation easing curve in format..."`
- Line 260: `|| "Bar widget"`
- Line 267: `|| "Show wallpaper name"`
- Line 268: `|| "Display the current wallpaper filename..."`
- Line 283: `|| "Status"`
- Line 295: `|| "awww daemon running"`
- Line 296: `|| "awww daemon not running"`
- Line 297: `|| "wallpapers"`
- Line 305: `|| "Refresh"`
- All model name entries (lines 153-164): `|| "Simple fade"`, etc.

- [ ] **Step 1: Remove all `|| "..."` fallbacks after `tr()` calls**

- [ ] **Step 2: Verify**

  Run: `qmllint swww-picker/Settings.qml`
  Expected: No errors.

- [ ] **Step 3: Commit**

  ```bash
  git add swww-picker/Settings.qml
  git commit -m "fix(swww-picker): remove translation fallback anti-pattern per AGENTS.md"
  ```

---

### Task 1.4: Add reactive `onPluginSettingsChanged` listener to `homeassistant` Settings.qml

**Files:**
- Modify: `homeassistant/Settings.qml`

**Context:** Settings values are bound directly to `pluginApi.pluginSettings` at component load (lines 18-24). If settings change externally (e.g., another instance edits them), the UI won't update. The standard pattern is a `syncFromPlugin()` function + `Connections` listener.

- [ ] **Step 1: Add `syncFromPlugin()` function**

  After the existing property declarations (before `Component.onCompleted`), add:
  ```qml
  function syncFromPlugin() {
    if (!pluginApi) return;
    valueHaUrl = pluginApi?.pluginSettings?.haUrl || pluginApi?.manifest?.metadata?.defaultSettings?.haUrl || "";
    valueHaToken = pluginApi?.pluginSettings?.haToken || pluginApi?.manifest?.metadata?.defaultSettings?.haToken || "";
    valueDefaultMediaPlayer = pluginApi?.pluginSettings?.defaultMediaPlayer || pluginApi?.manifest?.metadata?.defaultSettings?.defaultMediaPlayer || "";
    valueBarWidgetMaxWidth = (pluginApi?.pluginSettings?.barWidgetMaxWidth ?? pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetMaxWidth ?? 200).toString();
    valueBarWidgetUseFixedWidth = pluginApi?.pluginSettings?.barWidgetUseFixedWidth ?? pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetUseFixedWidth ?? false;
    valueBarWidgetScrollingMode = pluginApi?.pluginSettings?.barWidgetScrollingMode || pluginApi?.manifest?.metadata?.defaultSettings?.barWidgetScrollingMode || "hover";
    valueShowVolumePercentage = pluginApi?.pluginSettings?.showVolumePercentage ?? pluginApi?.manifest?.metadata?.defaultSettings?.showVolumePercentage ?? false;
  }
  ```

- [ ] **Step 2: Add `Connections` listener**

  After the existing `Component.onCompleted` block, add:
  ```qml
  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      syncFromPlugin();
    }
  }
  ```

- [ ] **Step 3: Replace inline property bindings with plain properties**

  Change lines 18-24 from:
  ```qml
  property string valueHaUrl: pluginApi?.pluginSettings?.haUrl || ...
  ```
  to:
  ```qml
  property string valueHaUrl: ""
  ```
  (Do this for all 7 settings properties.)

  Then call `syncFromPlugin()` in `Component.onCompleted`.

- [ ] **Step 4: Verify**

  Run: `qmllint homeassistant/Settings.qml`
  Expected: No errors.

- [ ] **Step 5: Commit**

  ```bash
  git add homeassistant/Settings.qml
  git commit -m "fix(homeassistant): add reactive settings sync with onPluginSettingsChanged"
  ```

---

### Task 1.5: Add reactive `onPluginSettingsChanged` listener to `swww-picker` Settings.qml

**Files:**
- Modify: `swww-picker/Settings.qml`

**Context:** Already has `syncFromPlugin()` but is missing the `Connections` listener that reacts to external settings changes.

- [ ] **Step 1: Add `Connections` listener**

  After the existing `Component.onCompleted: syncFromPlugin()` line, add:
  ```qml
  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      syncFromPlugin();
    }
  }
  ```

- [ ] **Step 2: Verify**

  Run: `qmllint swww-picker/Settings.qml`
  Expected: No errors.

- [ ] **Step 3: Commit**

  ```bash
  git add swww-picker/Settings.qml
  git commit -m "fix(swww-picker): add reactive settings sync with onPluginSettingsChanged"
  ```

---

## Phase 2: i18n Completeness

> **Pre-condition:** Phase 1 is fully committed.
> **Commit rule:** One commit per plugin (combine Settings.qml + en.json changes).

### Task 2.1: Extract hardcoded strings in `omarchy` Settings.qml → i18n keys

**Files:**
- Modify: `omarchy/Settings.qml`
- Modify: `omarchy/i18n/en.json`

**Hardcoded strings to extract:**
- Line 208: `"Plugin controls"` → `tr("settings.controls.title", "Plugin controls")`
- Line 216: `"Omarchy detected · "` / `"Active"` / `"Inactive"` → combine into `tr("status.format", "{detected} · {state}")` with args
- Line 297: `"Time-based Theme Filtering"` → `tr("settings.time-filtering.title", "Time-based Theme Filtering")`
- Line 305: `"Automatically filter themes based on time of day..."` → `tr("settings.time-filtering.desc", ...)`
- Line 380: `"Configure Omarchy integration."` → already wrapped but verify key exists in en.json
- Line 387: `"Set the executable and config directory Omarchy should use."` → add key
- Line 409: `"Omarchy config dir"` → already wrapped but verify

Also check status texts (lines 223-229):
- `"Disconnected from auth daemon"` → wait, that's bb-auth. For omarchy:
- Status texts in the NText block around line 216-230.

- [ ] **Step 1: Identify all remaining hardcoded strings**

  Search: `grep -n '"[A-Z]' omarchy/Settings.qml`
  Document each one and assign a `tr("settings...")` key.

- [ ] **Step 2: Replace each hardcoded string with `tr()` call**

- [ ] **Step 3: Add missing keys to `omarchy/i18n/en.json`**

- [ ] **Step 4: Verify**

  Run: `qmllint omarchy/Settings.qml`
  Check JSON validity: `python3 -m json.tool omarchy/i18n/en.json`

- [ ] **Step 5: Commit**

  ```bash
  git add omarchy/Settings.qml omarchy/i18n/en.json
  git commit -m "i18n(omarchy): extract hardcoded settings strings to translation keys"
  ```

---

### Task 2.2: Extract hardcoded strings in `bb-auth` Settings.qml → i18n keys

**Files:**
- Modify: `bb-auth/Settings.qml`
- Modify: `bb-auth/i18n/en.json`

**Hardcoded strings to extract:**
- Line 116: `"Dialog behavior"` → `tr("settings.dialog-behavior.title")`
- Line 123: `"Configure how the authentication dialog appears and behaves."` → `tr("settings.dialog-behavior.desc")`
- Line 193: `"Status"` → `tr("settings.status.title")`
- Lines 224-229: Status texts:
  - `"Disconnected from auth daemon"` → `tr("status.disconnected")`
  - `"Negotiating with auth daemon"` → `tr("status.negotiating")`
  - `"Active — ready to handle requests"` → `tr("status.active")`
  - `"Standby — another agent is active"` → `tr("status.standby")`
- Line 242: `"Conflict policy: "` → `tr("settings.conflict-policy")`
- Line 260: `"About"` → `tr("settings.about.title")`

- [ ] **Step 1: Replace all hardcoded strings with `tr()` calls**

- [ ] **Step 2: Add missing keys to `bb-auth/i18n/en.json`**

- [ ] **Step 3: Verify**

  Run: `qmllint bb-auth/Settings.qml && python3 -m json.tool bb-auth/i18n/en.json`

- [ ] **Step 4: Commit**

  ```bash
  git add bb-auth/Settings.qml bb-auth/i18n/en.json
  git commit -m "i18n(bb-auth): extract hardcoded settings strings to translation keys"
  ```

---

### Task 2.3: Extract hardcoded strings in `hypr-overview` Settings.qml → i18n keys

**Files:**
- Modify: `hypr-overview/Settings.qml`
- Modify: `hypr-overview/i18n/en.json`

**Hardcoded strings to extract:**
- Line 326 helper: `"S"` fallback for special workspace char — already has `tr("...", "S")`, acceptable
- Lines 335, 434-438: helper functions returning English strings for tooltip generation
  - `"Untitled"` → already wrapped
  - `"Special: "` → should be `tr("overview.tooltip.special-prefix", "Special: ")`
  - `"Workspace "` → `tr("overview.tooltip.workspace-prefix", "Workspace ")`
  - `" (active)"` → `tr("overview.tooltip.active-suffix", " (active)")`
  - `"special"` → `tr("overview.tooltip.special", "special")`
- Check Settings tab headers (lines 888-918) — already wrapped with `tr()` + fallback
- Check any remaining `"text": "source = ~/.config/hypr/..."` — code hint, probably OK to leave hardcoded

- [ ] **Step 1: Audit all raw string literals in Settings.qml**

  Search: `grep -n '"[A-Z][a-z]' hypr-overview/Settings.qml | grep -v tr(`
  Document each.

- [ ] **Step 2: Replace with `tr()` where user-facing**

- [ ] **Step 3: Update `hypr-overview/i18n/en.json`**

- [ ] **Step 4: Commit**

  ```bash
  git add hypr-overview/Settings.qml hypr-overview/i18n/en.json
  git commit -m "i18n(hypr-overview): extract hardcoded settings strings to translation keys"
  ```

---

## Phase 3: Settings Layout Standardization

> **Pre-condition:** Phase 2 is fully committed.

### Task 3.1: Standardize `Layout.preferredWidth` across all Settings.qml

**Files:**
- Modify: `homeassistant/Settings.qml`
- Reference: `omarchy/Settings.qml` (the canonical pattern)

**Canonical pattern (from omarchy):**
```qml
FontMetrics {
  id: appFontMetrics
  font: Qt.application.font
}
readonly property int basePreferredWidth: Math.round(520 * Style.uiScaleRatio)
readonly property int fontSafePreferredWidth: Math.round(appFontMetrics.averageCharacterWidth * 56 + Style.marginL * 2)
Layout.preferredWidth: Math.max(basePreferredWidth, fontSafePreferredWidth)
```

**What to fix:**
- `homeassistant/Settings.qml` lines 14-15: uses fixed `520 * Style.uiScaleRatio` without font-safe calculation.
- `swww-picker/Settings.qml` lines 13-16: same fixed width.
- `quickshell-screenshot/Settings.qml` lines 21-24: same fixed width.
- `bb-auth/Settings.qml` lines 12, 78-80: already has the pattern — use as reference.

- [ ] **Step 1: Apply canonical width pattern to `homeassistant/Settings.qml`**

  Add `FontMetrics` block and update `Layout.preferredWidth`.

- [ ] **Step 2: Apply canonical width pattern to `swww-picker/Settings.qml`**

- [ ] **Step 3: Apply canonical width pattern to `quickshell-screenshot/Settings.qml`**

- [ ] **Step 4: Verify all four**

  Run: `qmllint homeassistant/Settings.qml swww-picker/Settings.qml quickshell-screenshot/Settings.qml`

- [ ] **Step 5: Commit**

  ```bash
  git add homeassistant/Settings.qml swww-picker/Settings.qml quickshell-screenshot/Settings.qml
  git commit -m "style(settings): standardize Layout.preferredWidth with font-safe calculation"
  ```

---

### Task 3.2: Standardize `syncFromPlugin` / `saveSettings` signatures

**Files:**
- Modify: `homeassistant/Settings.qml`
- Modify: `quickshell-screenshot/Settings.qml`
- Reference: `omarchy/Settings.qml`, `bb-auth/Settings.qml`

**Standard pattern checklist:**
1. `function syncFromPlugin()` guards with `if (!pluginApi) return`
2. Sets `isLoading = true` at start, `isLoading = false` at end
3. All properties initialized from `getSetting(key, default)` helper
4. `Connections { target: pluginApi; function onPluginSettingsChanged() { syncFromPlugin() } }` present
5. `onPluginApiChanged: syncFromPlugin()` present
6. `Component.onCompleted: syncFromPlugin()` present
7. `saveSettings()` reads from local state, writes to `pluginApi.pluginSettings`, calls `pluginApi.saveSettings()`

**Audit results:**
- `homeassistant`: Missing #4 (Connections listener), #6 (no syncFromPlugin function at all)
- `quickshell-screenshot`: Missing #4, #5 (no onPluginApiChanged). Has `syncFromSettings()` but no reactive listener.
- `swww-picker`: Missing #4 (will be fixed in Phase 1.5)

- [ ] **Step 1: Add missing `syncFromPlugin()` + reactive listeners to `quickshell-screenshot/Settings.qml`**

  Rename `syncFromSettings()` → `syncFromPlugin()` for consistency.
  Add:
  ```qml
  onPluginApiChanged: syncFromPlugin()
  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      syncFromPlugin()
    }
  }
  ```

- [ ] **Step 2: Verify `homeassistant` has complete pattern after Task 1.4**

- [ ] **Step 3: Verify `swww-picker` has complete pattern after Task 1.5**

- [ ] **Step 4: Commit**

  ```bash
  git add quickshell-screenshot/Settings.qml
  git commit -m "style(quickshell-screenshot): standardize syncFromPlugin + reactive settings listener"
  ```

---

## Phase 4: Design Polish

> **Pre-condition:** Phase 3 is fully committed.

### Task 4.1: Verify all BarWidgets handle vertical bar correctly

**Files:**
- Inspect all: `*/BarWidget.qml`

**Checklist per widget:**
- [ ] Declares `property string section`, `property int sectionWidgetIndex`, `property int sectionWidgetsCount`
- [ ] Computes `isBarVertical` / `isVertical` from `Settings.getBarPositionForScreen(screen?.name)`
- [ ] `implicitWidth` / `implicitHeight` swap when vertical
- [ ] Visual content swaps between `RowLayout` (horizontal) and `ColumnLayout` or centered `Item` (vertical)
- [ ] `MouseArea` uses correct margin adjustments for edge widgets (`sectionWidgetIndex === 0` / `sectionWidgetsCount - 1`)

**Audit results from initial scan:**
- `hypr-overview`: ✅ Uses `NIconButton` centered, handles `isVertical` correctly
- `bb-auth`: ✅ Simple `NIconButton` centered, no text — naturally vertical-safe
- `homeassistant`: ✅ Complex but has vertical layout path
- `omarchy`: ✅ Complex but has vertical layout path
- `swww-picker`: ✅ Complex but has vertical layout path
- `quickshell-screenshot`: N/A (no BarWidget)

**No code changes required** — documentation only. If a plugin fails this check during implementation, fix it here.

- [ ] **Step 1: Document findings**

  No changes needed based on initial audit. Mark as verified.

- [ ] **Step 2: Commit**

  ```bash
  git commit --allow-empty -m "docs(audit): verify all BarWidgets support vertical bar layout"
  ```

---

### Task 4.2: Audit settings save debouncing UX

**Files:**
- Inspect all: `*/Settings.qml`

**Desired behavior:**
- Text inputs should debounce (e.g., 350ms `Timer`) to avoid saving on every keystroke
- Toggles/checkboxes should save immediately (no debounce needed)
- Combo boxes should save immediately on selection
- Buttons (test connection, refresh) should not trigger save

**Audit:**
- `omarchy`: ✅ Has `saveDebounce` Timer (350ms) for text inputs. Toggles save immediately.
- `bb-auth`: ⚠️ Saves immediately on every toggle — acceptable for 3 settings. No text inputs.
- `homeassistant`: ⚠️ Saves on every text change (no debounce). Should add timer.
- `swww-picker`: ⚠️ Saves nowhere — `saveSettings()` is defined but never called! Only `onTextChanged` updates local state. Missing save triggers.
- `quickshell-screenshot`: ⚠️ `saveSettings()` called only in `onClicked` of reset button. Toggles don't call save!
- `hypr-overview`: ✅ Already has robust save pattern with debounce.

- [ ] **Step 1: Fix `swww-picker/Settings.qml` — add save triggers**

  At end of `saveSettings()`, call it from toggle handlers:
  ```qml
  onToggled: checked => {
    root.autoCycleEnabled = checked
    saveSettings()
  }
  ```
  And from combo `onSelected` and text `onTextChanged` (with debounce for text).

- [ ] **Step 2: Fix `quickshell-screenshot/Settings.qml` — add save triggers**

  Add `onToggled` handlers to all `NToggle` that call `saveSettings()`.

- [ ] **Step 3: Fix `homeassistant/Settings.qml` — add save debounce**

  Add a `Timer` for text inputs, call `saveSettings()` from toggle/combo handlers.

- [ ] **Step 4: Verify**

  Run: `qmllint swww-picker/Settings.qml quickshell-screenshot/Settings.qml homeassistant/Settings.qml`

- [ ] **Step 5: Commit**

  ```bash
  git add swww-picker/Settings.qml quickshell-screenshot/Settings.qml homeassistant/Settings.qml
  git commit -m "fix(settings): ensure all settings controls trigger save + add debounce where needed"
  ```

---

## Final Verification

After all phases are complete:

- [ ] Run `qmllint` on every modified `.qml` file
- [ ] Run `python3 -m json.tool` on every modified `en.json`
- [ ] Run `git status` to ensure no unstaged changes remain
- [ ] Review the commit log to confirm one-commit-per-task discipline was followed
- [ ] Optionally run the plugins in Noctalia with `NOCTALIA_DEBUG=1` to verify no runtime warnings

---

## Risk & Rollback

- **Low risk:** All changes are cosmetic / pattern-alignment. No functional logic is modified except reactive sync (Task 1.4, 1.5) and save triggers (Task 4.2).
- **Rollback:** Individual commits can be reverted with `git revert <commit-hash>`.
- **Testing:** Each task includes a `qmllint` verification step. Runtime testing requires a live Noctalia session.
