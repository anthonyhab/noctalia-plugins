# Hypr Overview Plugin for Noctalia

Hypr Overview adds a Hyprland workspace overview to Noctalia Shell with window previews, keyboard navigation, and drag-and-drop window movement.

## Features

- Configurable workspace grid with optional empty-row hiding.
- Live window previews using Hyprland/Wayland screencopy, with an optional pixelated/dithered shader style.
- Drag windows between workspaces, including optional cross-monitor migration.
- Retile previews for supported Hyprland layouts.
- Keyboard, mouse, and scroll-wheel workspace navigation.
- Optional workspace labels, window title strips, status badges, and monitor indicators.

## Settings

Key settings are available in the Noctalia plugin settings panel:

- `showMonitorIndicators`: show monitor badges on window previews.
- `enableCrossMonitorDrag`: allow dragging windows to workspaces on other monitors.
- `visualMode`: `live`, `simplified` pixel shader, or `off`.
- `shaderPreset`: `pixelated` or `mac` for the classic dithered look.
- Grid rows, columns, scale, spacing, position, animation profile, labels, badges, title strips, preview styling, drag thresholds, and layout badges/guides.

Obsolete effects keys are removed from saved plugin settings on load. Compatibility preview keys from earlier builds are migrated into the supported preview style settings.

## Installation

Ensure you have the plugin files in:
`~/.config/noctalia/plugins/hypr-overview/`

## Usage

### Via Bar Widget
Add the "Hypr Overview" widget to your Noctalia bar.

### Via IPC (Keybindings)
You can toggle the overview using the Noctalia IPC interface. This is ideal for assigning to a keyboard shortcut.

**Command:**
```bash
qs -c noctalia-shell ipc call plugin:hypr-overview toggle
```

#### Hyprland Keybind Example
Add the following to your `hyprland.conf`:
```bash
bind = SUPER, TAB, exec, qs -c noctalia-shell ipc call plugin:hypr-overview toggle
```

## Requirements

- **Noctalia Shell**: 3.6.0 or later
- **Hyprland**: For workspace and window tracking
- **Quickshell**: The framework powering Noctalia
