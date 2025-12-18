This is a development copy of a Home Assistant integration plugin for Noctalia.

**Install**

- Copy this folder to `~/.config/noctalia/plugins/homeassistant/`
- Ensure `~/.config/noctalia/plugins.json` enables the plugin (or enable it in Settings → Plugins)

**Setup**

1. In Home Assistant, go to Profile → Security → Long-Lived Access Tokens
2. Create a new token and copy it
3. In Noctalia Settings → Plugins → Home Assistant, enter:
   - Your Home Assistant URL (e.g., http://homeassistant.local:8123)
   - The access token you created
4. Select your default media player (optional)

**Features**

- Control media players from the bar widget
- Full media control panel with playback controls, volume, and seek
- Real-time status updates via polling
- Support for multiple media players
- Shuffle and repeat controls

This plugin uses HTTP REST API calls to communicate with Home Assistant.