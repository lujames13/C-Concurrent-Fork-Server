#!/bin/bash
# Attack 3: SIGPIPE Attack

# ✅ 修改參數處理
HOST="${1:-localhost}"   # 第一個參數是 HOST (IP)
PORT="${2:-8080}"        # 第二個參數是 PORT
NUM_CONNECTIONS=20

echo "=== Attack 3: SIGPIPE Attack ==="
echo "Target: $HOST:$PORT"  # 顯示正確的目標
echo "Connections: $NUM_CONNECTIONS (rapid disconnect)"
echo ""

echo "Launching $NUM_CONNECTIONS rapid connect/disconnect cycles..."
echo "(Sending data then immediately closing connection)"
echo ""

for i in $(seq 1 $NUM_CONNECTIONS); do
    # ✅ 使用 $HOST 變數而不是硬編碼的 localhost
    (echo "GET_SYS_INFO" | nc -w 0 $HOST $PORT &) 2>/dev/null
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
