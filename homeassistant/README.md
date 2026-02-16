![Home Assistant](preview.png)

# Home Assistant Plugin

Control Home Assistant media players from Noctalia Shell.

## Features

- Bar widget controls for media playback
- Panel UI with playback, seek, and volume controls
- Shuffle and repeat actions
- Optional default media player selection

## Availability

Install and update through the Noctalia plugin directory:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add `https://github.com/anthonyhab/noctalia-plugins/`

## Setup

1. In Home Assistant, create a long-lived access token:
   - Profile -> Security -> Long-Lived Access Tokens
2. Open **Noctalia Settings -> Plugins -> Home Assistant**.
3. Configure:
   - Home Assistant URL (for example `http://homeassistant.local:8123`)
   - Access token
   - Default media player (optional)

## Notes

- This plugin uses Home Assistant REST API calls.
- Keep your token private and rotate it if compromised.
