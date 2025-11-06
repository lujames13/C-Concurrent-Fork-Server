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
#   - server_bad (NO_ROBUST): Child processes may crash on SIGPIPE
#     (depends on timing - if write happens after client disconnect)
#   - server_good: Child processes ignore SIGPIPE and handle the
#     EPIPE error gracefully
#
# Verification:
#   Check if parent server is still running after the attack:
#   pgrep -f 'server_(good|bad)'
#   Server should remain stable despite rapid disconnects

PORT="${1:-8080}"
NUM_CONNECTIONS=20

echo "=== Attack 3: SIGPIPE Attack ==="
echo "Target: localhost:$PORT"
echo "Connections: $NUM_CONNECTIONS (rapid disconnect)"
echo ""

echo "Launching $NUM_CONNECTIONS rapid connect/disconnect cycles..."
echo "(Sending data then immediately closing connection)"
echo ""

for i in $(seq 1 $NUM_CONNECTIONS); do
    (echo "GET_SYS_INFO" | nc -w 0 localhost $PORT &) 2>/dev/null
    sleep 0.02
done

echo "Waiting for all attempts to complete..."
sleep 2

echo ""
echo "Attack complete."
echo ""
echo "Expected behavior:"
echo "  - server_bad: May experience child process crashes"
echo "    (if write() occurs after client disconnect)"
echo "  - server_good: All child processes handle SIGPIPE gracefully"
echo "    (signal(SIGPIPE, SIG_IGN) working)"
echo ""
echo "Verify parent server is still running:"
echo "  pgrep -af 'server_(good|bad) $PORT'"
