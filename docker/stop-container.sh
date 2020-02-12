#!/bin/sh

echo "Stopping HAProxy"
kill -SIGUSR1 $(cat /run/haproxy.pid)

