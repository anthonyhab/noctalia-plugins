# Bibe Plugins

This repo contains community plugins for Noctalia. Each plugin lives in its own
folder (for example: `appletv`, `homeassistant`, `omarchy`). The top-level
`registry.json` lists everything published here.

## Install

1. Clone this repo.
2. Symlink the plugins into Noctalia:
   ```
   mkdir -p ~/.config/noctalia/plugins
   ln -sfn /path/to/bibe-plugins/* ~/.config/noctalia/plugins/
   ```
3. Restart Noctalia and enable the plugins in Settings.

## Notes

- Screenshots will be added per plugin.
- Each plugin folder includes its own README with setup steps and requirements.
