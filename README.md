# bb's plugins

A personal collection of plugins and tooling for [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell).

## Installation

Plugins are installed through the Noctalia plugin UI:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add: `https://github.com/anthonyhab/noctalia-plugins/`

## Repo contents

### BB Auth

[![BB Auth](bb-auth/preview.png)](bb-auth/README.md)

[BB Auth](bb-auth/README.md) — Use Noctalia as your Polkit + keyring authentication agent. Supports authentication requests from apps, keyring unlock, and GPG pinentry with automatic fallback UI when the shell UI  is unavailable. Requires [bb-auth](https://github.com/anthonyhab/bb-auth).

---

### Home Assistant

[![Home Assistant](homeassistant/preview.png)](homeassistant/README.md)

[Home Assistant](homeassistant/README.md) — Control Home Assistant media players from Noctalia Shell.

---

### Omarchy Theme Sync

[![Omarchy](omarchy/preview.png)](omarchy/README.md)

[Omarchy Integration](omarchy/README.md) — Synchronize Noctalia Color Scheme with Omarchy themes.

---

### SWWW Wallpaper Picker

[![SWWW Wallpaper Picker](swww-picker/preview.png)](swww-picker/README.md)

[SWWW Wallpaper Picker](swww-picker/README.md) — Wallpaper management using `swww`.

---

### Workspace Overview

[![Workspace Overview](workspace-overview/preview.png)](workspace-overview/README.md)

[Workspace Overview](workspace-overview/README.md) — Visual workspace overview with live window previews, drag-and-drop, and keyboard navigation for Hyprland. Supports special/scratchpad workspaces.

Forked from [quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview) by [Shanu-Kumawat](https://github.com/Shanu-Kumawat).


## Validation

Run repository checks before committing:

```bash
./scripts/validate-plugins.sh
```
