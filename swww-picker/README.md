# SWWW Wallpaper Picker

Wallpaper management plugin for Noctalia Shell using `swww`.

## Features

- Next, previous, and random wallpaper controls
- Optional auto-cycle mode with configurable interval
- Multiple transition types with tunable duration/FPS/step
- Shuffle mode and wallpaper history support
- Bar widget and panel integration

## Requirements

- `swww` installed
- `swww-daemon` running in your session

## Availability

Install and update through the Noctalia plugin directory:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add `https://github.com/anthonyhab/noctalia-plugins/`

## Configuration

Open **Settings -> Plugins -> SWWW Wallpaper Picker** and configure:

- Wallpapers directory
- Auto-cycle enabled/interval
- Transition type and transition tuning
- Shuffle mode
- Bar widget label visibility

Default wallpaper directory is `~/Pictures/Wallpapers`.

## Troubleshooting

- If status shows daemon not running, start it manually:

```bash
swww-daemon
```

- If no wallpapers appear, verify your configured directory contains image files.
