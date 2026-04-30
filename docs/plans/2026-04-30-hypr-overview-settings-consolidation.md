# Hypr Overview — Settings Consolidation & Fixed Panel

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce hypr-overview settings from ~65 controls / 6 tabs to ~30 controls / 4 tabs with fixed panel height. Ship great defaults for removed settings. Gnome/macOS philosophy: minimal knobs, curated defaults.

**Architecture:** Keep Grid, Behavior, Layout, Appearance (4 tabs). Merge Visual Effects + Performance into Appearance. Give `NTabView` a fixed `Layout.preferredHeight` so all tabs are the same size and overflow scrolls. Remove UI controls for 27 settings while retaining their manifest defaults — code that reads `pluginApi.pluginSettings` is unaffected.

**Tech Stack:** QML (Quickshell / Qt6), Noctalia Shell plugin APIs, JSON i18n

**Files touched:** `hypr-overview/Settings.qml`, `hypr-overview/manifest.json`, `hypr-overview/i18n/en.json`

---

## Task 0: Checkpoint Commit

> **CRITICAL:** Do this first. Creates a rollback point.

- [ ] **Step 1: Stage and commit current state**

```bash
git add -A && git commit -m "chore(hypr-overview): checkpoint before settings consolidation"
```

Expected: Clean working tree. All changes from prior audit committed.

---

## Task 1: Fix Panel Height to Fixed Size

**Files:** Modify `hypr-overview/Settings.qml`

**Context:** Currently `NTabView` uses `Layout.fillHeight: true`, causing the panel to resize when switching tabs. Fix to a fixed height so all tabs are uniform and overflow scrolls.

- [ ] **Step 1: Read the current NTabView declaration**

Read around line 930 of `hypr-overview/Settings.qml`:
```qml
NTabView {
    id: tabLayout
    Layout.fillWidth: true
    Layout.fillHeight: true
    currentIndex: tabBar.currentIndex
```

- [ ] **Step 2: Replace Layout.fillHeight with fixed preferredHeight**

Change:
```qml
    Layout.fillHeight: true
```
to:
```qml
    Layout.preferredHeight: Math.round(640 * Style.uiScaleRatio)
```

The existing `Flickable` + `clip: true` pattern in each tab handles overflow scrolling automatically.

- [ ] **Step 3: Verify**

Run: `qmllint hypr-overview/Settings.qml`
Expected: Noctalia import warnings only, no new errors.

- [ ] **Step 4: Commit**

```bash
git add hypr-overview/Settings.qml
git commit -m "fix(hypr-overview): set fixed panel height (640px scaled) for consistent tab sizing"
```

---

## Task 2: Remove Visual Effects Tab + Performance Tab, Restructure Visual Mode

**Files:** Modify `hypr-overview/Settings.qml`

**Context:** Two tabs (Visual Effects and Performance) get deleted. Their content is either removed or merged into the Appearance tab's Visual Mode section. The new Visual Mode has 3 options: Live, Simplified, Off.

### Step 1: Remove the Visual Effects + Performance tab buttons from NTabBar

The tab bar is at lines 881-923. Keep only 4 buttons:

```qml
NTabBar {
    id: tabBar
    Layout.fillWidth: true
    currentIndex: 0
    distributeEvenly: true

    NTabButton { text: tr("settings.tabs.grid", "Grid"); tabIndex: 0; checked: tabBar.currentIndex === 0 }
    NTabButton { text: tr("settings.tabs.behavior", "Behavior"); tabIndex: 1; checked: tabBar.currentIndex === 1 }
    NTabButton { text: tr("settings.tabs.layout", "Layout"); tabIndex: 2; checked: tabBar.currentIndex === 2 }
    NTabButton { text: tr("settings.tabs.appearance", "Appearance"); tabIndex: 3; checked: tabBar.currentIndex === 3 }
}
```

Remove the last 2 NTabButton for "Visual Effects" and "Performance".

### Step 2: Delete the Visual Effects tab Item (lines ~2198-2432)

Remove the entire `// === Visual Effects Tab ===` Item block — from the comment line through its closing `}` before `// === Performance Tab ===`.

This removes: empty workspace wallpaper, glass mode, blur effects — all 7 controls.

### Step 3: Delete the Performance tab Item (lines ~2434-2543)

Remove the entire `// === Performance Tab ===` Item block.

### Step 4: Restructure the Visual Mode NComboBox in Appearance tab

Find the existing `NComboBox` at line ~1513 inside the `// --- Visual Mode ---` NCollapsible. Replace it with a new 3-option dropdown that controls BOTH `previewMode` and `visualMode`:

```qml
NComboBox {
    Layout.fillWidth: true
    label: tr("settings.appearance.visualMode.label", "Visual mode")
    description: tr("settings.appearance.visualMode.description", "Controls window preview rendering — choose live, stylized, or off for lowest resource usage")
    model: [
        { "key": "live", "name": tr("settings.appearance.visualMode.live", "Live") },
        { "key": "simplified", "name": tr("settings.appearance.visualMode.simplified", "Simplified") },
        { "key": "off", "name": tr("settings.appearance.visualMode.off", "Off") }
    ]
    currentKey: root.visualMode
    onSelected: key => {
        root.visualMode = key;
        if (key === "off") {
            root.previewMode = "off";
            root.useSimplifiedPreview = false;
        } else if (key === "simplified") {
            root.previewMode = "event";
            root.useSimplifiedPreview = true;
        } else {
            root.previewMode = "live";
            root.useSimplifiedPreview = false;
        }
        root.saveSettings();
    }
}
```

### Step 5: Remove the shader sub-controls (shader preset, preset strength, color depth, saturation, contrast)

Delete the collapsed Item block (lines ~1539-1682) that contains shaderControlsColumn — this is the Shader Preset dropdown, Preset Strength, Pixel Density, Color Depth, Saturation, and Contrast sliders.

### Step 6: Add the conditional pixel density slider for "Simplified" mode

After the Visual Mode NComboBox from Step 4, add:

```qml
Item {
    Layout.fillWidth: true
    Layout.maximumHeight: root.visualMode === "simplified" ? implicitHeight : 0
    implicitHeight: pixelDensitySlider.implicitHeight
    opacity: root.visualMode === "simplified" ? 1.0 : 0.0
    visible: opacity > 0
    clip: true

    Behavior on Layout.maximumHeight {
        NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
    }

    NValueSlider {
        id: pixelDensitySlider
        anchors.left: parent.left
        anchors.right: parent.right
        label: tr("settings.appearance.pixelDensity.label", "Pixel Density")
        description: tr("settings.appearance.pixelDensity.description", "Controls pixelation level — higher values show more detail")
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
}
```

### Step 7: Verify

Run: `qmllint hypr-overview/Settings.qml`
Expected: No new errors beyond Noctalia import warnings.

### Step 8: Commit

```bash
git add hypr-overview/Settings.qml
git commit -m "refactor(hypr-overview): remove Visual Effects + Performance tabs, restructure Visual Mode to Live/Simplified/Off"
```

---

## Task 3: Trim Appearance Tab — Icons, Title Strip, Badges, Dimming, Borders, Multi-Monitor

**Files:** Modify `hypr-overview/Settings.qml`

**Context:** 27 settings removed from UI across the Appearance tab's collapsible sections.

### Step 1: Simplify Window Icons section (lines ~1686-1763)

**Remove:** Colorize icons toggle (lines 1731-1739), Icon placement combo (lines 1741-1760), and the collapsing Item wrapper (lines 1702-1761).

**Keep:** Only the Show Window Icons toggle.

After the NCollapsible header, the section should be just:
```qml
NCollapsible {
    label: tr("settings.appearance.section.windowIcons", "Window Icons")
    description: tr("settings.appearance.section.windowIcons.desc", "Icon display and positioning")
    expanded: true
    Layout.fillWidth: true

    NToggle {
        label: tr("settings.appearance.windowIcons.label", "Window icons")
        description: tr("settings.appearance.windowIcons.description", "Show app icons inside each window preview card")
        checked: root.showWindowIcons
        onToggled: checked => {
            root.showWindowIcons = checked;
            root.saveSettings();
        }
    }
}
```

### Step 2: Simplify Title Strip section (lines ~1766-1891)

**Remove:** Title Strip Metadata combo (lines 1865-1888).

**Keep:** Title Strip Mode, Position, and Height.

Delete the NComboBox with label "Title strip metadata" and its model entries.

### Step 3: Simplify Window Badges section (lines ~1894-1978)

**Remove:** Fullscreen badge toggle (lines 1920-1928), Monitor badge toggle (lines 1930-1938), Drag indicator style combo (lines 1965-1978).

**Keep:** Urgency badge toggle, Floating badge toggle, Multi-Monitor NText header, Show monitor indicators toggle, Cross-monitor drag toggle.

The section should be:
```qml
NCollapsible {
    label: tr("settings.appearance.section.windowBadges", "Window Badges")
    description: tr("settings.appearance.section.windowBadges.desc", "Status indicators on window previews")
    expanded: true
    Layout.fillWidth: true

    NToggle {
        label: tr("settings.appearance.urgencyBadge.label", "Urgency badge")
        description: tr("settings.appearance.urgencyBadge.description", "Show a red badge when a window requests urgent attention")
        checked: root.showUrgencyBadge
        onToggled: checked => { root.showUrgencyBadge = checked; root.saveSettings(); }
    }

    NToggle {
        label: tr("settings.appearance.floatingBadge.label", "Floating badge")
        description: tr("settings.appearance.floatingBadge.description", "Show a badge on windows currently floating in Hyprland")
        checked: root.showFloatingBadge
        onToggled: checked => { root.showFloatingBadge = checked; root.saveSettings(); }
    }

    NText {
        text: tr("settings.appearance.section.multiMonitor", "Multi-Monitor")
        font.weight: Font.Bold
    }

    NToggle {
        label: tr("settings.appearance.showMonitorIndicators.label", "Show monitor indicators")
        description: tr("settings.appearance.showMonitorIndicators.description", "Show monitor badges on workspace cells for workspaces bound to other monitors")
        checked: root.showMonitorIndicators
        onToggled: checked => { root.showMonitorIndicators = checked; root.saveSettings(); }
    }

    NToggle {
        label: tr("settings.appearance.enableCrossMonitorDrag.label", "Cross-monitor drag")
        description: tr("settings.appearance.enableCrossMonitorDrag.description", "Enable dragging windows to workspaces on other monitors")
        checked: root.enableCrossMonitorDrag
        onToggled: checked => { root.enableCrossMonitorDrag = checked; root.saveSettings(); }
    }
}
```

**IMPORTANT:** The local properties `showFullscreenBadge`, `showMonitorBadge`, and `crossMonitorDragStyle` remain in the property declarations at the top of the file — only their UI controls are removed. They keep their manifest defaults.

### Step 4: Simplify Dimming & Focus section (lines ~1982-2048)

**Remove:** Inactive saturation slider (lines 2005-2020), Hover emphasis slider (lines 2022-2037), Focused glow toggle (lines 2039-2047).

**Keep:** Inactive workspace dim slider only.

The section becomes:
```qml
NCollapsible {
    label: tr("settings.appearance.section.dimmingFocus", "Dimming & Focus")
    description: tr("settings.appearance.section.dimmingFocus.desc", "Inactive workspace dimming")
    expanded: true
    Layout.fillWidth: true

    NValueSlider {
        Layout.fillWidth: true
        label: tr("settings.appearance.dimInactive.label", "Inactive workspace dim")
        description: tr("settings.appearance.dimInactive.description", "How much previews are dimmed when not on the active workspace")
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
}
```

### Step 5: Simplify Borders & Corners section (lines ~2051-2185)

**Remove:** Border gradient toggle (lines 2121-2129), Accent color combo (lines 2131-2150), Container border slider (lines 2152-2167), Selection border slider (lines 2169-2184).

**Keep:** Corner mode combo, conditional fixed corner radius slider.

The section becomes:
```qml
NCollapsible {
    label: tr("settings.appearance.section.bordersCorners", "Borders & Corners")
    description: tr("settings.appearance.section.bordersCorners.desc", "Preview corner rounding")
    expanded: true
    Layout.fillWidth: true

    NComboBox {
        Layout.fillWidth: true
        label: tr("settings.appearance.cornerMode.label", "Corner mode")
        description: tr("settings.appearance.cornerMode.description", "Use Hyprland rounding or force a fixed radius for previews")
        model: [
            { "key": "hyprland", "name": tr("settings.appearance.cornerMode.hyprland", "Hyprland") },
            { "key": "fixed", "name": tr("settings.appearance.cornerMode.fixed", "Fixed") }
        ]
        currentKey: root.previewCornerMode
        onSelected: key => { root.previewCornerMode = key; root.saveSettings(); }
    }

    Item {
        Layout.fillWidth: true
        Layout.maximumHeight: root.previewCornerMode === "fixed" ? implicitHeight : 0
        implicitHeight: cornerRadiusSlider.implicitHeight
        opacity: root.previewCornerMode === "fixed" ? 1.0 : 0.0
        visible: opacity > 0
        clip: true

        Behavior on Layout.maximumHeight {
            NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
        }

        NValueSlider {
            id: cornerRadiusSlider
            anchors.left: parent.left
            anchors.right: parent.right
            label: tr("settings.appearance.fixedCornerRadius.label", "Fixed corner radius")
            description: tr("settings.appearance.fixedCornerRadius.description", "Corner radius applied when corner mode is set to Fixed")
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
}
```

### Step 6: Add Accent Color combo back as a standalone control

After the Borders & Corners NCollapsible, add:

```qml
NComboBox {
    Layout.fillWidth: true
    label: tr("settings.appearance.accentColor.label", "Accent color")
    description: tr("settings.appearance.accentColor.description", "Color used for selection indicator and special workspaces")
    model: [
        { "key": "secondary", "name": tr("settings.appearance.accentColor.secondary", "Secondary") },
        { "key": "primary", "name": tr("settings.appearance.accentColor.primary", "Primary") }
    ]
    currentKey: root.accentColorType
    onSelected: key => { root.accentColorType = key; root.saveSettings(); }
}
```

### Step 7: Commit

```bash
git add hypr-overview/Settings.qml
git commit -m "refactor(hypr-overview): simplify Appearance tab — remove 20+ niche controls, keep 14 essentials"
```

---

## Task 4: Trim Layout Tab — Remove Guides and Layout Badge

**Files:** Modify `hypr-overview/Settings.qml`

### Step 1: Remove Row/Column guides toggle

Delete lines 1386-1394 (the NToggle with label "Row/column guides").

### Step 2: Remove Layout badge toggle + setup hint

Delete lines 1396-1475 — the NToggle with label "Layout badge" and the entire Rectangle setup hint that follows it (copy-button, clipboard helper, hyprland config code block).

The Layout tab now ends after the Special workspace style NComboBox.

### Step 3: Commit

```bash
git add hypr-overview/Settings.qml
git commit -m "refactor(hypr-overview): remove niche Layout tab settings (guides, layout badge)"
```

---

## Task 5: Remove Animation Duration + Snap Threshold from Behavior/Grid

**Files:** Modify `hypr-overview/Settings.qml`

### Step 1: Simplify Animation Profile — remove Slow and Custom options

In the Grid tab's NComboBox at ~line 1045, change the animation profile model from 5 options to 3:

```qml
model: [
    { "key": "none", "name": tr("settings.grid.animationProfile.none", "No animation") },
    { "key": "fast", "name": tr("settings.grid.animationProfile.fast", "Fast") },
    { "key": "hyprlike", "name": tr("settings.grid.animationProfile.hyprlike", "Hyprlike") }
]
```

### Step 2: Remove the custom duration slider and its animated container

Delete the Item block at lines ~1078-1119 that contains `animDurationSlider` (visible only when animationProfile === "custom").

### Step 3: Remove Drag snap threshold slider

In the Behavior tab, delete lines ~1193-1209 (NValueSlider labeled "Drag snap threshold", visible when drag preview not off).

**Keep:** Retile preview opacity slider.

### Step 4: Commit

```bash
git add hypr-overview/Settings.qml
git commit -m "refactor(hypr-overview): remove animation duration slider, snap threshold, streamline animation profile"
```

---

## Task 6: Update Manifest Defaults and i18n File

**Files:** Modify `hypr-overview/manifest.json`, `hypr-overview/i18n/en.json`

### Step 1: Update manifest.json defaultSettings

The internal defaults are already correct for all removed settings — no changes needed. Verify:
- `shaderPreset: "classic"` ✅
- `simplifiedPixelDensity: 0.5` ✅ (now the only exposed shader control)
- `crossMonitorDragStyle: "border"` → **Change to `"both"`** (we removed the UI picker, ship the most informative option)
- All other removed settings already have good defaults.

Change in manifest.json (`metadata.defaultSettings`):
```json
"crossMonitorDragStyle": "both"
```

### Step 2: Update en.json — remove obsolete i18n keys

These keys are no longer referenced by any UI control and should be removed:

**Visual Effects keys to remove:**
- `settings.visualEffects.*` — all entries (wallpaper, glass, blur sections)

**Performance keys to remove:**
- `settings.performance.*` — all entries

**Appearance keys to remove:**
- `settings.appearance.shaderPreset.*`
- `settings.appearance.shaderPresetStrength.*`
- `settings.appearance.colorDepth.*`
- `settings.appearance.saturation.*`
- `settings.appearance.contrast.*`
- `settings.appearance.colorizeIcons.*`
- `settings.appearance.iconPlacement.*`
- `settings.appearance.titleStripMeta.*`
- `settings.appearance.fullscreenBadge.*`
- `settings.appearance.monitorBadge.*`
- `settings.appearance.crossMonitorDragStyle.options.*`
- `settings.appearance.inactiveSaturation.*`
- `settings.appearance.hoverLift.*`
- `settings.appearance.focusedGlow.*`
- `settings.appearance.borderGradient.*`
- `settings.appearance.containerBorder.*`
- `settings.appearance.selectionBorder.*`

**Layout keys to remove:**
- `settings.layout.rowColumnGuides.*`
- `settings.layout.layoutBadge.*`

**Grid keys to remove:**
- `settings.grid.animationProfile.slow`
- `settings.grid.animationProfile.custom`
- `settings.grid.animationDuration.*`

**Tab keys to remove:**
- `settings.tabs.visual`
- `settings.tabs.performance`

**Keys to add (new or renamed):**
- `settings.appearance.section.visualMode.desc`: "Preview rendering and shader quality" (keep existing if already present)
- `settings.appearance.visualMode.off`: "Off"
- `settings.appearance.visualMode.description`: "Controls window preview rendering — choose live, stylized, or off for lowest resource usage"

### Step 3: Verify JSON validity

```bash
python3 -m json.tool hypr-overview/i18n/en.json > /dev/null && echo "JSON valid"
```

### Step 4: Commit

```bash
git add hypr-overview/manifest.json hypr-overview/i18n/en.json
git commit -m "refactor(hypr-overview): update manifest default for crossMonitorDragStyle, clean obsolete i18n keys"
```

---

## Task 7: Final Verification

- [ ] **Step 1: Run qmllint**

```bash
qmllint hypr-overview/Settings.qml
```

Expected: Noctalia import warnings expected (qs.Commons, qs.Widgets unresolved outside shell runtime). No new errors.

- [ ] **Step 2: Verify removed controls are gone**

```bash
grep -c "NToggle\|NComboBox\|NValueSlider\|NSpinBox\|NTextInput" hypr-overview/Settings.qml
```

The count should be significantly lower than before (~30 vs ~65).

- [ ] **Step 3: Verify all kept local properties still exist**

Check that these `property` declarations at the top of Settings.qml are still present (code in Main.qml references them):
- `gridRows`, `gridColumns`, `gridScale`, `gridSpacing`
- `hideEmptyRows`, `showScratchpadWorkspaces`
- `dragPreviewMode`, `retilePreviewOpacity`
- `overviewPosition`, `barMargin`, `overviewBackgroundOpacityRatio`
- `useSlideAnimation`, `showWorkspaceLabels`, `workspaceLabelMode`
- `specialWorkspaceStyle`
- `visualMode`, `previewMode`, `useSimplifiedPreview`, `simplifiedPixelDensity`
- `showWindowIcons`
- `showWindowTitleStrip`, `titleStripMode`, `titleStripPosition`, `titleStripHeight`
- `showUrgencyBadge`, `showFloatingBadge`
- `showMonitorIndicators`, `enableCrossMonitorDrag`
- `dimInactiveWorkspaces`
- `previewCornerMode`, `previewFixedCornerRadius`
- `accentColorType`
- `animationProfile`

- [ ] **Step 4: Review git diff**

```bash
git diff HEAD~7 --stat
```

Should show reduction in file size for Settings.qml (from ~2607 lines to ~1600-1800 lines).

- [ ] **Step 5: Commit any final fixes**

```bash
git add -A && git commit -m "chore(hypr-overview): final verification after settings consolidation"
```

---

## Summary

| | Before | After |
|---|--------|-------|
| Settings.qml lines | ~2607 | ~1600-1800 |
| Tabs | 6 | 4 |
| Controls | ~65 | ~30 |
| Removed from UI | — | 26 settings (defaults retained) |
| Panel height | Variable per tab | Fixed (640px scaled) |

**Tabs:**
1. **Grid** — rows, columns, scale, spacing, animation profile (3 options)
2. **Behavior** — hide empty, scratchpad, drag preview mode, retile preview opacity
3. **Layout** — position, bar margin, opacity, slide, labels, label format, special style
4. **Appearance** — visual mode (Live/Simplified/Off) + pixel density, window icons, title strip mode/pos/height, badges (urgency + floating), multi-monitor (indicators + drag), dimming, corners (mode + radius), accent color

---

## Risk & Rollback

- **Low risk.** Only UI controls removed; property declarations and manifest defaults preserved. Code in `Main.qml` that reads `pluginApi.pluginSettings` is unaffected.
- **Rollback:** `git revert HEAD~7..HEAD` reverts all 7 commits.
- **Testing:** Each task includes `qmllint` verification. Runtime test requires live Noctalia session.
