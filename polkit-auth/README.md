# Polkit Authentication

Use Noctalia as your Polkit authentication agent. When an app requests elevated privileges, a Noctalia panel opens for password entry.

## Setup

### 1. Install dependencies

```bash
# Arch
sudo pacman -S qt6-base polkit-qt6 hyprutils cmake

# Fedora
sudo dnf install qt6-qtbase-devel polkit-qt6-1-devel hyprutils-devel cmake

# Debian/Ubuntu
sudo apt install qt6-base-dev libpolkit-qt6-1-dev cmake
# hyprutils may need to be built from source
```

### 2. Build and install noctalia-polkit

```bash
git clone https://github.com/anthonyhab/noctalia-polkit.git
cd noctalia-polkit
cmake -B build
cmake --build build
sudo cmake --install build
```

### 3. Disable other polkit agents

Remove any existing polkit agent from your session autostart. For example, in Hyprland:

```bash
# Remove this line from ~/.config/hypr/hyprland.conf if present:
# exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
```

### 4. Enable the systemd service

```bash
systemctl --user enable --now hyprpolkitagent.service
```

### 5. Configure the plugin

In Noctalia's plugin settings, set the helper path to the installed binary (typically `/usr/local/libexec/hyprpolkitagent`).
