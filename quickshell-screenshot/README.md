# Quickshell Screenshot Plugin

A pixel-perfect screenshot comparison tool for Noctalia Shell, designed for comparing UI changes in shell development.

## Features

- **Draggable Region Selector**: Precisely position and resize the capture area
- **Smart State Management**: Remembers region between captures with 5-minute auto-reset
- **Before/After Workflow**: Capture two screenshots at the exact same location
- **Visual Grid Overlay**: Rule-of-thirds grid for composition
- **Shared State with Script**: Uses same state file as `qs-screenshot-compare` script
- **Keyboard Shortcuts**: Quick capture without mouse

## Installation

Install through Noctalia Settings → Plugins → Sources → Add custom repository:
```
https://github.com/anthonyhab/noctalia-plugins/
```

## Usage

### Quick Capture (Script)
```bash
# First press: Select region → captures "before"
# Second press (within 5 min): Captures "after" at same location
qs-screenshot-compare
```

### Pixel-Perfect Selector (Quickshell)
```bash
# Opens draggable overlay for precise positioning
# Same 5-minute window for before/after captures
```

### Keybinds (Hyprland)
```conf
# Quick capture
bind = SUPER SHIFT, PRINT, exec, qs-screenshot-compare

# Pixel-perfect selector
bind = SUPER SHIFT ALT, PRINT, exec, quickshell -c quickshell-screenshot -n
```

## IPC / Keybinds

Trigger actions without opening the full UI:

```bash
qs-dev ipc call quickshell-screenshot openSelector   # open region selector UI
qs-dev ipc call quickshell-screenshot captureRegion  # silent capture of saved region
qs-dev ipc call quickshell-screenshot resetState     # clear before/after state
```

`captureRegion` falls back to opening the selector if no region is saved yet.

### Hyprland example binds
```conf
bind = $mod, Print,       exec, qs-dev ipc call quickshell-screenshot openSelector
bind = $mod SHIFT, Print, exec, qs-dev ipc call quickshell-screenshot captureRegion
```

## Controls

### Region Selector
- **Drag center**: Move selection
- **Drag edges/corners**: Resize
- **Double-click**: Capture
- **Enter/Space**: Capture
- **Escape**: Cancel

### Workflow
1. Open selector or run script
2. Position region over UI element
3. Capture "before" screenshot
4. Make changes to shell
5. Capture "after" (same position automatically)
6. Compare screenshots in `~/Pictures/qs-compare/`

## Settings

- **Show Grid Overlay**: Display rule-of-thirds grid
- **Snap to Windows**: Auto-snap to window boundaries
- **Copy to Clipboard**: Auto-copy after capture
- **Open After Capture**: Open in image viewer
- **Reset Timeout**: Minutes before "before" expires (default: 5)

## State File

Both script and plugin share state:
```
~/.cache/qs-screenshot/state.json
```

## Output

Screenshots saved to:
```
~/Pictures/qs-compare/YYYY-MM-DD/
  shell-before-YYYY-MM-DD_HH-MM-SS.png
  shell-after-YYYY-MM-DD_HH-MM-SS.png
```

## Dependencies

- `grim`: Screenshot capture
- `wl-copy`: Clipboard integration
- `slurp`: Region selection (script only)
- `notify-send`: Notifications

## Development

Plugin structure:
```
quickshell-screenshot/
├── manifest.json        # Plugin metadata
├── Main.qml            # Entry point with overlay
├── RegionSelector.qml  # Draggable selection box
├── Settings.qml        # Configuration panel
├── StateManager.js     # Shared state management
└── ScreenshotManager.js # Capture logic
```

## License

MIT
