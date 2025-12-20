# Waybar to Noctalia Converter

Converts Waybar custom module configurations to Noctalia CustomButton widgets or full plugin scaffolds.

## Features

- Parses Waybar JSONC configuration files (with comments)
- Supports multi-bar configs (arrays of bar objects)
- Converts `custom/*` modules to Noctalia `CustomButton` widget configurations
- Optionally generates full plugin scaffolds with `Main.qml`, `BarWidget.qml`, and `Settings.qml`
- Handles polling and streaming modes
- Transforms JSON output format
- Maps click and scroll handlers

## Usage

```bash
# Basic usage - converts to CustomButton widget configs
./waybar_to_noctalia.py

# Specify a custom waybar config path
./waybar_to_noctalia.py ~/.config/waybar/config.jsonc

# Generate full plugin scaffolds
./waybar_to_noctalia.py --mode plugins

# Generate both widgets and plugins
./waybar_to_noctalia.py --mode both --output-dir ./my-output

# Show detailed conversion report
./waybar_to_noctalia.py --verbose

# Override the default interval used when Waybar omits it
./waybar_to_noctalia.py --default-interval 120

# Use a tighter poll interval for modules that rely on Waybar signals
./waybar_to_noctalia.py --signal-poll-interval 2
```

## Output Modes

### `widgets` (default)
Generates a `custom_widgets.json` file containing CustomButton configurations that can be added to your Noctalia `settings.json`.

### `plugins`
Generates complete plugin folder structures with:
- `manifest.json` - Plugin metadata + default settings
- `Main.qml` - Command runner + parsing logic
- `BarWidget.qml` - Bar widget implementation
- `Settings.qml` - Basic settings UI
- `i18n/en.json` - Translation strings
- `README.md` - Quick usage notes

### `both`
Generates both widget configs and plugin scaffolds.

## Property Mapping

| Waybar Property | Noctalia Equivalent | Notes |
|-----------------|---------------------|-------|
| `exec` | `textCommand` | Command to execute |
| `interval` (seconds) | `textIntervalMs` (ms) | Multiplied by 1000 |
| `interval: once/0` | `textStream: true` | Treated as streaming (no polling) |
| `return-type: "json"` | `parseJson: true` | JSON parsing |
| `on-click` | `leftClickExec` | Left click handler |
| `on-click-right` | `rightClickExec` | Right click handler |
| `on-click-middle` | `middleClickExec` | Middle click handler |
| `on-scroll-up` | `wheelUpExec` | Scroll up handler |
| `on-scroll-down` | `wheelDownExec` | Scroll down handler |
| `max-length` | `maxTextLength.horizontal` | Text truncation |
| `exec-on-event` | `*UpdateText: true` | Refresh after click |

Notes:
- Waybar defaults `interval` to 60 seconds when omitted. The converter mirrors this unless you override `--default-interval`.
- Modules that use Waybar `signal` without an interval can be polled more frequently via `--signal-poll-interval`.

## JSON Output Format

Waybar JSON output format:
```json
{"text": "...", "tooltip": "...", "class": "...", "percentage": 50}
```

Noctalia JSON output format:
```json
{"text": "...", "tooltip": "...", "icon": "..."}
```

The converter wraps commands that use `percentage` + `format-icons` to select icons programmatically (python wrapper, no `jq` dependency).

## Limitations

Some Waybar features don't have direct equivalents:

| Feature | Status | Workaround |
|---------|--------|------------|
| `signal` (SIGRTMIN+N) | ⚠️ Not supported | Use polling or streaming |
| CSS styling/classes | ⚠️ Not supported | Use Noctalia theming |
| Pango markup | ⚠️ Stripped | Use plain text |
| `format-icons` | ✅ Converted | Wrapped in shell script |
| `exec-if` | ✅ Converted | Wrapped in conditional |
| `min-length` | ⚠️ Not supported | Use styling |

## Examples

### Simple Polling Module

Waybar:
```jsonc
"custom/updates": {
  "exec": "checkupdates | wc -l",
  "interval": 3600,
  "on-click": "kitty -e sudo pacman -Syu"
}
```

Noctalia CustomButton:
```json
{
  "type": "CustomButton",
  "textCommand": "checkupdates | wc -l",
  "textIntervalMs": 3600000,
  "textStream": false,
  "leftClickExec": "kitty -e sudo pacman -Syu",
  "leftClickUpdateText": true
}
```

### Streaming JSON Module

Waybar:
```jsonc
"custom/spotify": {
  "exec": "playerctl metadata --format '{...}' --follow",
  "return-type": "json",
  "max-length": 40,
  "on-click": "playerctl play-pause"
}
```

Noctalia CustomButton:
```json
{
  "type": "CustomButton",
  "textCommand": "playerctl metadata --format '{...}' --follow",
  "textStream": true,
  "parseJson": true,
  "maxTextLength": {"horizontal": 40, "vertical": 10},
  "leftClickExec": "playerctl play-pause"
}
```

## Installation

The converter requires Python 3.8+. No external dependencies needed.

```bash
# Run directly
./waybar_to_noctalia.py

# Or with Python
python3 waybar_to_noctalia.py
```

## After Conversion

### Using Widget Configs

1. Open the generated `custom_widgets.json`
2. Copy widget entries to your Noctalia `~/.config/noctalia/settings.json`
3. Add to `bar.widgets.left`, `bar.widgets.center`, or `bar.widgets.right`

### Using Plugin Scaffolds

1. Copy generated plugin folders to `~/.config/noctalia/plugins/`
2. Restart Noctalia or reload plugins
3. Add the bar widget through Noctalia settings

## Testing

Run the unit tests with:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

A sample Waybar config is provided in `samples/waybar-config-sample.jsonc`:

```bash
./waybar_to_noctalia.py samples/waybar-config-sample.jsonc --verbose
```
