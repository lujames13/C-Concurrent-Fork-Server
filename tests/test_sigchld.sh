#!/bin/bash
# Test SIGCHLD handling - verify no zombie processes accumulate

PORT=8084
SERVER_PID=""

# Cleanup function
cleanup() {
    if [ -n "$SERVER_PID" ]; then
        echo "Cleaning up server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null
        wait $SERVER_PID 2>/dev/null
    fi
}

trap cleanup EXIT

echo "=== Story 2.1: SIGCHLD Handler Test ==="
echo ""

# Start server
echo "[1] Starting server_bad on port $PORT..."
./build/server_bad $PORT &
SERVER_PID=$!
sleep 1

if ! ps -p $SERVER_PID > /dev/null; then
    echo "ERROR: Server failed to start"
    exit 1
fi
echo "Server running (PID: $SERVER_PID)"
echo ""

# Connect multiple clients to create and terminate child processes
echo "[2] Connecting 10 clients to create child processes..."
for i in {1..10}; do
    ./build/client 127.0.0.1 $PORT > /dev/null 2>&1 &
done

# Wait for all clients to complete
sleep 2
echo ""

# Check for zombie processes
echo "[3] Checking for zombie processes..."
ZOMBIES=$(ps aux | grep defunct | grep -v grep | wc -l)

echo "Zombie processes found: $ZOMBIES"
echo ""

if [ $ZOMBIES -gt 0 ]; then
    echo "RESULT: ❌ FAILED - Found $ZOMBIES zombie processes"
    echo ""
    echo "Zombie processes:"
    ps aux | grep defunct | grep -v grep
    exit 1
else
    echo "RESULT: ✅ PASSED - No zombie processes found"
    echo ""
    echo "Note: Since server_bad has NO_ROBUST defined, it does NOT include"
    echo "SIGCHLD handling. Zombie processes are expected with this build."
    echo ""
    echo "To test with SIGCHLD handling enabled, use server_good (Story 2.6)"
fi

echo ""
echo "=== Test Complete ==="
