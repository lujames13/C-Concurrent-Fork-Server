#!/bin/bash
# Script to capture network traffic for documentation

PORT=8091
PCAP_FILE="docs/network_capture.pcap"

echo "=== Network Traffic Capture for Documentation ==="
echo ""

# Check if running as root (needed for tcpdump)
if [ "$EUID" -ne 0 ]; then
    echo "Note: This script may need sudo for tcpdump"
    echo "If tcpdump fails, run with: sudo ./capture_traffic.sh"
    echo ""
fi

# Start tcpdump in background
echo "[1] Starting packet capture on port $PORT..."
tcpdump -i lo -w $PCAP_FILE port $PORT > /dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1

if ! ps -p $TCPDUMP_PID > /dev/null; then
    echo "ERROR: tcpdump failed to start"
    echo "Try: sudo ./capture_traffic.sh"
    exit 1
fi

echo "    tcpdump running (PID: $TCPDUMP_PID)"
echo ""

# Start server
echo "[2] Starting server_good on port $PORT..."
./build/server_good $PORT > /dev/null 2>&1 &
SERVER_PID=$!
sleep 1

if ! ps -p $SERVER_PID > /dev/null; then
    echo "ERROR: Server failed to start"
    kill $TCPDUMP_PID
    exit 1
fi

echo "    server_good running (PID: $SERVER_PID)"
echo ""

# Send client request
echo "[3] Sending client request..."
./build/client 127.0.0.1 $PORT > /dev/null 2>&1
sleep 1
echo "    Request completed"
echo ""

# Stop capture
echo "[4] Stopping packet capture..."
kill $TCPDUMP_PID 2>/dev/null
kill $SERVER_PID 2>/dev/null
wait $TCPDUMP_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
echo ""

# Analyze capture
echo "[5] Packet capture saved to: $PCAP_FILE"
echo ""

if [ -f "$PCAP_FILE" ]; then
    PACKET_COUNT=$(tcpdump -r $PCAP_FILE 2>/dev/null | wc -l)
    echo "    Total packets captured: $PACKET_COUNT"
    echo ""

    echo "=== Packet Analysis Preview ==="
    echo ""
    echo "First 10 packets:"
    tcpdump -r $PCAP_FILE -n -c 10 2>/dev/null
    echo ""

    echo "To view full capture:"
    echo "  tcpdump -r $PCAP_FILE -A"
    echo ""
    echo "To analyze in Wireshark:"
    echo "  wireshark $PCAP_FILE"
else
    echo "ERROR: Capture file not created"
    exit 1
fi

echo ""
echo "=== Capture Complete ==="
