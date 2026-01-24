#!/bin/bash
# Noctalia Auth v2 Test Harness

SOCKET="${XDG_RUNTIME_DIR}/noctalia-auth.sock"

send() {
    echo "$1" | nc -U "$SOCKET" -w 1
}

echo "=== Noctalia Auth v2 Test Suite ==="
echo ""

echo "Test 1: Ping/Pong with version"
PONG=$(send '{"type":"ping"}')
echo "Response: $PONG"
if echo "$PONG" | grep -q '"version":"2.0"'; then
    echo "✓ PASS: Version 2.0 confirmed"
else
    echo "✗ FAIL: Expected version 2.0"
fi
echo ""

echo "Test 2: Poll for events (should be empty)"
NEXT=$(send '{"type":"next"}')
echo "Response: $NEXT"
if echo "$NEXT" | grep -q '"type":"empty"'; then
    echo "✓ PASS: Empty queue"
else
    echo "? INFO: Got event (may have pending auth)"
fi
echo ""

echo "Test 3: Trigger polkit auth"
echo "Run in another terminal: pkexec echo 'test'"
echo "Then press Enter to continue..."
read

NEXT=$(send '{"type":"next"}')
echo "Response: $NEXT"
if echo "$NEXT" | grep -q '"type":"session.created"'; then
    echo "✓ PASS: Got session.created"
    SESSION_ID=$(echo "$NEXT" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo "  Session ID: $SESSION_ID"
else
    echo "✗ FAIL: Expected session.created"
    exit 1
fi

NEXT=$(send '{"type":"next"}')
echo "Response: $NEXT"
if echo "$NEXT" | grep -q '"type":"session.updated"'; then
    echo "✓ PASS: Got session.updated with prompt"
else
    echo "✗ FAIL: Expected session.updated"
fi
echo ""

echo "Test 4: Submit wrong password"
send "{\"type\":\"session.respond\",\"id\":\"$SESSION_ID\",\"response\":\"wrongpassword\"}"
sleep 1
NEXT=$(send '{"type":"next"}')
echo "Response: $NEXT"
if echo "$NEXT" | grep -q '"error"'; then
    echo "✓ PASS: Got error in session.updated (retry)"
else
    echo "? INFO: May have succeeded or different behavior"
fi
echo ""

echo "Test 5: Cancel session"
send "{\"type\":\"session.cancel\",\"id\":\"$SESSION_ID\"}"
sleep 1
NEXT=$(send '{"type":"next"}')
echo "Response: $NEXT"
if echo "$NEXT" | grep -q '"type":"session.closed"'; then
    echo "✓ PASS: Session closed"
else
    echo "? INFO: Session may have already closed"
fi

echo ""
echo "=== Test Suite Complete ==="
