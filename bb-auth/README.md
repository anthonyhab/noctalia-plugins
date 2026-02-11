# BB Auth

Use Noctalia as your Polkit authentication agent. When an app requests elevated privileges, a Noctalia panel opens for password entry.

## Availability

Install and update through the Noctalia plugin directory:

1. Open `Settings -> Plugins -> Sources`
2. Click `Add custom repository`
3. Add `https://github.com/anthonyhab/noctalia-plugins/`

## Setup

### 1. Install dependencies

```bash
# Arch
sudo pacman -S qt6-base polkit polkit-qt6 gcr-4 json-glib cmake pkgconf

# Fedora
sudo dnf install qt6-qtbase-devel polkit polkit-qt6-1-devel gcr-devel json-glib-devel cmake pkgconf-pkg-config

# Debian/Ubuntu
sudo apt install qt6-base-dev polkit libpolkit-qt6-1-dev libgcr-4-dev libjson-glib-dev cmake pkg-config
```

### 2. Build and install bb-auth

If you use AUR, install `bb-auth-git` instead of building manually.

```bash
git clone https://github.com/anthonyhab/noctalia-polkit.git
cd noctalia-polkit
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
```
Use `/usr/local` instead if you want a local install.

### 3. Service bootstrap behavior

When `bb-auth.service` starts, bootstrap automatically:

- fixes stale `gpg-agent` pinentry paths
- stops known competing polkit agents for the current session
- launches fallback auth UI if no shell provider is active

This keeps setup zero-command for most users.

### 4. Enable the systemd service

```bash
systemctl --user daemon-reload
systemctl --user enable --now bb-auth.service
```

### 5. Configure the plugin

The plugin talks to the agent over IPC via:

`$XDG_RUNTIME_DIR/bb-auth.sock`

Make sure the systemd user service is enabled and running. No extra configuration is required in the common path.

The plugin auto-reconnects after daemon restarts and re-subscribes without requiring shell restart.

## Rebrand Notice

Previously known as `polkit-auth` (plugin) and `noctalia-auth` (daemon).
Renamed to BB Auth as part of the "habibe → bibe → BB" branding.
The plugin ID has changed from `polkit-auth` to `bb-auth`.
Reinstall through the Noctalia plugin UI if you were using the previous version.
