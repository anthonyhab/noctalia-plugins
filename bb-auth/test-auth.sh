#!/usr/bin/env bash
set -euo pipefail

SOCKET="${XDG_RUNTIME_DIR}/bb-auth.sock"

send() {
    local payload="$1"
    echo "$payload" | nc -U "$SOCKET" -w 5
}

if [ ! -S "$SOCKET" ]; then
    echo "Socket not found: $SOCKET"
    echo "Ensure bb-auth.service is running"
    exit 1
fi

echo "=== Noctalia Auth v2 Smoke Test ==="
echo

echo "1) Ping daemon"
PONG=$(send '{"type":"ping"}')
echo "Response: $PONG"
if [[ "$PONG" != *'"type":"pong"'* ]]; then
    echo "FAIL: daemon did not reply with pong"
    exit 1
fi
echo "PASS: daemon reachable"
echo

echo "2) Trigger an auth request"
echo "In another terminal run: pkexec true"
echo
echo "Waiting for next session event (long-poll, up to 30s)..."
EVENT=$(timeout 30s sh -c "echo '{\"type\":\"next\"}' | nc -U '$SOCKET' -w 30") || true

if [ -z "$EVENT" ]; then
    echo "FAIL: no event received (timeout)"
    exit 1
fi

echo "Response: $EVENT"
if [[ "$EVENT" != *'"type":"session.'* ]]; then
    echo "FAIL: expected a session event"
    exit 1
fi

echo "PASS: received session event"
echo
echo "=== Smoke test complete ==="
