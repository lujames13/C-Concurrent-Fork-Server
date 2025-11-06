#!/bin/bash
# Attack 2: Slowloris Attack
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
#
# Verification:
#   Monitor child process count over time:
#   watch -n 1 'pgrep -P <SERVER_PID> | wc -l'
#   server_good should drop to 0 after ~5 seconds

PORT="${1:-8080}"
NUM_CONNECTIONS=15
DURATION=10

echo "=== Attack 2: Slowloris Attack ==="
echo "Target: localhost:$PORT"
echo "Connections: $NUM_CONNECTIONS (idle, no data sent)"
echo "Duration: ${DURATION}s"
echo ""

echo "Creating $NUM_CONNECTIONS idle connections..."
echo "(These connections will NOT send any data)"
echo ""

for i in $(seq 1 $NUM_CONNECTIONS); do
    (nc localhost $PORT &) &
    NC_PIDS="$NC_PIDS $!"
    sleep 0.1
done

echo "Idle connections established."
echo ""
echo "Expected behavior:"
echo "  - server_bad: Child processes persist indefinitely"
echo "  - server_good: Child processes timeout after ~5 seconds"
echo ""
echo "Monitor child process count with:"
echo "  pgrep -P \$(pgrep -f 'server_(good|bad) $PORT') | wc -l"
echo ""
echo "Waiting ${DURATION} seconds..."

for i in $(seq 1 $DURATION); do
    echo -n "."
    sleep 1
done
echo ""
echo ""

echo "Cleaning up idle connections..."
for pid in $NC_PIDS; do
    kill -9 $pid 2>/dev/null
done

echo ""
echo "Attack complete."
echo ""
echo "For server_good, idle connections should have been cleaned up"
echo "automatically after 5s (SO_RCVTIMEO timeout)."
