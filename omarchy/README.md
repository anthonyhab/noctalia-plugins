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
- `omarchy theme set` and `omarchy theme list` available through the Omarchy dispatcher
- for older installs, legacy `omarchy-theme-set` and `omarchy-theme-list` binaries available from `OMARCHY_PATH/bin` or the standard `~/.local/share/omarchy/bin/` path

## Setup

1. Install the plugin from this repository.
2. Open **Noctalia Settings -> Plugins -> Omarchy Integration**.
3. Enable the plugin.
4. Confirm the Omarchy config directory if you do not use the default location.
5. Leave **Theme-set command** blank to use `omarchy theme set`, or set it to a custom executable wrapper if you need one.
6. Optionally add the bar widget or control center button for quick access.

## Usage

- Open the panel from the bar widget or control center button.
- Search for a theme or cycle between all, light, and dark filters.
- Apply a theme to switch Omarchy and sync Noctalia colors together.
- Disable the plugin to restore the saved Noctalia color preferences that were active before Omarchy sync.

## Notes

- Cached palettes keep theme switching fast during normal use.
- The **Theme-set command** setting is treated as an executable path for custom wrappers only. The plugin otherwise uses `omarchy theme set` and falls back to legacy binaries for older installs.
- The plugin reads `current/theme/colors.toml` for palette data.
- The plugin prefers `current/theme/hyprland.lua` for the active border color and falls back to legacy `current/theme/hyprland.conf` when needed.
- Fast custom wrappers are supported, for example `~/.local/bin/omarchy-theme-set-fast`.
- If your Omarchy install lives in a nonstandard location, set `OMARCHY_PATH` or update the settings fields instead of editing plugin files.
