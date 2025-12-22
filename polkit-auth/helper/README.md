# noctalia-polkit-agent (helper)

This helper runs as a user-level polkit Authentication Agent and bridges
requests to the Noctalia plugin.

## Build

The helper is implemented in C using `libpolkit-agent-1` so it can use the
official authentication session APIs.

Dependencies (package names vary by distro): `polkit`, `polkit-devel`,
`glib2-devel`, `gio-devel`.

```
make
sudo make install
```

## Expected CLI

The plugin expects the helper to implement the following subcommands:

- `--daemon`:
  - Start the background agent and IPC socket.
- `--ping`:
  - Return exit code 0 if the daemon is running and registered.
- `--next`:
  - Output a single JSON object for the next pending request, or nothing if none.
- `--respond <id> --password <password>`:
  - Send the password for the request with id `<id>`.
  - Use `--password-stdin` to read the password from stdin.
- `--cancel <id>`:
  - Cancel the request.

The socket path defaults to `$XDG_RUNTIME_DIR/noctalia-polkit-agent.sock` and
can be overridden with `--socket`.

## JSON payload example

```
{"type":"request","id":"abc","actionId":"org.freedesktop.policykit.exec","message":"Authentication required","icon":"dialog-password","user":"habibe","details":{}}
```

## Systemd unit

Use the provided `noctalia-polkit-agent.service` as a starting point and update
`ExecStart` to the installed helper path.
