# Bibe Plugins

A small collection of plugins and tooling for Noctalia Shell.

## Installation

Plugins are installed through the Noctalia plugin UI:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add: `https://github.com/anthonyhab/noctalia-plugins/`

## Repo contents

- `omarchy/` - Omarchy integration plugin that syncs Omarchy theme colors into Noctalia so the shell follows Omarchy themes.
- `homeassistant/` - Home Assistant plugin that surfaces devices and controls in Noctalia panels/widgets.
- `swww-picker/` - Wallpaper picker and auto-cycler powered by `swww`.
- `polkit-auth/` - Polkit authentication integration for Noctalia panels.
- `waybar-converter/` - Utility to help convert Waybar configs/themes into Noctalia compatible plugin.
  
## Demo videos


#### Omarchy Integration
https://github.com/user-attachments/assets/d1e9bd2c-7594-4c73-b744-59590e3d8b6a


#### Home Assistant
https://github.com/user-attachments/assets/37c017b4-bf07-4e77-9bcf-44638dec2ef8

## Validation

Run repository checks before committing:

```bash
./scripts/validate-plugins.sh
```
