![Home Assistant](preview.png)

# Home Assistant

Control Home Assistant media players from Noctalia with a compact bar widget and a fuller panel UI.

## Availability

Install and update through the Noctalia plugin directory:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add `https://github.com/anthonyhab/noctalia-plugins/`

## Requirements

- A reachable Home Assistant instance
- A Home Assistant long-lived access token

## Features

- Bar widget controls for media playback
- Panel UI with playback, seek, and volume controls
- Shuffle and repeat actions
- Optional default media player selection
- IPC commands for keybind-driven control

## Quick Start

1. In Home Assistant, create a long-lived access token:
   - Profile -> Security -> Long-Lived Access Tokens
2. Open **Noctalia Settings -> Plugins -> Home Assistant**.
3. Configure:
   - Home Assistant URL (for example `http://homeassistant.local:8123`)
   - Access token
   - Default media player (optional)

## IPC / Keybinds

Control the plugin from the command line or Hyprland keybinds:

```bash
qs-dev ipc call homeassistant volumeUp
qs-dev ipc call homeassistant volumeDown
qs-dev ipc call homeassistant setVolume "0.5"   # 0.0–1.0
qs-dev ipc call homeassistant toggleMute
qs-dev ipc call homeassistant playPause
qs-dev ipc call homeassistant next
qs-dev ipc call homeassistant previous
qs-dev ipc call homeassistant stop
qs-dev ipc call homeassistant toggleShuffle
qs-dev ipc call homeassistant cycleRepeat
qs-dev ipc call homeassistant selectPlayer "media_player.my_speaker"
qs-dev ipc call homeassistant refresh
qs-dev ipc call homeassistant togglePanel
```

Example Hyprland binds (`~/.config/hypr/media.conf`):

```ini
$osdclient = qs-dev ipc call

bindeld = CTRL SHIFT, XF86AudioRaiseVolume, HA volume up,   exec, $osdclient homeassistant volumeUp
bindeld = CTRL SHIFT, XF86AudioLowerVolume, HA volume down, exec, $osdclient homeassistant volumeDown
bindld  = CTRL SHIFT, XF86AudioMute,        HA mute toggle, exec, $osdclient homeassistant toggleMute
bindld  = CTRL SHIFT, F8,                   HA play/pause,  exec, $osdclient homeassistant playPause
bindld  = CTRL SHIFT, F9,                   HA next track,  exec, $osdclient homeassistant next
bindld  = CTRL SHIFT, F7,                   HA prev track,  exec, $osdclient homeassistant previous
```

The namespaced form `plugin:homeassistant` is also supported as an alias.

## Notes

- This plugin uses Home Assistant REST API calls.
- Keep your token private and rotate it if compromised.
