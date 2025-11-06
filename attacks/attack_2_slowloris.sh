#!/bin/bash

PORT=8080

for i in {1..15}
do
  ( nc localhost $PORT & )
done

# Keep the script running to maintain the connections
while true; do
  sleep 1
done
