# Native Noctalia Shell Reference (Plugin UI Alignment)

This document summarizes how native Noctalia shell widgets, panels, and settings
are implemented. Use it to align plugin UI behavior with the shell so plugins
blend in and behave consistently.

Sources reviewed in `~/noctalia-shell` include:
- `Modules/Bar/Widgets/*.qml`
- `Widgets/NPopupContextMenu.qml`, `Widgets/NContextMenu.qml`
- `Services/UI/BarService.qml`, `Services/UI/PanelService.qml`
- `Modules/Panels/Plugins/PluginPanelSlot.qml`
- `Widgets/NPluginSettingsPopup.qml`
- `Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml`

---

## 1) Bar widgets (native pattern)

Native bar widgets typically follow this shape (see `Modules/Bar/Widgets/Volume.qml`):

- Use `BarPill` as the visual root.
- Provide `screen`, `density`, and `oppositeDirection`.
- Use `implicitWidth` / `implicitHeight` bound to the pill size.
- Use `TooltipService` and `BarService.getTooltipDirection()` for tooltips.
- Use `PanelService.getPanel(name, screen)?.toggle(this)` for panel toggles.

Key properties:
- `screen: root.screen`
- `density: Settings.data.bar.density`
- `oppositeDirection: BarService.getPillDirection(root)`
- `tooltipText` for the pill or a child, with TooltipService show/hide.

When implementing a plugin bar widget, mirror this structure and keep the pill
as the main anchor for interactions.

---

## 2) Context menus (bar widgets)

Native bar widgets do not compute context menu positions manually. They rely on
`NPopupContextMenu.openAtItem(item, screen)` to calculate the correct position
for all bar orientations.

Pattern (from `Modules/Bar/Widgets/Volume.qml`):

- Get popup menu window: `var popupMenuWindow = PanelService.getPopupMenuWindow(screen);`
- If present: `popupMenuWindow.showContextMenu(contextMenu);`
- Open menu: `contextMenu.openAtItem(pill, screen);`
- On action: close the popup menu window before handling the action; avoid
  calling `contextMenu.close()` directly (the popup window handles it).

Notes:
- `NPopupContextMenu` is designed for bar widgets and top-level contexts.
- `NContextMenu` is for panels and dialogs (see `Widgets/NContextMenu.qml`).
- `NPopupContextMenu` positions itself using `Settings.data.bar.position` and
  respects screen bounds internally (see `Widgets/NPopupContextMenu.qml`).

---

## 3) Panels and panel lifecycle

Panels are managed by `PanelService` (`Services/UI/PanelService.qml`).

Important patterns:
- `PanelService.getPanel(name, screen)` returns a screen-specific instance.
- Only one panel is kept open at a time; `PanelService.willOpenPanel()` handles
  closing the previous one automatically.
- Use `panel?.toggle(sourceItem)` for standard toggles from bar widgets.
- If you need a popup menu window for context menus, use
  `PanelService.getPopupMenuWindow(screen)`.

Plugins that open their own panels should use `pluginApi.openPanel(screen, item)`
and `pluginApi.closePanel(screen)`, which delegate to the panel system.

---

## 4) Plugin panels (native loader behavior)

Plugin panels are loaded by `Modules/Panels/Plugins/PluginPanelSlot.qml`:

- The loader injects a dummy `pluginApi` immediately to avoid undefined warnings.
- Once the panel component is ready, the real `pluginApi` is injected before
  bindings are evaluated.
- Panel anchoring can be customized by the plugin panel component via:
  `panelAnchorHorizontalCenter`, `panelAnchorVerticalCenter`,
  `panelAnchorTop`, `panelAnchorBottom`, `panelAnchorLeft`, `panelAnchorRight`.
- Plugins can optionally define:
  - `allowAttach`
  - `contentPreferredWidth`
  - `contentPreferredHeight`

If your plugin panel needs a specific layout or anchoring, expose those
properties on the panel root item.

---

## 5) Settings dialogs (native)

### Bar widget settings

Core widgets open settings through `BarService.openWidgetSettings(...)`, which
shows `BarWidgetSettingsDialog.qml`. It expects:
- `saveSettings()` in the settings UI to return a new settings object.
- The dialog handles apply/cancel and updates `Settings.data.bar.widgets`.

If a plugin wants a standard settings dialog from the bar context menu, use
`NPluginSettingsPopup` rather than a custom popup.

### Plugin settings popup

Native plugin settings are shown via `Widgets/NPluginSettingsPopup.qml`:
- It loads the plugin `Settings.qml` entry point.
- It injects `pluginApi` and provides default layout, buttons, and toasts.
- It calls `saveSettings()` on the loaded settings component when “Apply” is
  clicked.

When opening settings from a widget or panel, prefer
`NPluginSettingsPopup` to match native UX.

---

## 6) Service helpers used by native widgets

Use these services rather than re-implementing behavior:

- `BarService.getPillDirection(widgetInstance)`
  - Determines pill orientation based on bar position and section.
- `BarService.getTooltipDirection()`
  - Keeps tooltips consistent with bar placement.
- `PanelService.getPopupMenuWindow(screen)`
  - Ensures context menus and popups render in the correct window.
- `TooltipService.show(...)`, `TooltipService.hide()`
  - Native widgets often hide tooltips on click, wheel, or drag.

Avoid custom position math for menus; use `NPopupContextMenu.openAtItem(...)`.

---

## 7) Translation and UI consistency

Native UI uses:
- `I18n.tr(...)` for core UI
- `pluginApi.tr(...)` for plugin UI
- `Style.*` constants for spacing, fonts, and animation
- `Color.*` palette for surfaces and text

Using `NText`, `NButton`, `NIcon`, `NIconButton`, and `NPopupContextMenu`
keeps typography and spacing consistent with the shell.

- Prefer `NText.pointSize` instead of `font.pointSize` so font scaling stays
  consistent with `Style.uiScaleRatio` and user font scales.

---

## 8) Spacing, padding, and sizing (native constants)

Native UI relies on `Style` constants so spacing scales with user settings.
Use these instead of hard-coded pixel values.

From `Commons/Style.qml`:
- Margins: `Style.marginXXS` (2), `marginXS` (4), `marginS` (6), `marginM` (9),
  `marginL` (13), `marginXL` (18) * `Style.uiScaleRatio`
- Radii: `Style.radiusXXS`..`Style.radiusL` (container), `Style.iRadiusXXS`..`iRadiusL` (inputs)
- Borders: `Style.borderS`/`borderM`/`borderL`
- Base sizing: `Style.baseWidgetSize` (33)
- Bar sizing: `Style.barHeight`, `Style.capsuleHeight`

Common layout patterns seen in native widgets/panels:
- Panel root: `anchors.margins: Style.marginL`, `spacing: Style.marginM`
- Card/box header: `Layout.preferredHeight: child.implicitHeight + (Style.marginM * 2)`
- Menu padding: `NPopupContextMenu` uses `Style.marginS` internal padding
- Button/icon sizing: `baseSize` derived from `Style.baseWidgetSize`
- Max widths/heights: `Math.round(value * Style.uiScaleRatio)`
- Interaction hygiene: hide tooltips on wheel/drag or other continuous input
  to prevent overlay clutter (e.g., `TooltipService.hide()` in `BarPill.onWheel`)

When creating new UI:
- Scale custom sizes with `Style.uiScaleRatio`
- Prefer `Style.margin*` for padding/spacing
- Prefer `Style.radius*`/`Style.iRadius*` for rounding
- Avoid raw numbers unless it is a semantic size that is already a Style constant

---

## 8) Plugin component expectations

Based on native loader behavior:
- Always declare `property var pluginApi: null` on QML entry points.
- Be robust to a `null`/dummy `pluginApi` during initialization.
- Use `pluginApi.mainInstance` for shared state and helper methods.
- Use `pluginApi.pluginSettings` and `pluginApi.saveSettings()` for persistence.

---

## 9) Practical do/don’t checklist

Do:
- Use `NPopupContextMenu` + `openAtItem(item, screen)` for bar menus.
- Call `PanelService.getPopupMenuWindow(screen)` before showing menus.
- Use `BarService.getPillDirection(...)` and `BarService.getTooltipDirection()`.
- Use `NPluginSettingsPopup` for plugin settings UIs.
- Keep `BarPill` as the anchor for bar widgets.

Don’t:
- Manually compute context menu positions.
- Create custom popup windows for bar widget menus.
- Assume `pluginApi` is ready at `Component.onCompleted`.
- Hardcode spacing, fonts, or colors outside `Style` / `Color`.

---

## 10) Quick reference pointers

Files to consult in `~/noctalia-shell`:
- `Modules/Bar/Widgets/Volume.qml` (canonical bar widget)
- `Widgets/NPopupContextMenu.qml` (menu positioning)
- `Services/UI/BarService.qml` (pill/tooltip direction, widget settings dialog)
- `Services/UI/PanelService.qml` (panel/popup window registry)
- `Modules/Panels/Plugins/PluginPanelSlot.qml` (plugin panel loading)
- `Widgets/NPluginSettingsPopup.qml` (plugin settings dialog)
- `Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml` (core widget settings)
