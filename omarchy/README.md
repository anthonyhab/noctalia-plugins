![Omarchy](preview.png)

# Omarchy Integration

Sync Noctalia colors from your active Omarchy theme and switch themes directly from Noctalia.

## Availability

Install and update through the Noctalia plugin directory:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add `https://github.com/anthonyhab/noctalia-plugins/`

## What It Does

- syncs Noctalia color schemes from Omarchy themes
- ships cached palettes for instant theme switches
- falls back to live conversion if a cached palette is unavailable
- exposes theme controls through Settings, Panel, Bar Widget, and Control Center entry points
- supports search plus light/dark theme filtering in the panel

## Requirements

- Omarchy installed on the same user session
- your Omarchy config directory available at `~/.config/omarchy/` or a custom path
- a working theme-set command, usually `~/.local/share/omarchy/bin/omarchy-theme-set`

## Setup

1. Install the plugin from this repository.
2. Open **Noctalia Settings -> Plugins -> Omarchy Integration**.
3. Enable the plugin.
4. Confirm the Omarchy config directory if you do not use the default location.
5. If needed, set **Theme-set command** to your local `omarchy-theme-set` path.
6. Optionally add the bar widget or control center button for quick access.

## Usage

- Open the panel from the bar widget or control center button.
- Search for a theme or cycle between all, light, and dark filters.
- Apply a theme to switch Omarchy and sync Noctalia colors together.
- Disable the plugin to restore the saved Noctalia color preferences that were active before Omarchy sync.

## Notes

- Cached palettes keep theme switching fast during normal use.
- The plugin stores its user preference backup under the Noctalia config directory, not inside the plugin directory.
- If your Omarchy install lives in a nonstandard location, update the settings fields instead of editing plugin files.
