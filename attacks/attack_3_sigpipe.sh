#!/bin/bash

PORT=8080

# This script will connect and immediately close the connection.
# The server might try to write to a closed socket, which would
# trigger a SIGPIPE if not handled.
for i in {1..20}
do
  ( echo "GET_SYS_INFO" | nc -w 0 localhost $PORT & )
done

wait
