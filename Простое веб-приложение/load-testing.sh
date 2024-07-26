#!/usr/bin/env bash
SERVER_IP="${SERVER_IP:-https://myapp-host.ru}"
for i in {1..10000}
do
  echo $i
  curl -k $SERVER_IP
done