#!/bin/bash
# Attack 1: Zombie Process Attack
#
# Purpose:
#   Test SIGCHLD handling by creating many child processes that exit quickly.
#   Without proper SIGCHLD handling, these will become zombie processes.
#
# Expected Results:
#   - server_bad (NO_ROBUST): Will accumulate zombie processes
#   - server_good: Will properly reap all child processes (no zombies)
#
# Verification:
#   Run: ps aux | grep defunct | grep -v grep
#   Should show zombie processes for server_bad, none for server_good

PORT="${1:-8080}"
NUM_CONNECTIONS=20

echo "=== Attack 1: Zombie Process Attack ==="
echo "Target: localhost:$PORT"
echo "Connections: $NUM_CONNECTIONS"
echo ""

echo "Launching $NUM_CONNECTIONS rapid connect/disconnect cycles..."

for i in $(seq 1 $NUM_CONNECTIONS); do
    (echo "GET_SYS_INFO" | nc -w 1 localhost $PORT > /dev/null 2>&1 &)
    sleep 0.05
done

echo "Waiting for all connections to complete..."
sleep 2

echo ""
echo "Attack complete. To check for zombie processes, run:"
echo "  ps aux | grep defunct | grep -v grep"
echo ""
echo "Expected results:"
echo "  - server_bad: Will show zombie (defunct) processes"
echo "  - server_good: No zombie processes (SIGCHLD handler working)"
