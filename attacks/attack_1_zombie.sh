#!/bin/bash
# Attack 1: Zombie Process Attack - Ultra Simple

PORT="${1:-8080}"

echo "=== Attack 1: Zombie Process Attack ==="
echo "Port: $PORT"
echo ""

# Launch 20 clients
echo "Launching 20 clients..."
for i in {1..20}; do
    ./build/client 127.0.0.1 $PORT > /dev/null 2>&1 &
    echo -n "."
done
echo " done"

# Wait for all to finish
wait
sleep 1

echo ""
echo "Checking for zombie processes..."
echo ""

# Show all server_bad processes and their children
ps auxf | grep -E "(server_bad|defunct)" | grep -v grep

echo ""
echo "Zombie count:"
ps aux | grep defunct | grep -v grep | wc -l
