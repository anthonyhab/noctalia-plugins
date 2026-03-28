# Scrolling Overview

A fresh, vertical workspace overview for Hyprland in Noctalia Shell.

## Highlights

- Vertical workspace lane (default: 10x1)
- Live window previews via `ScreencopyView`
- Drag a window tile to another workspace slot
- Current-monitor-first behavior with optional all-monitor mode
- Keyboard + mouse wheel workspace navigation while overlay is open

## IPC

Target:

`plugin:scrolling-overview`

Methods:

- `toggle`
- `open`
- `close`
- `togglePanel`
- `openPanel`
- `closePanel`

Examples:

```bash
qs ipc call plugin:scrolling-overview toggle
qs ipc call plugin:scrolling-overview open
qs ipc call plugin:scrolling-overview close
```

## Hyprland keybind example

```ini
bind = SUPER, TAB, exec, qs ipc call plugin:scrolling-overview toggle
```
