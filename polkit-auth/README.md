# Polkit Authentication

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
sudo pacman -S qt6-base polkit polkit-qt6 hyprutils cmake pkgconf

# Fedora
sudo dnf install qt6-qtbase-devel polkit polkit-qt6-1-devel hyprutils-devel cmake pkgconf-pkg-config

# Debian/Ubuntu
sudo apt install qt6-base-dev polkit libpolkit-qt6-1-dev cmake pkg-config
# hyprutils may need to be built from source
```

### 2. Build and install noctalia-polkit

```bash
git clone https://github.com/anthonyhab/noctalia-polkit.git
cd noctalia-polkit
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
```
Use `/usr/local` instead if you want a local install.

### 3. Disable other polkit agents

Remove any existing polkit agent from your session autostart. For example, in Hyprland:

```bash
# Remove this line from ~/.config/hypr/hyprland.conf if present:
# exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
```

### 4. Enable the systemd service

```bash
systemctl --user daemon-reload
systemctl --user enable --now noctalia-polkit.service
```

### 5. Configure the plugin

The plugin talks to the agent over IPC via:

`$XDG_RUNTIME_DIR/noctalia-polkit-agent.sock`

Make sure the systemd user service is enabled and running. No extra configuration is required.
