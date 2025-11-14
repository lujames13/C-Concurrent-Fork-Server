#!/bin/bash
# Attack 3: SIGPIPE Attack
#
# Purpose:
#   Test SIGPIPE handling by connecting and immediately disconnecting.
#   When the server tries to write to a closed socket, it receives a
#   SIGPIPE signal. Without proper handling (signal(SIGPIPE, SIG_IGN)),
#   this will crash the child process.
#
# Expected Results:
#   - server_bad (NO_ROBUST): Child processes will crash on SIGPIPE
#     (terminated with signal 13 / exit code 141)
#   - server_good: Child processes ignore SIGPIPE and handle the
#     EPIPE error gracefully
#
# Verification:
#   Check if parent server is still running after the attack:
#   pgrep -f 'server_(good|bad)'
#   Server should remain stable despite rapid disconnects
#
# Usage:
#   ./attack_3_sigpipe.sh [HOST] [PORT]
#   
# Examples:
#   ./attack_3_sigpipe.sh                    # localhost:8080 (default)
#   ./attack_3_sigpipe.sh localhost 8080     # explicit localhost
#   ./attack_3_sigpipe.sh 127.0.0.1 8080     # explicit IP

# Parse command-line arguments
HOST="${1:-localhost}"
PORT="${2:-8080}"
NUM_CONNECTIONS=20

echo "=== Attack 3: SIGPIPE Attack ==="
echo "Target: $HOST:$PORT"
echo "Connections: $NUM_CONNECTIONS (rapid disconnect)"
echo ""

# Verify server is reachable before attack
echo "[Pre-check] Verifying server is listening..."
if ! nc -z -w 1 $HOST $PORT 2>/dev/null; then
    echo "ERROR: Cannot connect to $HOST:$PORT"
    echo "Please ensure server is running: ./build/server_bad $PORT"
    exit 1
fi
echo "✓ Server is reachable"
echo ""

echo "Launching $NUM_CONNECTIONS rapid connect/disconnect cycles..."
echo "(Sending GET_SYS_INFO then immediately closing connection)"
echo ""

# Strategy: Send request but close socket immediately
# This creates a race condition where server tries to write() to closed socket
for i in $(seq 1 $NUM_CONNECTIONS); do
    # Method 1: Use timeout to kill connection quickly (most reliable)
    (echo "GET_SYS_INFO"; sleep 0.01) | timeout 0.05 nc $HOST $PORT >/dev/null 2>&1 &
    
    # Small delay to space out attacks
    sleep 0.05
done

echo "Waiting for all connection attempts to complete..."
sleep 2

# Clean up any lingering nc processes
pkill -9 nc 2>/dev/null

echo ""
echo "=== Attack Complete ==="
echo ""

# Provide verification commands
echo "Verification Steps:"
echo ""
echo "1. Check if parent server is still running:"
echo "   pgrep -af 'server_(good|bad) $PORT'"
echo ""
echo "2. Check system logs for SIGPIPE signals (may require sudo):"
echo "   dmesg | tail -20 | grep -i sig"
echo ""
echo "3. For server_good with debug mode, check for EPIPE logs:"
echo "   (Should see: 'write() error: Broken pipe (EPIPE)')"
echo ""

# Automatic verification
echo "=== Automatic Verification ==="
echo ""

# Find server process
SERVER_PID=$(pgrep -f "server_(good|bad) $PORT" | head -1)

if [ -n "$SERVER_PID" ]; then
    echo "✓ Parent server still running (PID: $SERVER_PID)"
    
    # Count child processes
    CHILD_COUNT=$(pgrep -P $SERVER_PID 2>/dev/null | wc -l)
    echo "  Current child processes: $CHILD_COUNT"
    
    # Test if server is still responsive
    echo ""
    echo "Testing if server is still responsive..."
    RESPONSE=$(echo "GET_SYS_INFO" | nc -w 2 $HOST $PORT 2>/dev/null)
    
    if [ -n "$RESPONSE" ]; then
        echo "✓ Server is still accepting connections"
        echo "  Response: ${RESPONSE:0:60}..."
    else
        echo "✗ Server not responding (may be overloaded or crashed)"
    fi
else
    echo "✗ Server process not found!"
    echo "  This may indicate:"
    echo "  - server_bad crashed completely (unexpected)"
    echo "  - Server was stopped manually"
    echo "  - Wrong port number"
fi

echo ""
echo "=== Expected Behavior ==="
echo ""
echo "server_bad (NO_ROBUST):"
echo "  • Child processes crash when write() to closed socket"
echo "  • May see 'Broken pipe' errors in terminal"
echo "  • Exit code 141 (128 + 13 SIGPIPE) for crashed children"
echo "  • Parent should still be running"
echo ""
echo "server_good (with ROBUST):"
echo "  • All child processes handle EPIPE gracefully"
echo "  • Debug logs show: 'write() error: Broken pipe (EPIPE)'"
echo "  • Child processes exit normally with code 0"
echo "  • Parent continues accepting connections normally"
echo ""

# Display process tree if available
if command -v pstree >/dev/null 2>&1 && [ -n "$SERVER_PID" ]; then
    echo "=== Current Process Tree ==="
    pstree -p $SERVER_PID 2>/dev/null || ps --forest -g $(ps -o sid= -p $SERVER_PID)
    echo ""
fi

echo "Attack script finished."
