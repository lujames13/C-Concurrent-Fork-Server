#!/bin/bash
# Story 1.7 Logging System Test Script

echo "========================================="
echo "Story 1.7: 日誌系統整合測試"
echo "========================================="
echo ""

# Test 1: Without -d flag (INFO only)
echo "驗證 1: 不帶 -d 旗標 (應該只顯示 INFO 訊息)"
echo "-----------------------------------------"
./build/server_bad 9001 &
SRV_PID=$!
sleep 1
echo "Client output:"
./build/client 127.0.0.1 9001
kill $SRV_PID 2>/dev/null
wait $SRV_PID 2>/dev/null
echo ""
sleep 1

# Test 2: With -d flag (INFO + DEBUG)
echo "驗證 2: 帶 -d 旗標 (應該顯示 INFO 和 DEBUG 訊息)"
echo "-----------------------------------------"
./build/server_bad -d 9002 &
SRV_PID=$!
sleep 1
echo "Client output:"
./build/client -d 127.0.0.1 9002
kill $SRV_PID 2>/dev/null
wait $SRV_PID 2>/dev/null
echo ""

echo "========================================="
echo "測試完成!"
echo "========================================="
