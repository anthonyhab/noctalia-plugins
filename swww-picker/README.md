![AWWW Wallpaper Picker](preview.png)

# AWWW Wallpaper Picker

Wallpaper management for Noctalia using `awww`, with quick controls in both the bar and panel.

## Features

- Next, previous, and random wallpaper controls
- Optional auto-cycle mode with configurable interval
- Multiple transition types with tunable duration/FPS/step
- Shuffle mode and wallpaper history support
- Bar widget and panel integration

## Requirements

- `awww` installed
- `awww-daemon` running in your session

## Availability

Install and update through the Noctalia plugin directory:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add `https://github.com/anthonyhab/noctalia-plugins/`

## Quick Start

Open **Settings -> Plugins -> AWWW Wallpaper Picker** and configure:

- Wallpapers directory
- Auto-cycle enabled/interval
- Transition type and transition tuning
- Shuffle mode
- Bar widget label visibility

Default wallpaper directory is `~/Pictures/Wallpapers`.

## Configuration

The plugin supports:

- Manual next, previous, and random actions
- Auto-cycle with interval control
- Transition tuning for type, duration, FPS, and step
- Shuffle mode and history-aware browsing
- Optional wallpaper name display in the bar

## Troubleshooting

- If status shows daemon not running, start it manually:

```bash
awww-daemon
```

- If no wallpapers appear, verify your configured directory contains image files.
