# Omarchy Feedback

Tiny Omarchy runtime state indicators for Noctalia bar widgets.

## Included indicators

- Voxtype dictation state (`recording`, `transcribing`)
- Active screen recording (`gpu-screen-recorder`)
- Idle lock disabled (`hypridle` not running)
- Omarchy update available

## Not included

- Notification silencing (Mako)
- Weather
- Omarchy launcher icon

## Requirements

- Omarchy installed and discoverable via `OMARCHY_PATH`, `omarchy` on `PATH`, or the standard `~/.local/share/omarchy` install
- Omarchy dispatcher commands available, or legacy helper binaries available from the detected install
- Voxtype, `gpu-screen-recorder`, and `hypridle` available if you want their respective indicators
