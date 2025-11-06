#!/bin/bash

PORT=8080

for i in {1..20}
do
  ( (sleep 1; echo "QUIT") | nc localhost $PORT & )
done

wait