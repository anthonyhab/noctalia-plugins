# Noctalia Auth v2 - Implementation Plan

## Overview

This document describes the complete refactoring of the noctalia-auth system from
an ad-hoc message-based protocol to a structured Session-based architecture.

**Goal:** Fix the "stuck on verifying" bug and establish a solid foundation for
authentication handling across polkit, keyring, and pinentry.

**Repositories:**
- Agent (C++): `/home/habibe/Projects/noctalia-polkit`
- Plugin (QML): `/home/habibe/Projects/bibe-plugins/polkit-auth`

---

## Problem Statement

### Root Cause
The plugin ignores `request_prompt` messages from the agent. When PAM asks for a
password, the agent sends `{"type": "request_prompt", ...}` but the plugin only
handles `{"type": "request", ...}`. This causes the UI to remain stuck in
"verifying" state indefinitely.

### Secondary Issues
1. **Field name mismatch**: Agent sends `kind`/`actor`/`error`, plugin expects `source`/`requestor`/`warning`
2. **No retry handling**: Plugin state machine is linear, cannot transition `verifying` → `prompting`
3. **Documentation drift**: PROTOCOL.md describes unimplemented session.* types
4. **Inconsistent sources**: Polkit, keyring, and pinentry use different message structures

---

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Protocol version | v2 only (clean cut) | No legacy cruft, simpler implementation |
| Scope | All 3 sources | Consistent API for polkit, keyring, pinentry |
| State ownership | Agent owns Session | Single source of truth |
| Backward compat | None | Plugin and agent deploy together |

---

## v2 Protocol Specification

### Message Types

#### Server → Client

| Type | Fields | Description |
|------|--------|-------------|
| `session.created` | `id, source, context` | New auth session started |
| `session.updated` | `id, state, prompt?, error?` | Session state changed |
| `session.closed` | `id, result` | Session ended |
| `pong` | `version, capabilities` | Response to ping |

#### Client → Server

| Type | Fields | Description |
|------|--------|-------------|
| `session.respond` | `id, response` | Submit password |
| `session.cancel` | `id` | Cancel session |
| `ping` | - | Check availability |
| `next` | - | Long-poll for events |

### Session States

```
┌──────────┐  session.created   ┌───────────┐
│   IDLE   │ ─────────────────→ │ PROMPTING │ ←─────────────┐
└──────────┘                    └─────┬─────┘               │
                                      │                     │
                              respond │                     │
                                      ↓                     │
                                ┌───────────┐   error       │
                                │ VERIFYING │ ──────────────┘
                                └─────┬─────┘   (retry)
                                      │
                              success │ cancelled
                                      ↓
                                ┌───────────┐
                                │  CLOSED   │
                                └───────────┘
```

### Source Types

| Source | Context Fields |
|--------|----------------|
| `polkit` | `message, actionId, user, details` |
| `keyring` | `message, keyringName` |
| `pinentry` | `description, keyinfo, curRetry, maxRetries, confirmOnly` |

### Example Flow

```json
← {"type":"session.created","id":"abc123","source":"polkit","context":{"message":"Authentication required","actionId":"org.freedesktop.policykit.exec","requestor":{"name":"pkexec","icon":"system-run"}}}
← {"type":"session.updated","id":"abc123","state":"prompting","prompt":"Password: "}
→ {"type":"session.respond","id":"abc123","response":"wrongpassword"}
← {"type":"session.updated","id":"abc123","state":"prompting","prompt":"Password: ","error":"Authentication failed"}
→ {"type":"session.respond","id":"abc123","response":"correctpassword"}
← {"type":"session.closed","id":"abc123","result":"success"}
```

---

## Implementation Checklist

### Phase 1: Agent Core (C++)
- [ ] Create Session.hpp
- [ ] Create Session.cpp
- [ ] Update CMakeLists.txt
- [ ] Update Agent.hpp
- [ ] Update Agent.cpp
- [ ] Update PolkitListener.cpp
- [ ] Update KeyringManager.cpp
- [ ] Update PinentryManager.cpp
- [ ] Update IpcServer.cpp

### Phase 2: Plugin (QML)
- [ ] Update Main.qml message handlers
- [ ] Update AuthContent.qml retry handling
- [ ] Rewrite PROTOCOL.md

### Phase 3: Testing
- [ ] Create test-auth.sh
- [ ] Build agent
- [ ] Test integration

---

## Verification Checklist

After implementation, verify each item:

### Agent
- [ ] `Session.hpp` and `Session.cpp` compile without warnings
- [ ] `ping` returns `{"type":"pong","version":"2.0","capabilities":[...]}`
- [ ] Polkit auth triggers `session.created` followed by `session.updated`
- [ ] Wrong password triggers `session.updated` with `error` field
- [ ] Correct password triggers `session.closed` with `result:"success"`
- [ ] Cancel triggers `session.closed` with `result:"cancelled"`
- [ ] Keyring unlock uses same session.* protocol
- [ ] GPG passphrase uses same session.* protocol

### Plugin
- [ ] UI opens on `session.created`
- [ ] Password field populates from `session.updated` prompt
- [ ] Submitting password sends `session.respond`
- [ ] Wrong password shows error and shakes UI (on `session.updated` with error)
- [ ] Correct password shows success state
- [ ] Cancel button sends `session.cancel`
- [ ] Multiple queued sessions work correctly

### Integration
- [ ] `pkexec echo test` completes successfully
- [ ] `secret-tool` keyring unlock works
- [ ] GPG signing with passphrase works
- [ ] Retry flow works (wrong password → retry → correct password)

---

## Rollback Plan

If issues arise:
1. Agent: Revert to previous commit, rebuild, restart service
2. Plugin: Revert Main.qml and AuthContent.qml changes
3. Both components must be rolled back together (v2 protocol is incompatible with v1)
