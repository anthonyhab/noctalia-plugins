# Apple TV Direct Plugin

Control Apple TV and HomePod devices directly via [`pyatv`](https://github.com/postlund/pyatv)
without routing through Home Assistant. The plugin shells out to a bundled helper
script (`helper/appletv_helper.py`) which in turn executes pyatv commands for
state refreshes and transport controls.

## Features

- Polls playback metadata (title, artist, album, elapsed time, app name).
- Transport controls: play/pause, next/previous, seek.
- Volume + mute/unmute with optimistic caching for devices that do not expose
  current levels.
- Panel UI mirrors the built-in Home Assistant panel styling.
- Optional bar widget with quick play/pause and navigation shortcuts.

## Requirements

1. Install `pyatv` inside a Python environment that Noctalia can access:
   ```bash
   pip install --upgrade pyatv
   ```
2. Pair your machine with the Apple TV/HomePod using `atvremote`:
   ```bash
   atvremote --scan
   atvremote --id <identifier> pair
   ```
   Copy the generated credentials strings for the protocols you paired
   (MRP is required, Companion/AirPlay optional) into the plugin settings.
3. Ensure the helper script is executable (`chmod +x helper/appletv_helper.py`).

## Configuration

Open *Settings → Plugins → Apple TV Direct* and fill out:

- **Display name** – label shown in UI.
- **Device identifier / IP / name** – at least one is required so the helper can
  discover the device.
- **Python executable / helper script path** – defaults to `python3` and the
  bundled helper.
- **Credentials** – paste strings from `atvremote pair`.
- **Polling / scan interval** – adjust to taste.

Use the “Test helper” button to verify connectivity before saving. When the
helper returns a JSON payload the plugin will automatically start polling and
update both the panel and the bar widget.

## Registry metadata

This plugin is declared in `registry.json` with id `appletv` so it can be
published alongside the built-in Home Assistant and Omarchy plugins.
