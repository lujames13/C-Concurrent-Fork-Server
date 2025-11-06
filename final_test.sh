#!/bin/bash
echo "========================================="
echo "Story 1.7: Final Comprehensive Test"
echo "========================================="
echo ""
echo "Test 1: Client with debug mode (-d flag)"
./build/server_bad -d 9010 &
SRV_PID=$!
sleep 1
./build/client -d 127.0.0.1 9010 2>&1 | head -20
kill $SRV_PID 2>/dev/null
wait $SRV_PID 2>/dev/null
echo ""
echo "Test 2: Client_release with NDEBUG (no debug even with -d)"
./build/server_bad -d 9011 &
SRV_PID=$!
sleep 1
./build/client_release -d 127.0.0.1 9011 2>&1 | head -10
kill $SRV_PID 2>/dev/null
wait $SRV_PID 2>/dev/null
echo ""
echo "========================================="
echo "All Story 1.7 validations completed!"
echo "========================================="
