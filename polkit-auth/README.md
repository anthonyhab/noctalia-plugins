# Polkit Authentication (Noctalia)

This plugin lets Noctalia act as the Polkit Authentication Agent. When polkit
prompts for authentication, a Noctalia panel opens so you can enter your
password.

## Requirements

- A running helper daemon (`noctalia-polkit-agent`).
- The daemon must be registered as the active polkit agent for the user session.

## Setup (systemd --user)

1. Build or install the helper binary (see `helper/README.md`).
   - Example:
     ```
     cd polkit-auth/helper
     make
     sudo make install
     ```
   - Make sure the `polkit-agent-1` development headers are installed.
2. Copy the unit file and enable it:

```
mkdir -p ~/.config/systemd/user
cp helper/noctalia-polkit-agent.service ~/.config/systemd/user/
# edit ExecStart to point to your installed helper binary
systemctl --user daemon-reload
systemctl --user enable --now noctalia-polkit-agent.service
```

3. Disable other polkit agents so only Noctalia handles prompts. If you were
   starting GNOME's agent on login, remove it:

```
# Example: remove from your session autostart/exec-once
# exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
```

## Plugin configuration

Open the plugin settings and set:

- Helper binary path: the absolute path to `noctalia-polkit-agent`.
- Poll interval: how quickly Noctalia checks for requests (ms).

## Protocol notes

The helper should expose a CLI that supports:

- `--ping`: exit 0 when the daemon is running and registered.
- `--next`: print a JSON request (or nothing) for the next pending auth prompt.
- `--respond <id>`: send the password via stdin.
- `--cancel <id>`: cancel the request.

For security, the plugin writes the password to stdin.

## Security

- Passwords are never stored in plugin settings.
- Avoid logging stdout/stderr that could contain password data.
- Prefer stdin for password transport (see helper TODO).
