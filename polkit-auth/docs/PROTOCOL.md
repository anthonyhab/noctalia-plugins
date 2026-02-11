# Noctalia Auth Protocol v2

## Overview

The Noctalia Auth Protocol v2 is a session-based IPC protocol between the daemon (`noctalia-auth`) and the UI plugin (`polkit-auth`).

- Transport: line-delimited JSON over Unix socket
- Socket path: `${XDG_RUNTIME_DIR}/noctalia-auth.sock`
- Session ownership: daemon is the source of truth for lifecycle and state transitions

## Session Lifecycle

### 1) `session.created`

Emitted once when a logical auth flow starts.

```json
{
  "type": "session.created",
  "id": "unique-session-id",
  "source": "polkit",
  "context": {
    "message": "Authentication required",
    "requestor": {
      "name": "Application Name",
      "icon": "icon-name",
      "pid": 1234
    }
  }
}
```

### 2) `session.updated`

Emitted when the same session needs input again or has retry feedback.

```json
{
  "type": "session.updated",
  "id": "unique-session-id",
  "state": "prompting",
  "prompt": "Password:",
  "echo": false,
  "error": "Optional retry error",
  "curRetry": 1,
  "maxRetries": 3
}
```

Notes:
- Retries must be modeled as `session.updated` on the same `id`
- `curRetry` and `maxRetries` are primarily used by pinentry flows

### 3) `session.closed`

Emitted exactly once for terminal outcomes.

```json
{
  "type": "session.closed",
  "id": "unique-session-id",
  "result": "success",
  "error": "Optional terminal error"
}
```

`result` values:
- `success`
- `cancelled`
- `error`

## Client Commands

### `session.respond`

Submit a user response for a prompting session.

```json
{
  "type": "session.respond",
  "id": "unique-session-id",
  "response": "secret-payload"
}
```

Acknowledgement:
- Success: `{"type":"ok"}`
- Failure: `{"type":"error","message":"..."}`

Common failure causes:
- unknown session id
- session not accepting input (invalid state)
- source mismatch
- not active UI provider

### `session.cancel`

Cancel a session.

```json
{
  "type": "session.cancel",
  "id": "unique-session-id"
}
```

Acknowledgement:
- Success: `{"type":"ok"}`
- Failure: `{"type":"error","message":"..."}`

## Utility Messages

### `ping`

Request:

```json
{"type":"ping"}
```

Response:

```json
{
  "type":"pong",
  "version":"2.0",
  "capabilities":["polkit","keyring","pinentry"],
  "bootstrap": {
    "mode":"session",
    "pinentry_path":"/usr/libexec/pinentry-noctalia",
    "timestamp": 1739198208
  },
  "provider": {
    "id":"provider-id",
    "name":"polkit-auth",
    "kind":"quickshell",
    "priority":100
  }
}
```

`bootstrap` is optional and reports startup self-heal/conflict policy state.
`provider` is optional and reports the currently active UI provider.

### UI provider registration

UI frontends should register so the daemon can enforce active-provider ownership.

Register request:

```json
{
  "type":"ui.register",
  "name":"polkit-auth",
  "kind":"quickshell",
  "priority":100
}
```

Register response:

```json
{
  "type":"ui.registered",
  "id":"provider-id",
  "active":true,
  "priority":100
}
```

`active` is computed after provider election and is authoritative for the registering client.

Heartbeat request:

```json
{
  "type":"ui.heartbeat",
  "id":"provider-id"
}
```

Unregister request:

```json
{
  "type":"ui.unregister"
}
```

Acknowledgement:
- Success: `{"type":"ok"}`
- Failure: `{"type":"error","message":"Provider not registered"}`

Daemon active-provider event:

```json
{
  "type":"ui.active",
  "active":true,
  "id":"provider-id",
  "name":"polkit-auth",
  "kind":"quickshell",
  "priority":100
}
```

Notes:
- `ui.active` is a broadcast snapshot for all subscribers/providers.
- When `active=true`, `id` is the elected provider.
- When `active=false`, no provider is currently elected; clients should remain connected and wait for the next `ui.registered` / `ui.active` update.

### `next`

Long-poll one queued event.

Request:

```json
{"type":"next"}
```

Response:
- one `session.*` event (request blocks until an event is available)

## Source Contexts

### Polkit
- `message`
- `actionId`
- `user`
- `details` (optional)

### Keyring
- `message`
- `keyringName`

### Pinentry
- `description`
- `keyinfo`
- `curRetry`
- `maxRetries`
- `confirmOnly`
- `repeat`

## Pinentry Notes

- Pinentry retries should not force close+recreate loops
- Wrong password should emit `session.updated` with `error` and stay in the same session
- A terminal result (`success`, `cancelled`, or terminal `error`) must emit `session.closed` once
