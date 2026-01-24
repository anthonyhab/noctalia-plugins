# Noctalia Auth Protocol v2

## Overview

The Noctalia Auth Protocol v2 is a session-based communication protocol between the authentication agent (`noctalia-auth`) and the UI client (`polkit-auth`).

All messages are line-delimited JSON objects sent over a Unix domain socket at `${XDG_RUNTIME_DIR}/noctalia-auth.sock`.

---

## Session Lifecycle

### 1. Creation (`session.created`)
Sent by the agent when a new authentication request is received (Polkit, Keyring, or Pinentry).

```json
{
  "type": "session.created",
  "id": "unique-session-id",
  "source": "polkit" | "keyring" | "pinentry",
  "context": {
    "message": "Authentication required",
    "requestor": {
      "name": "Application Name",
      "icon": "icon-name",
      "pid": 1234
    },
    ... source-specific fields
  }
}
```

### 2. Prompting (`session.updated`)
Sent by the agent when user input (e.g., password) is required.

```json
{
  "type": "session.updated",
  "id": "unique-session-id",
  "state": "prompting",
  "prompt": "Password: ",
  "echo": false,
  "error": "Optional error message for retries"
}
```

### 3. Response (`session.respond`)
Sent by the client to submit the user's response.

```json
{
  "type": "session.respond",
  "id": "unique-session-id",
  "response": "secret-payload"
}
```

### 4. Completion (`session.closed`)
Sent by the agent when the session is finished.

```json
{
  "type": "session.closed",
  "id": "unique-session-id",
  "result": "success" | "cancelled" | "error"
}
```

---

## Utility Messages

### Ping
Client checks if the agent is alive and retrieves version/capabilities.

**Request:** `{"type": "ping"}`
**Response:** `{"type": "pong", "version": "2.0", "capabilities": ["polkit", "keyring", "pinentry"]}`

### Next (Long Polling)
Client polls for the next pending event in the agent's queue.

**Request:** `{"type": "next"}`
**Response:** One of the `session.*` events, or `{"type": "empty"}` if no events are pending.

---

## Source Contexts

### Polkit
- `message`: Action description
- `actionId`: The Polkit action ID
- `user`: Target user for authentication

### Keyring
- `keyringName`: The name of the keyring being unlocked

### Pinentry
- `description`: GPG prompt description
- `keyinfo`: Internal GPG key identifier
- `curRetry`: Current attempt number
- `maxRetries`: Maximum allowed attempts
- `confirmOnly`: If true, only a Yes/No confirmation is needed
